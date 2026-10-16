param(
    [ValidateSet('inventario_devoluciones','finanzas_reportes','clientes_facturas','notificaciones','pedido_carrito','limites_acceso','acceso_endpoints','usuarios_iniciales','variantes_imagenes')]
    [string[]]$Pruebas = @('inventario_devoluciones','finanzas_reportes','clientes_facturas','notificaciones','pedido_carrito','limites_acceso','acceso_endpoints','usuarios_iniciales','variantes_imagenes'),
    [ValidateRange(55000,55999)][int]$Puerto = 55439,
    [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$Php = 'C:\xampp\php\php.exe'
)
$ErrorActionPreference = 'Stop'
$raizTemporal = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
$nombre = 'isa_pg_scram_' + [guid]::NewGuid().ToString('N')
$ruta = Join-Path $raizTemporal $nombre
$archivoClave = $ruta + '.pw'
$archivoLog = $ruta + '.log'
$claveAnterior = $env:ISA_TEST_DB_PASSWORD
$marcaAnterior = $env:ISA_TEST_DB_MARCA
$iniciado = $false
$generador = [Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
$generador.GetBytes($bytes)
$generador.Dispose()
$env:ISA_TEST_DB_PASSWORD = [BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant()
$env:ISA_TEST_DB_MARCA = [guid]::NewGuid().ToString('N')
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    Set-Content -LiteralPath $archivoClave -Value $env:ISA_TEST_DB_PASSWORD -Encoding Ascii -NoNewline
    & "$PgBin\initdb.exe" -D $ruta -U postgres --auth-host=scram-sha-256 --auth-local=scram-sha-256 --pwfile=$archivoClave --no-locale -E UTF8
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo inicializar el cluster temporal' }
    Remove-Item -LiteralPath $archivoClave -Force
    & "$PgBin\pg_ctl.exe" -D $ruta -l $archivoLog -o "-p $Puerto -h 127.0.0.1 -c isa.pruebas=$env:ISA_TEST_DB_MARCA" -w -t 15 start
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar el cluster temporal' }
    $iniciado = $true
    & $Php tests/postgres_temporal.php $Puerto validar-autenticacion
    if ($LASTEXITCODE -ne 0) { throw 'Autenticacion temporal no validada' }
    foreach ($prueba in $Pruebas) {
        & $Php tests/postgres_temporal.php $Puerto limpiar
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar la fixture aislada' }
        Write-Output "Prueba: $prueba"
        if ($prueba -eq 'finanzas_reportes') { & $Php "tests/$prueba.php" $Puerto indices }
        else { & $Php "tests/$prueba.php" $Puerto }
        if ($LASTEXITCODE -ne 0) { throw "Fallo la prueba $prueba" }
    }
} finally {
    if ($iniciado -or (Test-Path -LiteralPath (Join-Path $ruta 'postmaster.pid'))) {
        & "$PgBin\pg_ctl.exe" -D $ruta -m fast -w -t 15 stop
    }
    $env:ISA_TEST_DB_PASSWORD = $claveAnterior
    $env:ISA_TEST_DB_MARCA = $marcaAnterior
    Pop-Location
    # Comprobar todos los destinos absolutos antes de borrar, usando PowerShell de principio a fin.
    $comprobada = [IO.Path]::GetFullPath($ruta)
    if (-not $comprobada.StartsWith($raizTemporal,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $comprobada -Leaf) -ne $nombre) { throw 'Ruta temporal fuera del destino previsto' }
    if (Test-Path -LiteralPath (Join-Path $comprobada 'postmaster.pid')) { throw 'Servidor temporal activo; se conservan sus archivos' }
    foreach ($archivo in @($archivoClave,$archivoLog)) {
        if ([IO.Path]::GetFullPath($archivo) -notin @(($comprobada+'.pw'),($comprobada+'.log'))) { throw 'Archivo temporal fuera del destino previsto' }
        if (Test-Path -LiteralPath $archivo) { Remove-Item -LiteralPath $archivo -Force }
    }
    if (Test-Path -LiteralPath $comprobada) { Remove-Item -LiteralPath $comprobada -Recurse -Force }
}
