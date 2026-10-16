<?php
if (PHP_SAPI!=='cli') {http_response_code(404);exit;}
$modo=$argv[1]??'local';
if (!in_array($modo,['local','entorno','invalida'],true)) {
    throw new InvalidArgumentException('Modo desconocido');
}
$carpeta=sys_get_temp_dir().'/isa_config_'.bin2hex(random_bytes(12));
mkdir($carpeta);
try {
    foreach(['configuracion.php','configuracion_util.php'] as $archivo) {
        copy(__DIR__.'/../php/'.$archivo,$carpeta.'/'.$archivo);
    }
    if ($modo==='local') {
        file_put_contents($carpeta.'/config.local.php','<?php $GLOBALS["lecturas_fixture"]=($GLOBALS["lecturas_fixture"]??0)+1; return ["host"=>"fixture-local","mail"=>["provider"=>"brevo"]];');
    } elseif ($modo==='invalida') {
        file_put_contents($carpeta.'/config.local.php','<?php return false;');
    } else {
        putenv('ISA_DB_HOST=fixture-entorno');
    }
    $rechazada=false;
    try {
        $primera=require_once $carpeta.'/configuracion.php';
    } catch (RuntimeException $e) {
        $rechazada=true;
    }
    if ($modo==='invalida') {
        if (!$rechazada) {
            throw new RuntimeException('Configuracion invalida aceptada');
        }
        echo "PASS configuracion local invalida rechazada\n";
    } else {
        require_once $carpeta.'/configuracion.php';
        $segunda=cargar_configuracion();
        $tercera=cargar_configuracion();
        if (!is_array($primera) || $primera!==$segunda || $segunda!==$tercera) {
            throw new RuntimeException('Se perdio el arreglo en inclusiones repetidas');
        }
        $host=$modo==='local'?'fixture-local':'fixture-entorno';
        if ($segunda['host']!==$host) {
            throw new RuntimeException('Origen de configuracion incorrecto');
        }
        if ($modo==='local' && (($GLOBALS['lecturas_fixture']??0)!==1 || $segunda['mail']['provider']!=='brevo')) {
            throw new RuntimeException('Relectura o configuracion anidada perdida');
        }
        echo 'PASS configuracion '.$modo.': arreglo estable y origen conservado'.PHP_EOL;
    }
} finally {
    foreach(['config.local.php','configuracion_util.php','configuracion.php'] as $archivo) {
        if (is_file($carpeta.'/'.$archivo)) {
            unlink($carpeta.'/'.$archivo);
        }
    }
    rmdir($carpeta);
}
