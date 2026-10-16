-- =====================================================
-- ISA BOUTIQUE - DATOS MINIMOS PARA PRODUCCION
-- Ejecutar despues de database/produccion_schema.sql
-- =====================================================

-- Usuarios de referencia inactivos. El marcador no es un hash ni una clave valida.
-- No se habilitan cuentas ni se distribuyen contrasenas predeterminadas.
-- Asignar claves propias mediante scripts/crear_usuario_inicial.php.
INSERT INTO usuario_sistema (nombre, correo, contrasena, rol, estado)
VALUES
('Administrador Isa Boutique', 'admin@isaboutique.com', '!SIN_ACCESO_INICIAL!', 'admin', FALSE),
('Vendedora Principal', 'vendedora@isaboutique.com', '!SIN_ACCESO_INICIAL!', 'vendedor', FALSE)
ON CONFLICT (correo) DO NOTHING;

-- Categorias visibles en la tienda.

INSERT INTO categoria (nombre, descripcion, estado)
VALUES
('vestidos', 'Vestidos para ocasiones especiales', TRUE),
('blusas', 'Blusas y tops femeninos', TRUE),
('conjuntos', 'Conjuntos femeninos', TRUE),
('shorts', 'Shorts y prendas frescas', TRUE),
('jeans', 'Jeans y denim', TRUE),
('bodys', 'Bodys femeninos', TRUE),
('faldas', 'Faldas femeninas', TRUE),
('accesorios', 'Accesorios de moda femenina', TRUE)
ON CONFLICT (nombre) DO NOTHING;
