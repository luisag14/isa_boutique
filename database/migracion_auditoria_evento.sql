BEGIN;

CREATE TABLE IF NOT EXISTS auditoria_evento (
    id_auditoria BIGSERIAL PRIMARY KEY,
    id_usuario INTEGER NULL REFERENCES usuario_sistema(id_usuario) ON DELETE SET NULL,
    rol VARCHAR(30),
    accion VARCHAR(80) NOT NULL,
    entidad VARCHAR(80),
    id_entidad VARCHAR(80),
    detalle JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip VARCHAR(64),
    user_agent TEXT,
    fecha TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE auditoria_evento
    ADD COLUMN IF NOT EXISTS id_usuario INTEGER NULL REFERENCES usuario_sistema(id_usuario) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS rol VARCHAR(30),
    ADD COLUMN IF NOT EXISTS accion VARCHAR(80),
    ADD COLUMN IF NOT EXISTS entidad VARCHAR(80),
    ADD COLUMN IF NOT EXISTS id_entidad VARCHAR(80),
    ADD COLUMN IF NOT EXISTS detalle JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS ip VARCHAR(64),
    ADD COLUMN IF NOT EXISTS user_agent TEXT;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'auditoria_evento'
        AND column_name = 'operacion'
    ) THEN
        UPDATE auditoria_evento
        SET accion = COALESCE(accion, operacion),
            entidad = COALESCE(entidad, tabla_afectada),
            id_entidad = COALESCE(id_entidad, llave_registro),
            detalle = COALESCE(detalle, '{}'::jsonb)
        WHERE accion IS NULL;
    END IF;

    -- Conservar los campos historicos sin exigirlos en los eventos nuevos.
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'auditoria_evento'
        AND column_name = 'operacion'
    ) THEN
        ALTER TABLE auditoria_evento ALTER COLUMN operacion DROP NOT NULL;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'auditoria_evento'
        AND column_name = 'tabla_afectada'
    ) THEN
        ALTER TABLE auditoria_evento ALTER COLUMN tabla_afectada DROP NOT NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_auditoria_evento_fecha
    ON auditoria_evento (fecha DESC);

CREATE INDEX IF NOT EXISTS idx_auditoria_evento_accion
    ON auditoria_evento (accion);

CREATE INDEX IF NOT EXISTS idx_auditoria_evento_usuario
    ON auditoria_evento (id_usuario);

COMMIT;
