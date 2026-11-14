-- =============================================================================
-- CañaScan · Seguridad de cuadrillas, recuperación de PIN y políticas RLS
-- -----------------------------------------------------------------------------
-- Ejecutar COMPLETO en Supabase → SQL Editor (una sola vez; es re-ejecutable).
--
-- Qué hace:
--   1. Funciones RPC (security definer) para todas las operaciones sensibles:
--      registro de perfil, recuperación de PIN, cuadrillas y tratamiento.
--   2. Guarda la respuesta de auxilio como hash bcrypt (y migra las existentes).
--   3. Limita intentos de recuperación de PIN (5 fallos / 15 min por DNI).
--   4. Reemplaza TODAS las políticas de perfiles, grupos e historial_escaneos
--      por políticas mínimas, y quita permisos de escritura directa.
--   5. Políticas del bucket 'escaneos' (cada usuario solo escribe en su carpeta).
--   6. Repara datos inconsistentes de 'rol'.
-- =============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- 1. Funciones auxiliares
-- -----------------------------------------------------------------------------

-- Grupo activo del usuario actual (security definer para evitar recursión RLS)
create or replace function public.mi_grupo_id()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select grupo_id from public.perfiles where id = auth.uid();
$$;

-- Mueve al usuario a otra cuadrilla que lidere (la más reciente) o lo deja libre
create or replace function public._reubicar_usuario(p_uid uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_otro uuid;
begin
  select id into v_otro
    from public.grupos
   where lider_id = p_uid
   order by created_at desc
   limit 1;

  update public.perfiles
     set grupo_id = v_otro,
         rol = case when v_otro is null then 'empleado' else 'lider' end
   where id = p_uid;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Registro y recuperación de PIN
-- -----------------------------------------------------------------------------

create table if not exists public.intentos_recuperacion (
  id bigint generated always as identity primary key,
  dni text not null,
  created_at timestamptz not null default now()
);
create index if not exists intentos_recuperacion_dni_idx
  on public.intentos_recuperacion (dni, created_at);
alter table public.intentos_recuperacion enable row level security;
revoke all on public.intentos_recuperacion from anon, authenticated;

-- Hashear respuestas de auxilio que aún estén en texto plano
update public.perfiles
   set respuesta_auxilio = extensions.crypt(lower(trim(respuesta_auxilio)), extensions.gen_salt('bf', 10))
 where respuesta_auxilio is not null
   and respuesta_auxilio !~ '^\$2[abxy]?\$';

-- Crea el perfil del usuario recién registrado. El DNI se toma del email
-- interno (DNI@canascan.app), así nadie puede reclamar un DNI ajeno.
create or replace function public.registrar_perfil(
  p_nombre text,
  p_pregunta text,
  p_respuesta text
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_dni text;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para completar el registro.';
  end if;

  select split_part(email, '@', 1) into v_dni from auth.users where id = v_uid;
  if v_dni is null or v_dni !~ '^\d{8}$' then
    raise exception 'La cuenta no corresponde a un DNI válido.';
  end if;
  if length(trim(coalesce(p_nombre, ''))) < 3 then
    raise exception 'Ingresa tu nombre completo.';
  end if;
  if length(trim(coalesce(p_respuesta, ''))) < 2 then
    raise exception 'La respuesta de auxilio es muy corta.';
  end if;

  insert into public.perfiles
    (id, dni, nombre_completo, pregunta_auxilio, respuesta_auxilio, rol, grupo_id)
  values
    (v_uid, v_dni, trim(p_nombre), trim(p_pregunta),
     extensions.crypt(lower(trim(p_respuesta)), extensions.gen_salt('bf', 10)),
     'empleado', null)
  on conflict (id) do nothing;
end;
$$;

-- Devuelve solo la pregunta (se usa sin sesión)
create or replace function public.obtener_pregunta_auxilio(p_dni text)
returns text
language sql stable security definer
set search_path = ''
as $$
  -- Si el DNI no existe se devuelve una pregunta ficticia (siempre la misma
  -- para ese DNI) para no revelar qué DNIs están registrados.
  select coalesce(
    (select pregunta_auxilio from public.perfiles where dni = trim(p_dni)),
    (array[
      '¿Cuál es el nombre de tu mamá?',
      '¿Cuál es el nombre de tu pueblo o caserío natal?',
      '¿Cuál es el nombre de tu primera mascota?',
      '¿Cuál es el nombre de tu hacienda o finca favorita?'
    ])[1 + ((hashtext(trim(coalesce(p_dni, '')))::bigint % 4) + 4) % 4]
  );

$$;

-- Restablece el PIN si la respuesta coincide. Devuelve un estado en vez de
-- lanzar excepción para que el registro del intento fallido no se revierta:
--   'ok' | 'respuesta_incorrecta' | 'bloqueado' | 'pin_invalido'
create or replace function public.restablecer_pin(
  p_dni text,
  p_respuesta text,
  p_nuevo_pin text
)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_dni text := trim(p_dni);
  v_id uuid;
  v_hash text;
  v_fallos int;
begin
  if coalesce(p_nuevo_pin, '') !~ '^\d{4,6}$' then
    return 'pin_invalido';
  end if;

  select count(*) into v_fallos
    from public.intentos_recuperacion
   where dni = v_dni
     and created_at > now() - interval '15 minutes';
  if v_fallos >= 5 then
    return 'bloqueado';
  end if;

  select id, respuesta_auxilio into v_id, v_hash
    from public.perfiles
   where dni = v_dni;

  if v_id is null or v_hash is null
     or extensions.crypt(lower(trim(coalesce(p_respuesta, ''))), v_hash) <> v_hash then
    insert into public.intentos_recuperacion (dni) values (v_dni);
    return 'respuesta_incorrecta';
  end if;

  update auth.users
     set encrypted_password = extensions.crypt('pin_' || p_nuevo_pin, extensions.gen_salt('bf', 10)),
         updated_at = now()
   where id = v_id;

  delete from public.intentos_recuperacion where dni = v_dni;
  return 'ok';
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Cuadrillas
-- -----------------------------------------------------------------------------

create or replace function public.crear_grupo(p_nombre text)
returns public.grupos
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_codigo text;
  v_grupo public.grupos;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para crear una cuadrilla.';
  end if;
  if length(trim(coalesce(p_nombre, ''))) < 3 then
    raise exception 'El nombre de la cuadrilla debe tener al menos 3 letras.';
  end if;

  loop
    v_codigo := 'CANA-' || lpad(floor(random() * 10000)::int::text, 4, '0');
    exit when not exists (
      select 1 from public.grupos where codigo_invitacion = v_codigo
    );
  end loop;

  insert into public.grupos (nombre, codigo_invitacion, lider_id)
  values (trim(p_nombre), v_codigo, v_uid)
  returning * into v_grupo;

  update public.perfiles
     set grupo_id = v_grupo.id, rol = 'lider'
   where id = v_uid;

  return v_grupo;
end;
$$;

create or replace function public.unirse_a_grupo(p_codigo text)
returns public.grupos
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_codigo text := upper(trim(coalesce(p_codigo, '')));
  v_grupo public.grupos;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para unirte a una cuadrilla.';
  end if;

  select * into v_grupo from public.grupos where codigo_invitacion = v_codigo;
  if v_grupo.id is null then
    raise exception 'No se encontró ninguna cuadrilla con el código %.', v_codigo;
  end if;

  update public.perfiles
     set grupo_id = v_grupo.id,
         rol = case when v_grupo.lider_id = v_uid then 'lider' else 'empleado' end
   where id = v_uid;

  return v_grupo;
end;
$$;

create or replace function public.cambiar_grupo_activo(p_grupo_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not exists (
    select 1 from public.grupos where id = p_grupo_id and lider_id = v_uid
  ) then
    raise exception 'Solo puedes activar cuadrillas que lideras.';
  end if;

  update public.perfiles
     set grupo_id = p_grupo_id, rol = 'lider'
   where id = v_uid;
end;
$$;

create or replace function public.salir_de_grupo()
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_actual uuid;
begin
  select grupo_id into v_actual from public.perfiles where id = v_uid;
  if v_actual is null then
    return;
  end if;

  if exists (
    select 1 from public.grupos where id = v_actual and lider_id = v_uid
  ) then
    raise exception 'Eres el líder: transfiere el liderazgo o disuelve la cuadrilla antes de salir.';
  end if;

  perform public._reubicar_usuario(v_uid);
end;
$$;

create or replace function public.remover_miembro(p_usuario_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_grupo uuid;
begin
  if p_usuario_id = v_uid then
    raise exception 'No puedes removerte a ti mismo.';
  end if;

  select grupo_id into v_grupo from public.perfiles where id = p_usuario_id;
  if v_grupo is null or not exists (
    select 1 from public.grupos where id = v_grupo and lider_id = v_uid
  ) then
    raise exception 'Solo el líder de la cuadrilla puede remover a sus integrantes.';
  end if;

  perform public._reubicar_usuario(p_usuario_id);
end;
$$;

create or replace function public.transferir_liderazgo(
  p_grupo_id uuid,
  p_nuevo_lider uuid
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not exists (
    select 1 from public.grupos where id = p_grupo_id and lider_id = v_uid
  ) then
    raise exception 'Solo el líder actual puede transferir el liderazgo.';
  end if;
  if p_nuevo_lider = v_uid then
    raise exception 'Elige a otro integrante como nuevo líder.';
  end if;
  if not exists (
    select 1 from public.perfiles where id = p_nuevo_lider and grupo_id = p_grupo_id
  ) then
    raise exception 'El nuevo líder debe ser integrante de la cuadrilla.';
  end if;

  update public.grupos set lider_id = p_nuevo_lider where id = p_grupo_id;
  update public.perfiles set rol = 'lider' where id = p_nuevo_lider;

  -- El líder saliente deja la cuadrilla solo si era su cuadrilla activa
  if (select grupo_id from public.perfiles where id = v_uid) = p_grupo_id then
    perform public._reubicar_usuario(v_uid);
  end if;
end;
$$;

create or replace function public.disolver_cuadrilla(p_grupo_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_miembros uuid[];
  v_miembro uuid;
begin
  if not exists (
    select 1 from public.grupos where id = p_grupo_id and lider_id = v_uid
  ) then
    raise exception 'Solo el líder puede disolver la cuadrilla.';
  end if;

  select coalesce(array_agg(id), '{}') into v_miembros
    from public.perfiles where grupo_id = p_grupo_id;

  -- Los reportes se conservan en el historial personal de cada autor
  update public.historial_escaneos set grupo_id = null where grupo_id = p_grupo_id;
  update public.perfiles set grupo_id = null, rol = 'empleado' where grupo_id = p_grupo_id;
  delete from public.grupos where id = p_grupo_id;

  -- Quien lidere otras cuadrillas pasa a una de ellas
  foreach v_miembro in array v_miembros loop
    perform public._reubicar_usuario(v_miembro);
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Tratamiento de focos
-- -----------------------------------------------------------------------------

-- Puede actualizar: el líder de la cuadrilla del escaneo, o el autor si el
-- escaneo es personal (sin cuadrilla).
create or replace function public.actualizar_tratamiento(
  p_scan_id uuid,
  p_estado text,
  p_notas text default null
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_autor uuid;
  v_grupo uuid;
begin
  if p_estado not in ('pendiente', 'tratado', 'descartado') then
    raise exception 'Estado de tratamiento no válido.';
  end if;

  select user_id, grupo_id into v_autor, v_grupo
    from public.historial_escaneos where id = p_scan_id;
  if not found then
    raise exception 'El registro ya no existe.';
  end if;

  if not (
    (v_grupo is null and v_autor = v_uid)
    or (v_grupo is not null and exists (
      select 1 from public.grupos where id = v_grupo and lider_id = v_uid
    ))
  ) then
    raise exception 'Solo el líder de la cuadrilla puede actualizar el tratamiento.';
  end if;

  update public.historial_escaneos
     set estado_tratamiento = p_estado,
         tratado_por = case when p_estado = 'pendiente' then null else v_uid end,
         fecha_tratamiento = case when p_estado = 'pendiente' then null else now() end,
         notas_tratamiento = p_notas
   where id = p_scan_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. Permisos de ejecución de las funciones
-- -----------------------------------------------------------------------------

revoke all on function public._reubicar_usuario(uuid) from public, anon, authenticated;

revoke all on function public.mi_grupo_id() from public, anon;
grant execute on function public.mi_grupo_id() to authenticated;

revoke all on function public.obtener_pregunta_auxilio(text) from public;
grant execute on function public.obtener_pregunta_auxilio(text) to anon, authenticated;

revoke all on function public.restablecer_pin(text, text, text) from public;
grant execute on function public.restablecer_pin(text, text, text) to anon, authenticated;

revoke all on function public.registrar_perfil(text, text, text) from public, anon;
revoke all on function public.crear_grupo(text) from public, anon;
revoke all on function public.unirse_a_grupo(text) from public, anon;
revoke all on function public.cambiar_grupo_activo(uuid) from public, anon;
revoke all on function public.salir_de_grupo() from public, anon;
revoke all on function public.remover_miembro(uuid) from public, anon;
revoke all on function public.transferir_liderazgo(uuid, uuid) from public, anon;
revoke all on function public.disolver_cuadrilla(uuid) from public, anon;
revoke all on function public.actualizar_tratamiento(uuid, text, text) from public, anon;

grant execute on function public.registrar_perfil(text, text, text) to authenticated;
grant execute on function public.crear_grupo(text) to authenticated;
grant execute on function public.unirse_a_grupo(text) to authenticated;
grant execute on function public.cambiar_grupo_activo(uuid) to authenticated;
grant execute on function public.salir_de_grupo() to authenticated;
grant execute on function public.remover_miembro(uuid) to authenticated;
grant execute on function public.transferir_liderazgo(uuid, uuid) to authenticated;
grant execute on function public.disolver_cuadrilla(uuid) to authenticated;
grant execute on function public.actualizar_tratamiento(uuid, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Políticas RLS (se borran todas las anteriores de estas tablas)
-- -----------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select policyname, tablename
      from pg_policies
     where schemaname = 'public'
       and tablename in ('perfiles', 'grupos', 'historial_escaneos')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end;
$$;

alter table public.perfiles enable row level security;
alter table public.grupos enable row level security;
alter table public.historial_escaneos enable row level security;

-- perfiles: solo lectura de columnas no sensibles; escritura vía RPC
revoke all on public.perfiles from anon;
revoke select, insert, update, delete on public.perfiles from authenticated;
grant select (id, dni, nombre_completo, pregunta_auxilio, grupo_id, rol, created_at, updated_at)
  on public.perfiles to authenticated;
grant update (nombre_completo) on public.perfiles to authenticated;

create policy "perfiles_select_propio_y_cuadrilla"
  on public.perfiles for select to authenticated
  using (
    id = (select auth.uid())
    or grupo_id = (select public.mi_grupo_id())
    or id in (select lider_id from public.grupos where id = (select public.mi_grupo_id()))
  );

create policy "perfiles_update_propio"
  on public.perfiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- grupos: solo ves las cuadrillas que lideras o a la que perteneces
revoke all on public.grupos from anon;
revoke insert, update, delete on public.grupos from authenticated;

create policy "grupos_select_miembro_o_lider"
  on public.grupos for select to authenticated
  using (
    lider_id = (select auth.uid())
    or id = (select public.mi_grupo_id())
  );

-- historial_escaneos: el tratamiento se actualiza vía RPC
revoke all on public.historial_escaneos from anon;
revoke update on public.historial_escaneos from authenticated;

create policy "historial_select_propio_y_cuadrilla"
  on public.historial_escaneos for select to authenticated
  using (
    user_id = (select auth.uid())
    or (grupo_id is not null and grupo_id = (select public.mi_grupo_id()))
  );

create policy "historial_insert_propio"
  on public.historial_escaneos for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (grupo_id is null or grupo_id = (select public.mi_grupo_id()))
  );

create policy "historial_delete_propio"
  on public.historial_escaneos for delete to authenticated
  using (user_id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- 7. Storage: bucket 'escaneos' (lectura pública por URL; escritura por carpeta)
-- -----------------------------------------------------------------------------

drop policy if exists "escaneos_insert_propio" on storage.objects;
create policy "escaneos_insert_propio"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'escaneos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "escaneos_select_propio" on storage.objects;
create policy "escaneos_select_propio"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'escaneos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "escaneos_delete_propio" on storage.objects;
create policy "escaneos_delete_propio"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'escaneos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- -----------------------------------------------------------------------------
-- 8. Reparar datos: 'rol' debe reflejar si lidera su cuadrilla activa
-- -----------------------------------------------------------------------------

update public.perfiles p
   set rol = case
               when exists (
                 select 1 from public.grupos g
                  where g.id = p.grupo_id and g.lider_id = p.id
               ) then 'lider'
               else 'empleado'
             end;

commit;
