-- Permite registrar compras como mercancia nueva pendiente de clasificar
-- o como reposicion de productos existentes.

ALTER TABLE compra_mercancia
ADD COLUMN IF NOT EXISTS tipo_compra VARCHAR(30) NOT NULL DEFAULT 'reposicion',
ADD COLUMN IF NOT EXISTS estado VARCHAR(30) NOT NULL DEFAULT 'registrada',
ADD COLUMN IF NOT EXISTS proveedor_referencia VARCHAR(160);

ALTER TABLE detalle_compra_mercancia
ADD COLUMN IF NOT EXISTS tipo_item VARCHAR(30) NOT NULL DEFAULT 'reposicion',
ADD COLUMN IF NOT EXISTS categoria VARCHAR(120),
ADD COLUMN IF NOT EXISTS descripcion VARCHAR(180),
ADD COLUMN IF NOT EXISTS color VARCHAR(80),
ADD COLUMN IF NOT EXISTS estado_registro VARCHAR(30) NOT NULL DEFAULT 'registrado';

ALTER TABLE detalle_compra_mercancia
ALTER COLUMN id_producto DROP NOT NULL;

ALTER TABLE compra_mercancia
DROP CONSTRAINT IF EXISTS compra_mercancia_tipo_compra_check;

ALTER TABLE compra_mercancia
ADD CONSTRAINT compra_mercancia_tipo_compra_check
CHECK (tipo_compra IN ('mercancia_nueva', 'reposicion', 'mixta'));

ALTER TABLE compra_mercancia
DROP CONSTRAINT IF EXISTS compra_mercancia_estado_check;

ALTER TABLE compra_mercancia
ADD CONSTRAINT compra_mercancia_estado_check
CHECK (estado IN ('pendiente_clasificar', 'registrada', 'parcial'));

ALTER TABLE detalle_compra_mercancia
DROP CONSTRAINT IF EXISTS detalle_compra_mercancia_tipo_item_check;

ALTER TABLE detalle_compra_mercancia
ADD CONSTRAINT detalle_compra_mercancia_tipo_item_check
CHECK (tipo_item IN ('mercancia_nueva', 'reposicion'));

ALTER TABLE detalle_compra_mercancia
DROP CONSTRAINT IF EXISTS detalle_compra_mercancia_estado_registro_check;

ALTER TABLE detalle_compra_mercancia
ADD CONSTRAINT detalle_compra_mercancia_estado_registro_check
CHECK (estado_registro IN ('pendiente', 'registrado'));

ALTER TABLE detalle_compra_mercancia
DROP CONSTRAINT IF EXISTS detalle_compra_mercancia_producto_o_descripcion_check;

ALTER TABLE detalle_compra_mercancia
ADD CONSTRAINT detalle_compra_mercancia_producto_o_descripcion_check
CHECK (
    (tipo_item = 'reposicion' AND id_producto IS NOT NULL)
    OR
    (tipo_item = 'mercancia_nueva' AND descripcion IS NOT NULL AND categoria IS NOT NULL)
);
