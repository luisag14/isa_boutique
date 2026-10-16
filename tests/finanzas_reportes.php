<?php
require_once __DIR__.'/postgres_temporal.php';
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
date_default_timezone_set('America/Bogota');
require_once __DIR__.'/../php/finanzas_resumen_util.php';
require_once __DIR__.'/../php/reportes_util.php';
require_once __DIR__.'/../php/nomina_util.php';
function verificar_finanzas($condicion, $mensaje) { if (!$condicion) throw new RuntimeException($mensaje); }
function igual_importe($actual,$esperado,$mensaje) { verificar_finanzas(abs((float)$actual-$esperado)<0.005,$mensaje.' ('.$actual.' frente a '.$esperado.')'); }
$privados=['error'=>false,'ventas_hoy'=>119,'devoluciones_hoy'=>0,'neto_hoy'=>119,'ventas_mes'=>119,'neto_mes'=>119,'producto_top'=>'Blusa',
    'rango'=>['nomina'=>2000000,'utilidad_neta'=>20],'gastos_por_tipo'=>['nomina'=>2000000],
    'meta_diaria'=>['objetivo'=>10,'avance'=>50,'faltante'=>5,'ventas_hoy'=>5,'meta_mensual'=>300,'nomina'=>2000000]];
$vendedor=reporte_para_vendedor($privados);
verificar_finanzas(!isset($vendedor['rango']) && !isset($vendedor['gastos_por_tipo']) && !isset($vendedor['meta_diaria']['nomina']), 'Reporte vendedor filtra datos privados');
verificar_finanzas(count($vendedor)===8 && count($vendedor['meta_diaria'])===5,'Contrato del vendedor alterado');
verificar_finanzas(fecha_financiera('2026-02-30','respaldo')==='respaldo','Fecha inexistente aceptada');
verificar_finanzas(fecha_financiera('2026-02-28','respaldo')==='2026-02-28','Fecha valida rechazada');
verificar_finanzas(validar_pago_fijo('salario','2000000')===2000000,'Pago fijo rechazado');
foreach ([['deduccion',50000],['salario',1950000],['bono',2000000],['salario',null]] as $pago) {
    $rechazado=false; try { validar_pago_fijo(...$pago); } catch (DomainException $e) { $rechazado=true; }
    verificar_finanzas($rechazado,'Pago diferente al fijo aceptado');
}
echo "PASS permisos de respuesta, fechas y salario fijo\n";
if (!isset($argv[1])) exit;
$puerto=filter_var($argv[1],FILTER_VALIDATE_INT);
if ($puerto<55000 || $puerto>55999) throw new RuntimeException('Puerto local de pruebas invalido');
$db=conexion_postgres_prueba($puerto,[
    PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>true]);
