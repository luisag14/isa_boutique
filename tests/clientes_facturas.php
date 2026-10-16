<?php
require_once __DIR__.'/postgres_temporal.php';
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../php/cliente_util.php';
require_once __DIR__.'/../php/factura_util.php';
require_once __DIR__.'/../php/catalogo_util.php';
require_once __DIR__.'/../php/finanzas_util.php';
function verificar_privacidad($valor,$mensaje){if(!$valor)throw new RuntimeException($mensaje);}
if(!isset($argv[1])){echo "Se requiere un PostgreSQL temporal local vacio y su puerto (55000-55999).\n";exit;}
$puerto=filter_var($argv[1],FILTER_VALIDATE_INT);
if($puerto<55000||$puerto>55999)throw new RuntimeException('Puerto de pruebas invalido');
$db=conexion_postgres_prueba($puerto,[
 PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>true]);
if((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()!==0)throw new RuntimeException('Base temporal no vacia');
$db->exec(<<<'SQL'
CREATE TABLE cliente(id_cliente serial PRIMARY KEY,nombre text,telefono text,correo text,tipo_documento text,numero_documento text,direccion text);
CREATE TABLE usuario_sistema(id_usuario integer PRIMARY KEY,nombre text,rol text,sesion_token text,estado boolean);
CREATE TABLE categoria(id_categoria integer PRIMARY KEY,nombre text);
CREATE TABLE producto(id_producto integer PRIMARY KEY,codigo text,nombre text,marca text,color text,id_categoria integer REFERENCES categoria,precio numeric,costo_unitario numeric,cantidad integer,estado text,imagen text);
CREATE TABLE producto_color(id_producto_color integer PRIMARY KEY,id_producto integer REFERENCES producto,nombre_color text,codigo_hex text,orden integer);
CREATE TABLE producto_color_talla(id_producto_color_talla integer PRIMARY KEY,id_producto_color integer REFERENCES producto_color,talla text,cantidad integer);
CREATE TABLE producto_talla(id_producto_talla integer PRIMARY KEY,id_producto integer REFERENCES producto,talla text,cantidad integer);
CREATE TABLE producto_imagen(id_producto_imagen integer PRIMARY KEY,id_producto integer REFERENCES producto,ruta text,es_principal boolean,orden integer);
CREATE TABLE venta(id_venta integer PRIMARY KEY,id_cliente integer REFERENCES cliente,id_usuario integer REFERENCES usuario_sistema,fecha timestamp DEFAULT CURRENT_TIMESTAMP,medio_pago text,canal_venta text,tipo_entrega text,estado text,total numeric,subtotal_bruto numeric,descuento numeric,base_gravable numeric,iva numeric,tarifa_iva numeric,precio_incluye_iva boolean);
CREATE TABLE detalle_venta(id_detalle_venta integer PRIMARY KEY,id_venta integer REFERENCES venta,id_producto integer REFERENCES producto,id_producto_color integer REFERENCES producto_color,color text,talla text,cantidad integer,precio_unitario numeric,descuento numeric,base_gravable numeric,iva numeric,tarifa_iva numeric,subtotal numeric);
CREATE SEQUENCE numero_factura_prueba;
CREATE TABLE factura(id_factura serial PRIMARY KEY,id_venta integer UNIQUE REFERENCES venta ON DELETE CASCADE,numero_factura text UNIQUE DEFAULT ('ISA-'||nextval('numero_factura_prueba')),fecha timestamp DEFAULT CURRENT_TIMESTAMP,subtotal numeric,descuento numeric,base_gravable numeric,iva numeric,tarifa_iva numeric,precio_incluye_iva boolean,total numeric,estado text);
INSERT INTO usuario_sistema VALUES(1,'Administradora','admin','vigente',true),(2,'Vendedora','vendedor','vendedor',true);
INSERT INTO cliente(nombre,telefono,correo,tipo_documento,numero_documento,direccion) VALUES('Original','3001234567','original@example.test','CC','123','Calle original');
INSERT INTO categoria VALUES(1,'blusas');
INSERT INTO producto VALUES(1,'P1','Blusa original','Marca original','Rojo',1,119,60,2,'activo','imagen.jpg'),(2,'P2','Prenda inactiva','Marca','Azul',1,200,80,1,'inactivo','imagen2.jpg');
INSERT INTO producto_color VALUES(11,1,'Rojo','#ff0000',0);
INSERT INTO producto_color_talla VALUES(111,11,'M',2);
INSERT INTO producto_talla VALUES(1,1,'M',2);
INSERT INTO venta VALUES(1,1,1,CURRENT_TIMESTAMP,'efectivo','tienda_fisica','recoger_tienda','pagada',119,119,0,100,19,19,true),(2,1,1,CURRENT_TIMESTAMP,'efectivo','tienda_fisica','recoger_tienda','pagada',119,119,0,100,19,19,true);
INSERT INTO detalle_venta VALUES(1,1,1,11,'Rojo','M',1,119,0,100,19,19,119),(2,2,1,11,'Rojo','M',1,119,0,100,19,19,119);
INSERT INTO factura(id_venta,subtotal,descuento,base_gravable,iva,tarifa_iva,precio_incluye_iva,total,estado) VALUES(2,119,0,100,19,19,true,119,'emitida');
SQL);
$datos=['nombre'=>'Otra persona','telefono'=>'3001234567','correo'=>'otra@example.test','tipo_documento'=>'CC','numero_documento'=>'456'];
$db->beginTransaction();$nuevo=cliente_para_venta($db,$datos);$repetido=cliente_para_venta($db,$datos);$db->commit();
verificar_privacidad($nuevo!==1 && $nuevo===$repetido,'Cliente sobrescrito o duplicado para datos identicos');
verificar_privacidad($db->query('SELECT nombre FROM cliente WHERE id_cliente=1')->fetchColumn()==='Original','Pedido publico altero al cliente anterior');
$legado=leer_finanzas_consistentes($db,function()use($db){return leer_factura_venta($db,2);});
verificar_privacidad($legado['datos_emision_conservados']===false,'Factura antigua presentada como historica verificada');
$db->beginTransaction();$rechazada=false;
try{asegurar_factura_venta($db,1);}catch(PDOException $e){$rechazada=true;}$db->rollBack();
verificar_privacidad($rechazada,'Nueva emision aceptada sin esquema para conservar datos');
$db->exec(file_get_contents(__DIR__.'/../database/migracion_factura_datos_emision.sql'));
$db->exec(file_get_contents(__DIR__.'/../database/migracion_factura_datos_emision.sql'));
$db->beginTransaction();$factura=asegurar_factura_venta($db,1);$db->commit();
$original=leer_finanzas_consistentes($db,function()use($db){return leer_factura_venta($db,1);});
verificar_privacidad($original['datos_emision_conservados']===true,'Datos de emision no conservados');
$db->exec("UPDATE cliente SET nombre='Cambiado',correo='cambiado@example.test' WHERE id_cliente=1; UPDATE producto SET nombre='Producto cambiado',marca='Otra marca',precio=300 WHERE id_producto=1; UPDATE usuario_sistema SET nombre='Otro nombre' WHERE id_usuario=1; UPDATE venta SET total=250 WHERE id_venta=1");
$despues=leer_finanzas_consistentes($db,function()use($db){return leer_factura_venta($db,1);});
verificar_privacidad($original===$despues,'Una edicion posterior altera la factura historica');
$db->beginTransaction();$misma=asegurar_factura_venta($db,1);$db->commit();
verificar_privacidad($misma['id_factura']===$factura['id_factura'] && (float)$misma['total']===119.0,'Reemision altera numero o importe');
verificar_privacidad((int)$db->query('SELECT COUNT(*) FROM factura')->fetchColumn()===2,'Consultar o reemitir duplica facturas');
verificar_privacidad($db->query('SELECT datos_emision FROM factura WHERE id_venta=2')->fetchColumn()===null,'Se inventaron datos historicos para factura antigua');
foreach([null,['id_usuario'=>2,'rol'=>'vendedor','sesion_token'=>'vendedor'],['id_usuario'=>1,'rol'=>'admin','sesion_token'=>'revocado']] as $usuario){
 $publico=leer_finanzas_consistentes($db,function()use($db,$usuario){return listar_productos_visibles($db,$usuario);});
 verificar_privacidad(count($publico)===1 && !array_key_exists('costo_unitario',$publico[0]),'Catalogo expone costos o productos inactivos');
}
$admin=leer_finanzas_consistentes($db,function()use($db){return listar_productos_visibles($db,['id_usuario'=>1,'rol'=>'admin','sesion_token'=>'vigente']);});
verificar_privacidad(count($admin)===2 && array_key_exists('costo_unitario',$admin[0]),'Administracion pierde costo o inventario inactivo');
echo "PASS PostgreSQL: clientes sin sobrescritura, reutilizacion exacta, facturas inmutables, lectura sin escrituras, compatibilidad historica y catalogo por permisos\n";
