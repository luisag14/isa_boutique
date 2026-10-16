<?php
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/postgres_temporal.php';
require_once __DIR__.'/../php/usuario_inicial_util.php';
require_once __DIR__.'/../php/cookie_segura.php';
function comprobar_inicial($ok,$mensaje){if(!$ok)throw new RuntimeException($mensaje);}
$local=['HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'127.0.0.1'];
comprobar_inicial(opciones_cookie_sesion($local,false,'local')['secure']===true,'Local pierde el atributo Secure');
comprobar_inicial(opciones_cookie_sesion($local+['HTTPS'=>'on'],false,'production')['secure']===true,'HTTPS no exige cookie segura');
foreach([
    ['HTTPS'=>'on','REMOTE_ADDR'=>'192.0.2.1','HTTP_HOST'=>'tienda.example'],
    ['SERVER_PORT'=>'443','REMOTE_ADDR'=>'192.0.2.1','HTTP_HOST'=>'tienda.example']
] as $servidorHttps){
    $cookie=opciones_cookie_sesion($servidorHttps,false,'production');
    comprobar_inicial($cookie['secure']===true && $cookie['httponly']===true && $cookie['samesite']==='Lax','La sesion HTTPS pierde sus atributos de seguridad');
}
foreach(['localhost:8080','127.0.0.1:8080','[::1]:8080'] as $hostLocal){
    $servidorLocal=['HTTP_HOST'=>$hostLocal,'REMOTE_ADDR'=>$hostLocal==='[::1]:8080'?'::1':'127.0.0.1'];
    comprobar_inicial(opciones_cookie_sesion($servidorLocal,false,'local')['secure']===true,'Local con puerto pierde Secure');
}
foreach([
    [$local,'production'],
    [['HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'192.0.2.1'],'local'],
    [['HTTP_HOST'=>'tienda.example','REMOTE_ADDR'=>'127.0.0.1'],'local'],
    [['HTTP_HOST'=>'tienda.example','REMOTE_ADDR'=>'192.0.2.1','HTTP_X_FORWARDED_PROTO'=>'https'],'production'],
    [['HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'192.0.2.1','HTTP_X_FORWARDED_FOR'=>'127.0.0.1'],'local'],
    [['HTTP_HOST'=>'localhost','REMOTE_ADDR'=>'127.0.0.1','HTTPS'=>'off'],'production']
] as [$servidor,$entorno]){
    $rechazado=false;try{opciones_cookie_sesion($servidor,false,$entorno);}catch(DomainException $e){$rechazado=true;}
    comprobar_inicial($rechazado,'HTTP publico elude HTTPS');
}
// Claves de fixture nuevas por ejecucion, nunca hashes ni claves iniciales compartidas.
$password='Aa1'.bin2hex(random_bytes(16));
$usuario=preparar_usuario_inicial('Admin inicial','NUEVO@example.test','admin',$password);
comprobar_inicial(password_verify($password,$usuario['contrasena'])&&$usuario['correo']==='nuevo@example.test','Password o correo incorrectos');
if(!isset($argv[1])){echo "PASS cookies por entorno y preparacion sin claves predeterminadas\n";exit;}
$db=conexion_postgres_prueba($argv[1]);
comprobar_inicial((int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'")->fetchColumn()===0,'Base no vacia');
$db->exec('CREATE TABLE usuario_sistema(id_usuario serial PRIMARY KEY,nombre varchar(100),correo varchar(100) UNIQUE,contrasena varchar(255),rol text,estado boolean)');
$db->exec('CREATE TABLE categoria(nombre text UNIQUE,descripcion text,estado boolean)');
$db->exec(file_get_contents(__DIR__.'/../database/produccion_datos_minimos.sql'));
$db->exec(file_get_contents(__DIR__.'/../database/produccion_datos_minimos.sql'));
comprobar_inicial((int)$db->query('SELECT COUNT(*) FROM usuario_sistema WHERE estado=TRUE')->fetchColumn()===0,'La semilla habilita cuentas');
foreach($db->query('SELECT contrasena FROM usuario_sistema')->fetchAll(PDO::FETCH_COLUMN) as $marcador) comprobar_inicial(!password_verify($marcador,$marcador),'Marcador utilizable como password');
$admin=preparar_usuario_inicial('Admin','admin@isaboutique.com','admin',$password);
$id=crear_usuario_inicial($db,$admin);
$q=$db->prepare('SELECT contrasena,estado FROM usuario_sistema WHERE id_usuario=?');$q->execute([$id]);$fila=$q->fetch();
comprobar_inicial(password_verify($password,$fila['contrasena'])&&$fila['estado'],'No se habilita marcador con clave propia');
$antes=$db->query('SELECT md5(jsonb_agg(to_jsonb(u) ORDER BY id_usuario)::text) FROM usuario_sistema u')->fetchColumn();
$rechazado=false;try{crear_usuario_inicial($db,preparar_usuario_inicial('Cambio','admin@isaboutique.com','admin','Aa2'.bin2hex(random_bytes(16))));}catch(DomainException $e){$rechazado=true;}
comprobar_inicial($rechazado&&!$db->inTransaction(),'Sobrescribe usuario normal');
comprobar_inicial($antes===$db->query('SELECT md5(jsonb_agg(to_jsonb(u) ORDER BY id_usuario)::text) FROM usuario_sistema u')->fetchColumn(),'Rechazo altera datos');
crear_usuario_inicial($db,$usuario);
$db->exec(file_get_contents(__DIR__.'/../database/migracion_seguridad_passwords.sql'));
$db->exec("INSERT INTO usuario_sistema(nombre,correo,contrasena,rol,estado) VALUES('Heredado','heredado@example.test','sin-hash','vendedor',TRUE)");
$rechazado=false;try{$db->exec(file_get_contents(__DIR__.'/../database/migracion_seguridad_passwords.sql'));}catch(PDOException $e){$rechazado=true;}
comprobar_inicial($rechazado,'La comprobacion acepta cuentas activas sin hash');
echo "PASS PostgreSQL: semillas inactivas e idempotentes, claves propias, creacion, rechazo de sobrescritura y comprobacion heredada\n";
