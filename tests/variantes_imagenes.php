<?php
if (PHP_SAPI!=='cli') {http_response_code(404);exit;}
require_once __DIR__.'/postgres_temporal.php';
$db=conexion_postgres_prueba($argv[1]??null);
if ((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()!==0) {
    throw new RuntimeException('Base temporal no vacia');
}
$db->exec('CREATE TABLE producto(id_producto integer PRIMARY KEY,color text,imagen varchar(255)); CREATE TABLE producto_talla(id_producto integer REFERENCES producto,talla text,cantidad integer); CREATE TABLE detalle_venta(id_detalle_venta serial PRIMARY KEY)');
$sql=file_get_contents(__DIR__.'/../database/migracion_variantes_producto.sql');
$db->exec($sql);
$db->exec("INSERT INTO producto VALUES(1,NULL,NULL),(2,NULL,''),(3,NULL,' '),(4,NULL,'img/prueba.jpg'),(5,NULL,'img/previa.jpg'); INSERT INTO producto_imagen(id_producto,ruta) VALUES(5,'img/ya-registrada.jpg')");
$db->exec($sql);
$filas=$db->query('SELECT id_producto,ruta FROM producto_imagen ORDER BY id_producto')->fetchAll();
$esperadas=[['id_producto'=>3,'ruta'=>' '],['id_producto'=>4,'ruta'=>'img/prueba.jpg'],['id_producto'=>5,'ruta'=>'img/ya-registrada.jpg']];
if ($filas!==$esperadas) {
    throw new RuntimeException('Cambio en seleccion de imagenes NULL/vacias o duplicacion');
}
$db->exec($sql);
if ($db->query('SELECT id_producto,ruta FROM producto_imagen ORDER BY id_producto')->fetchAll()!==$filas) {
    throw new RuntimeException('Repetir migracion altera imagenes');
}
echo "PASS PostgreSQL: NULLIF conserva el filtro de imagenes y la migracion sigue siendo repetible\n";
