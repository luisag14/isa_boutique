CREATE SEQUENCE IF NOT EXISTS factura_numero_seq;

CREATE TABLE IF NOT EXISTS factura (
    id_factura SERIAL PRIMARY KEY,
    id_venta INT NOT NULL UNIQUE REFERENCES venta(id_venta) ON DELETE CASCADE,
    numero_factura VARCHAR(30) NOT NULL UNIQUE DEFAULT (
        'FAC-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || LPAD(nextval('factura_numero_seq')::TEXT, 6, '0')
    ),
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
    descuento NUMERIC(12,2) NOT NULL DEFAULT 0,
    total NUMERIC(12,2) NOT NULL DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'emitida'
        CHECK (estado IN ('emitida', 'anulada'))
);

INSERT INTO factura (id_venta, subtotal, descuento, total, estado)
SELECT id_venta, total, 0, total, 'emitida'
FROM venta
WHERE estado IN ('pagada', 'devuelta')
ON CONFLICT (id_venta) DO NOTHING;
