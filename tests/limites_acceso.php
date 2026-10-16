<?php
require_once __DIR__.'/postgres_temporal.php';
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/../php/limite_acceso.php';
require_once __DIR__.'/../php/app_url.php';
function verificar_limite($ok, $mensaje) { if (!$ok) throw new RuntimeException($mensaje); }
$servidor=['REMOTE_ADDR'=>'192.0.2.1'];
$r=reglas_limite_acceso('login',' Persona@example.test ', $servidor);
verificar_limite($r===reglas_limite_acceso('login','persona@example.test',$servidor+['HTTP_X_FORWARDED_FOR'=>'203.0.113.1']), 'Identidad eludible con mayusculas o cabecera');
verificar_limite(reglas_limite_acceso('confirmar','',['REMOTE_ADDR'=>'2001:db8::1'])===reglas_limite_acceso('confirmar','',['REMOTE_ADDR'=>'2001:0db8:0:0:0:0:0:1']), 'IPv6 no normalizada');
$_SERVER['HTTP_HOST']='atacante.example';
verificar_limite(url_base_configurada(['app_url'=>'https://tienda.example/isa/'])==='https://tienda.example/isa','URL depende del Host');
foreach(['http://tienda.example','https://user:pass@tienda.example','https://tienda.example/?x=1',"https://tienda.example\r\nX:y",'//tienda.example'] as $url) {
    $rechazada=false; try { url_base_configurada(['app_url'=>$url]); } catch (RuntimeException $e) { $rechazada=true; }
    verificar_limite($rechazada,'URL insegura aceptada');
}
if (!isset($argv[1])) { echo "PASS identidad, IP y URL configurada\n"; exit; }
$puerto=filter_var($argv[1],FILTER_VALIDATE_INT);
if($puerto<55000||$puerto>55999) throw new RuntimeException('Solo PostgreSQL temporal');
$db=conexion_postgres_prueba($puerto,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_EMULATE_PREPARES=>true]);
if(($argv[2]??'')==='worker') {
    echo json_encode(consumir_limite_acceso($db,'login','concurrente@example.test',['REMOTE_ADDR'=>'192.0.2.55'])); exit;
}
verificar_limite((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()===0,'Base no vacia');
$fallo=false;try{consumir_limite_acceso($db,'login','x@example.test',$servidor);}catch(PDOException $e){$fallo=true;}
verificar_limite($fallo&&!$db->inTransaction(),'Fallo sin migracion no revierte');
$migracion=file_get_contents(__DIR__.'/../database/migracion_limites_acceso.sql');$db->exec($migracion);$db->exec($migracion);
for($i=0;$i<5;$i++) verificar_limite(consumir_limite_acceso($db,'login','persona@example.test',['REMOTE_ADDR'=>'192.0.2.'.($i+1)])['permitido'],'Cuota inicial incorrecta');
$_SESSION=[]; // Borrar la sesion no debe cambiar la decision.
$bloqueado=consumir_limite_acceso($db,'login','PERSONA@example.test',['REMOTE_ADDR'=>'192.0.2.99']);
verificar_limite(!$bloqueado['permitido']&&$bloqueado['espera']>0&&$bloqueado['espera']<=300,'Cuenta no bloqueada tras cambiar IP y sesion');
for($i=0;$i<30;$i++) verificar_limite(consumir_limite_acceso($db,'login','otra'.$i.'@example.test',['REMOTE_ADDR'=>'192.0.2.100'])['permitido'],'Cuota IP inicial incorrecta');
verificar_limite(!consumir_limite_acceso($db,'login','otra-final@example.test',['REMOTE_ADDR'=>'192.0.2.100'])['permitido'],'Cambiar cuenta evade limite IP');
for($i=0;$i<3;$i++) verificar_limite(consumir_limite_acceso($db,'recuperar','persona@example.test',$servidor)['permitido'],'Cuota recuperacion incorrecta');
verificar_limite(!consumir_limite_acceso($db,'recuperar','persona@example.test',$servidor)['permitido'],'Recuperacion no limitada');
for($i=0;$i<30;$i++) verificar_limite(consumir_limite_acceso($db,'confirmar','',$servidor)['permitido'],'Cuota confirmacion incorrecta');
verificar_limite(!consumir_limite_acceso($db,'confirmar','',$servidor)['permitido'],'Confirmacion no limitada');
$db->exec("UPDATE limite_acceso SET vence_en=NOW()-INTERVAL '1 second'");
verificar_limite(consumir_limite_acceso($db,'login','persona@example.test',$servidor)['permitido'],'Ventana vencida no se reinicia');
// Ocho procesos compiten por la misma cuota de cinco solicitudes.
$procesos=[];
for($i=0;$i<8;$i++) {
    $p=proc_open([PHP_BINARY,__FILE__,(string)$puerto,'worker'],[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes,null,null,['bypass_shell'=>true]);
    if(!is_resource($p)) throw new RuntimeException('No se pudo iniciar proceso');
    fclose($pipes[0]);$procesos[]=[$p,$pipes];
}
$permitidos=0;$rechazados=0;
foreach($procesos as [$p,$pipes]) {
    $salida=stream_get_contents($pipes[1]);fclose($pipes[1]);$error=stream_get_contents($pipes[2]);fclose($pipes[2]);
    verificar_limite(proc_close($p)===0,'Proceso concurrente fallo: '.$error);
    $resultado=json_decode($salida,true,512,JSON_THROW_ON_ERROR);
    if($resultado['permitido'])$permitidos++;else $rechazados++;
}
verificar_limite($permitidos===5&&$rechazados===3,'La concurrencia excede la cuota');
// Mantener una fila bloqueada debe fallar, nunca permitir acceso por omision.
$reglas=reglas_limite_acceso('login','bloqueada@example.test',$servidor);
consumir_limite_acceso($db,'login','bloqueada@example.test',$servidor);
$otra=conexion_postgres_prueba($puerto,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
$db->beginTransaction();$q=$db->prepare('SELECT clave FROM limite_acceso WHERE clave=? FOR UPDATE');$q->execute([$reglas[0]['clave']]);
$fallo=false;try{consumir_limite_acceso($otra,'login','bloqueada@example.test',$servidor);}catch(PDOException $e){$fallo=$e->getCode()==='55P03';}
$db->rollBack();verificar_limite($fallo&&!$otra->inTransaction(),'Bloqueo permite acceso o deja transaccion');
$q=$db->prepare("INSERT INTO limite_acceso VALUES(?,1,NOW()-INTERVAL '2 days')");
for($i=0;$i<150;$i++)$q->execute([hash('sha256','caducado'.$i)]);
consumir_limite_acceso($db,'login','limpieza@example.test',$servidor);
verificar_limite((int)$db->query("SELECT COUNT(*) FROM limite_acceso WHERE vence_en<NOW()-INTERVAL '1 day'")->fetchColumn()===50,'Limpieza no acotada a 100 filas');
echo "PASS PostgreSQL: limites por cuenta/IP, sesion nueva, caducidad, ocho procesos concurrentes, rollback y limpieza acotada\n";
