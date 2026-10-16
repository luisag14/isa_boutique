CREATE TABLE IF NOT EXISTS notificacion_correo (
    id_notificacion SERIAL PRIMARY KEY,
    destinatario VARCHAR(150) NOT NULL,
    asunto VARCHAR(180) NOT NULL,
    cuerpo_html TEXT NOT NULL,
    cuerpo_texto TEXT NOT NULL,
    estado VARCHAR(20) DEFAULT 'pendiente' NOT NULL,
    intentos INT DEFAULT 0 NOT NULL,
    error_ultimo TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_envio TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notificacion_correo_estado
ON notificacion_correo (estado, fecha_creacion);
