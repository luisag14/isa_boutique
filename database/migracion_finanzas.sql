-- Migracion para administracion financiera de Isa Boutique.
-- Ejecutar una sola vez sobre la base isa_boutiquevs.

CREATE TABLE IF NOT EXISTS gasto_negocio (
    id_gasto SERIAL PRIMARY KEY,
    id_usuario INT,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN (
        'primario',
        'secundario',
        'servicio',
        'nomina',
        'transporte',
        'publicidad',
        'empaque',
        'mantenimiento',
        'otro'
    )),
    concepto VARCHAR(120) NOT NULL,
    valor NUMERIC(12,2) NOT NULL CHECK (valor > 0),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    detalle TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_gasto_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
);

CREATE TABLE IF NOT EXISTS inversion_negocio (
    id_inversion SERIAL PRIMARY KEY,
    id_usuario INT,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN (
        'capital',
        'mercancia',
        'adecuacion',
        'publicidad',
        'tecnologia',
        'otro'
    )),
    concepto VARCHAR(120) NOT NULL,
    valor NUMERIC(12,2) NOT NULL CHECK (valor > 0),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    detalle TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_inversion_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
);
