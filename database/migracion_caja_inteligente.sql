-- Migracion para lectura contable de caja y clasificacion de ventas.
-- No reemplaza tablas existentes: organiza la informacion financiera actual.

CREATE OR REPLACE VIEW vw_movimientos_caja AS
SELECT
    'venta' AS origen,
    v.id_venta AS id_origen,
    v.fecha,
    'entrada' AS movimiento,
    'ventas' AS clasificacion,
    'Venta #' || v.id_venta AS concepto,
    v.total::numeric AS valor
FROM venta v
WHERE v.estado IN ('pagada', 'devuelta')

UNION ALL

SELECT
    'devolucion' AS origen,
    d.id_devolucion AS id_origen,
    d.fecha,
    'salida' AS movimiento,
    'devoluciones' AS clasificacion,
    'Devolucion venta #' || d.id_venta AS concepto,
    d.total_devuelto::numeric AS valor
FROM devolucion d
WHERE d.estado = 'aprobada'

UNION ALL

SELECT
    'compra_mercancia' AS origen,
    c.id_compra AS id_origen,
    c.fecha,
    'salida' AS movimiento,
    'mercancia' AS clasificacion,
    'Compra de mercancia #' || c.id_compra AS concepto,
    c.total_compra::numeric AS valor
FROM compra_mercancia c

UNION ALL

SELECT
    'gasto' AS origen,
    g.id_gasto AS id_origen,
    g.fecha,
    'salida' AS movimiento,
    CASE
        WHEN g.tipo = 'nomina' THEN 'trabajadores'
        WHEN g.tipo IN ('servicio', 'primario') THEN 'servicios_renta'
        WHEN g.tipo IN ('empaque', 'publicidad', 'transporte') THEN 'operacion_venta'
        ELSE 'otros_gastos'
    END AS clasificacion,
    g.concepto,
    g.valor::numeric AS valor
FROM gasto_negocio g

UNION ALL

SELECT
    'pago_trabajador' AS origen,
    p.id_pago_trabajador AS id_origen,
    p.fecha,
    'salida' AS movimiento,
    'trabajadores' AS clasificacion,
    'Pago trabajador #' || p.id_pago_trabajador AS concepto,
    p.valor::numeric AS valor
FROM pago_trabajador p

UNION ALL

SELECT
    'inversion' AS origen,
    i.id_inversion AS id_origen,
    i.fecha,
    'entrada' AS movimiento,
    'capital_inversion' AS clasificacion,
    i.concepto,
    i.valor::numeric AS valor
FROM inversion_negocio i;

CREATE OR REPLACE VIEW vw_clasificacion_venta AS
SELECT
    v.id_venta,
    v.fecha,
    v.total::numeric AS total_venta,
    COALESCE(v.iva, 0)::numeric AS para_iva,
    COALESCE(SUM(dv.subtotal_costo), 0)::numeric AS para_reponer_mercancia,
    (v.total - COALESCE(v.iva, 0) - COALESCE(SUM(dv.subtotal_costo), 0))::numeric AS utilidad_bruta_estimada
FROM venta v
LEFT JOIN detalle_venta dv
    ON v.id_venta = dv.id_venta
WHERE v.estado IN ('pagada', 'devuelta')
GROUP BY v.id_venta, v.fecha, v.total, v.iva;

CREATE OR REPLACE VIEW vw_resumen_caja_mensual AS
SELECT
    DATE_TRUNC('month', fecha)::date AS mes,
    COALESCE(SUM(CASE WHEN movimiento = 'entrada' THEN valor ELSE 0 END), 0)::numeric AS entradas,
    COALESCE(SUM(CASE WHEN movimiento = 'salida' THEN valor ELSE 0 END), 0)::numeric AS salidas,
    COALESCE(SUM(CASE WHEN movimiento = 'entrada' THEN valor ELSE -valor END), 0)::numeric AS saldo_estimado
FROM vw_movimientos_caja
GROUP BY DATE_TRUNC('month', fecha)::date;
