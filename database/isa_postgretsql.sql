-- =====================================================
-- BASE DE DATOS: ISA BOUTIQUE
-- PostgreSQL - Script final
-- =====================================================

-- =====================================================
-- LIMPIEZA PREVIA
-- =====================================================

DROP TABLE IF EXISTS auditoria_log CASCADE;
DROP TABLE IF EXISTS cambio_precio CASCADE;
DROP TABLE IF EXISTS movimiento_inventario CASCADE;
DROP TABLE IF EXISTS detalle_devolucion CASCADE;
DROP TABLE IF EXISTS devolucion CASCADE;
DROP TABLE IF EXISTS detalle_venta CASCADE;
DROP TABLE IF EXISTS venta CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS usuario_sistema CASCADE;

DROP TYPE IF EXISTS rol_usuario CASCADE;
DROP TYPE IF EXISTS estado_producto CASCADE;
DROP TYPE IF EXISTS estado_venta CASCADE;
DROP TYPE IF EXISTS medio_pago CASCADE;
DROP TYPE IF EXISTS estado_devolucion CASCADE;
DROP TYPE IF EXISTS tipo_movimiento CASCADE;


-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE rol_usuario AS ENUM (
    'admin',
    'vendedor'
);

CREATE TYPE estado_producto AS ENUM (
    'activo',
    'inactivo',
    'agotado'
);

CREATE TYPE estado_venta AS ENUM (
    'pagada',
    'pendiente',
    'cancelada',
    'devuelta'
);

CREATE TYPE medio_pago AS ENUM (
    'efectivo',
    'transferencia',
    'tarjeta_debito',
    'tarjeta_credito'
);

CREATE TYPE estado_devolucion AS ENUM (
    'pendiente',
    'aprobada',
    'rechazada'
);

CREATE TYPE tipo_movimiento AS ENUM (
    'ingreso_inicial',
    'ingreso_stock',
    'ajuste_stock',
    'venta',
    'devolucion',
    'activacion',
    'desactivacion',
    'eliminacion',
    'cambio_precio'
);


-- =====================================================
-- TABLA: USUARIOS DEL SISTEMA
-- =====================================================

CREATE TABLE usuario_sistema (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    contrasena VARCHAR(255) NOT NULL,
    rol rol_usuario NOT NULL DEFAULT 'vendedor',
    estado BOOLEAN DEFAULT TRUE,
    sesion_token VARCHAR(128),
    sesion_actualizada TIMESTAMP,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =====================================================
-- TABLA: CLIENTES
-- =====================================================

CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    correo VARCHAR(100),
    direccion TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =====================================================
-- TABLA: CATEGORÍAS
-- =====================================================

CREATE TABLE categoria (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(80) UNIQUE NOT NULL,
    descripcion TEXT,
    estado BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =====================================================
-- TABLA: PRODUCTOS
-- =====================================================

CREATE TABLE producto (
    id_producto SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    marca VARCHAR(80) NOT NULL,
    id_categoria INT NOT NULL,
    precio NUMERIC(12,2) NOT NULL CHECK (precio > 0),
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    estado estado_producto NOT NULL DEFAULT 'activo',
    imagen TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
);


-- =====================================================
-- TABLA: VENTAS
-- =====================================================

CREATE TABLE venta (
    id_venta SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_usuario INT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    medio_pago medio_pago NOT NULL,
    canal_venta VARCHAR(30) NOT NULL DEFAULT 'tienda_fisica'
        CHECK (canal_venta IN ('tienda_fisica', 'pagina_web', 'whatsapp', 'instagram')),
    tipo_entrega VARCHAR(30) NOT NULL DEFAULT 'recoger_tienda'
        CHECK (tipo_entrega IN ('recoger_tienda', 'envio_local', 'envio_nacional')),
    total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    estado estado_venta NOT NULL DEFAULT 'pagada',

    CONSTRAINT fk_venta_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente),

    CONSTRAINT fk_venta_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
);


-- =====================================================
-- TABLA: DETALLE DE VENTA
-- =====================================================

CREATE TABLE detalle_venta (
    id_detalle_venta SERIAL PRIMARY KEY,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),

    CONSTRAINT fk_detalle_venta
        FOREIGN KEY (id_venta)
        REFERENCES venta(id_venta)
        ON DELETE CASCADE,

    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);

-- =====================================================
-- TABLA: DEVOLUCIONES
-- =====================================================

