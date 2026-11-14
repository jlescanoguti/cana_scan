-- =============================================================================
-- CañaScan · Limpieza de políticas antiguas del bucket 'escaneos'
-- -----------------------------------------------------------------------------
-- Las políticas de Storage se combinan con OR: mientras existan las antiguas,
-- las nuevas (escaneos_*_propio, por carpeta de usuario) no restringen nada.
--
-- Tras esta limpieza:
--   · Cada usuario solo sube, lista y borra fotos en su carpeta {user_id}/.
--   · Las fotos se siguen viendo por su URL pública (el bucket es público y
--     esa lectura no pasa por RLS), pero nadie puede listar el bucket entero.
-- =============================================================================

begin;

drop policy if exists "Permitir a los usuarios eliminar sus fotos en escaneos" on storage.objects;
drop policy if exists "Permitir a usuarios autenticados subir fotos a escaneos" on storage.objects;
drop policy if exists "Permitir lectura publica de fotos en escaneos" on storage.objects;

commit;
