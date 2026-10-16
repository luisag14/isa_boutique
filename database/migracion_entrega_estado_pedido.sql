ALTER TABLE venta
ADD COLUMN IF NOT EXISTS tipo_entrega VARCHAR(30) NOT NULL DEFAULT 'recoger_tienda';

ALTER TABLE venta
DROP CONSTRAINT IF EXISTS venta_tipo_entrega_check;

ALTER TABLE venta
ADD CONSTRAINT venta_tipo_entrega_check
CHECK (tipo_entrega IN ('recoger_tienda', 'envio_local', 'envio_nacional'));
