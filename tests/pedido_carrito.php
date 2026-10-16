<?php
require_once __DIR__.'/postgres_temporal.php';
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../php/pedido_util.php';
function verificar_pedido($valor,$mensaje){if(!$valor)throw new RuntimeException($mensaje);}
function rechazar_pedido(callable $fn,$mensaje){try{$fn();}catch(DomainException $e){return;}throw new RuntimeException($mensaje);}
$datos=['cliente'=>'Cliente','telefono'=>'3001234567','correo'=>'cliente@example.test','medio_pago'=>'efectivo','tipo_entrega'=>'recoger_tienda',
 'items'=>[['id_producto'=>1,'id_producto_color'=>11,'talla'=>'M','cantidad'=>1,'precio'=>0],['id_producto'=>2,'id_producto_color'=>21,'talla'=>'L','cantidad'=>1]]];
$normal=normalizar_pedido_carrito($datos);
verificar_pedido(count($normal['items'])===2&&!isset($normal['items'][0]['precio']),'Precio del navegador confiado');
$decimal=$datos;$decimal['items'][0]['cantidad']=1.5;
rechazar_pedido(function()use($decimal){normalizar_pedido_carrito($decimal);},'Cantidad decimal aceptada');
$duplicadas=$datos;$duplicadas['items']=[$datos['items'][0],$datos['items'][0]];
$n=normalizar_pedido_carrito($duplicadas);verificar_pedido(count($n['items'])===1&&$n['items'][0]['cantidad']===2,'Variantes repetidas no agrupadas');
echo "PASS validacion, agrupacion de variantes y precios ignorados del cliente\n";
if(!isset($argv[1]))exit;
$puerto=filter_var($argv[1],FILTER_VALIDATE_INT);
if($puerto<55000||$puerto>55999)throw new RuntimeException('Puerto de pruebas invalido');
$opciones=[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>true];
$db=conexion_postgres_prueba($puerto,$opciones);
if((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()!==0)throw new RuntimeException('Base temporal no vacia');
$db->exec(<<<'SQL'
CREATE TABLE cliente(id_cliente serial PRIMARY KEY,nombre text,telefono text,correo text,tipo_documento text,numero_documento text);
CREATE TABLE usuario_sistema(id_usuario integer PRIMARY KEY,rol text,estado boolean);
CREATE TABLE producto(id_producto integer PRIMARY KEY,nombre text,precio numeric(12,2),costo_unitario numeric(12,2),cantidad integer CHECK(cantidad>=0),estado text);
CREATE TABLE producto_color(id_producto_color integer PRIMARY KEY,id_producto integer REFERENCES producto,nombre_color text);
CREATE TABLE producto_color_talla(id_producto_color integer REFERENCES producto_color,talla text,cantidad integer CHECK(cantidad>=0),UNIQUE(id_producto_color,talla));
CREATE TABLE producto_talla(id_producto integer REFERENCES producto,talla text,cantidad integer CHECK(cantidad>=0),UNIQUE(id_producto,talla));
CREATE TABLE venta(id_venta serial PRIMARY KEY,id_cliente integer REFERENCES cliente,id_usuario integer REFERENCES usuario_sistema,medio_pago text,canal_venta text,tipo_entrega text,subtotal_bruto numeric(12,2),descuento numeric(12,2),base_gravable numeric(12,2),iva numeric(12,2),tarifa_iva numeric,precio_incluye_iva boolean,total numeric(12,2),estado text);
CREATE TABLE detalle_venta(id_detalle_venta serial PRIMARY KEY,id_venta integer REFERENCES venta,id_producto integer REFERENCES producto,id_producto_color integer REFERENCES producto_color,color text,talla text,cantidad integer CHECK(cantidad>0),precio_unitario numeric(12,2),costo_unitario numeric(12,2),descuento numeric(12,2),base_gravable numeric(12,2),iva numeric(12,2),tarifa_iva numeric,precio_incluye_iva boolean,subtotal numeric(12,2),subtotal_costo numeric(12,2));
CREATE TABLE movimiento_inventario(id_producto integer,cantidad integer);
CREATE TABLE factura(id_factura integer PRIMARY KEY);
CREATE FUNCTION descontar_general() RETURNS trigger AS $$ BEGIN UPDATE producto SET cantidad=cantidad-NEW.cantidad WHERE id_producto=NEW.id_producto; INSERT INTO movimiento_inventario VALUES(NEW.id_producto,NEW.cantidad); RETURN NEW; END $$ LANGUAGE plpgsql;
CREATE TRIGGER descontar AFTER INSERT ON detalle_venta FOR EACH ROW EXECUTE FUNCTION descontar_general();
CREATE FUNCTION fallo_prueba() RETURNS trigger AS $$ BEGIN IF NEW.id_producto=2 AND current_setting('isa.fallo_prueba',true)='on' THEN RAISE EXCEPTION 'Fallo segundo detalle'; END IF;RETURN NEW;END $$ LANGUAGE plpgsql;
CREATE TRIGGER fallo BEFORE INSERT ON detalle_venta FOR EACH ROW EXECUTE FUNCTION fallo_prueba();
INSERT INTO usuario_sistema VALUES(1,'admin',true);
INSERT INTO producto VALUES(1,'Prenda A',119,60,5,'activo'),(2,'Prenda B',238,100,2,'activo');
INSERT INTO producto_color VALUES(11,1,'Rojo'),(12,1,'Azul'),(21,2,'Negro');
INSERT INTO producto_color_talla VALUES(11,'M',3),(12,'M',2),(21,'L',2);
INSERT INTO producto_talla VALUES(1,'M',5),(2,'L',2);
SQL);
$clave=str_repeat('a',32);$faltaMigracion=false;
try{registrar_pedido_carrito($db,$datos,$clave);}catch(PDOException $e){$faltaMigracion=true;}
verificar_pedido($faltaMigracion&&(int)$db->query('SELECT COUNT(*) FROM venta')->fetchColumn()===0,'Pedido sin migracion aceptado');
$db->exec(file_get_contents(__DIR__.'/../database/migracion_pedido_carrito.sql'));
$db->exec(file_get_contents(__DIR__.'/../database/migracion_pedido_carrito.sql'));
$primero=registrar_pedido_carrito($db,$datos,$clave);
verificar_pedido($primero['total']===357.0&&$primero['estado']==='pendiente','Importes del pedido incorrectos');
verificar_pedido((int)$db->query('SELECT COUNT(*) FROM venta')->fetchColumn()===1&&(int)$db->query('SELECT COUNT(*) FROM detalle_venta')->fetchColumn()===2,'El carrito no genera una sola venta');
$reintento=registrar_pedido_carrito($db,$datos,$clave);
$ordenInverso=$datos;$ordenInverso['items']=array_reverse($datos['items']);$reordenado=registrar_pedido_carrito($db,$ordenInverso,$clave);
verificar_pedido($reintento['reutilizado']&&$reordenado['id_venta']===$primero['id_venta'],'Reintento duplica el pedido');
verificar_pedido((int)$db->query('SELECT cantidad FROM producto WHERE id_producto=1')->fetchColumn()===4,'El reintento descuenta stock');
$cambiado=$datos;$cambiado['items'][0]['cantidad']=2;
rechazar_pedido(function()use($db,$cambiado,$clave){registrar_pedido_carrito($db,$cambiado,$clave);},'Clave aceptada con otro contenido');
// Una segunda conexion no puede procesar la misma clave mientras esta bloqueada.
$otra=conexion_postgres_prueba($puerto,$opciones);$db->beginTransaction();
$q=$db->prepare('SELECT pg_advisory_xact_lock(hashtextextended(?,0))');$q->execute(['pedido-carrito:'.$clave]);
$bloqueado=false;try{registrar_pedido_carrito($otra,$datos,$clave);}catch(PDOException $e){$bloqueado=$e->getCode()==='55P03';}
$db->rollBack();verificar_pedido($bloqueado&&!$otra->inTransaction(),'Clave concurrente no serializada');
$resultado=registrar_pedido_carrito($otra,$datos,$clave);verificar_pedido($resultado['reutilizado'],'Reintento tras bloqueo no reutiliza pedido');
// Fallar DESPUES de insertar el primer detalle debe revertir todo, incluso cliente y trigger.
$antes=$db->query('SELECT SUM(cantidad) FROM producto')->fetchColumn();
$clientesAntes=$db->query('SELECT COUNT(*) FROM cliente')->fetchColumn();$movimientosAntes=$db->query('SELECT COUNT(*) FROM movimiento_inventario')->fetchColumn();
$fallido=$datos;$fallido['cliente']='Cliente nuevo';$fallido['telefono']='3000000000';
$db->exec("SET isa.fallo_prueba='on'");$fallo=false;
try{registrar_pedido_carrito($db,$fallido,str_repeat('b',32));}catch(PDOException $e){$fallo=true;}
verificar_pedido($fallo&&(int)$db->query('SELECT COUNT(*) FROM venta')->fetchColumn()===1,'Venta parcial conservada');
verificar_pedido($db->query('SELECT SUM(cantidad) FROM producto')->fetchColumn()===$antes,'Stock parcial conservado');
verificar_pedido($db->query('SELECT COUNT(*) FROM cliente')->fetchColumn()===$clientesAntes&&$db->query('SELECT COUNT(*) FROM movimiento_inventario')->fetchColumn()===$movimientosAntes,'Cliente o movimiento de transaccion fallida conservado');
$db->exec("SET isa.fallo_prueba='off'");registrar_pedido_carrito($db,$fallido,str_repeat('b',32));
rechazar_pedido(function()use($db,$duplicadas){registrar_pedido_carrito($db,$duplicadas,str_repeat('c',32));},'Variante duplicada supera el stock');
$variantes=$datos;$variantes['items']=[['id_producto'=>1,'id_producto_color'=>11,'talla'=>'M','cantidad'=>1],['id_producto'=>1,'id_producto_color'=>12,'talla'=>'M','cantidad'=>2]];
$db->exec('UPDATE producto SET cantidad=2 WHERE id_producto=1');
rechazar_pedido(function()use($db,$variantes){registrar_pedido_carrito($db,$variantes,str_repeat('d',32));},'Suma de variantes supera stock general');
$db->exec('UPDATE producto SET cantidad=3 WHERE id_producto=1');
registrar_pedido_carrito($db,$variantes,str_repeat('d',32));
verificar_pedido((int)$db->query('SELECT cantidad FROM producto WHERE id_producto=1')->fetchColumn()===0,'Stock general incorrecto');
verificar_pedido((int)$db->query("SELECT cantidad FROM producto_talla WHERE id_producto=1 AND talla='M'")->fetchColumn()===0,'Stock agregado de talla incorrecto');
verificar_pedido((int)$db->query('SELECT SUM(cantidad) FROM producto_color_talla WHERE id_producto_color IN(11,12)')->fetchColumn()===0,'Stock por color incorrecto');
verificar_pedido((int)$db->query('SELECT COUNT(*) FROM factura')->fetchColumn()===0,'Se emitio factura para pedido pendiente');
echo "PASS PostgreSQL: pedido unico, reintentos, claves concurrentes, precios del servidor, rollback completo y stock de varias variantes\n";
