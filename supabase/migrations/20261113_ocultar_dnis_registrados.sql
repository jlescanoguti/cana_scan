-- =============================================================================
-- CañaScan · No revelar qué DNIs están registrados
-- -----------------------------------------------------------------------------
-- Ejecutar en Supabase → SQL Editor. obtener_pregunta_auxilio se puede llamar
-- sin sesión; antes devolvía null para DNIs no registrados, lo que permitía
-- averiguar qué DNIs tienen cuenta. Ahora devuelve una pregunta ficticia
-- estable, y restablecer_pin ya responde 'respuesta_incorrecta' en ese caso.
-- (La misma corrección está incluida en 20261112_seguridad_cuadrillas.sql.)
-- =============================================================================

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

revoke all on function public.obtener_pregunta_auxilio(text) from public;
grant execute on function public.obtener_pregunta_auxilio(text) to anon, authenticated;
