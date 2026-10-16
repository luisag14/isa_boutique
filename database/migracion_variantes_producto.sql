CREATE TABLE IF NOT EXISTS producto_color (
    id_producto_color SERIAL PRIMARY KEY,
    id_producto INT NOT NULL REFERENCES producto(id_producto) ON DELETE CASCADE,
    nombre_color VARCHAR(80) NOT NULL,
    codigo_hex VARCHAR(20),
    orden INT NOT NULL DEFAULT 0,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_producto_color UNIQUE (id_producto, nombre_color)
);

CREATE TABLE IF NOT EXISTS producto_color_talla (
    id_producto_color_talla SERIAL PRIMARY KEY,
    id_producto_color INT NOT NULL REFERENCES producto_color(id_producto_color) ON DELETE CASCADE,
    talla VARCHAR(20) NOT NULL,
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_producto_color_talla UNIQUE (id_producto_color, talla)
);

CREATE TABLE IF NOT EXISTS producto_imagen (
    id_producto_imagen SERIAL PRIMARY KEY,
    id_producto INT NOT NULL REFERENCES producto(id_producto) ON DELETE CASCADE,
    ruta VARCHAR(255) NOT NULL,
    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    orden INT NOT NULL DEFAULT 0,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE detalle_venta
ADD COLUMN IF NOT EXISTS id_producto_color INT REFERENCES producto_color(id_producto_color),
ADD COLUMN IF NOT EXISTS color VARCHAR(80);

INSERT INTO producto_color (id_producto, nombre_color, codigo_hex, orden)
SELECT p.id_producto, COALESCE(NULLIF(p.color, ''), 'Único'), NULL, 0
FROM producto p
WHERE NOT EXISTS (
    SELECT 1
    FROM producto_color pc
    WHERE pc.id_producto = p.id_producto
);

INSERT INTO producto_color_talla (id_producto_color, talla, cantidad)
SELECT pc.id_producto_color, pt.talla, pt.cantidad
FROM producto_color pc
INNER JOIN producto_talla pt
    ON pc.id_producto = pt.id_producto
WHERE NOT EXISTS (
    SELECT 1
    FROM producto_color_talla pct
    WHERE pct.id_producto_color = pc.id_producto_color
    AND pct.talla = pt.talla
);

INSERT INTO producto_imagen (id_producto, ruta, es_principal, orden)
SELECT p.id_producto, p.imagen, TRUE, 0
FROM producto p
WHERE NULLIF(p.imagen, '') IS NOT NULL
AND NOT EXISTS (
    SELECT 1
    FROM producto_imagen pi
    WHERE pi.id_producto = p.id_producto
);
