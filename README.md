# Isa Boutique

Sistema web para la gestión de inventario, ventas, clientes, trabajadores, proveedores y finanzas de Isa Boutique.

## Tecnología

- Frontend: HTML, CSS y JavaScript.
- Backend: PHP.
- Base de datos: PostgreSQL.
- Entorno local: XAMPP con PHP y PostgreSQL.

Nota: el documento inicial mencionaba MySQL, pero el proyecto final se desarrolló con PostgreSQL para mantener mejor estructura, integridad y control de datos.

## Roles

- Administrador: gestiona inventario, categorías, ventas, reportes, finanzas, proveedores, trabajadores, usuarios y seguridad.
- Vendedor: registra ventas, consulta inventario, revisa historial, reportes y devoluciones dentro del horario laboral.
- Cliente: navega la tienda, consulta productos, selecciona tallas y registra pedidos desde la página web.

## Módulos principales

- Catálogo público: inicio, productos, categorías, carrito y pedidos.
- Inventario: productos, tallas, stock, categorías, movimientos y cambios de precio.
- Ventas: venta interna, venta pública, canal de venta, tipo de entrega, historial, pedidos pendientes, confirmación y cancelación.
- Finanzas: ingresos, gastos, inversiones, compras, ganancias y resumen del negocio.
- Personas: clientes, proveedores, trabajadores y pagos.
- Seguridad: autenticación, roles, contraseñas con hash, sesión única y restricción de horario para vendedor.

## Base de datos

Los archivos principales están en `database/`:

- `isa_postgretsql.sql`: script histórico con datos de ejemplo y limpieza previa de tablas; conservar como referencia, no ejecutar sobre una base con datos reales.
- `produccion_schema.sql`: esquema para producción.
- `produccion_datos_minimos.sql`: usuarios y categorías iniciales.
- `migracion_*.sql`: cambios aplicables si la base ya existe.

La conexión se configura en:

- `php/config.example.php`: plantilla.
- `php/config.local.php`: configuración local privada, no debe publicarse.

## Carpetas importantes

- `html/`: tienda pública y paneles de administrador y vendedor.
- `php/`: endpoints del backend.
- `js/`: scripts del frontend.
- `css/`: estilos visuales.
- `img/`: imágenes del proyecto.
- `database/`: estructura y migraciones PostgreSQL.
- `docs/`: instrucciones de publicación, pruebas funcionales y documento de desarrollo.

## Entrada al sistema

- Tienda: `http://localhost/isa_boutique/` (redirige a `html/index.html`).
- Administrador: `http://localhost/isa_boutique/html/admin.html`.
- Vendedor: `http://localhost/isa_boutique/html/vendedor.html`.

Apache debe estar iniciado en XAMPP. Los paneles abiertos como archivos locales
(`file://`) redirigen a su dirección de localhost para que PHP pueda generar la
verificación humana y procesar el acceso.

## Documentación

- [Publicación](docs/PUBLICACION.md).
- [Pruebas finales](docs/PRUEBAS_FINALES.md).
- [Documento de desarrollo](docs/TERCERA_FASE_ISA_BOUTIQUE.md).
- [Revisión de estructura y validaciones](docs/REVISION_ESTRUCTURA.md).

Las rutas de los documentos se expresan desde la raíz del proyecto. Las migraciones,
los respaldos privados y las fotos de `img/productos/` se conservan porque pueden
ser necesarios para las bases existentes. Las fotos pueden compartir contenido y
tener nombres distintos vinculados a productos; no se deben borrar sin revisar esas
referencias en la base de datos.

## Requisitos cubiertos

- Gestión de categorías.
- Control de inventario por producto y talla.
- Registro de ventas, devoluciones y pedidos pendientes.
- Historial de movimientos.
- Búsqueda por nombre, código, marca y categoría.
- Registro de clientes.
- Reportes de ventas, productos, medios de pago y canales.
- Cambios de precio con historial.
- Control de medios de pago.
- Alertas de stock bajo.
- Roles y permisos.
- Restricción de horario para vendedor.
- Sesión única por usuario.

## Mejoras futuras

- Plan separe o apartados con abonos.
- Escaneo QR real.
- Backup automático programado.
- Módulo formal de cambios de producto.
- Notificaciones de promociones para clientes registrados.
