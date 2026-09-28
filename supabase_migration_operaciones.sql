-- Migración para Módulo de Operaciones: 3 nuevos campos
-- Ejecutar en Supabase SQL Editor

-- 1. Supervisor responsable en las asignaciones de turno
ALTER TABLE shift_assignments 
ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES users(id);

-- 2. Incidencias y observaciones en las asistencias
ALTER TABLE attendances 
ADD COLUMN IF NOT EXISTS notes TEXT;

-- 3. Historial de cambios de asignación
CREATE TABLE IF NOT EXISTS assignment_change_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id UUID,
  user_id UUID REFERENCES users(id),
  changed_by UUID REFERENCES users(id),
  change_type TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE assignment_change_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_ven_historial_cambios" ON assignment_change_log;
CREATE POLICY "admins_ven_historial_cambios" ON assignment_change_log
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "admins_insertan_historial_cambios" ON assignment_change_log;
CREATE POLICY "admins_insertan_historial_cambios" ON assignment_change_log
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin(auth.uid()));
