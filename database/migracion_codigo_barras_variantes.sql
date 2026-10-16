ALTER TABLE producto_color_talla
ADD COLUMN IF NOT EXISTS codigo_barras VARCHAR(40);

CREATE UNIQUE INDEX IF NOT EXISTS uq_producto_color_talla_codigo_barras
ON producto_color_talla (codigo_barras)
WHERE codigo_barras IS NOT NULL;

UPDATE producto_color_talla pct
SET codigo_barras = p.codigo || '-V' || LPAD(pct.id_producto_color_talla::TEXT, 4, '0')
FROM producto_color pc
INNER JOIN producto p
    ON p.id_producto = pc.id_producto
WHERE pct.id_producto_color = pc.id_producto_color
AND (pct.codigo_barras IS NULL OR pct.codigo_barras = '');
