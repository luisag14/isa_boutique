ALTER TABLE venta
ADD COLUMN IF NOT EXISTS subtotal_bruto NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS descuento NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_gravable NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS iva NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS tarifa_iva NUMERIC(5,2) NOT NULL DEFAULT 19.00,
ADD COLUMN IF NOT EXISTS precio_incluye_iva BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE detalle_venta
ADD COLUMN IF NOT EXISTS descuento NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_gravable NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS iva NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS tarifa_iva NUMERIC(5,2) NOT NULL DEFAULT 19.00,
ADD COLUMN IF NOT EXISTS precio_incluye_iva BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE factura
ADD COLUMN IF NOT EXISTS base_gravable NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS iva NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS tarifa_iva NUMERIC(5,2) NOT NULL DEFAULT 19.00,
ADD COLUMN IF NOT EXISTS precio_incluye_iva BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE venta
SET
    subtotal_bruto = CASE WHEN subtotal_bruto = 0 THEN total + descuento ELSE subtotal_bruto END,
    base_gravable = ROUND((CASE WHEN total > 0 THEN total ELSE subtotal_bruto END) / 1.19, 2),
    iva = (CASE WHEN total > 0 THEN total ELSE subtotal_bruto END) - ROUND((CASE WHEN total > 0 THEN total ELSE subtotal_bruto END) / 1.19, 2)
WHERE precio_incluye_iva = TRUE;

UPDATE detalle_venta
SET
    base_gravable = ROUND(subtotal / 1.19, 2),
    iva = subtotal - ROUND(subtotal / 1.19, 2)
WHERE precio_incluye_iva = TRUE;

UPDATE factura f
SET
    subtotal = COALESCE(v.subtotal_bruto, f.subtotal),
    descuento = COALESCE(v.descuento, f.descuento),
    base_gravable = COALESCE(v.base_gravable, f.base_gravable),
    iva = COALESCE(v.iva, f.iva),
    tarifa_iva = COALESCE(v.tarifa_iva, f.tarifa_iva),
    precio_incluye_iva = COALESCE(v.precio_incluye_iva, f.precio_incluye_iva),
    total = v.total
FROM venta v
WHERE f.id_venta = v.id_venta;
