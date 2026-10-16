-- Conserva las ventas anteriores sin asignarles claves. Respaldar antes de aplicar.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
ALTER TABLE venta ADD COLUMN IF NOT EXISTS clave_pedido VARCHAR(64), ADD COLUMN IF NOT EXISTS huella_pedido VARCHAR(64);
DO $$ BEGIN
    IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='venta'::regclass AND conname='venta_clave_huella_pedido') THEN
        ALTER TABLE venta ADD CONSTRAINT venta_clave_huella_pedido CHECK (
            (clave_pedido IS NULL AND huella_pedido IS NULL) OR
            (clave_pedido IS NOT NULL AND huella_pedido IS NOT NULL AND
             clave_pedido ~ '^[a-f0-9]{32,64}$' AND huella_pedido ~ '^[a-f0-9]{64}$')
        );
    END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_venta_clave_pedido ON venta(clave_pedido);
COMMIT;
