CREATE TABLE IF NOT EXISTS password_reset_token (
    id_reset SERIAL PRIMARY KEY,
    id_usuario INT NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expira_en TIMESTAMP NOT NULL,
    usado BOOLEAN DEFAULT FALSE NOT NULL,
    ip_solicitud VARCHAR(64),
    fecha_solicitud TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_uso TIMESTAMP,
    CONSTRAINT fk_password_reset_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario_sistema(id_usuario)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_password_reset_usuario
ON password_reset_token (id_usuario);

CREATE INDEX IF NOT EXISTS idx_password_reset_vigente
ON password_reset_token (token_hash, expira_en, usado);
