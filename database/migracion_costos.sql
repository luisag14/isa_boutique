-- Migracion para calcular utilidad real con costo de mercancia.
-- Ejecutar una sola vez sobre la base isa_boutiquevs.

ALTER TABLE producto
ADD COLUMN IF NOT EXISTS costo_unitario NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (costo_unitario >= 0);

ALTER TABLE detalle_venta
ADD COLUMN IF NOT EXISTS costo_unitario NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (costo_unitario >= 0);

ALTER TABLE detalle_venta
ADD COLUMN IF NOT EXISTS subtotal_costo NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal_costo >= 0);

ALTER TABLE detalle_devolucion
ADD COLUMN IF NOT EXISTS costo_unitario NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (costo_unitario >= 0);

ALTER TABLE detalle_devolucion
ADD COLUMN IF NOT EXISTS subtotal_costo_devuelto NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal_costo_devuelto >= 0);

UPDATE detalle_venta dv
SET
    costo_unitario = p.costo_unitario,
    subtotal_costo = p.costo_unitario * dv.cantidad
FROM producto p
WHERE dv.id_producto = p.id_producto
AND dv.costo_unitario = 0;
