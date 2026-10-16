<?php
require_once __DIR__.'/postgres_temporal.php';
// Solo admite un PostgreSQL temporal en localhost, nunca la configuracion del proyecto.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../php/devolucion_util.php';
require_once __DIR__ . '/../php/inventario_util.php';
function verificar_negocio($condicion, $mensaje) {
    if (!$condicion) throw new RuntimeException($mensaje);
}
function rechazar_negocio($operacion, $mensaje) {
    try { $operacion(); } catch (DomainException $e) { return; }
    throw new RuntimeException($mensaje);
}
verificar_negocio(importe_devolucion('80.00', 1, 0, 1, 0) === 80.0, 'Reembolso ignora descuento');
$primero = importe_devolucion('10.00', 3, 0, 1, 0);
$segundo = importe_devolucion('10.00', 3, 1, 1, $primero);
$tercero = importe_devolucion('10.00', 3, 2, 1, $primero+$segundo);
verificar_negocio(abs($primero+$segundo+$tercero-10) < 0.001, 'Redondeo acumulado incorrecto');
rechazar_negocio(function () { importe_devolucion('80', 1, 1, 1, 80); }, 'Exceso de unidades aceptado');
rechazar_negocio(function () { importe_devolucion('80', 1, 0, 1, 100); }, 'Sobrepago historico aceptado');
echo "PASS importes, descuentos, redondeo y limites\n";
if (!isset($argv[1])) exit;
$puerto = filter_var($argv[1], FILTER_VALIDATE_INT);
if ($puerto < 55000 || $puerto > 55999) throw new RuntimeException('Puerto de pruebas invalido');
$db = conexion_postgres_prueba($puerto, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES=>true]);
$db->exec(<<<'SQL'
CREATE TABLE producto (id_producto integer PRIMARY KEY, cantidad integer NOT NULL CHECK(cantidad>=0), color text);
CREATE TABLE producto_color (id_producto_color integer PRIMARY KEY,id_producto integer REFERENCES producto,nombre_color text);
CREATE TABLE producto_color_talla (id_producto_color_talla serial PRIMARY KEY,id_producto_color integer REFERENCES producto_color,talla text,cantidad integer CHECK(cantidad>=0),UNIQUE(id_producto_color,talla));
CREATE TABLE producto_talla (id_producto integer REFERENCES producto,talla text,cantidad integer CHECK(cantidad>=0),UNIQUE(id_producto,talla));
CREATE TABLE venta (id_venta integer PRIMARY KEY,id_cliente integer,estado text);
CREATE TABLE detalle_venta (id_detalle_venta integer PRIMARY KEY,id_venta integer REFERENCES venta,id_producto integer REFERENCES producto,id_producto_color integer REFERENCES producto_color,talla text,cantidad integer,precio_unitario numeric,costo_unitario numeric,subtotal numeric,subtotal_costo numeric);
CREATE TABLE devolucion (id_devolucion serial PRIMARY KEY,id_venta integer REFERENCES venta,id_cliente integer,motivo text,total_devuelto numeric,estado text);
CREATE TABLE detalle_devolucion (id_detalle_devolucion serial PRIMARY KEY,id_devolucion integer REFERENCES devolucion,id_producto integer REFERENCES producto,talla text,cantidad integer,precio_unitario numeric,costo_unitario numeric,subtotal_devuelto numeric,subtotal_costo_devuelto numeric);
CREATE FUNCTION reponer_general() RETURNS trigger AS $$ BEGIN UPDATE producto SET cantidad=cantidad+NEW.cantidad WHERE id_producto=NEW.id_producto; RETURN NEW; END $$ LANGUAGE plpgsql;
CREATE TRIGGER devolver_general AFTER INSERT ON detalle_devolucion FOR EACH ROW EXECUTE FUNCTION reponer_general();
INSERT INTO producto VALUES (1,0,'Rojo');
INSERT INTO producto_color VALUES (11,1,'Rojo'),(12,1,'Azul');
INSERT INTO producto_color_talla(id_producto_color,talla,cantidad) VALUES (11,'M',0),(12,'M',0);
INSERT INTO producto_talla VALUES (1,'M',0);
INSERT INTO venta VALUES (1,1,'pagada'),(2,1,'pendiente'),(3,1,'cancelada'),(4,1,'pagada');
INSERT INTO detalle_venta VALUES (101,1,1,11,'M',2,100,50,160,100),(102,1,1,12,'M',2,100,50,200,100),(104,4,1,11,'M',1,100,50,80,50);
SQL);
function operacion_prueba(PDO $db, callable $fn) {
    $db->beginTransaction();
    try { $resultado=$fn(); $db->commit(); return $resultado; }
    catch (Throwable $e) { $db->rollBack(); throw $e; }
}
foreach ([2,3] as $venta) {
    rechazar_negocio(function () use ($db,$venta) { operacion_prueba($db, function () use ($db,$venta) { guardar_devolucion($db,$venta,1,101,1,'prueba'); }); }, 'Estado no pagado aceptado');
}
rechazar_negocio(function () use ($db) { operacion_prueba($db, function () use ($db) { guardar_devolucion($db,1,1,101,1,'prueba'); }); }, 'Venta ambigua aceptada sin migracion');
$db->beginTransaction();
verificar_negocio(guardar_devolucion($db,4,1,104,1,'compatible')===80.0, 'Venta simple no funciona sin migracion');
$db->rollBack();
$sql=file_get_contents(__DIR__.'/../database/migracion_devoluciones_variantes.sql');
$db->exec($sql);
$db->exec($sql); // Repetir la migracion no elimina datos ni crea columnas duplicadas.
// El bloqueo de la venta debe impedir otra devolucion simultanea.
$db->beginTransaction();
$db->query('SELECT id_venta FROM venta WHERE id_venta=1 FOR UPDATE')->fetch();
$otra=conexion_postgres_prueba($puerto,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>true]);
$otra->beginTransaction(); $otra->exec("SET LOCAL lock_timeout='200ms'"); $bloqueada=false;
try { guardar_devolucion($otra,1,1,101,1,'concurrente'); } catch (PDOException $e) { $bloqueada=$e->getCode()==='55P03'; }
$otra->rollBack(); $db->rollBack();
verificar_negocio($bloqueada,'Devolucion concurrente no espera el bloqueo');
$importe=operacion_prueba($db,function () use ($db) { return guardar_devolucion($db,1,1,101,1,'prueba'); });
verificar_negocio($importe===80.0,'Primera devolucion con descuento incorrecta');
verificar_negocio($db->query('SELECT cantidad FROM producto')->fetchColumn()==1,'Stock general incorrecto');
verificar_negocio($db->query('SELECT cantidad FROM producto_color_talla WHERE id_producto_color=11')->fetchColumn()==1,'Variante roja no repuesta');
verificar_negocio($db->query('SELECT cantidad FROM producto_color_talla WHERE id_producto_color=12')->fetchColumn()==0,'Otra variante fue repuesta');
operacion_prueba($db,function () use ($db) { guardar_devolucion($db,1,1,101,1,'prueba'); });
verificar_negocio($db->query('SELECT estado FROM venta WHERE id_venta=1')->fetchColumn()==='pagada','Venta completa marcada antes de tiempo');
rechazar_negocio(function () use ($db) { operacion_prueba($db,function () use ($db) { guardar_devolucion($db,1,1,101,1,'exceso'); }); },'Variante devuelta dos veces');
operacion_prueba($db,function () use ($db) { guardar_devolucion($db,1,1,102,2,'prueba'); });
verificar_negocio($db->query('SELECT estado FROM venta WHERE id_venta=1')->fetchColumn()==='devuelta','Venta completa no marcada');
verificar_negocio($db->query('SELECT SUM(total_devuelto) FROM devolucion')->fetchColumn()==360,'Reembolsos exceden importe cobrado');
operacion_prueba($db,function () use ($db) { reponer_variante($db,1,12,'','M',3); $db->exec('UPDATE producto SET cantidad=cantidad+3 WHERE id_producto=1'); });
verificar_negocio($db->query('SELECT cantidad FROM producto_color_talla WHERE id_producto_color=12')->fetchColumn()==5,'Reposicion azul incorrecta');
verificar_negocio($db->query('SELECT cantidad FROM producto_talla')->fetchColumn()==7,'Talla agregada incorrecta');
rechazar_negocio(function () use ($db) { operacion_prueba($db,function () use ($db) { reponer_variante($db,1,99,'','M',1); }); },'Color ajeno aceptado');
rechazar_negocio(function () use ($db) { operacion_prueba($db,function () use ($db) { reponer_variante($db,1,11,'','XL',1); }); },'Talla ajena aceptada');
$producto=$db->query('SELECT * FROM producto WHERE id_producto=1')->fetch();
operacion_prueba($db,function () use ($db,$producto) { conservar_variantes_edicion($db,$producto,7,'Rojo',[]); });
verificar_negocio($db->query('SELECT COUNT(*) FROM producto_color')->fetchColumn()==2,'Edicion elimina colores');
rechazar_negocio(function () use ($db,$producto) { operacion_prueba($db,function () use ($db,$producto) { conservar_variantes_edicion($db,$producto,8,'Rojo',[]); }); },'Stock ambiguo editado');
// Un color conserva identificadores aunque exista una venta que lo referencia.
$db->exec("INSERT INTO producto VALUES (2,2,'Negro'); INSERT INTO producto_color VALUES (21,2,'Negro'); INSERT INTO producto_color_talla(id_producto_color,talla,cantidad) VALUES (21,'UNICA',2); INSERT INTO producto_talla VALUES (2,'UNICA',2)");
$producto=$db->query('SELECT * FROM producto WHERE id_producto=2')->fetch();
$idAntes=$db->query('SELECT id_producto_color_talla FROM producto_color_talla WHERE id_producto_color=21')->fetchColumn();
operacion_prueba($db,function () use ($db,$producto) { conservar_variantes_edicion($db,$producto,3,'Negro',[]); });
verificar_negocio($db->query('SELECT id_producto_color_talla FROM producto_color_talla WHERE id_producto_color=21')->fetchColumn()==$idAntes,'Identificador de variante cambiado');
verificar_negocio($db->query('SELECT cantidad FROM producto_color_talla WHERE id_producto_color=21')->fetchColumn()==3,'Stock unico no ajustado');
$db->exec("INSERT INTO producto VALUES (3,2,''); INSERT INTO producto_talla VALUES (3,'L',2)");
$producto=$db->query('SELECT * FROM producto WHERE id_producto=3')->fetch();
operacion_prueba($db,function () use ($db,$producto) { conservar_variantes_edicion($db,$producto,3,'',[]); });
verificar_negocio($db->query('SELECT cantidad FROM producto_talla WHERE id_producto=3')->fetchColumn()==3,'Talla de producto antiguo no ajustada');
// Una variante desaparecida debe revertir cabecera, detalle y trigger de stock.
$db->exec("INSERT INTO venta VALUES (5,1,'pagada'); INSERT INTO detalle_venta VALUES (105,5,1,11,'XL',1,100,50,100,50)");
$stockAntes=$db->query('SELECT cantidad FROM producto WHERE id_producto=1')->fetchColumn();
$eventosAntes=$db->query('SELECT COUNT(*) FROM devolucion')->fetchColumn();
rechazar_negocio(function () use ($db) { operacion_prueba($db,function () use ($db) { guardar_devolucion($db,5,1,105,1,'variante perdida'); }); }, 'Variante perdida aceptada');
verificar_negocio($db->query('SELECT cantidad FROM producto WHERE id_producto=1')->fetchColumn()==$stockAntes,'Stock no revertido tras fallo');
verificar_negocio($db->query('SELECT COUNT(*) FROM devolucion')->fetchColumn()==$eventosAntes,'Devolucion parcial guardada tras fallo');
echo "PASS PostgreSQL: estados, variantes, bloqueo concurrente, descuentos, devolucion completa, reposicion y edicion\n";