CREATE TABLE devolucion (
    id_devolucion SERIAL PRIMARY KEY,
    id_venta INT NOT NULL,
    id_cliente INT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    motivo TEXT NOT NULL,
    total_devuelto NUMERIC(12,2) NOT NULL CHECK (total_devuelto >= 0),
    estado estado_devolucion NOT NULL DEFAULT 'aprobada',

    CONSTRAINT fk_devolucion_venta
        FOREIGN KEY (id_venta)
        REFERENCES venta(id_venta),

    CONSTRAINT fk_devolucion_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente)
);


-- =====================================================
-- TABLA: DETALLE DE DEVOLUCIÓN
-- =====================================================

CREATE TABLE detalle_devolucion (
    id_detalle_devolucion SERIAL PRIMARY KEY,
    id_devolucion INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal_devuelto NUMERIC(12,2) NOT NULL CHECK (subtotal_devuelto >= 0),

    CONSTRAINT fk_detalle_devolucion
        FOREIGN KEY (id_devolucion)
        REFERENCES devolucion(id_devolucion)
        ON DELETE CASCADE,

    CONSTRAINT fk_detalle_devolucion_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);


-- =====================================================
-- TABLA: MOVIMIENTOS DE INVENTARIO
-- =====================================================

CREATE TABLE movimiento_inventario (
    id_movimiento SERIAL PRIMARY KEY,
    id_producto INT NOT NULL,
    id_usuario INT,
    tipo tipo_movimiento NOT NULL,
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    detalle TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_movimiento_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto),

    CONSTRAINT fk_movimiento_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
);


-- =====================================================
-- TABLA: CAMBIOS DE PRECIO
-- =====================================================

CREATE TABLE cambio_precio (
    id_cambio_precio SERIAL PRIMARY KEY,
    id_producto INT NOT NULL,
    id_usuario INT,
    precio_anterior NUMERIC(12,2) NOT NULL CHECK (precio_anterior > 0),
    precio_nuevo NUMERIC(12,2) NOT NULL CHECK (precio_nuevo > 0),
    detalle TEXT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_cambio_precio_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto),

    CONSTRAINT fk_cambio_precio_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario),

    CONSTRAINT chk_precio_diferente
        CHECK (precio_anterior <> precio_nuevo)
);


-- =====================================================
-- TABLA: AUDITORÍA GENERAL
-- =====================================================

