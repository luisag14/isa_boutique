<?php
require_once __DIR__.'/postgres_temporal.php';
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$puerto=filter_var($argv[1]??0,FILTER_VALIDATE_INT);
if($puerto<55000||$puerto>55999) throw new RuntimeException('Solo PostgreSQL temporal');
$opciones=[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>true];
if(($argv[2]??'')==='worker') {
    $directorio=$argv[3];$datos=json_decode(base64_decode($argv[4]),true,512,JSON_THROW_ON_ERROR);
    set_include_path($directorio.PATH_SEPARATOR.realpath(__DIR__.'/../php'));
    if(realpath(stream_resolve_include_path('conexion.php'))!==realpath($directorio.'/conexion.php')) throw new RuntimeException('Conexion de prueba no resuelta');
    session_set_save_handler(fn()=>true,fn()=>true,fn()=>'',fn()=>true,fn()=>true,fn()=>0);
    $_SERVER=['REQUEST_METHOD'=>$datos['metodo']??'POST','REMOTE_ADDR'=>$datos['ip']??'192.0.2.201','HTTP_HOST'=>'atacante.example'];
    require_once 'auth_guard.php';require_once 'captcha_util.php';
    $_POST=$datos['post'];
    if($datos['endpoint']==='login') {$_POST['captcha_token']=crear_captcha_token('4');$_POST['captcha_respuesta']=$datos['captcha']??'4';}
    ob_start();register_shutdown_function(function(){ $cuerpo=ob_get_clean();echo json_encode(['estado'=>http_response_code()?:200,'respuesta'=>json_decode($cuerpo,true)]); });
    require_once __DIR__.'/../php/'.$datos['endpoint'].'.php';exit;
}
$db=conexion_postgres_prueba($puerto,$opciones);
if($db->query("SELECT to_regclass('public.usuario_sistema')")->fetchColumn()!==null) throw new RuntimeException('La fixture requiere ausencia de usuarios');
$db->exec(file_get_contents(__DIR__.'/../database/migracion_limites_acceso.sql'));
$db->exec("CREATE TABLE usuario_sistema(id_usuario serial PRIMARY KEY,nombre text,correo text,contrasena text,rol text,estado boolean,sesion_token text,sesion_actualizada timestamptz);
CREATE TABLE password_reset_token(id_reset serial PRIMARY KEY,id_usuario integer,token_hash text,expira_en timestamptz,usado boolean DEFAULT false,fecha_uso timestamptz,ip_solicitud text);
CREATE TABLE correo_prueba(cuerpo text);");
$q=$db->prepare("INSERT INTO usuario_sistema(nombre,correo,contrasena,rol,estado) VALUES('Prueba',?,?, 'admin',true)");
$q->execute(['correcto@example.test',password_hash(' Clave12345 ',PASSWORD_DEFAULT)]);
$carpeta=sys_get_temp_dir().'/isa_endpoints_'.bin2hex(random_bytes(12));mkdir($carpeta);
file_put_contents($carpeta.'/conexion.php', '<?php require_once '.var_export(__DIR__.'/postgres_temporal.php',true).'; $config=["app_url"=>"https://tienda.example/isa"]; $conexion=conexion_postgres_prueba('.$puerto.');');
file_put_contents($carpeta.'/mailer_smtp.php','<?php function enviar_correo_smtp($correo,$asunto,$html,$texto){global $conexion; $q=$conexion->prepare("INSERT INTO correo_prueba VALUES(?)");$q->execute([$texto]);}');
file_put_contents($carpeta.'/notificaciones_seguridad.php','<?php function notificar_inicio_sesion($usuario){} function notificar_intento_otro_dispositivo($usuario){}');
function peticion_prueba($datos) {
    global $puerto,$carpeta;
    $p=proc_open([PHP_BINARY,__FILE__,(string)$puerto,'worker',$carpeta,base64_encode(json_encode($datos))],[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes,null,null,['bypass_shell'=>true]);
    if(!is_resource($p))throw new RuntimeException('No se pudo iniciar peticion');
    fclose($pipes[0]);$salida=stream_get_contents($pipes[1]);fclose($pipes[1]);$error=stream_get_contents($pipes[2]);fclose($pipes[2]);
    $errorPrevisto=($datos['error_esperado']??false)&&str_contains($error,'No se pudo comprobar el limite de acceso: PDOException');
    if(proc_close($p)!==0||($error!==''&&!$errorPrevisto)) throw new RuntimeException('Fallo endpoint temporal: '.$error);
    return json_decode($salida,true,512,JSON_THROW_ON_ERROR);
}
function comprobar_endpoint($ok,$mensaje) {if(!$ok)throw new RuntimeException($mensaje);}
try {
    $login=['endpoint'=>'login','post'=>['correo'=>'incorrecto@example.test','contrasena'=>'incorrecta'],'captcha'=>'incorrecto'];
    for($i=0;$i<5;$i++) comprobar_endpoint(peticion_prueba($login)['estado']===200,'Captcha inicial bloqueado');
    $login['ip']='192.0.2.202';comprobar_endpoint(peticion_prueba($login)['estado']===429,'Cambiar sesion/IP evade limite del endpoint');
    $login=['endpoint'=>'login','post'=>['correo'=>'correcto@example.test','contrasena'=>' Clave12345 ']];
    $r=peticion_prueba($login);comprobar_endpoint($r['estado']===200&&$r['respuesta']['error']===false,'Login valido falla o altera espacios de password');
    $recuperar=['endpoint'=>'password_recuperar_solicitar','post'=>['correo'=>'correcto@example.test']];
    for($i=0;$i<3;$i++) comprobar_endpoint(peticion_prueba($recuperar)['respuesta']['error']===false,'Recuperacion valida falla');
    comprobar_endpoint(peticion_prueba($recuperar)['estado']===429,'Recuperacion evita limite con sesion nueva');
    comprobar_endpoint((int)$db->query('SELECT COUNT(*) FROM correo_prueba')->fetchColumn()===3,'Cantidad de correos simulados incorrecta');
    $correo=$db->query('SELECT cuerpo FROM correo_prueba ORDER BY ctid DESC LIMIT 1')->fetchColumn();
    comprobar_endpoint(strpos($correo,'https://tienda.example/isa/html/restablecer_password.html?token=')!==false&&strpos($correo,'atacante.example')===false,'Enlace envenenado por Host');
    preg_match('/token=([a-f0-9]{64})/',$correo,$m);
    $confirmar=['endpoint'=>'password_recuperar_confirmar','post'=>['token'=>$m[1],'password_nueva'=>' Nueva12345 ','password_confirmar'=>' Nueva12345 ']];
    comprobar_endpoint(peticion_prueba($confirmar)['respuesta']['error']===false,'No se pudo confirmar password');
    comprobar_endpoint(peticion_prueba($confirmar)['estado']===400,'Token reutilizable');
    $fila=$db->query('SELECT contrasena,sesion_token FROM usuario_sistema')->fetch();
    comprobar_endpoint(password_verify(' Nueva12345 ',$fila['contrasena'])&&$fila['sesion_token']===null,'Password o revocacion incorrectos');
    $db->exec('ALTER TABLE limite_acceso RENAME TO limite_acceso_temporal');
    try {comprobar_endpoint(peticion_prueba(['endpoint'=>'login','post'=>[],'error_esperado'=>true])['estado']===503,'Ausencia de tabla permite acceso');}
    finally {$db->exec('ALTER TABLE limite_acceso_temporal RENAME TO limite_acceso');}
    echo "PASS endpoints reales con conexion/correo simulados: captcha, cuota persistente, login, URL segura, recuperacion y token de un uso\n";
} finally {
    // Solo los tres archivos de prueba que este proceso creo en su directorio aleatorio.
    foreach(['conexion.php','mailer_smtp.php','notificaciones_seguridad.php'] as $archivo) unlink($carpeta.'/'.$archivo);
    rmdir($carpeta);
}
