-- Migracion para manejar stock por talla en Isa Boutique.
-- Ejecutar una sola vez sobre la base isa_boutiquevs.

CREATE TABLE IF NOT EXISTS producto_talla (
    id_producto_talla SERIAL PRIMARY KEY,
    id_producto INT NOT NULL,
    talla VARCHAR(20) NOT NULL,
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_producto_talla_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
        ON DELETE CASCADE,

    CONSTRAINT uq_producto_talla
        UNIQUE (id_producto, talla)
);

ALTER TABLE detalle_venta
ADD COLUMN IF NOT EXISTS talla VARCHAR(20);

ALTER TABLE detalle_devolucion
ADD COLUMN IF NOT EXISTS talla VARCHAR(20);

INSERT INTO producto_talla (id_producto, talla, cantidad)
SELECT id_producto, 'Unica', cantidad
FROM producto p
WHERE NOT EXISTS (
    SELECT 1
    FROM producto_talla pt
    WHERE pt.id_producto = p.id_producto
);
