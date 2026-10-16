# Checklist antes de publicar Isa Boutique

## Base de datos

- Crear una base PostgreSQL en el hosting.
- Importar `database/produccion_schema.sql`.
- Importar `database/produccion_datos_minimos.sql`.
- Si ya existe una base anterior, ejecutar las migraciones nuevas como `database/migracion_canal_venta.sql`, `database/migracion_entrega_estado_pedido.sql` y `database/migracion_sesion_unica.sql`.
- Crear un usuario de base de datos que no sea `postgres`.
- Usar una contraseña fuerte para la base de datos.
- Guardar el backup local en `database/backups/`; no subir esa carpeta al hosting ni a GitHub.

## Configuración

En el servidor puedes usar variables de entorno:

- `ISA_DB_HOST`
- `ISA_DB_PORT`
- `ISA_DB_NAME`
- `ISA_DB_USER`
- `ISA_DB_PASSWORD`
- `ISA_DB_SSLMODE` (`require` en Neon)
- `ISA_DB_OPTIONS` (`endpoint=...` en Neon cuando el host lo pida)
- `ISA_APP_ENV` (`production` al publicar; `local` solo para desarrollo HTTP en loopback).
- `ISA_APP_URL` (URL HTTPS definitiva para los enlaces de recuperacion).

Si el hosting no permite variables de entorno, copia `php/config.example.php` como `php/config.local.php` y llena los datos reales. Ese archivo no debe subirse a GitHub.

Para Neon, `php/config.local.php` debe incluir `"sslmode" => "require"`. Si usas el host pooler y Neon muestra un error de endpoint/SNI, agrega `"options" => "endpoint=nombre-del-endpoint-pooler"`.

## Correos con Brevo por HTTPS

La recuperacion de contrasenas y las notificaciones usan el proveedor configurado
en `mail.provider`. Brevo utiliza HTTPS; no necesita los puertos SMTP 587 o 465.

1. En Brevo, crea una clave API para Isa Boutique desde Configuracion > SMTP y API >
   Claves API y MCP. Debe ser una clave API convencional para la API de correo.
2. Agrega y verifica el remitente que usara la tienda, por ejemplo
   `envision.estudioweb@gmail.com`. Revisa que la cuenta permita envios transaccionales.
3. En la seccion `mail` de `php/config.local.php`, completa:

   ```php
   "provider" => "brevo",
   "api_key" => "TU_CLAVE_API_PRIVADA",
   "from_email" => "envision.estudioweb@gmail.com",
   "from_name" => "Isa Boutique",
   ```

La clave se guarda solo en el archivo privado, nunca en JavaScript ni en Git.
En un servidor sin configuracion local puedes usar `ISA_MAIL_PROVIDER=brevo`,
`ISA_BREVO_API_KEY`, `ISA_MAIL_FROM_EMAIL` e `ISA_MAIL_FROM_NAME`.
PHP necesita cURL y certificados de confianza; la validacion TLS permanece activa.

Para probar, solicita recuperar la contrasena de una cuenta registrada y comprueba
su bandeja de entrada y los registros transaccionales de Brevo. Una aceptacion de
la API no confirma por si sola la entrega al destinatario. Mientras el sitio sea
local, el enlace recibido se abre en el computador que ejecuta XAMPP.

Para volver a SMTP, cambia `mail.provider` a `smtp`; los campos de Gmail se conservan.

Documentacion oficial:
- https://help.brevo.com/hc/es/articles/209467485-Crear-o-eliminar-una-clave-API
- https://developers.brevo.com/docs/send-a-transactional-email

## Usuarios internos

