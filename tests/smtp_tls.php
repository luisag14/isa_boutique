<?php
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/../php/mailer_smtp.php';
function comprobar_tls($condicion,$mensaje) { if (!$condicion) throw new RuntimeException($mensaje); }
$opciones=opciones_tls_smtp('correo.example.test');
comprobar_tls($opciones['crypto_method']===(STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT|STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT),'Protocolos TLS no restringidos');
comprobar_tls($opciones['verify_peer']===true&&$opciones['verify_peer_name']===true&&$opciones['allow_self_signed']===false,'Verificacion del certificado desactivada');
comprobar_tls($opciones['peer_name']==='correo.example.test','Identidad del servidor incorrecta');
$contexto=stream_context_create(['ssl'=>$opciones]);
comprobar_tls(stream_context_get_options($contexto)['ssl']===$opciones,'Opciones perdidas al crear contexto');
// Configuracion ficticia: estos casos deben rechazarse ANTES de abrir cualquier conexion.
foreach(['none','plain','sin-cifrado'] as $cifrado) {
    $config=['mail'=>['provider'=>'smtp','host'=>'correo.example.test','username'=>'usuario-prueba',
        'password'=>'dato-ficticio','from_email'=>'prueba@example.test','encryption'=>$cifrado]];
    $rechazado=false;
    try {enviar_correo_smtp('destino@example.test','Prueba','Texto');}
    catch(RuntimeException $e) {$rechazado=str_contains($e->getMessage(),'requiere TLS');}
    comprobar_tls($rechazado,'SMTP sin cifrado no rechazado antes de conectar');
}
echo "PASS politica TLS 1.2/1.3, certificados y rechazo de SMTP sin cifrado; sin conexiones ni correos\n";
