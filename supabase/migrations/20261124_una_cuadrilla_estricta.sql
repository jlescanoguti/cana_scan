-- =============================================================================
-- CañaScan · Regla estricta: Una sola cuadrilla por usuario a la vez
-- -----------------------------------------------------------------------------
-- Ejecutar en Supabase → SQL Editor.
--
-- Modificaciones:
--   1. Limpia cuadrillas huérfanas sin miembros activas de pruebas anteriores.
--   2. crear_grupo(): Valida que el usuario no pertenezca a ninguna cuadrilla.
--   3. unirse_a_grupo(): Valida que el usuario no pertenezca a ninguna cuadrilla.
--   4. _reubicar_usuario(): Si el usuario sale o es removido, limpia su perfil
--      (grupo_id = null, rol = 'empleado') sin buscar "otras cuadrillas".
--   5. Elimina la función obsoleta cambiar_grupo_activo().
-- =============================================================================

begin;

-- 1. Limpiar cuadrillas huérfanas que no tienen ningún miembro asignado
delete from public.grupos
 where id not in (
   select distinct grupo_id 
     from public.perfiles 
    where grupo_id is not null
 );

-- 2. Actualizar función de reubicación: siempre deja al usuario libre
create or replace function public._reubicar_usuario(p_uid uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.perfiles
     set grupo_id = null,
         rol = 'empleado'
   where id = p_uid;
end;
$$;

-- 3. Crear cuadrilla: solo si no pertenece a ninguna
create or replace function public.crear_grupo(p_nombre text)
returns public.grupos
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_codigo text;
  v_grupo public.grupos;
  v_grupo_actual uuid;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para crear una cuadrilla.';
  end if;

  if length(trim(coalesce(p_nombre, ''))) < 3 then
    raise exception 'El nombre de la cuadrilla debe tener al menos 3 letras.';
  end if;

  -- Validar que el usuario no tenga ya una cuadrilla asignada en su perfil
  select grupo_id into v_grupo_actual from public.perfiles where id = v_uid;
  if v_grupo_actual is not null then
    raise exception 'Ya perteneces a una cuadrilla. Debes salir o disolver tu cuadrilla actual antes de crear una nueva.';
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

-- 4. Unirse a cuadrilla: solo si no pertenece a ninguna
create or replace function public.unirse_a_grupo(p_codigo text)
returns public.grupos
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_codigo text := upper(trim(coalesce(p_codigo, '')));
  v_grupo public.grupos;
  v_grupo_actual uuid;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión para unirte a una cuadrilla.';
  end if;

  -- Validar que el usuario no tenga ya una cuadrilla asignada
  select grupo_id into v_grupo_actual from public.perfiles where id = v_uid;
  if v_grupo_actual is not null then
    raise exception 'Ya perteneces a una cuadrilla. Debes salir de tu cuadrilla actual antes de unirte a otra.';
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

-- 5. Eliminar función obsoleta de cambio de grupo activo si existe
drop function if exists public.cambiar_grupo_activo(uuid);

commit;