CREATE TABLE auditoria_log (
    id_auditoria SERIAL PRIMARY KEY,
    tabla_afectada VARCHAR(100) NOT NULL,
    operacion VARCHAR(20) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    usuario_bd VARCHAR(100) DEFAULT CURRENT_USER,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- FUNCIÓN: ACTUALIZAR ESTADO DEL PRODUCTO
-- =====================================================

CREATE OR REPLACE FUNCTION fn_actualizar_estado_producto()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad = 0 THEN
        NEW.estado := 'agotado';
    ELSIF NEW.cantidad > 0 AND NEW.estado = 'agotado' THEN
        NEW.estado := 'activo';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_estado_producto
BEFORE INSERT OR UPDATE OF cantidad
ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_estado_producto();


-- =====================================================
-- FUNCIÓN: DESCONTAR STOCK AL REGISTRAR VENTA
-- =====================================================

CREATE OR REPLACE FUNCTION fn_descontar_stock_venta()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad > (
        SELECT cantidad
        FROM producto
        WHERE id_producto = NEW.id_producto
    ) THEN
        RAISE EXCEPTION 'Stock insuficiente para realizar la venta';
    END IF;

    UPDATE producto
    SET cantidad = cantidad - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    INSERT INTO movimiento_inventario (
        id_producto,
        tipo,
        cantidad,
        detalle
    )
    VALUES (
        NEW.id_producto,
        'venta',
        NEW.cantidad,
        'Venta registrada y stock descontado automáticamente'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_descontar_stock_venta
AFTER INSERT
ON detalle_venta
FOR EACH ROW
EXECUTE FUNCTION fn_descontar_stock_venta();


-- =====================================================
-- FUNCIÓN: SUMAR STOCK AL REGISTRAR DEVOLUCIÓN
-- =====================================================

CREATE OR REPLACE FUNCTION fn_sumar_stock_devolucion()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE producto
    SET cantidad = cantidad + NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    INSERT INTO movimiento_inventario (
        id_producto,
        tipo,
        cantidad,
        detalle
    )
    VALUES (
        NEW.id_producto,
        'devolucion',
        NEW.cantidad,
        'Devolución registrada y stock aumentado automáticamente'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sumar_stock_devolucion
AFTER INSERT
ON detalle_devolucion
FOR EACH ROW
EXECUTE FUNCTION fn_sumar_stock_devolucion();


-- =====================================================
-- FUNCIÓN: REGISTRAR CAMBIO DE PRECIO
-- =====================================================

CREATE OR REPLACE FUNCTION fn_registrar_cambio_precio()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO cambio_precio (
            id_producto,
            precio_anterior,
            precio_nuevo,
            detalle
        )
        VALUES (
            OLD.id_producto,
            OLD.precio,
            NEW.precio,
            'Cambio de precio registrado automáticamente'
        );

        INSERT INTO movimiento_inventario (
            id_producto,
            tipo,
            cantidad,
            detalle
        )
        VALUES (
            OLD.id_producto,
            'cambio_precio',
            0,
            'Precio anterior: ' || OLD.precio || ' | Precio nuevo: ' || NEW.precio
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_registrar_cambio_precio
AFTER UPDATE OF precio
ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_cambio_precio();


-- =====================================================
-- FUNCIÓN: AUDITORÍA GENERAL
-- =====================================================

CREATE OR REPLACE FUNCTION fn_auditoria_general()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_log (
            tabla_afectada,
            operacion,
            datos_anteriores,
            datos_nuevos
        )
        VALUES (
            TG_TABLE_NAME,
            TG_OP,
            NULL,
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_log (
            tabla_afectada,
            operacion,
            datos_anteriores,
            datos_nuevos
        )
        VALUES (
            TG_TABLE_NAME,
            TG_OP,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_log (
            tabla_afectada,
            operacion,
            datos_anteriores,
            datos_nuevos
        )
        VALUES (
            TG_TABLE_NAME,
            TG_OP,
            to_jsonb(OLD),
            NULL
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- =====================================================
-- TRIGGERS DE AUDITORÍA
-- =====================================================

CREATE TRIGGER trg_auditoria_producto
AFTER INSERT OR UPDATE OR DELETE
ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria_general();

CREATE TRIGGER trg_auditoria_venta
AFTER INSERT OR UPDATE OR DELETE
ON venta
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria_general();

CREATE TRIGGER trg_auditoria_cliente
AFTER INSERT OR UPDATE OR DELETE
ON cliente
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria_general();

CREATE TRIGGER trg_auditoria_devolucion
AFTER INSERT OR UPDATE OR DELETE
ON devolucion
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria_general();

-- =====================================================
-- VISTA: INVENTARIO GENERAL
-- =====================================================

CREATE VIEW vista_inventario_general AS
SELECT 
    p.id_producto,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    c.nombre AS categoria,
    p.precio,
    p.cantidad,
    p.estado,
    p.imagen,
    p.fecha_creacion
FROM producto p
INNER JOIN categoria c
    ON p.id_categoria = c.id_categoria;


-- =====================================================
-- VISTA: VENTAS DETALLADAS
-- =====================================================

CREATE VIEW vista_ventas_detalladas AS
SELECT
    v.id_venta,
    v.fecha,
    cl.nombre AS cliente,
    cl.telefono,
    u.nombre AS usuario,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    dv.cantidad,
    dv.precio_unitario,
    dv.subtotal,
    v.medio_pago,
    v.canal_venta,
    v.tipo_entrega,
    v.total,
    v.estado
FROM venta v
INNER JOIN cliente cl
    ON v.id_cliente = cl.id_cliente
INNER JOIN usuario_sistema u
    ON v.id_usuario = u.id_usuario
INNER JOIN detalle_venta dv
    ON v.id_venta = dv.id_venta
INNER JOIN producto p
    ON dv.id_producto = p.id_producto;


-- =====================================================
-- VISTA: REPORTE MENSUAL
-- Ventas brutas, devoluciones y neto
-- =====================================================

CREATE VIEW vista_reporte_mensual AS
SELECT
    ventas_mes.mes,
    ventas_mes.ventas_brutas,
    COALESCE(devoluciones_mes.devoluciones, 0) AS devoluciones,
    ventas_mes.ventas_brutas - COALESCE(devoluciones_mes.devoluciones, 0) AS neto
FROM (
    SELECT
        DATE_TRUNC('month', v.fecha) AS mes,
        SUM(dv.subtotal) AS ventas_brutas
    FROM venta v
    INNER JOIN detalle_venta dv
        ON v.id_venta = dv.id_venta
    WHERE v.estado IN ('pagada', 'devuelta')
    GROUP BY DATE_TRUNC('month', v.fecha)
) ventas_mes
LEFT JOIN (
    SELECT
        DATE_TRUNC('month', d.fecha) AS mes,
        SUM(d.total_devuelto) AS devoluciones
    FROM devolucion d
    WHERE d.estado = 'aprobada'
    GROUP BY DATE_TRUNC('month', d.fecha)
) devoluciones_mes
ON ventas_mes.mes = devoluciones_mes.mes;


-- =====================================================
-- VISTA: PRODUCTO MÁS VENDIDO
-- Incluye ranking con función de ventana
-- =====================================================

CREATE VIEW vista_ranking_productos AS
SELECT
    p.id_producto,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    SUM(dv.cantidad) AS total_vendido,
    RANK() OVER (
        ORDER BY SUM(dv.cantidad) DESC
    ) AS ranking_producto
FROM producto p
INNER JOIN detalle_venta dv
    ON p.id_producto = dv.id_producto
INNER JOIN venta v
    ON dv.id_venta = v.id_venta
WHERE v.estado IN ('pagada', 'devuelta')
GROUP BY 
    p.id_producto,
    p.codigo,
    p.nombre,
    p.marca;


-- =====================================================
-- VISTA: VENTAS ACUMULADAS
-- Función de ventana
-- =====================================================

CREATE VIEW vista_ventas_acumuladas AS
SELECT
    v.id_venta,
    v.fecha,
    cl.nombre AS cliente,
    v.total,
    SUM(v.total) OVER (
        ORDER BY v.fecha
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS total_acumulado
FROM venta v
INNER JOIN cliente cl
    ON v.id_cliente = cl.id_cliente
WHERE v.estado = 'pagada';


-- =====================================================
-- FUNCIÓN: TOTAL DE VENTAS NETAS
-- =====================================================

CREATE OR REPLACE FUNCTION fn_total_ventas_netas()
RETURNS NUMERIC AS $$
DECLARE
    total_ventas NUMERIC;
    total_devoluciones NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total), 0)
    INTO total_ventas
    FROM venta
    WHERE estado IN ('pagada', 'devuelta');

    SELECT COALESCE(SUM(total_devuelto), 0)
    INTO total_devoluciones
    FROM devolucion
    WHERE estado = 'aprobada';

    RETURN total_ventas - total_devoluciones;
END;
$$ LANGUAGE plpgsql;


-- =====================================================
-- PROCEDIMIENTO: REGISTRAR MOVIMIENTO DE INVENTARIO
-- =====================================================

CREATE OR REPLACE PROCEDURE sp_registrar_movimiento(
    p_id_producto INT,
    p_id_usuario INT,
    p_tipo tipo_movimiento,
    p_cantidad INT,
    p_detalle TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO movimiento_inventario (
        id_producto,
        id_usuario,
        tipo,
        cantidad,
        detalle
    )
    VALUES (
        p_id_producto,
        p_id_usuario,
        p_tipo,
        p_cantidad,
        p_detalle
    );
END;
$$;


-- =====================================================
-- CONSULTAS ÚTILES PARA REPORTES
-- =====================================================

-- Productos con stock bajo
-- SELECT codigo, nombre, marca, cantidad, estado
-- FROM producto
-- WHERE cantidad <= 3
-- ORDER BY cantidad ASC;

-- Ventas por día
-- SELECT 
--     fecha::date AS dia,
--     SUM(total) AS total_vendido
-- FROM venta
-- WHERE estado IN ('pagada', 'devuelta')
-- GROUP BY fecha::date
-- ORDER BY dia DESC;

-- Movimientos de inventario
-- SELECT 
--     mi.fecha,
--     p.codigo,
--     p.nombre,
--     mi.tipo,
--     mi.cantidad,
--     mi.detalle
-- FROM movimiento_inventario mi
-- JOIN producto p ON mi.id_producto = p.id_producto
-- ORDER BY mi.fecha DESC;

-- Cambios de precio
-- SELECT 
--     cp.fecha,
--     p.codigo,
--     p.nombre,
--     cp.precio_anterior,
--     cp.precio_nuevo,
--     cp.detalle
-- FROM cambio_precio cp
-- JOIN producto p ON cp.id_producto = p.id_producto
-- ORDER BY cp.fecha DESC;

-- =====================================================
-- DATOS DE PRUEBA
-- =====================================================

-- Usuarios de referencia para las ventas de ejemplo: inactivos y sin clave utilizable.
-- Para habilitarlos, usar scripts/crear_usuario_inicial.php con una clave propia.
INSERT INTO usuario_sistema (nombre, correo, contrasena, rol, estado)
VALUES
('Administrador Isa Boutique', 'admin@isaboutique.com', '!SIN_ACCESO_INICIAL!', 'admin', FALSE),
('Vendedora Principal', 'vendedora@isaboutique.com', '!SIN_ACCESO_INICIAL!', 'vendedor', FALSE);

-- Categorías
INSERT INTO categoria (nombre, descripcion)
VALUES
('vestidos', 'Vestidos para ocasiones especiales'),
('blusas', 'Blusas femeninas y modernas'),
('conjuntos', 'Conjuntos completos'),
('shorts', 'Shorts y bermudas'),
('jeans', 'Jeans y pantalones'),
('bodys', 'Bodys femeninos'),
('faldas', 'Faldas para dama'),
('accesorios', 'Accesorios de moda');


-- Clientes
INSERT INTO cliente (nombre, telefono, correo, direccion)
VALUES
('María Pérez', '3001234567', 'maria@correo.com', 'Cartagena'),
('Laura Gómez', '3019876543', 'laura@correo.com', 'Cartagena'),
('Cliente Prueba', '3025558899', 'cliente@correo.com', 'Cartagena');


-- Productos
INSERT INTO producto (
    codigo,
    nombre,
    marca,
    id_categoria,
    precio,
    cantidad,
    imagen
)
VALUES
('IB-001', 'Vestido elegante rosa', 'ANWND', 1, 85000, 5, 'img/vestido1.png'),
('IB-002', 'Blusa crop blanca', 'Zenana', 2, 45000, 8, 'img/blusas.png'),
('IB-003', 'Short denim', 'Cello', 4, 70000, 6, 'img/Vermuda.jpg'),
('IB-004', 'Jean clásico', 'Beloved', 5, 120000, 4, 'img/pantalon.jpg'),
('IB-005', 'Falda casual', 'Isa Boutique', 7, 60000, 3, 'img/falda.jpg'),
('IB-006', 'Accesorio dorado', 'Isa Boutique', 8, 25000, 10, 'img/Zapatos.jpg');


-- =====================================================
-- VENTA DE PRUEBA
-- =====================================================

INSERT INTO venta (
    id_cliente,
    id_usuario,
    medio_pago,
    canal_venta,
    tipo_entrega,
    total,
    estado
)
VALUES (
    1,
    1,
    'efectivo',
    'tienda_fisica',
    'recoger_tienda',
    85000,
    'pagada'
);

INSERT INTO detalle_venta (
    id_venta,
    id_producto,
    cantidad,
    precio_unitario,
    subtotal
)
VALUES (
    1,
    1,
    1,
    85000,
    85000
);


-- =====================================================
-- DEVOLUCIÓN DE PRUEBA
-- =====================================================

INSERT INTO devolucion (
    id_venta,
    id_cliente,
    motivo,
    total_devuelto,
    estado
)
VALUES (
    1,
    1,
    'Cambio de talla',
    85000,
    'aprobada'
);

INSERT INTO detalle_devolucion (
    id_devolucion,
    id_producto,
    cantidad,
    precio_unitario,
    subtotal_devuelto
)
VALUES (
    1,
    1,
    1,
    85000,
    85000
);


-- =====================================================
-- CAMBIO DE PRECIO DE PRUEBA
-- =====================================================

UPDATE producto
SET precio = 90000
WHERE codigo = 'IB-001';


-- =====================================================
-- CONSULTAS DE VERIFICACIÓN FINAL
-- =====================================================

SELECT * FROM vista_inventario_general;

SELECT * FROM vista_ventas_detalladas;

SELECT * FROM vista_reporte_mensual;

SELECT * FROM vista_ranking_productos;

SELECT * FROM vista_ventas_acumuladas;

SELECT fn_total_ventas_netas() AS total_neto_vendido;

SELECT * FROM movimiento_inventario;

SELECT * FROM cambio_precio;

SELECT * FROM auditoria_log;

