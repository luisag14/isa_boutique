-- Solo agrega indices; no modifica registros.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

CREATE INDEX IF NOT EXISTS idx_detalle_venta_venta ON detalle_venta(id_venta);
CREATE INDEX IF NOT EXISTS idx_detalle_venta_producto ON detalle_venta(id_producto);
CREATE INDEX IF NOT EXISTS idx_detalle_devolucion_devolucion ON detalle_devolucion(id_devolucion);
CREATE INDEX IF NOT EXISTS idx_detalle_devolucion_producto ON detalle_devolucion(id_producto);
CREATE INDEX IF NOT EXISTS idx_devolucion_venta_estado ON devolucion(id_venta,estado);
CREATE INDEX IF NOT EXISTS idx_venta_fecha ON venta(fecha);
CREATE INDEX IF NOT EXISTS idx_devolucion_fecha ON devolucion(fecha);
CREATE INDEX IF NOT EXISTS idx_gasto_negocio_fecha ON gasto_negocio(fecha);
CREATE INDEX IF NOT EXISTS idx_pago_trabajador_fecha ON pago_trabajador(fecha);
CREATE INDEX IF NOT EXISTS idx_compra_mercancia_fecha ON compra_mercancia(fecha);
CREATE INDEX IF NOT EXISTS idx_inversion_negocio_fecha ON inversion_negocio(fecha);
CREATE INDEX IF NOT EXISTS idx_cliente_telefono ON cliente(telefono);
CREATE INDEX IF NOT EXISTS idx_producto_imagen_producto ON producto_imagen(id_producto);

COMMIT;
