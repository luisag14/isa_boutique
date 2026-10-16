<?php
// No utiliza configuracion.php ni credenciales de Neon.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

function conexion_postgres_prueba($puerto, array $opciones = []): PDO {
    $puerto = filter_var($puerto, FILTER_VALIDATE_INT);
    $password = getenv('ISA_TEST_DB_PASSWORD');
    $marca = getenv('ISA_TEST_DB_MARCA');
    if ($puerto < 55000 || $puerto > 55999 || !is_string($password) || !preg_match('/^[a-f0-9]{64}$/D', $password)
        || !is_string($marca) || !preg_match('/^[a-f0-9]{32}$/D', $marca)) {
        throw new RuntimeException('Ejecuta tests/ejecutar_postgres.ps1 para crear una base temporal autenticada');
    }
    $predeterminadas = [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES=>true];
    $db = new PDO('pgsql:host=127.0.0.1;port='.$puerto.';dbname=postgres;connect_timeout=5', 'postgres', $password, array_replace($predeterminadas,$opciones));
    $marcaServidor = $db->query("SELECT current_setting('isa.pruebas',true)")->fetchColumn();
    if (!is_string($marcaServidor) || !hash_equals($marca,$marcaServidor)) throw new RuntimeException('El servidor no pertenece a esta ejecucion temporal');
    $scram = $db->query("SELECT bool_and(auth_method='scram-sha-256') FROM pg_hba_file_rules WHERE error IS NULL")->fetchColumn();
    if (!filter_var($scram,FILTER_VALIDATE_BOOLEAN)) throw new RuntimeException('El servidor de pruebas requiere SCRAM sin reglas trust');
    return $db;
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    $db = conexion_postgres_prueba($argv[1] ?? null);
    if (($argv[2] ?? '') === 'limpiar') {
        // Solo tras comprobar puerto loopback, secreto efimero, marca y autenticacion del cluster temporal.
        $db->exec('DROP SCHEMA public CASCADE; CREATE SCHEMA public');
    } elseif (($argv[2] ?? '') === 'validar-autenticacion') {
        $rechazado = false;
        try {
            new PDO('pgsql:host=127.0.0.1;port='.(int)$argv[1].';dbname=postgres;connect_timeout=5', 'postgres', getenv('ISA_TEST_DB_PASSWORD').'-incorrecta', [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
        } catch (PDOException $e) { $rechazado = true; }
        if (!$rechazado) throw new RuntimeException('El servidor acepta una contrasena incorrecta');
        echo "PASS cluster temporal identificado, SCRAM y rechazo de contrasena incorrecta\n";
    } else {
        throw new InvalidArgumentException('Operacion de prueba desconocida');
    }
}