- Cambiar la contraseña del administrador.
- Cambiar la contraseña del vendedor.
- No usar `123456` en producción.
- Mantener las contraseñas guardadas con hash.
- Usar la pestaña `Seguridad` del panel interno para cambiar o restablecer contraseñas.
- `produccion_datos_minimos.sql` crea referencias inactivas, sin contrasenas utilizables. No hay claves predeterminadas.
- Para una instalacion nueva, usa `scripts/crear_usuario_inicial.php` desde CLI con nombre, correo y rol (`admin` o `vendedor`). Recibe la clave mediante `ISA_USUARIO_PASSWORD`, exige 12 a 72 bytes con letras y numeros y genera el hash en el momento.
- El comando solo crea una cuenta nueva o habilita un marcador inicial inactivo con el mismo rol. Rechaza sobrescribir cuentas normales. No usarlo para restablecer usuarios existentes.

Ejemplo de creacion explicita en PowerShell; no ejecutarlo sobre una base existente sin comprobar antes la cuenta que se desea crear:

```powershell
$claveInicial = Read-Host 'Nueva contrasena propia' -AsSecureString
try {
    $env:ISA_USUARIO_PASSWORD = [System.Net.NetworkCredential]::new('', $claveInicial).Password
    & 'C:\xampp\php\php.exe' scripts/crear_usuario_inicial.php 'Administrador' 'tu-correo@ejemplo.com' admin
} finally {
    Remove-Item Env:ISA_USUARIO_PASSWORD -ErrorAction SilentlyContinue
    $claveInicial.Dispose()
}
```

El script usa la base configurada: ejecutarlo es una operacion de escritura deliberada. No imprime claves ni hashes. Si la cuenta ya existe, cambiar su clave mediante el panel o recuperacion. Las cuentas ya configuradas en Neon no necesitan ejecutar estos datos iniciales otra vez.

Las cookies de sesion y CSRF llevan siempre Secure. Produccion requiere HTTPS; HTTP solo se admite si `app_env`/`ISA_APP_ENV` es `local` y tanto la conexion como el nombre del servidor son loopback. Chrome permite cookies Secure por HTTP en localhost y se comprobo con un perfil temporal. Otros navegadores, incluidos Safari, pueden necesitar HTTPS tambien en desarrollo; no se quita Secure para hacerlos funcionar. Un reverse proxy debe configurar correctamente HTTPS y el host canonico en el servidor; no se confia automaticamente en cabeceras reenviadas. Al publicar, no conservar `app_env=local`.

El catalogo carga modulos JavaScript desde el mismo origen. Publicar juntos `catalogo-comun.js`, `catalogo-productos.js`, `catalogo-categoria.js` y sus dos entradas `*-inicio.js`, junto con los HTML actualizados. El panel necesita ademas `admin-tablas.js`, cargado antes de su script clasico. El servidor debe servir los archivos .js con tipo JavaScript. Abrir las paginas desde el servidor web, no mediante file://.

## Archivos sensibles

- No publicar `php/config.local.php`.
- No publicar `.git`.
- No dejar respaldos `.sql` descargables en carpetas públicas.
- La carpeta `database` tiene bloqueo por `.htaccess`, pero aun así es mejor no subir respaldos innecesarios.

## Pruebas finales

- Revisar `README.md` para explicar el alcance del sistema.
- Marcar `docs/PRUEBAS_FINALES.md` antes de publicar o exponer.
- Login administrador.
- Login vendedor.
- Agregar producto.
- Crear, editar y revisar categorías desde el panel administrador.
- Registrar compra de mercancía.
- Registrar venta pública.
- Validar tallas y stock.
- Revisar finanzas.
- Cerrar sesión.

## Permisos por rol

- Administrador: inventario completo, finanzas, proveedores, trabajadores, usuarios, eliminaciones y cambios de precio.
- Vendedor: registrar ventas, revisar inventario, historial, devoluciones y resumen de ventas.
- Público: ver productos y registrar compra desde la tienda.
- `venta_registrar.php` queda disponible para compras públicas; los endpoints administrativos requieren sesión y rol.
- Las contraseñas de usuarios internos son administradas solo por el administrador.
