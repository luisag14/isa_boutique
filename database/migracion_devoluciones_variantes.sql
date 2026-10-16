-- Conserva los detalles de devolucion existentes.
BEGIN;
ALTER TABLE detalle_devolucion
    ADD COLUMN IF NOT EXISTS id_detalle_venta INTEGER
    REFERENCES detalle_venta(id_detalle_venta) ON DELETE RESTRICT;

-- Solo vincular historicos cuando existe una unica linea candidata.
UPDATE detalle_devolucion dd
SET id_detalle_venta = dv.id_detalle_venta
FROM devolucion d, detalle_venta dv
WHERE dd.id_devolucion = d.id_devolucion
AND dv.id_venta = d.id_venta AND dv.id_producto = dd.id_producto
AND dd.id_detalle_venta IS NULL
AND (SELECT COUNT(*) FROM detalle_venta candidato
     WHERE candidato.id_venta = d.id_venta AND candidato.id_producto = dd.id_producto) = 1;

CREATE INDEX IF NOT EXISTS idx_devolucion_detalle_venta ON detalle_devolucion(id_detalle_venta);
COMMIT;
