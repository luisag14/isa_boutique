<?php
require_once __DIR__.'/postgres_temporal.php';
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../php/notificaciones_util.php';
require_once __DIR__.'/../php/mailer_brevo.php';
function comprobar_correo($valor,$mensaje){if(!$valor)throw new RuntimeException($mensaje);}
comprobar_correo(brevo_validar_respuesta(201,'{"messageId":"prueba"}')===true,'Confirmacion valida rechazada');
foreach([401,403,400,429] as $codigo){
 $rechazada=false;try{brevo_validar_respuesta($codigo,'{}');}catch(CorreoNoAceptadoException $e){$rechazada=$e->esReintentable()===($codigo===429);}
 comprobar_correo($rechazada,'Clasificacion de rechazo incorrecta');
}
foreach([[201,'{}'],[500,'{}'],[408,'{}']] as $respuesta){
 $incierta=false;try{brevo_validar_respuesta(...$respuesta);}catch(Throwable $e){$incierta=!($e instanceof CorreoNoAceptadoException);}
 comprobar_correo($incierta,'Respuesta incierta considerada reintentable');
}
echo "PASS respuestas simuladas del proveedor\n";
if(!isset($argv[1]))exit;
$puerto=filter_var($argv[1],FILTER_VALIDATE_INT);
if($puerto<55000||$puerto>55999)throw new RuntimeException('Puerto temporal invalido');
$opciones=[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>true];
$db=conexion_postgres_prueba($puerto,$opciones);$otra=conexion_postgres_prueba($puerto,$opciones);
if((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()!==0)throw new RuntimeException('Base temporal no vacia');
$db->exec("CREATE TABLE notificacion_correo(id_notificacion serial PRIMARY KEY,destinatario varchar(150),asunto varchar(200),cuerpo_html text,cuerpo_texto text,estado varchar(20) DEFAULT 'pendiente',intentos integer DEFAULT 0,error_ultimo text,fecha_creacion timestamp DEFAULT CURRENT_TIMESTAMP,fecha_envio timestamp)");
function agregar_correo(PDO $db,$asunto='Prueba'){
 $q=$db->prepare("INSERT INTO notificacion_correo(destinatario,asunto,cuerpo_html,cuerpo_texto)VALUES('nadie@example.test',?,'<p>Prueba</p>','Prueba')RETURNING id_notificacion");$q->execute([$asunto]);return(int)$q->fetchColumn();
}
$ids=[agregar_correo($db),agregar_correo($db),agregar_correo($db)];$envios=[];$resultadoOtro=null;
$resultado=procesar_notificaciones($db,2,function($n)use($db,$otra,&$envios,&$resultadoOtro){
 $envios[]=$n['id_notificacion'];
 comprobar_correo(!$db->inTransaction(),'Transaccion abierta durante envio');
 if($resultadoOtro===null){$resultadoOtro=procesar_notificaciones($otra,20,function($otro)use(&$envios){$envios[]=$otro['id_notificacion'];return true;});}
 return true;
});
comprobar_correo(count($envios)===3&&count(array_unique($envios))===3,'Procesadores envian el mismo correo');
comprobar_correo($resultado['enviadas']===2&&$resultadoOtro['enviadas']===1&&$resultado['pendientes']===0,'Conteo concurrente incorrecto');
$incierto=agregar_correo($db,'Incierto');
$r=procesar_notificaciones($db,20,function(){throw new RuntimeException('Tiempo agotado despues de enviar');});
comprobar_correo($r['requieren_revision']===1&&$r['pendientes']===0,'Envio ambiguo vuelve a pendiente');
$enviadosDespues=0;procesar_notificaciones($db,20,function()use(&$enviadosDespues){$enviadosDespues++;return true;});
comprobar_correo($enviadosDespues===0,'Reenvio automatico de correo incierto');
$rechazado=agregar_correo($db,'Temporal');
for($intento=1;$intento<=3;$intento++){
 $r=procesar_notificaciones($db,20,function(){throw new CorreoNoAceptadoException('Limite del proveedor',true);});
 comprobar_correo($r['fallidas']===1&&$r['pendientes']===($intento<3?1:0),'Limite de reintentos o pendientes incorrecto');
}
$q=$db->prepare('SELECT intentos,estado FROM notificacion_correo WHERE id_notificacion=?');$q->execute([$rechazado]);$fila=$q->fetch();
comprobar_correo((int)$fila['intentos']===3&&$fila['estado']==='fallida','Se excedieron tres intentos');
$definitivo=agregar_correo($db,'Definitivo');
$r=procesar_notificaciones($db,20,function(){throw new CorreoNoAceptadoException('Destinatario invalido');});
comprobar_correo($r['pendientes']===0,'Rechazo definitivo reintentable');
// Una reserva abandonada no se envia otra vez sin revision humana.
$abandonado=agregar_correo($db,'Abandonado');$reservados=reservar_notificaciones($db,1);
comprobar_correo((int)$reservados[0]['id_notificacion']===$abandonado,'Reserva incorrecta');
$r=procesar_notificaciones($otra,20,function(){throw new RuntimeException('Nunca debe invocarse');});
comprobar_correo($r['en_proceso']===1&&$r['revision']===0,'Reserva abandonada reenviada');
// Falla la persistencia despues de que el remitente simulado confirma el envio.
$persistencia=agregar_correo($db,'Persistencia');
$db->exec("CREATE FUNCTION bloquear_confirmacion()RETURNS trigger AS $$ BEGIN IF NEW.estado='enviada' AND OLD.asunto='Persistencia' THEN RAISE EXCEPTION 'fallo simulado'; END IF;RETURN NEW;END $$ LANGUAGE plpgsql; CREATE TRIGGER fallo_confirmacion BEFORE UPDATE ON notificacion_correo FOR EACH ROW EXECUTE FUNCTION bloquear_confirmacion()");
$fallo=false;$llamadas=0;
try{procesar_notificaciones($db,20,function()use(&$llamadas){$llamadas++;return true;});}catch(PDOException $e){$fallo=true;}
comprobar_correo($fallo&&$llamadas===1,'No se detecto fallo posterior a aceptacion');
$db->exec('DROP TRIGGER fallo_confirmacion ON notificacion_correo');
procesar_notificaciones($db,20,function()use(&$llamadas){$llamadas++;return true;});
comprobar_correo($llamadas===1,'Envio duplicado tras fallo de persistencia');
// Comprobar SKIP LOCKED con una fila bloqueada por otra conexion.
$bloqueado=agregar_correo($db,'Bloqueado');$libre=agregar_correo($db,'Libre');
$db->beginTransaction();$db->query('SELECT * FROM notificacion_correo WHERE id_notificacion='.$bloqueado.' FOR UPDATE')->fetch();
$lote=reservar_notificaciones($otra,20);$db->rollBack();
comprobar_correo(count($lote)===1&&(int)$lote[0]['id_notificacion']===$libre,'Reserva no evita fila bloqueada');
echo "PASS PostgreSQL: reservas concurrentes, estados inciertos, reintentos limitados, conteos reales, reservas abandonadas y fallo despues del envio\n";
