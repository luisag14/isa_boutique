-- Respaldar antes de aplicar. No modifica usuarios, sesiones ni contrasenas.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE TABLE IF NOT EXISTS limite_acceso (
    clave VARCHAR(64) PRIMARY KEY CHECK (clave ~ '^[a-f0-9]{64}$'),
    intentos INTEGER NOT NULL CHECK (intentos > 0),
    vence_en TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_limite_acceso_vencimiento ON limite_acceso(vence_en);
COMMIT;
