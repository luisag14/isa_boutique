-- Migracion para proveedores y compras de mercancia.
-- Ejecutar una sola vez sobre la base isa_boutiquevs.

CREATE TABLE IF NOT EXISTS proveedor (
    id_proveedor SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(40),
    ciudad VARCHAR(80),
    producto_suministra VARCHAR(160),
    estado BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compra_mercancia (
    id_compra SERIAL PRIMARY KEY,
    id_proveedor INT,
    id_usuario INT,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo_compra VARCHAR(30) NOT NULL DEFAULT 'reposicion',
    estado VARCHAR(30) NOT NULL DEFAULT 'registrada',
    proveedor_referencia VARCHAR(160),
    costo_envio NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (costo_envio >= 0),
    total_productos NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_productos >= 0),
    total_compra NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_compra >= 0),
    detalle TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_compra_proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES proveedor(id_proveedor),

    CONSTRAINT fk_compra_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
);

CREATE TABLE IF NOT EXISTS detalle_compra_mercancia (
    id_detalle_compra SERIAL PRIMARY KEY,
    id_compra INT NOT NULL,
    id_producto INT,
    tipo_item VARCHAR(30) NOT NULL DEFAULT 'reposicion',
    categoria VARCHAR(120),
    descripcion VARCHAR(180),
    color VARCHAR(80),
    estado_registro VARCHAR(30) NOT NULL DEFAULT 'registrado',
    talla VARCHAR(20),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    costo_unitario NUMERIC(12,2) NOT NULL CHECK (costo_unitario >= 0),
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),

    CONSTRAINT fk_detalle_compra
        FOREIGN KEY (id_compra)
        REFERENCES compra_mercancia(id_compra)
        ON DELETE CASCADE,

    CONSTRAINT fk_detalle_compra_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);
