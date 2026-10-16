-- ============================================================
-- ISA BOUTIQUE - FACTURA FORMAL / COMPROBANTE INTERNO COLOMBIA
-- PostgreSQL
-- Agrega datos fiscales configurables, documento del cliente
-- y campos de anulacion sin borrar informacion existente.
-- ============================================================

ALTER TABLE cliente
ADD COLUMN IF NOT EXISTS tipo_documento VARCHAR(20) DEFAULT 'CC'
    CHECK (tipo_documento IN ('CC', 'CE', 'NIT', 'PASAPORTE', 'OTRO')),
ADD COLUMN IF NOT EXISTS numero_documento VARCHAR(40);

ALTER TABLE factura
ADD COLUMN IF NOT EXISTS observacion TEXT,
ADD COLUMN IF NOT EXISTS motivo_anulacion TEXT,
ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMP;

CREATE TABLE IF NOT EXISTS configuracion_facturacion (
    id_configuracion_facturacion SMALLINT PRIMARY KEY DEFAULT 1,
    nombre_comercial VARCHAR(120) NOT NULL DEFAULT 'Isa Boutique',
    razon_social VARCHAR(160) NOT NULL DEFAULT 'Isa Boutique',
    nit VARCHAR(40) NOT NULL DEFAULT 'Pendiente por registrar',
    regimen VARCHAR(120) NOT NULL DEFAULT 'Regimen no definido',
    direccion VARCHAR(180) NOT NULL DEFAULT 'Direccion pendiente',
    ciudad VARCHAR(80) NOT NULL DEFAULT 'Colombia',
    telefono VARCHAR(40) NOT NULL DEFAULT 'Pendiente',
    correo VARCHAR(120) NOT NULL DEFAULT 'contacto@isaboutique.com',
    actividad_economica VARCHAR(160) NOT NULL DEFAULT 'Comercio al por menor de prendas de vestir',
    nota_legal TEXT NOT NULL DEFAULT 'Comprobante interno generado por el sistema Isa Boutique. No equivale a factura electronica DIAN hasta que el negocio cuente con habilitacion, resolucion de numeracion y proveedor tecnologico autorizado.',
    tarifa_iva_general NUMERIC(5,2) NOT NULL DEFAULT 19.00 CHECK (tarifa_iva_general >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT configuracion_facturacion_unica CHECK (id_configuracion_facturacion = 1)
);

INSERT INTO configuracion_facturacion (
    id_configuracion_facturacion,
    nombre_comercial,
    razon_social,
    nit,
    regimen,
    direccion,
    ciudad,
    telefono,
    correo,
    actividad_economica
)
VALUES (
    1,
    'Isa Boutique',
    'Isa Boutique',
    'Pendiente por registrar',
    'Regimen no definido',
    'Direccion pendiente',
    'Colombia',
    'Pendiente',
    'contacto@isaboutique.com',
    'Comercio al por menor de prendas de vestir'
)
ON CONFLICT (id_configuracion_facturacion) DO NOTHING;

CREATE OR REPLACE VIEW vw_factura_formal AS
SELECT
    f.id_factura,
    f.numero_factura,
    f.fecha AS fecha_factura,
    f.estado AS estado_factura,
    f.subtotal,
    f.descuento,
    f.base_gravable,
    f.iva,
    f.tarifa_iva,
    f.precio_incluye_iva,
    f.total,
    f.observacion,
    f.motivo_anulacion,
    f.fecha_anulacion,
    v.id_venta,
    v.fecha AS fecha_venta,
    v.medio_pago,
    v.canal_venta,
    v.tipo_entrega,
    c.nombre AS cliente,
    c.tipo_documento,
    c.numero_documento,
    c.telefono,
    c.correo,
    c.direccion,
    u.nombre AS atendido_por
FROM factura f
INNER JOIN venta v
    ON f.id_venta = v.id_venta
INNER JOIN cliente c
    ON v.id_cliente = c.id_cliente
INNER JOIN usuario_sistema u
    ON v.id_usuario = u.id_usuario;
