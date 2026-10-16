<?php
// Pruebas locales: no conectan a PostgreSQL ni envian correos.
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

// Sesiones en memoria: las pruebas no crean archivos de sesion reales.
session_set_save_handler(
    function ($ruta, $nombre) { return true; },
    function () { return true; },
    function ($id) { return ''; },
    function ($id, $datos) { return true; },
    function ($id) { return true; },
    function ($tiempo) { return 0; }
);
require_once __DIR__ . '/../php/auth_guard.php';
require_once __DIR__ . '/../php/captcha_util.php';
require_once __DIR__ . '/../php/auditoria.php';
register_shutdown_function(function () {
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_destroy();
    }
});

function comprobar($condicion, $mensaje) {
    if (!$condicion) {
        throw new RuntimeException($mensaje);
    }
}

$cookieSesion = session_get_cookie_params();
comprobar($cookieSesion['secure'] === true, 'La sesion no exige cookie Secure');
comprobar($cookieSesion['httponly'] === true, 'La sesion pierde HttpOnly');
comprobar($cookieSesion['samesite'] === 'Lax', 'La sesion pierde SameSite=Lax');
comprobar($cookieSesion['lifetime'] === 0 && $cookieSesion['path'] === '/' && $cookieSesion['domain'] === '', 'Cambio inesperado de alcance o duracion de la cookie');

$modo = $argv[1] ?? 'captcha-auditoria';
if (strpos($modo, 'sesion-') === 0) {
    $_SERVER['REQUEST_METHOD'] = 'GET';
    $_SESSION = ['usuario' => ['id_usuario' => 1, 'rol' => 'admin', 'sesion_token' => 'activo']];
    $conexion = new class($modo) {
        private $modo;
        public function __construct($modo) { $this->modo = $modo; }
        public function prepare($sql) {
            return new class($this->modo) {
                private $modo;
                public function __construct($modo) { $this->modo = $modo; }
                public function execute($datos) { return true; }
                public function fetch() {
                    return ['sesion_token' => $this->modo === 'sesion-valida' ? 'activo' : 'revocado'];
                }
            };
        }
    };
    exigir_roles(['admin']);
    echo "Sesion aceptada\n";
    exit;
}
if (strpos($modo, 'csrf-') === 0) {
    $_SESSION = ['usuario' => ['id_usuario' => 1], 'csrf_token' => 'token-prueba'];
    $_SERVER['REQUEST_METHOD'] = 'POST';
    $_COOKIE['isa_csrf_token'] = 'token-prueba';
    $_POST = [];
    unset($_SERVER['HTTP_ORIGIN'], $_SERVER['HTTP_X_CSRF_TOKEN']);
    if ($modo === 'csrf-header') {
        $_SERVER['HTTP_X_CSRF_TOKEN'] = 'token-prueba';
    } elseif ($modo === 'csrf-form') {
        $_POST['csrf_token'] = 'token-prueba';
    } elseif ($modo === 'csrf-array') {
        $_POST['csrf_token'] = ['token-prueba'];
    }
    exigir_csrf_si_autenticado();
    echo "CSRF aceptado\n";
    exit;
}

$_SESSION = [];
$token = crear_captcha_token('11');
comprobar(strlen($token) === 64 && ctype_xdigit($token), 'Token opaco incorrecto');
comprobar(validar_captcha_token($token, '11'), 'Captcha valido rechazado');
comprobar(!validar_captcha_token($token, '11'), 'Captcha reutilizado aceptado');
$token = crear_captcha_token('11');
comprobar(!validar_captcha_token($token, '12'), 'Respuesta incorrecta aceptada');
comprobar(!validar_captcha_token($token, '11'), 'Intento incorrecto no consumio captcha');
$token = crear_captcha_token('11');
$_SESSION = [];
comprobar(!validar_captcha_token($token, '11'), 'Token aceptado en otra sesion');
$token = crear_captcha_token('11');
$_SESSION['login_captcha']['creado'] = time() - 301;
comprobar(!validar_captcha_token($token, '11'), 'Token expirado aceptado');

$conexionFalsa = new class {
    public function prepare($sql) {
        return new class {
            public function execute($parametros) {
                throw new PDOException('Fallo simulado');
            }
        };
    }
};
$falloPropagado = false;
try {
    registrar_auditoria($conexionFalsa, 'producto_creado');
} catch (PDOException $e) {
    $falloPropagado = $e->getPrevious() instanceof PDOException;
}
comprobar($falloPropagado, 'Fallo de auditoria ocultado');
echo "OK: captcha valido, replay, respuesta incorrecta, sesion ajena, caducidad y fallo de auditoria\n";
