ALTER TABLE venta
ADD COLUMN IF NOT EXISTS canal_venta VARCHAR(30) NOT NULL DEFAULT 'tienda_fisica';

ALTER TABLE venta
DROP CONSTRAINT IF EXISTS venta_canal_venta_check;

ALTER TABLE venta
ADD CONSTRAINT venta_canal_venta_check
CHECK (canal_venta IN ('tienda_fisica', 'pagina_web', 'whatsapp', 'instagram'));
