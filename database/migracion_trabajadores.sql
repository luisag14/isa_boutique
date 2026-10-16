-- Migracion para administracion de trabajadores y pagos.
-- Ejecutar una sola vez sobre la base isa_boutiquevs.

CREATE TABLE IF NOT EXISTS trabajador (
    id_trabajador SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    documento VARCHAR(40),
    telefono VARCHAR(40),
    cargo VARCHAR(80) NOT NULL,
    salario_base NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (salario_base >= 0),
    estado BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pago_trabajador (
    id_pago_trabajador SERIAL PRIMARY KEY,
    id_trabajador INT NOT NULL,
    id_usuario INT,
    tipo_pago VARCHAR(30) NOT NULL CHECK (tipo_pago IN (
        'salario',
        'comision',
        'adelanto',
        'bono',
        'deduccion',
        'otro'
    )),
    valor NUMERIC(12,2) NOT NULL CHECK (valor > 0),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    detalle TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pago_trabajador
        FOREIGN KEY (id_trabajador)
        REFERENCES trabajador(id_trabajador),

    CONSTRAINT fk_pago_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
);