if ((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()!==0) throw new RuntimeException('Se requiere una base de pruebas vacia');
$db->exec("SET TIME ZONE 'America/Bogota'");
$db->exec(<<<'SQL'
CREATE TABLE producto(id_producto integer PRIMARY KEY,codigo text,nombre text,estado text);
CREATE TABLE venta(id_venta integer PRIMARY KEY,id_cliente integer,id_usuario integer,fecha timestamp,estado text,total numeric,iva numeric,medio_pago text,canal_venta text);
CREATE TABLE detalle_venta(id_detalle_venta integer PRIMARY KEY,id_venta integer REFERENCES venta,id_producto integer REFERENCES producto,cantidad integer,subtotal numeric,subtotal_costo numeric,iva numeric);
CREATE TABLE devolucion(id_devolucion integer PRIMARY KEY,id_venta integer REFERENCES venta,fecha timestamp,total_devuelto numeric,estado text,motivo text);
CREATE TABLE detalle_devolucion(id_detalle_devolucion integer PRIMARY KEY,id_devolucion integer REFERENCES devolucion,id_detalle_venta integer REFERENCES detalle_venta,id_producto integer,cantidad integer,subtotal_devuelto numeric,subtotal_costo_devuelto numeric);
CREATE TABLE gasto_negocio(id_gasto integer PRIMARY KEY,id_usuario integer,tipo text,concepto text,valor numeric,fecha timestamp,detalle text);
CREATE TABLE pago_trabajador(id_pago_trabajador integer PRIMARY KEY,id_usuario integer,id_trabajador integer,tipo_pago text,valor numeric,fecha timestamp,detalle text);
CREATE TABLE inversion_negocio(id_inversion integer PRIMARY KEY,id_usuario integer,tipo text,concepto text,valor numeric,fecha timestamp,detalle text);
CREATE TABLE compra_mercancia(id_compra integer PRIMARY KEY,id_usuario integer,id_proveedor integer,total_compra numeric,fecha timestamp,detalle text);
CREATE TABLE cliente(id_cliente integer PRIMARY KEY,nombre text);
CREATE TABLE usuario_sistema(id_usuario integer PRIMARY KEY,nombre text);
CREATE TABLE trabajador(id_trabajador integer PRIMARY KEY,nombre text,cargo text);
CREATE TABLE proveedor(id_proveedor integer PRIMARY KEY,nombre text);
INSERT INTO producto VALUES(1,'P1','Blusa','activo'),(2,'P2','Sin ventas','activo');
INSERT INTO cliente VALUES(1,'Cliente'); INSERT INTO usuario_sistema VALUES(1,'Admin');
INSERT INTO trabajador VALUES(1,'Trabajador','Vendedor'); INSERT INTO proveedor VALUES(1,'Proveedor');
SQL);
$mes=date('Y-m-01');$siguiente=(new DateTimeImmutable($mes))->modify('+1 month')->format('Y-m-d');
$anterior=(new DateTimeImmutable($mes))->modify('-1 month')->format('Y-m-d');
$ultimo=(new DateTimeImmutable($mes))->modify('last day of this month')->format('Y-m-d');
$q=$db->prepare("INSERT INTO venta VALUES(?,1,1,?,?,?,?,'efectivo','tienda_fisica')");
foreach ([[1,$mes.' 10:00','pagada',119,19],[2,$mes.' 11:00','pendiente',9999,1596.48],[3,$mes.' 12:00','cancelada',8888,1419.09],
    [4,$anterior.' 10:00','pagada',119,19],[5,$ultimo.' 23:59:59','devuelta',10,1.60]] as $v) $q->execute($v);
$db->exec('INSERT INTO detalle_venta VALUES(11,1,1,1,119,60,19),(12,2,1,1,9999,9000,1596.48),(13,3,1,1,8888,8000,1419.09),(14,4,1,1,119,60,19),(15,5,1,3,10,3,1.60)');
$q=$db->prepare("INSERT INTO devolucion VALUES(?,?,?,?,'aprobada','Prueba')");
foreach ([[1,1,$mes.' 15:00',59.50],[2,4,$mes.' 16:00',119],[3,5,$ultimo.' 23:59:59',3.33],[4,5,$ultimo.' 23:59:59',3.34],[5,5,$ultimo.' 23:59:59',3.33]] as $d) $q->execute($d);
$db->exec('INSERT INTO detalle_devolucion VALUES(1,1,11,1,1,59.50,30),(2,2,14,1,1,119,60),(3,3,15,1,1,3.33,1),(4,4,15,1,1,3.34,1),(5,5,15,1,1,3.33,1)');
$q=$db->prepare("INSERT INTO gasto_negocio VALUES(?,1,?,?,?,?,'Prueba')");
$q->execute([1,'servicio','Luz',10,$ultimo.' 23:59:59']);$q->execute([2,'nomina','Nomina antigua',5,$mes]);
$q=$db->prepare("INSERT INTO pago_trabajador VALUES(?,1,1,?,?,?,'Prueba')");
$q->execute([1,'salario',2000000,$mes]);$q->execute([2,'deduccion',50000,$mes]);
$db->prepare("INSERT INTO inversion_negocio VALUES(1,1,'capital','Aporte',500,?,'Prueba')")->execute([$mes]);
$db->prepare("INSERT INTO compra_mercancia VALUES(1,1,1,200,?,'Prueba')")->execute([$mes]);
if (($argv[2] ?? '')==='indices') {
    // Completar solo las columnas/tablas que este fixture financiero no necesitaba.
    $db->exec('ALTER TABLE cliente ADD COLUMN telefono text; CREATE TABLE producto_imagen(id_producto_imagen integer PRIMARY KEY,id_producto integer REFERENCES producto)');
    $migracion=file_get_contents(__DIR__.'/../database/migracion_indices_consultas.sql');
    $db->exec($migracion);$db->exec($migracion);
    preg_match_all('/CREATE INDEX IF NOT EXISTS (\w+)/',$migracion,$nombres);
    foreach ($nombres[1] as $nombre) {
        $q=$db->prepare('SELECT indisvalid FROM pg_index WHERE indexrelid=CAST(? AS regclass)');$q->execute([$nombre]);
        verificar_finanzas(filter_var($q->fetchColumn(),FILTER_VALIDATE_BOOLEAN),'Indice invalido: '.$nombre);
    }
    $q=$db->prepare("INSERT INTO venta SELECT serie,1,1,CAST(? AS timestamp)-INTERVAL '1 year','pagada',119,19,'efectivo','tienda_fisica' FROM generate_series(10000,12999) serie");$q->execute([$mes]);
    $db->exec('INSERT INTO detalle_venta SELECT serie+20000,serie,1,1,119,60,19 FROM generate_series(10000,12999) serie');
    $db->exec('ANALYZE venta');
    $q=$db->prepare('EXPLAIN (FORMAT JSON) SELECT id_venta FROM venta WHERE fecha>=CAST(? AS timestamp) AND fecha<CAST(? AS timestamp)');
    $q->execute([$mes,$siguiente]);$plan=$q->fetchColumn();
    verificar_finanzas(strpos($plan,'idx_venta_fecha')!==false,'El filtro de rango no aprovecha el indice en la muestra sintetica');
    echo 'PASS '.count($nombres[1])." indices validos, migracion repetible y plan con indice en muestra sintetica\n";
}
$metricas=leer_finanzas_consistentes($db,function () use ($db,$mes,$siguiente) { return metricas_ventas_financieras($db,$mes,$siguiente); });
igual_importe($metricas['ventas'],129,'Ventas pendientes o canceladas incluidas');
igual_importe($metricas['costo_vendido'],63,'Costo de pedidos no pagados incluido');
igual_importe($metricas['iva_devuelto'],30.10,'IVA de devoluciones acumulado incorrecto');
igual_importe($metricas['devoluciones'],188.50,'Devoluciones del periodo incorrectas');
$resumen=leer_finanzas_consistentes($db,function () use ($db) { return construir_resumen_finanzas($db); });
$reportes=leer_finanzas_consistentes($db,function () use ($db,$mes,$ultimo) { return construir_reportes($db,$mes,$ultimo); });
igual_importe($resumen['costo_mercancia_mes'],-30,'Costo neto incorrecto');
igual_importe($resumen['utilidad_bruta_mes'],-20,'Utilidad sin IVA incorrecta');
igual_importe($resumen['iva_neto_mes'],-9.50,'IVA neto incorrecto');
igual_importe($reportes['rango']['gastos_generales'],15,'Gasto del ultimo dia omitido');
igual_importe($reportes['rango']['nomina'],2000000,'Deduccion historica tratada como pago');
foreach (['ventas_netas','costo_mercancia','utilidad_bruta','utilidad_neta','saldo_caja_estimado'] as $campo) {
    igual_importe($resumen[$campo.'_mes'],$reportes['rango'][$campo],'Resumen y reporte difieren en '.$campo);
}
igual_importe($resumen['clasificacion_mes']['ganancia_libre_estimada'],$resumen['utilidad_neta_mes'],'Dos ganancias diferentes');
igual_importe($resumen['clasificacion_mes']['trabajadores'],2000005,'Nomina en gastos omitida de clasificacion');
igual_importe($reportes['rango']['productos_top'][0]['ventas'],$reportes['rango']['ventas_netas'],'Ranking ignora devoluciones');
igual_importe($reportes['meta_diaria']['meta_mensual'],$resumen['meta_ventas_ganancia_mes'],'Metas inconsistentes');
$movimientos=leer_finanzas_consistentes($db,function () use ($db) { return construir_movimientos_financieros($db); });
$caja=0;foreach($movimientos as $m) if($m['fecha'] >= $mes && $m['fecha'] < $siguiente) $caja+=(float)$m['valor'];
igual_importe($caja,$resumen['saldo_caja_estimado_mes'],'Caja y movimientos no coinciden');
$ventasClasificadas=$resumen['ventas_clasificadas_mes'];
igual_importe($ventasClasificadas[0]['utilidad_bruta'],0,'Venta totalmente devuelta tiene utilidad');
$bloqueada=false;try { leer_finanzas_consistentes($db,function () use ($db) { $db->exec('UPDATE producto SET nombre=nombre'); }); }
catch(PDOException $e){$bloqueada=$e->getCode()==='25006';}
verificar_finanzas($bloqueada && !$db->inTransaction(),'Lectura permite escrituras o deja transaccion abierta');
echo "PASS PostgreSQL: estados, IVA, devoluciones entre meses, redondeos, fechas completas, caja, metas y lecturas sin escrituras\n";
