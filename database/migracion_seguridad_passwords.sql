-- Comprobacion preventiva; ya no distribuye hashes ni cambia contrasenas.
-- No ejecutar contra una base existente sin respaldo y autorizacion.
-- Las cuentas heredadas requieren una clave propia mediante recuperacion/panel.
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM usuario_sistema WHERE estado=TRUE AND
        contrasena !~ '^\$(2[aby]|argon2id|argon2i)\$') THEN
        RAISE EXCEPTION 'Existen cuentas activas sin hash valido. Restablecer sus claves por el flujo autorizado';
    END IF;
END $$;
