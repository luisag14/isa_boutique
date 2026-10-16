# Primer bloque de correcciones — 14 de octubre de 2026

Estado: cambios locales revisados. Migracion de auditoria aplicada con autorizacion del usuario.

## Cambios

- Apache bloquea el acceso HTTP a directorios de control de versiones.
- Las solicitudes autenticadas requieren un token CSRF explicito en cabecera o formulario; una cookie sola no autoriza la operacion.
- Las ventas autenticadas validan rol, sesion vigente y horario del vendedor. Los pedidos publicos no admiten descuentos enviados por el cliente.
- El captcha usa un token aleatorio, ligado a la sesion y consumido con cada intento. Esto evita revelar la respuesta en el token y reutilizarlo; una suma sigue siendo una proteccion limitada frente a automatizacion.
- El historial del vendedor escapa los textos identificados como vulnerables a XSS.
- Los errores de auditoria se propagan para impedir continuar y confirmar transacciones fallidas.
- Cambiar una contrasena o un correo incluye la auditoria en la misma transaccion. Restablecer la contrasena de otro usuario invalida su sesion.
- Se eliminaron dos bloques de captura de excepciones inalcanzables.

## Migracion aplicada

Archivo: `database/migracion_auditoria_evento.sql`.

La version preparada conserva registros y columnas existentes, completa los campos nuevos a partir de los historicos y quita la obligatoriedad de `operacion` y `tabla_afectada` cuando existen. Conserva sus restricciones de valores y ejecuta el conjunto dentro de una transaccion.

Se ejecuto despues de crear el respaldo `database/backups/antes_auditoria_20261014_223914.dump` (156378 bytes). PostgreSQL pudo leer su indice con `pg_restore --list`; no se probo una restauracion completa. SHA-256: `6f2457759f3deb6977d4fd2a8fb6e629bdf18e3e9476a3e80ab2d065a9d76215`. El respaldo esta excluido de Git.

La migracion se aplico dentro de una transaccion, con limite de espera de bloqueos y de ejecucion. Se comprobo que ambos campos historicos admiten NULL y que los cinco eventos existentes se conservaron. La funcion real de auditoria pudo insertar un evento temporal dentro de un SAVEPOINT; se revirtio ese evento antes de confirmar la migracion. PostgreSQL puede haber avanzado la secuencia del identificador durante la prueba; no se conservaron eventos de prueba.

No se ejecutaron ventas, compras ni devoluciones reales. Los cambios de codigo siguen locales y no se han publicado en GitHub. Cualquier otra base de datos de despliegue necesita esta migracion antes de publicar el bloque de codigo.

## Verificacion

Pruebas locales en `tests/seguridad.php`, sin PostgreSQL ni servicios de correo. Cubren captcha valido, reutilizacion, respuesta incorrecta, sesion ajena, expiracion, propagacion del error de auditoria, CSRF mediante cookie/formulario/cabecera y sesiones vigentes o revocadas mediante dobles de prueba.

Tambien se reviso la sintaxis PHP y JavaScript, el escape HTML del vendedor y las respuestas HTTP locales de `.git/HEAD` (403), el panel (200) y el captcha (200).

## Pendiente

No se considera terminada la auditoria ni superada la puerta de calidad. Falta consultar el listado de incidencias y bloques duplicados de SonarCloud; el detalle no fue accesible desde la herramienta de consulta. No se agregaron configuraciones ni extensiones de Sonar.

Siguen pendientes la paginacion de listas en el servidor, el esquema de instalacion y la duplicacion restante, incluidas plantillas de facturas. La correccion del carrito y su migracion estan aplicadas en la base configurada; sus limites de verificacion se detallan en el septimo bloque. Faltan la valoracion posterior de mercancia nueva y precisar la conciliacion de aportes e inversiones. El limite compartido de acceso y su migracion estan aplicados en la base configurada, con los limites de verificacion descritos en el octavo bloque. El enlace de recuperacion ya usa una base configurada, que debe apuntar al dominio HTTPS definitivo al publicar. Tambien quedan otros puntos de interpolacion HTML del panel y la configuracion de permisos/TLS del despliegue.

## Segundo bloque: devoluciones e inventario

Cambios locales preparados:

- Se bloquea la fila de venta durante la devolucion para serializar solicitudes simultaneas. Solo se admiten ventas pagadas y cantidades enteras positivas.
- El historial y los botones de ambos paneles identifican la linea de venta. El reembolso se calcula sobre su subtotal cobrado, con descuento incluido, y el redondeo se acumula para que varias devoluciones parciales no excedan ese subtotal.
- Una devolucion parcial conserva la venta pagada; pasa a devuelta cuando se han devuelto todas sus unidades. Se repone el color y la talla originales; cualquier fallo revierte la operacion completa, incluido el stock general actualizado por el trigger.
- Las reposiciones seleccionan un color existente, actualizan variante y talla agregada, y bloquean el producto antes de calcular su costo promedio. Las compras bloquean productos en orden de identificador para reducir conflictos.
- El envio de una compra mixta se reparte entre todas las unidades, evitando cargarlo entero a las reposiciones. La clasificacion y valoracion posterior de mercancia nueva sigue requiriendo revision; no se modificaron costos historicos.
- Editar un producto conserva identificadores, colores y tallas. Con varios colores se rechazan cambios ambiguos de stock desde el editor resumido; las reposiciones y devoluciones permiten seleccionar la variante. Con un solo color y talla se permite el ajuste directo sin recrear la variante.

Migracion aplicada con autorizacion del usuario: `database/migracion_devoluciones_variantes.sql`. Agrega una referencia nullable desde cada detalle de devolucion a su linea de venta y un indice. Vincula registros antiguos solo cuando hay una unica linea candidata; no adivina variantes de devoluciones ambiguas. La base configurada no tenia detalles de devolucion: se conservaron cero registros y no quedaron registros sin identificar. Se verificaron la columna nullable, la clave foranea validada con borrado restringido, el indice valido y la ausencia de enlaces inconsistentes. No se registraron devoluciones de prueba en la base real; los casos funcionales se probaron previamente en PostgreSQL temporal. En otra base con devoluciones historicas ambiguas se requiere revision manual aun despues de la migracion.

Respaldo previo: `database/backups/antes_devoluciones_variantes_20261014_194107.dump` (156361 bytes), legible con `pg_restore --list`. SHA-256: `9dd2998afa37257ddb90b90ad2be8c64c3d06d7b62d6e149cbc7f9612eb3c500`. No se hizo una restauracion completa de este respaldo. La migracion se ejecuto en una transaccion con limites de espera y ejecucion; se compararon cantidad y huella de los datos originales antes de confirmar.

Verificacion: `tests/inventario_devoluciones.php` paso en un PostgreSQL 18 local temporal separado de la configuracion del proyecto. Incluyo estados no pagados, descuentos y redondeos, compatibilidad sin migracion para ventas simples, rechazo de ventas ambiguas sin migracion, repeticion de la migracion, bloqueo desde una segunda conexion, devolucion parcial y completa, exceso de unidades, reposicion de color y talla, edicion que conserva variantes y reversibilidad tras una talla faltante. El servidor temporal se detuvo al terminar. No se realizaron ventas ni movimientos de inventario en la base del proyecto.

Tambien pasaron la sintaxis de 66 archivos PHP, siete scripts incrustados en HTML y `js/vendedor.js`. Se comprobo con un DOM simulado que el formulario muestra los colores existentes, limita tallas al color elegido y selecciona automaticamente un color unico. No se hizo una prueba completa con navegador ni una prueba de carga de varios usuarios. No se reevaluo SonarCloud ni se publicaron cambios en GitHub.

## Tercer bloque: finanzas, reportes y salario fijo

- Se comparten calculos entre resumen y reportes. El costo vendido solo incluye ventas pagadas o devueltas, excluyendo pedidos pendientes y cancelados.
- La utilidad resta el IVA neto. Las devoluciones revierten importe, costo e IVA en la fecha de la devolucion; el IVA se reparte con redondeo acumulado para no dejar centavos al completar varias devoluciones parciales. La caja conserva los cobros y pagos completos: separar IVA de utilidad no crea un pago de impuestos ficticio.
- Para detalles historicos sin linea identificada, el IVA se estima con la proporcion del IVA total de la venta. La base revisada no tenia devoluciones; si otro despliegue conserva devoluciones ambiguas o tasas mezcladas, requiere revision manual de esos historicos.
- Las ventas clasificadas y el ranking de productos incluyen las devoluciones. Los filtros de rango incluyen todo el ultimo dia, validan fechas del calendario y usan intervalos abiertos al dia siguiente.
- El resumen, los reportes y los movimientos se leen dentro de transacciones de solo lectura con una instantanea consistente. Los errores tecnicos se registran sin publicarse en las respuestas.
- El vendedor recibe exclusivamente indicadores de ventas, nombre del producto principal y metas comerciales mediante una lista positiva de campos; no recibe el bloque financiero, costos, utilidades ni nomina. Las metas siguen siendo datos comerciales compartidos. Los endpoints de resumen y movimientos conservan permiso exclusivo de administrador. No se modificaron aqui los permisos de otros endpoints del catalogo; ocultar costos publicos sigue pendiente.
- Las metas estimadas usan gastos operativos; las compras ya intervienen en el margen por el costo vendido y no se suman otra vez como gasto fijo. Se conserva el minimo comercial existente de $7.000.000 y el criterio de ganancia objetivo. Son estimaciones; no se configuraron nuevas metas del negocio.
- Por peticion del usuario, nuevos trabajadores y pagos admiten salario fijo de $2.000.000, validado en servidor y mostrado como campo de solo lectura. Se retiraron los otros tipos del formulario. No se registran pagos automaticamente, no se deducen adelantos y no se modificaron registros anteriores. Se encontro un adelanto historico que sigue contando como salida de caja. Las anotaciones historicas de tipo deduccion se muestran con efecto cero en caja y no se suman como nuevos pagos; no hay deducciones registradas en la base revisada.
- La clasificacion incluye los gastos historicos de tipo nomina dentro de trabajadores y la ganancia libre coincide con la utilidad neta del resumen. Posibles registros manuales duplicados entre gastos y pagos requieren conciliacion; no se borraron ni reinterpretaron registros para adivinar duplicados.

Pruebas: `tests/finanzas_reportes.php` verifica campos del vendedor, fechas y pago fijo. En un PostgreSQL 18 temporal separado verifico ventas pendientes y canceladas, devoluciones entre meses, redondeo de IVA, ultimo dia a las 23:59:59, igualdad entre resumen y reporte, caja frente a movimientos, metas consistentes y rechazo de escrituras dentro de las lecturas. El constructor de reportes, resumen y movimientos tambien se ejecuto contra la base configurada dentro de una transaccion de solo lectura: las cifras mensuales coincidieron. No se crearon trabajadores, pagos ni operaciones comerciales reales. Falta prueba completa de sesion y formulario en navegador. Este bloque no requiere migraciones nuevas ni cambios de servicios externos, y no se publico en GitHub ni se ejecuto SonarCloud.

## Cuarto bloque: datos personales, catalogo y facturas

- Registrar una venta ya no actualiza perfiles mediante el telefono. Solo reutiliza un cliente cuando nombre, telefono, correo y documento coinciden; si cambian los datos, crea un registro separado sin modificar al anterior. Un bloqueo por contacto reduce duplicados simultaneos de estos registros. Esto evita sobrescrituras; no demuestra identidad ni verifica la titularidad del telefono en pedidos anonimos.
- El directorio de clientes es exclusivo del administrador; el panel del vendedor no utiliza este endpoint. El vendedor conserva los datos necesarios para atender ventas y consultar facturas.
- El catalogo publico y el del vendedor omiten costos y productos inactivos. Ver costos requiere administrador activo con token vigente comprobado en la base; una sesion revocada recibe el catalogo publico.
- Consultar una factura es una lectura y no crea ni actualiza documentos. Emitirla sucede dentro de la transaccion de venta o de confirmacion del pedido. Emitir nuevamente una factura existente conserva numero e importes.
- La emision nueva prepara una copia de los datos de cliente, empresa, vendedor, productos y valores para que cambios posteriores no alteren el documento. Las facturas antiguas sin copia se identifican como datos actuales al imprimir, sin inventar informacion historica. No se modificaron reglas tributarias ni se habilito facturacion electronica.
- Se bloqueo el borrado global de historial desde el panel y se retiro la eliminacion forzada de productos con ventas o devoluciones. El producto se bloquea durante la comprobacion y eliminacion; los productos con historial deben desactivarse. No se borraron datos durante estas correcciones.

Migracion aplicada con autorizacion del usuario: `database/migracion_factura_datos_emision.sql`. Agrega `factura.datos_emision` de tipo JSONB nullable y una comprobacion de tipo objeto. No completa documentos antiguos con datos actuales. Se verificaron la columna, la restriccion validada y su reconocimiento por el codigo. Se compararon cantidad y huella de los campos originales antes de confirmar: la base tenia y conserva cero facturas. No se emitieron documentos de prueba. La dependencia de esquema para nuevas emisiones quedo cubierta en la base configurada; en otras bases de despliegue se debe aplicar esta migracion antes de publicar el codigo.

Respaldo previo: `database/backups/antes_factura_datos_emision_20261014_195650.dump` (157257 bytes). SHA-256: `2c8077bbcdd6ecbe08ca3c702f7980d9473828d6ea6da88e2846d0afa540cdcf`. Se comprobo su lectura con `pg_restore --list`, sin restauracion completa. La migracion se ejecuto en una transaccion con limites de bloqueo y ejecucion. El respaldo permanece excluido de Git y bloqueado por web.

Verificacion: `tests/clientes_facturas.php` paso en PostgreSQL 18 temporal separado de la base del proyecto. Incluyo cliente distinto con telefono compartido, reutilizacion con datos identicos, compatibilidad de lectura antigua, rechazo de emision sin migracion, migracion repetible, datos e importes inmutables tras editar entidades, numero de factura sin duplicados y catalogo para anonimo, vendedor, administrador vigente y token revocado. La consulta real del catalogo y la compatibilidad de lectura de facturas se verificaron en transaccion de solo lectura. No se emitieron facturas ni se registraron clientes en la base real. Pasaron la sintaxis de 75 archivos PHP y los scripts modificados; falta prueba completa de formularios y sesiones en navegador. No se ejecuto SonarCloud ni se publicaron cambios en GitHub.

## Quinto bloque: cola de correos

- Procesar pendientes requiere POST, administrador autenticado, origen permitido y token CSRF explicito. GET devuelve 405 y el limite debe estar entre 1 y 20. Se mantiene el envio directo de recuperacion de contrasena; no se añadieron tareas automaticas ni se activaron envios reales.
- Una transaccion selecciona un lote con `FOR UPDATE SKIP LOCKED`, lo marca `procesando` e incrementa los intentos antes de confirmar. El envio externo ocurre despues de confirmar la reserva, sin mantener una transaccion abierta durante la conexion de correo. Otros procesadores no pueden volver a seleccionar el lote reservado.
- `enviada` significa que el transporte confirmo la aceptacion; no demuestra entrega en bandeja de entrada. Un rechazo temporal confirmado puede volver a `pendiente` hasta un maximo de tres intentos, uno por ejecucion del lote. Un rechazo definitivo pasa a `fallida`.
- Un timeout, respuesta incierta o excepcion sin confirmacion de rechazo pasa a `revision`, sin reenvio automatico. Si se interrumpe el proceso o falla la persistencia despues de enviar, la reserva queda `procesando` y tampoco se selecciona otra vez. Esto evita duplicados automaticos a costa de requerir revision de esos mensajes; no garantiza entrega ni exactamente una entrega ante cualquier fallo externo.
- Antes de devolver `revision` o una reserva abandonada a `pendiente`, comprobar los registros del proveedor y la actividad del procesador. No se implemento una tarea que libere reservas automaticamente, porque podria reenviar un correo ya aceptado. Un proceso interrumpido puede dejar reservados mensajes del lote que todavia no intento enviar.
- Los contadores incluyen los pendientes reales de toda la cola, los mensajes en proceso y los que necesitan revision; no se calculan restando del lote los intentos fallidos. Los errores del proveedor no se publican en la respuesta del endpoint.

La tabla existente admite estados de hasta 20 caracteres y no tiene una restriccion de estados; este bloque no requiere migracion en la base revisada. No se modificaron registros reales: las diez notificaciones existentes siguen pendientes.

Verificacion: `tests/notificaciones.php` paso con un remitente simulado y PostgreSQL 18 temporal separado. Se probaron dos conexiones que reservan lotes sin duplicarlos, filas bloqueadas, reintentos hasta el limite, conteo de pendientes tras fallo temporal, rechazos definitivos, timeout ambiguo, reserva abandonada y fallo de persistencia posterior a la aceptacion. Tambien se probaron respuestas simuladas del adaptador Brevo, GET 405 y POST anonimo 401 del endpoint local. Pasaron 78 archivos PHP. No se enviaron correos reales, no se llamo a la API de Brevo ni se verifico entrega externa. No se ejecuto SonarCloud ni se publico en GitHub.

Referencia del contrato del adaptador: [Brevo, envio de correo transaccional](https://developers.brevo.com/reference/send-transac-email). No se añadieron encabezados de idempotencia ni se cambio la configuracion del servicio.

## Sexto bloque: consultas e implementacion compartida del catalogo

- Se extrajeron 24 funciones identicas del catalogo general y categorias a `js/catalogo-comun.js` (338 lineas repetidas antes de la extraccion). Ambas paginas cargan el archivo antes de sus scripts; no se modificaron los controles ni se añadieron dependencias externas. Esto reduce duplicacion local, sin afirmar un porcentaje de SonarCloud.
- Se unifico la lectura defensiva de listas JSON. Un carrito guardado con JSON invalido o que no sea una lista ya no detiene el arranque; los elementos de carrito con cantidades o precios invalidos no se recuperan.
- Se escapan textos y atributos de fichas, miniaturas, colores, tallas y carrito. Se rechazan esquemas de imagen ejecutables. La pagina de categoria declara explicitamente su contenedor en lugar de depender de la variable global creada implicitamente por el navegador.
- Los filtros diarios, mensuales y anuales de reportes y resumen comparan fechas con limites de intervalo, evitando aplicar funciones a la columna filtrada. Se conservan las agrupaciones por fecha y mes donde son necesarias para los graficos.
- El catalogo obtiene sus tallas con una subconsulta por producto: ya no multiplica filas mediante el JOIN de tallas para luego agrupar todas las columnas del producto. Se conserva el contrato JSON de imagenes, colores y tallas y la visibilidad de costos segun permisos.

Migracion aplicada con autorizacion del usuario: `database/migracion_indices_consultas.sql`. Agrega 13 indices para detalle de venta por venta/producto, detalle de devolucion por cabecera/producto, devolucion por venta/estado, fechas de ventas/devoluciones/gastos/nomina/compras/inversiones, telefono de cliente e imagenes por producto. Se revisaron los indices existentes y no se agregan duplicados de las claves de producto-color, color-talla o producto-talla, ni otro indice de la cola de notificaciones. La migracion solo crea indices, con limites de bloqueo y ejecucion, y no modifica registros. En otras bases con tablas grandes debe revisarse la ventana de mantenimiento: CREATE INDEX puede bloquear escrituras mientras se construye.

La aplicacion se hizo dentro de una transaccion, despues del respaldo `database/backups/antes_indices_consultas_20261014_204100.dump` (157424 bytes), legible con `pg_restore --list`. SHA-256: `7ccdef44db06e7c13c8e545a4159a8a7c4d4c5fcd12fa1e22ef62fc42224fea6`. No se probo una restauracion completa. Se verificaron validez, disponibilidad, tabla y columnas de cada uno de los 13 indices. Se compararon cantidad y huella de los registros en las diez tablas afectadas antes y despues: se conservaron. No se registraron operaciones comerciales. El respaldo esta excluido de Git y bloqueado por web.

Pruebas: `node tests/catalogo_comun.cjs` comprueba arranque de ambas paginas con sus scripts reales y DOM simulado, carrito corrupto, listas invalidas, escape de campos, apertura de compra, seleccion de variante y limite acumulado de stock. No sustituye una prueba visual en navegador. `tests/finanzas_reportes.php` con opcion `indices` paso en PostgreSQL temporal: los 13 indices quedaron validos y la migracion se repitio sin cambios de datos. En una muestra sintetica con 3.000 ventas adicionales, EXPLAIN uso el indice de fecha. Pasaron los casos financieros anteriores y la regresion `tests/clientes_facturas.php` con la nueva consulta del catalogo. Se consultaron catalogo y reportes reales dentro de una transaccion de solo lectura, sin diferencias entre resumen y reporte; el JS compartido se sirvio con HTTP 200 y tipo text/javascript.

No se midieron tiempos con datos productivos representativos ni una carga de usuarios; por tanto no se cuantifica una mejora de rendimiento real. Las listas que actualmente devuelven todo el historial siguen necesitando paginacion en servidor. No se ejecuto SonarCloud ni se publicaron cambios en GitHub.

## Septimo bloque: carrito atomico y reintentos

Codigo local y migracion `database/migracion_pedido_carrito.sql` aplicados en la base configurada con autorizacion del usuario. El nuevo endpoint dispone de las columnas e indice necesarios. En otra base de despliegue se debe aplicar primero la migracion; los cambios de codigo aun no se han publicado en GitHub.

- Catalogo y categorias comparten un unico envio de carrito a `php/pedido_carrito_registrar.php`. Todos sus detalles pertenecen a una venta pendiente, dentro de una transaccion; cliente, movimientos y stock tambien se revierten si falla cualquier detalle. No se emite factura ni se considera cobrado el pedido.
- El servidor valida cantidades enteras, variantes y suma de unidades por producto. Obtiene precios y costos de PostgreSQL e ignora los importes del navegador. Bloquea productos en orden de identificador. Las validaciones de inventario y calculos monetarios se comparten con la venta individual mediante `php/venta_util.php`. Se conserva el IVA fijo del 19% del flujo existente; conectarlo con la configuracion tributaria sigue pendiente.
- Una clave aleatoria identifica el intento y una huella vincula su contenido. Un bloqueo transaccional serializa solicitudes con la misma clave y un indice unico impide insertarla dos veces. Repetirla con otro contenido se rechaza; repetirla con el mismo contenido devuelve el pedido existente sin volver a descontar stock.
- La interfaz bloquea el doble clic y conserva clave y huella en localStorage antes de enviar, sin guardar los datos de contacto en ese registro auxiliar. Tras perder la respuesta o recargar la pagina, el mismo carrito y datos reutilizan la clave. Un rechazo comercial confirmado libera el intento para corregirlo; un error ambiguo conserva la clave. Cambiar el contenido mientras hay un resultado desconocido bloquea otro envio y pide comprobar el pedido anterior. Borrar el almacenamiento o enviar desde pestanas independientes con claves distintas no garantiza deduplicacion. El endpoint anterior de venta individual tampoco tiene esta proteccion.
- La migracion agrega dos columnas nullable, una restriccion de formato/coherencia y un indice unico. Las ventas anteriores quedan sin clave. Se aplico despues del respaldo y con autorizacion del usuario. Se verificaron ambas columnas VARCHAR(64) nullable, la restriccion CHECK validada y el indice unico valido y disponible sobre clave_pedido. Dentro de la misma transaccion se bloquearon escrituras en venta y detalle_venta y se compararon cantidades y huellas de los registros antes y despues (excluyendo las nuevas columnas): se conservaron cero ventas y cero detalles. No se crearon pedidos de prueba en la base real.

Respaldo previo: `database/backups/antes_pedido_carrito_20261015_020826.dump` (161295 bytes; nombre con fecha UTC), legible con `pg_restore --list`. SHA-256: `ee97b2ecd3d65fe0777b114d154607920cfab79be885911239cef463c81ee03b`. No se probo una restauracion completa. El respaldo esta excluido de Git y su acceso HTTP se comprueba bloqueado.

Verificacion: `tests/pedido_carrito.php` paso en PostgreSQL 18 temporal separado. Comprueba una venta con dos productos, precios del servidor, agrupacion de variantes, reintentos con orden distinto, conflicto de contenido, bloqueo con dos conexiones, rollback del cliente/stock/movimientos al fallar el segundo detalle, recuperacion posterior y limites de stock agregado y por variante. La migracion se aplico dos veces solo en esa base temporal. No se crearon pedidos ni clientes reales.

`node tests/carrito_envio.cjs` paso con transporte y DOM simulados: un solo POST con varios productos, doble clic, respuesta perdida, recarga y reutilizacion de clave, cabecera CSRF, rechazo comercial y bloqueo de cambios tras un resultado desconocido. Tambien paso `tests/catalogo_comun.cjs`; el endpoint local responde GET 405. Pasaron las revisiones de sintaxis PHP/JavaScript. No se probo el recorrido completo en navegador, la confirmacion/cancelacion de un pedido real de varias lineas, ni solicitudes simultaneas con claves distintas. La simulacion de dos conexiones verifica el bloqueo, no una prueba de carga. El navegador necesita crypto.subtle (HTTPS o localhost). No se enviaron correos ni se ejecuto SonarCloud y no se publicaron cambios en GitHub.

## Octavo bloque: limites de acceso, enlace de recuperacion y XSS del panel

Preparado y aplicado el 15 de octubre de 2026 con autorizacion del usuario: `database/migracion_limites_acceso.sql`. Los endpoints locales disponen de la tabla requerida. En otra base de despliegue debe aplicarse primero la migracion; sin ella, los POST de acceso y recuperacion responderan 503. El ultimo estado recibido del repositorio estaba limpio en `5bd97ce`; este bloque nuevo permanece sin commit ni publicacion.

Respaldo previo: `database/backups/antes_limites_acceso_20261015_154427.dump` (162599 bytes, nombre en UTC), legible con `pg_restore --list`. SHA-256: `23d4aa737eeb989a54cf57103f496af5f59b8f8d717593094c8d7a1147bb5118`. No se probo una restauracion completa. El respaldo esta excluido de Git y su acceso HTTP devuelve 403.

Se aplico la migracion dentro de una transaccion con limites de bloqueo y ejecucion. Se verificaron las tres columnas no nulas y sus tipos, la clave primaria unica, el indice de vencimiento y ambos CHECK validados. Se comprobo el rechazo de una clave invalida y un contador cero mediante SAVEPOINT con rollback, sin conservar filas. Se compararon cantidades y huellas de usuario_sistema y password_reset_token antes y despues, bloqueando escrituras durante la comprobacion: se conservaron los dos usuarios y los ocho registros de recuperacion, incluidas contrasenas y sesiones. La tabla de limites quedo con cero contadores. Los tres endpoints locales respondieron GET 405; no se iniciaron sesiones ni se enviaron solicitudes reales de recuperacion como prueba.

### Proteccion de acceso

`php/limite_acceso.php` comparte cuotas entre sesiones y procesos mediante una fila por accion e identidad con INSERT/ON CONFLICT atomico. Se comprueban cuenta e IP antes de validar captcha, contrasena o token. La cuota no depende de que el correo exista. Se cuenta toda solicitud admitida, incluidas las validas; iniciar sesion correctamente no borra los contadores.

| Accion | Por cuenta | Por IP | Ventana |
| --- | --- | --- | --- |
| Login | 5 | 30 | 5 minutos |
| Solicitar recuperacion | 3 | 10 | 15 minutos |
| Confirmar recuperacion | No aplica | 30 | 15 minutos |

Se mantiene la respuesta 429 y se incluye Retry-After con el tiempo restante. Una ventana empieza con la primera solicitud y no se prolonga por intentos bloqueados. Cambiar correo no evita el limite IP; cambiar IP no evita el de cuenta. La IP proviene de REMOTE_ADDR; no se acepta X-Forwarded-For arbitrario. Detras de un proxy debe configurarse la direccion real en el servidor. Redes compartidas pueden alcanzar la cuota IP entre varios usuarios. Un atacante puede consumir temporalmente la cuota de una cuenta conocida; no se implemento MFA ni una defensa completa contra ataques distribuidos. Las ventanas fijas permiten rafagas alrededor de su vencimiento.

Las claves almacenadas son SHA-256 de accion y cuenta/IP normalizadas; no se guardan esos identificadores en texto plano en la tabla. No son anonimizacion irreversible frente a un diccionario de valores conocidos. Se limpian hasta 100 filas vencidas hace mas de un dia por solicitud, sin bloquear filas que ya estan en uso. La limpieza depende del trafico y no constituye una cota absoluta del tamano de la tabla. Fallos de base o bloqueos impiden el acceso con 503; no se permite continuar con un limite solo en cookies.

Se eliminaron los contadores de sesion sustituidos y se validan entradas escalares. Login y confirmacion de recuperacion conservan los espacios de la contrasena. Para correos inexistentes se realiza una comprobacion bcrypt contra un hash auxiliar, sin crear una cuenta ni aceptar esa contrasena; esto no equivale a haber probado ausencia de enumeracion por tiempos en todas las respuestas.

### URL de recuperacion

`php/app_url.php` obtiene la base de `app_url` en configuracion o `ISA_APP_URL`, con respaldo explicito `http://localhost/isa_boutique` para este entorno. No utiliza Host, Origin ni cabeceras de proxy para construir el correo. Rechaza credenciales, query, fragmento, espacios, barras inversas y HTTP fuera de localhost/loopback. En produccion debe configurarse la URL HTTPS definitiva; no se publico ni se cambio configuracion externa del correo. La consulta real de solo lectura confirmo el respaldo localhost; la tabla nueva se creo posteriormente con autorizacion.

### Panel

- Inventario: se reemplazan los eventos que interpolaban nombre, estado y JSON de variantes por addEventListener y cierres sobre el objeto. Las filas se agregan como nodos para conservar sus eventos. Editar, activar/desactivar, eliminar y mostrar variantes mantienen sus argumentos sin convertir nombres en codigo.
- Se escapan atributos de imagen y textos de categoria, colores, tallas y estado del inventario. El selector de imagen rechaza esquemas ejecutables. Tambien se escapan textos de movimientos, trabajadores, pagos y mensajes de error que se insertaban como HTML en ambos paneles.
- Los identificadores dinamicos interpolados en acciones y atributos se convierten a Number. Se escapa el numero de factura en el boton del historial. Esto no convierte todos los innerHTML restantes del panel en seguros: quedan otros constructores de vistas y la revision global sigue pendiente.

### Verificacion y limites

`tests/limites_acceso.php` paso en PostgreSQL 18 temporal: cuotas de cuenta/IP, nueva sesion e IP, normalizacion de correo/IPv6, expiracion, limpieza acotada, ocho procesos concurrentes (exactamente cinco permitidos y tres bloqueados), bloqueo de fila y rollback. Se aplico dos veces la migracion en esa base temporal, sin error.

`tests/acceso_endpoints.php` ejecuto los archivos reales de login y recuperacion en procesos CLI separados, sustituyendo solo conexion y transporte/notificaciones por una base temporal y dobles de prueba. Comprobo que los captchas incorrectos consumen cuota, que cambiar sesion/IP no libera la cuenta, login valido con espacios, tres correos simulados y bloqueo del cuarto, Host malicioso excluido del enlace, confirmacion de contrasena, revocacion de sesion, token de un uso y respuesta 503 si falta la tabla. No se contactaron servidores de correo ni se utilizaron cuentas reales.

`node tests/panel_xss.cjs` paso con funciones reales extraidas de admin.html y DOM simulado: nombres con apostrofes, comillas y etiquetas, datos de variantes, atributos de imagen, acciones de dos filas conservadas, textos de movimientos/trabajadores/pagos y mensajes de error. No reemplaza la comprobacion visual en navegador ni una prueba de explotacion en todos los modulos. La verificacion de endpoints es CLI; no se probo el proxy/HTTPS de un despliegue publico ni una carga sostenida. Se retiraron las bases y archivos temporales. No se modificaron usuarios, contrasenas, tokens ni contadores en la base real; no se envio correo real. No se ejecuto SonarCloud ni se publicaron cambios en GitHub.

Referencias: [OWASP, autenticacion y limites de intentos](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) y [OWASP, prevencion de XSS y contextos de atributos](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html).

## Noveno bloque: capturas de TLS y ejecucion dinamica en pruebas

Cambios preparados el 15 de octubre de 2026 a partir de las capturas compartidas. No se ejecuto SonarCloud, no se cambiaron exclusiones, perfiles ni configuraciones de analisis y no se publicaron cambios en GitHub. No requieren migracion.

### SMTP

En `php/mailer_smtp.php`, el inicio de STARTTLS utilizaba STREAM_CRYPTO_METHOD_TLS_CLIENT. Se sustituyo por la mascara explicita TLSv1_2_CLIENT | TLSv1_3_CLIENT. El contexto de conexion impone la misma mascara para TLS implicito (la opcion historica ssl) y verifica certificado, nombre del servidor y ausencia de certificados autofirmados no confiables. Se rechazan configuraciones de SMTP sin cifrado antes de conectar o autenticar. La politica explicita usa las opciones documentadas por [PHP para habilitar cifrado](https://www.php.net/manual/en/function.stream-socket-enable-crypto.php) y [verificar certificados](https://www.php.net/manual/en/context.ssl.php).

La configuracion actual selecciona Brevo, verificado sin imprimir claves. Ese proveedor retorna por su adaptador HTTPS antes del codigo SMTP; este cambio endurece el transporte SMTP alternativo, no demuestra un fallo de entrega en Brevo. No se alteraron claves, remitentes ni servicios externos.

`tests/smtp_tls.php` paso: mascara exacta TLS 1.2/1.3, verificacion de identidad/certificados, conservacion de opciones al crear contexto y rechazo de tres configuraciones sin cifrado antes de abrir conexiones. Paso la sintaxis PHP. No se realizo handshake contra servidores TLS ni envio real de correo; el funcionamiento con certificados y protocolos de un proveedor debe verificarse en el entorno de despliegue.

### Pruebas JavaScript mostradas

Las capturas identifican llamadas de ejecucion dinamica en `tests/carrito_envio.cjs` y `tests/catalogo_comun.cjs`. Se reviso el origen del codigo: archivos fijos del repositorio y expresiones de prueba; no son llamadas usadas por las peticiones de la aplicacion. Esto no justifica ignorar todas las alertas ni acredita que las otras incidencias de seguridad sean inocuas.

Se eliminaron diez llamadas innecesarias a runInContext: de catorce sitios a cuatro entre esos dos archivos. Las pruebas ahora invocan funciones directamente, transmiten productos mediante fetch simulado y leen el carrito persistido. No concatenan productos serializados dentro de codigo ejecutable. Los datos maliciosos de prueba siguen presentes para comprobar el escape HTML. La carga de paginas se limita explicitamente a Producto.html y categoria.html; los contextos deshabilitan generacion de codigo por strings/WebAssembly y los puntos de carga tienen timeout de un segundo.

Las cuatro llamadas restantes cargan el JS local fijo y los scripts de las dos paginas previstas. Continuaran siendo puntos de ejecucion dinamica sujetos a revision; no se ocultaron mediante alias ni se eliminaron las pruebas. Node documenta que [vm no constituye una barrera de seguridad para codigo no confiable](https://nodejs.org/api/vm.html). Los limites indicados ayudan a contener errores de las pruebas, pero no permiten ejecutar archivos de terceros de forma segura. La revision depende de ejecutar una copia confiable del repositorio; no se cambiaron estados de incidencias en Sonar. Tambien quedan los puntos de ejecucion dinamica propios de `tests/panel_xss.cjs`, no incluidos en estas capturas, pendientes de su revision individual.

Pasaron `node tests/carrito_envio.cjs`, `node tests/catalogo_comun.cjs` y la regresion `node tests/panel_xss.cjs`. Se conservan los casos de doble clic, respuesta perdida, reintento con misma clave, rechazo comercial, cambio de carrito incierto, arranque de ambas paginas, escape HTML y limite de stock por variante. Son pruebas con DOM/transporte simulados; no sustituyen una prueba real en navegador. Los cambios no permiten afirmar un nuevo numero de incidencias ni que la puerta de calidad haya pasado: eso requiere el siguiente analisis del usuario.

## Decimo bloque: conexiones temporales autenticadas, prueba del panel y permisos de imagen

Cambios preparados el 15 de octubre de 2026 a partir del segundo grupo de capturas. No requieren migracion ni cambios en Neon. No se ejecutaron analisis, exclusiones o cambios de estado en SonarCloud.

### Bases de datos de prueba

Las conexiones con password vacio estaban en las fixtures temporales, no en la conexion de produccion. Se reemplazaron en los siete archivos de integracion, incluidas segundas conexiones y procesos auxiliares, por `conexion_postgres_prueba()` de `tests/postgres_temporal.php`. Ya no hay una alternativa de password vacio en estas conexiones.

El helper requiere CLI, host fijo 127.0.0.1, puerto entre 55000 y 55999, password efimero de 256 bits y marca aleatoria del cluster recibidos por entorno. Antes de usar la fixture compara la marca del servidor y comprueba que las reglas de autenticacion son SCRAM-SHA-256. No lee configuracion.php ni credenciales de la aplicacion. Sin el entorno de pruebas se detiene antes de conectar.

`tests/ejecutar_postgres.ps1` crea un cluster temporal nuevo con autenticacion SCRAM, genera una clave criptograficamente aleatoria por ejecucion y no la imprime ni la incluye en argumentos del proceso. initdb la recibe por un archivo temporal que se retira tras inicializar. Los procesos PHP la heredan por entorno; la configuracion temporal de endpoints carga el helper, sin escribir la clave en PHP. El ejecutor comprueba el rechazo de una clave incorrecta, prepara cada fixture por separado, detiene el servidor, restaura las variables de entorno y elimina los archivos temporales despues de verificar sus rutas y la ausencia del servidor activo. Usa el [mecanismo --pwfile y autenticacion de initdb](https://www.postgresql.org/docs/current/app-initdb.html).

Comando en PowerShell con scripts permitidos: `./tests/ejecutar_postgres.ps1`. Para una seleccion: `./tests/ejecutar_postgres.ps1 -Pruebas clientes_facturas`. En este equipo la politica bloquea scripts; la verificacion autorizada se ejecuto con `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/ejecutar_postgres.ps1`, excepcion limitada al proceso, sin cambiar la politica persistente.

Pasaron las siete integraciones: inventario/devoluciones, finanzas/reportes (incluidos indices), clientes/facturas, notificaciones simuladas, pedido/carrito, limites concurrentes y endpoints de acceso con correo simulado. El servidor rechazo la clave incorrecta y las conexiones correctas comprobaron las reglas SCRAM. Se detecto y corrigio un error de validacion de rutas en la limpieza final del ejecutor; despues se verifico un ciclo completo con clientes/facturas y limpieza automatica satisfactoria. Se retiraron tambien los archivos de la primera ejecucion, con el servidor detenido. No se utilizo Neon ni se enviaron correos reales.

### Ejecucion dinamica en panel_xss.cjs

Se retiro `new Function` de la comprobacion de sintaxis. Node ahora recibe el texto por stdin con `--check`, ejecutable fijo, sin shell y con timeout; analiza la sintaxis sin ejecutar ese texto. Se usa windowsHide al iniciar ese proceso. La lectura de admin.html se resuelve desde __dirname y no desde el directorio de trabajo.

La carga de las funciones del panel sigue necesitando un punto de `vm.runInContext` sobre nombres literales previstos, extraidos del admin.html fijo del repositorio. El contexto deshabilita generacion de codigo por strings/WebAssembly y cada carga tiene timeout. Paso `node tests/panel_xss.cjs`, conservando la comprobacion de XSS y las acciones de las filas. El entorno de aislamiento bloqueo inicialmente el subproceso Node con EPERM; la misma prueba paso al autorizar su ejecucion fuera de ese aislamiento.

Permanecen cinco sitios de runInContext entre las tres pruebas JavaScript (cuatro documentados en el noveno bloque y uno en panel_xss). Se revisaron sus fuentes como codigo local del repositorio; no se convierten datos de usuarios en codigo. Son puntos sujetos a revision de seguridad en Sonar, no se afirman eliminados. vm no permite ejecutar codigo de terceros con seguridad. No se sustituyeron por alias para ocultarlos ni se eliminaron pruebas para reducir el conteo.

### Permisos de imagenes

En `php/upload_seguro.php`, las carpetas nuevas se crean con 0750 y los archivos nuevos con 0640 en Unix: acceso del propietario y lectura del grupo del servidor, sin permisos para otros usuarios del sistema. Se quito la supresion de error de chmod; si falla, se intenta retirar el archivo recien subido y se rechaza la operacion. No se cambiaron permisos de imagenes o carpetas existentes.

En Windows se mantienen las ACL heredadas; no se pretende configurar ACL con chmod, cuya compatibilidad con permisos Windows es limitada segun [PHP](https://www.php.net/manual/en/function.chmod.php). No se modificaron ACL del equipo. Un despliegue con PHP y servidor estatico separados debe asignar correctamente el grupo lector antes de usar 0640/0750. Se verifico sintaxis PHP; no se probo una subida multipart completa ni los modos Unix en este equipo Windows. Por tanto el funcionamiento de esa politica en Linux sigue pendiente de validacion de despliegue.

Este bloque permanece local sin commit ni publicacion. La siguiente ejecucion de Sonar corresponde al usuario; las capturas no permiten afirmar una calificacion nueva ni una puerta de calidad superada.

## Undecimo bloque: seis hashes SQL, integridad de CDN y cookies de produccion

Preparado a partir del listado completo del analisis publicado el 15 de octubre de 2026 a las 11:40 (Bogota), revision b92e3a5e30815b8ae99f868eef9c6b9a3f437818. La lectura encontro 845 incidencias abiertas y 13 con impacto de seguridad: seis hashes bloqueadores, cinco cargas de pruebas con vm y dos bajas. No se cambio su estado en Sonar ni se ejecuto un analisis nuevo. No se considera superada la puerta de calidad.

### Hashes de contrasenas en SQL

Se retiraron los seis literales bcrypt de `database/isa_postgretsql.sql`, `database/migracion_seguridad_passwords.sql` y `database/produccion_datos_minimos.sql`. Las semillas conservan referencias de usuarios para las claves foraneas de los ejemplos, pero las dejan inactivas y con un marcador que password_verify no acepta como hash. No se distribuyen claves iniciales. La migracion heredada ya no actualiza contrasenas con valores comunes: comprueba el prefijo de hash en cuentas activas y se detiene ante claves sin hash; no sustituye el restablecimiento individual ni valida por completo todos los formatos de hash.

Se preparo `scripts/crear_usuario_inicial.php`, solo CLI, para futuras instalaciones. Valida nombre/correo/rol y recibe una clave propia por una variable de entorno efimera. Genera el hash en ejecucion. El helper crea cuentas nuevas o habilita exclusivamente marcadores iniciales inactivos del mismo rol, con transaccion y bloqueo por correo; rechaza sobrescribir cuentas normales. No se ejecuto este comando sobre Neon. PUBLICACION.md documenta su uso y deja de anunciar contrasenas predeterminadas.

Antes de retirar los literales se compararon con los hashes de las dos cuentas reales en una transaccion de solo lectura, sin imprimirlos. Ninguno coincidia; tampoco verificaron las antiguas claves de ejemplo. No fue necesario cambiar esas cuentas para esta correccion, y no se modificaron contrasenas, sesiones ni tokens reales. Esto no borra versiones historicas del repositorio ni acredita que esas claves nunca se hayan usado en otras instalaciones.

### Integridad de JsBarcode

El script remoto de `html/admin.html` ahora lleva integrity SHA-384 y crossorigin=anonymous, conservando la version fija 3.11.6. La huella se calculo sobre los 60817 bytes descargados del recurso exacto; el CDN devolvio Access-Control-Allow-Origin: *. No se ejecuto la libreria durante la descarga. La validacion de integridad sigue el [mecanismo SRI documentado por MDN](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Subresource_Integrity). No demuestra ausencia de vulnerabilidades de la libreria ni sustituye una prueba de impresion de codigos en navegador.

### Cookies

`php/cookie_segura.php` define Secure por defecto y rechaza acceso HTTP fuera del entorno local autorizado con respuesta 426. La excepcion web exige app_env=local, conexion loopback y Host localhost/loopback; no basta falsificar el Host desde una conexion remota. CLI conserva su uso en pruebas sin leer las credenciales de configuracion. La cookie CSRF utiliza la misma politica de transporte, manteniendo HttpOnly=false para su cabecera explicita; la cookie de sesion conserva HttpOnly y SameSite=Lax.

Se agrego app_env=production a la configuracion de ejemplo y al respaldo por variables de entorno. El archivo local ignorado se marco app_env=local para conservar XAMPP por HTTP sin cambiar las credenciales de conexion. Los despliegues nuevos requieren HTTPS y deben configurar el proxy y el host canonico correctamente; no se confia en X-Forwarded-Proto proporcionado por el cliente. La excepcion local es intencional y podria seguir requiriendo revision de php:S2092 en Sonar; no se da por cerrado ese aviso sin un nuevo analisis. [PHP documenta Secure en los parametros de sesion](https://www.php.net/session-set-cookie-params).

### Verificacion y pendientes

`tests/usuarios_iniciales.php` paso con PostgreSQL temporal autenticado: semillas inactivas/idempotentes, marcador no utilizable como clave, activacion con clave propia, creacion de usuario nuevo, rechazo de sobrescritura con datos conservados y comprobacion de cuentas heredadas. Probo cookies HTTPS, HTTP local autorizado, produccion sin HTTPS, Host local falsificado por IP remota y Host publico desde loopback. La regresion de endpoints de acceso y recuperacion paso en otra fixture temporal con correo simulado. El captcha real local respondio HTTP 200.

Las cinco cargas vm ya documentadas siguen sujetas a revision individual: no se ocultaron mediante exclusiones ni se sustituyeron pruebas por omisiones. La confiabilidad y el resto de mantenimiento tambien siguen pendientes. No se aplicaron SQL de semillas ni esta comprobacion heredada a Neon, no se crearon cuentas reales ni se enviaron correos. No se probo HTTPS/proxy publico ni impresion real de codigos. Los cambios de este bloque siguen locales y no se publicaron en GitHub.

## Duodecimo bloque: asociaciones de formularios y analisis del Host de cookies

Preparado el 15 de octubre de 2026 despues de confirmar que el analisis publicado de ea7823eb0b41650270bd936a083829d3c711e77b incluia las correcciones anteriores. La puerta seguia en C de confiabilidad y D de seguridad. Se trabajaron las reglas Web:InputWithoutLabelCheck y Web:S6853 y el aviso php:S5332 del helper de cookies. No se ejecutaron analisis ni cambios en la configuracion o estados de Sonar.

### Formularios

Se asociaron explicitamente 88 etiquetas existentes mediante for/id: 74 en admin.html y 14 en vendedor.html. Los campos de descuento se identifican por separado como tipo y valor; las cantidades de talla tambien tienen nombre propio. Se agregaron 22 nombres accesibles a los controles que carecian de una asociacion, incluidos ingreso, recuperacion y filtros de busqueda/auditoria. Se usan los [mecanismos de etiquetado descritos por W3C](https://www.w3.org/WAI/tutorials/forms/labels/).

Se sustituyeron tres labels que no etiquetaban entradas: el titulo de un grupo de variantes y dos textos de avance financiero. El grupo usa role=group y aria-labelledby hacia su titulo; los porcentajes conservan sus identificadores y actualizaciones. Los selectores CSS equivalentes mantienen el estilo de los titulos. Se actualizo la version de las hojas de estilo en ambos paneles para evitar usar la version anterior desde cache.

Una comparacion con HEAD confirmo que se conservan el orden y los atributos funcionales de input/select/textarea/button/form, excluyendo los nuevos atributos de nombre accesible. No se cambiaron id, name, valores, tipos, min/max, required, readonly ni acciones. La comprobacion semantica encontro 93 controles en administrador, 20 en vendedor y 2 en restablecimiento, todos con nombre accesible y etiquetas/referencias validas. Comprueba tambien IDs duplicados y referencias inexistentes. Es una revision del HTML estatico, no una certificacion completa de accesibilidad ni una prueba con lector de pantalla.

El listado previo contenia 107 avisos InputWithoutLabelCheck y 90 S6853 entre estas tres paginas. Son los grupos que esta correccion aborda; no se afirma que Sonar haya cerrado 197 incidencias sin volver a analizar. Quedan otras reglas de confiabilidad, por ejemplo las relacionadas con conversiones PHP, expresiones regulares y APIs JavaScript. Este bloque no acredita una calificacion A.

### Cookies

El helper construia una cadena con prefijo http:// solo para parse_url y obtener el host, sin abrir una conexion. Ahora utiliza una referencia de autoridad sin protocolo, manteniendo el mismo analisis de hostname y puertos. Se retira el protocolo ficticio que originaba el aviso php:S5332; no se oculta una llamada HTTP real. Secure sigue siendo obligatorio en produccion y la excepcion HTTP sigue limitada al entorno local autorizado con IP y Host loopback. El aviso php:S2092 de la excepcion local y los cinco puntos vm siguen sujetos a revision; no se cambiaron sus estados ni se desactivaron reglas.

### Verificacion

Pasaron `python tests/formularios_accesibles.py` (incluye casos negativos de IDs/nombres/referencias rotos), `php tests/usuarios_iniciales.php` sin puerto (politica de cookies, incluidos IPv4/IPv6 con puerto y rechazo de HTTP publico), captcha/auditoria, pruebas de envio del carrito y catalogo, y regresion XSS del panel. Se verifico sintaxis de cookie_segura.php; la comprobacion del panel analiza tambien sus scripts reales. En HTTP local el captcha respondio 200; la misma ruta con Host publico respondio 426, sin acceder a cuentas ni enviar correos.

No se probo visualmente el foco al pulsar cada label, ni HTTPS/proxy de produccion, ni la impresion de codigos en navegador. No se modifico Neon, no hubo migraciones ni operaciones comerciales y no se publicaron cambios en GitHub. Las correcciones estan locales para el siguiente commit y analisis del usuario.

## Decimotercer bloque: siete grupos de confiabilidad del analisis b08f9fa

Preparado el 15 de octubre de 2026 sobre el listado publicado a las 14:45 (Bogota), revision b08f9faa94cd272ae6ca699f49d810ffde915c14. Ese analisis tenia 64 incidencias con impacto de confiabilidad: 27 php:S2003, 26 javascript:S7773, seis javascript:S9383, dos javascript:S7723 y una de cada regla plsql:NullComparison, javascript:S6638 y javascript:S7781. Este bloque aborda esos siete grupos; no es un resultado nuevo de Sonar ni garantiza por si solo la calificacion A.

### Inclusiones y configuracion

Los helpers y archivos de prueba del listado ahora usan require_once para evitar redefiniciones. En configuracion no se hizo una sustitucion directa del valor de retorno: una inclusion ya realizada puede devolver true, como explica [PHP sobre inclusiones unicas](https://www.php.net/manual/en/function.include-once.php). `php/configuracion_util.php` centraliza `cargar_configuracion()`, conserva el arreglo completo en memoria durante la ejecucion y carga el archivo privado una vez, validando su tipo. El archivo `configuracion.php` mantiene el contrato de devolver el arreglo al incluirlo. Conexion, captcha y politica de cookies obtienen los datos mediante la funcion, independientemente de quien haya cargado antes el archivo.

No se modificaron los valores privados ni las credenciales. Las pruebas aisladas de configuracion cubren lectura local unica, arreglo estable tras inclusiones repetidas, datos anidados, variables de entorno y rechazo de un archivo que no devuelve un arreglo. No leen la configuracion real. Ademas se verifico una conexion real con SELECT 1 en transaccion de solo lectura y la igualdad de configuracion antes/despues, sin imprimir campos privados. El captcha local respondio HTTP 200.

### JavaScript

- Se usan Number.parseInt y Number.parseFloat en las llamadas del listado. Se usa Number.isNaN solo sobre resultados numericos ya convertidos; no se elimino implicitamente una conversion necesaria de strings. La diferencia de coercion esta documentada por [MDN](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Number/isNaN). No se cambio el criterio historico de truncamiento de parseInt ni se acredita una validacion nueva de todas las cantidades.
- El login espera a completar la renovacion del captcha tras un rechazo. El vendedor espera a abrir la factura antes de continuar el refresco, y la inicializacion espera las tres cargas del panel con Promise.all y captura de errores. La busqueda del historial espera su consulta. No se agrego void para silenciar promesas. Las funciones ya tienen sus manejadores de fallos de transporte; la captura de inicializacion cubre tambien fallos previos a las solicitudes.
- Se detecto y corrigio una inconsistencia de acceso: auth.js recortaba espacios de la contrasena aunque el backend ya los conservaba. Ahora se envia el valor exacto; el correo y la respuesta del captcha conservan su normalizacion independiente.
- Los dos errores simulados del carrito usan new Error. El historial del administrador ya no conserva una rama false && inalcanzable; renderiza directamente los mismos botones que antes seleccionaba siempre la rama restante. La categoria reemplaza guiones bajos mediante replaceAll, conservando la conversion posterior de mayusculas.
- Se actualizaron las versiones de los scripts de ambos paneles y la importacion de auth.js para evitar usar codigo anterior desde cache.

### SQL

En `database/migracion_variantes_producto.sql`, el filtro de imagen ahora expresa NULLIF(p.imagen, '') IS NOT NULL. El original era valido para PostgreSQL: sus strings vacios no equivalen a NULL como en Oracle/PLSQL. La nueva expresion conserva el resultado en PostgreSQL y evita la comparacion directa con cadena vacia que marcaba el analizador PL/SQL. Se probo en PostgreSQL temporal con NULL, cadena vacia, espacio, imagen valida e imagen ya registrada, incluida repeticion de la migracion. No se normalizaron espacios ni se alteraron rutas existentes. No se aplico esta migracion a Neon; el cambio es para la fuente y futuras instalaciones.

### Verificacion

Pasaron las nueve integraciones temporales autenticadas: inventario/devoluciones, finanzas/reportes e indices, clientes/facturas, notificaciones con transporte simulado, pedido/carrito, limites concurrentes, endpoints de acceso/recuperacion, usuarios iniciales y variantes/imagenes. El ejecutor detuvo y retiro el cluster y sus archivos.

`tests/promesas_panel.cjs` carga los archivos reales mediante require/import de rutas fijas, sin vm ni evaluacion de strings. Usa DOM y transporte simulados para comprobar que el panel espera sus tres consultas, que la busqueda devuelve su trabajo asincrono, que el formulario espera la factura y que el login espera al captcha nuevo y conserva espacios de la clave. Se ejercitan fallos controlados; no sustituye el recorrido visual ni la impresion real de facturas. `tests/configuracion.php` se ejecuta en sus tres modos con archivos de fixture separados.

Tambien pasaron las regresiones de carrito, catalogo y XSS del panel, los 115 controles estaticos de formularios, captcha/auditoria y politica TLS sin envios. Se verificaron los 94 archivos PHP y la sintaxis de auth.js, script.js y vendedor.js. No se enviaron correos, no se hicieron operaciones comerciales ni cambios de datos en Neon y no se ejecutaron migraciones reales. No se publico en GitHub ni se ejecuto SonarCloud. Permanecen las seis revisiones de seguridad previamente identificadas (cinco cargas vm y la excepcion local de cookies), ademas de mantenimiento; no se alteraron exclusiones, reglas ni estados para ocultarlas.

## Decimocuarto bloque: eliminar ejecucion dinamica y conservar Secure siempre

Preparado tras el analisis de a56437a30d611607aab125dd101d7d0f09f4b11e del 15 de octubre, 19:50 de Bogota. Seguian abiertas cinco javascript:S1523 y una php:S2092. Este bloque cambia los patrones de codigo, sin decisiones de cierre manual, exclusiones, NOSONAR ni cambios de reglas. El cierre efectivo de las incidencias requiere el siguiente analisis publicado por el usuario.

### Modulos de catalogo y panel

`catalogo-comun.js` exporta crearCatalogo con entorno, estado y acciones explicitos. Las dos paginas tienen ahora modulos propios (`catalogo-productos.js`, `catalogo-categoria.js`) y entradas de navegador. El carrito, producto seleccionado e indice/imagenes del carrusel se comparten mediante accesores al estado de cada pagina. Las funciones y eventos originales siguen usando ese mismo estado, y el bloqueo de envio permanece separado por instancia. Los HTML cargan las nuevas entradas como modulos desde el mismo servidor. Las importaciones y entradas incluyen version nueva para cache.

Las trece funciones probadas del panel se trasladaron sin cambiar sus cuerpos a `admin-tablas.js`. El panel las obtiene de crearTablasAdmin con DOM, transporte y callbacks explicitos. Se mantiene el resto de su script clasico y sus nombres accesibles a manejadores existentes. El transporte delegado permite conservar el wrapper fetch/CSRF que instala auth.js posteriormente. La misma fabrica se carga en Node mediante require; los modulos del catalogo mediante import de rutas locales fijas.

`tests/catalogo_comun.cjs`, `tests/carrito_envio.cjs` y `tests/panel_xss.cjs` ya no importan vm, extraen funciones para ejecutarlas ni evaluan strings. Conservan las comprobaciones de datos maliciosos, dependencias de ambas paginas, stock, doble clic, respuesta perdida y clave de reintento. El panel conserva ademas el analisis de sintaxis de sus scripts inline mediante node --check, que no los ejecuta. No se sustituyo vm por otra API de evaluacion ni se borraron las pruebas.

### Cookies

Se retiro la asignacion Secure=false del helper. Sesion, CSRF y borrado de sesion establecen Secure=true explicitamente. HttpOnly y SameSite=Lax de la sesion se conservan; la cookie CSRF sigue accesible para su cabecera explicita. La validacion de transporte se ejecuta antes de crear cookies: HTTP de produccion se rechaza con 426; HTTP local requiere entorno local, Host local e IP de conexion loopback, sin confiar en X-Forwarded-Proto o X-Forwarded-For.

Chrome permite las cookies Secure por HTTP en localhost. Se comprobo su continuidad en un perfil temporal y que HttpOnly impide leerlas con document.cookie. Esta excepcion del navegador [esta documentada por MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies); no equivale a cifrar HTTP. Safari y otros entornos que no admitan esa excepcion requieren HTTPS tambien en desarrollo. No se cambiaron certificados, configuracion global de Apache ni credenciales para forzar compatibilidad.

### Verificacion

Pasaron las tres regresiones Node de catalogo/carrito/XSS y la de promesas del vendedor/acceso; los 115 controles de formularios; usuarios iniciales sin base; captcha/auditoria; sintaxis PHP de los archivos modificados y JavaScript de los seis modulos/entradas. La comparacion con HEAD confirmo que los cuerpos de las trece funciones extraidas del panel se conservaron.

`tests/navegador_modulos.py` sirve los HTML/JS reales con una API simulada en loopback y Chrome sin ventana con perfiles temporales. Pasaron Producto.html, categoria.html?tipo=blusas y admin.html: carga nativa de modulos, nombres escapados, eventos, estado del carrito, stock limitado a dos unidades, carrusel, confirmacion de pedido simulada, inventario con acciones y tablas del panel. El CDN de codigos de barras se omite solo en la fixture; no se probo impresion de etiquetas. La primera comprobacion del carrusel suponia una imagen principal distinta y la primera insercion del verificador entraba tambien en una plantilla de impresion; se corrigieron ambas fixtures antes del resultado final, sin cambiar la logica del producto para acomodar las pruebas.

El captcha real de XAMPP devolvio HTTP 200 y Set-Cookie con Secure, HttpOnly y SameSite=Lax. La misma ruta con Host publico por HTTP devolvio 426. La persistencia de cookie en navegador se probo en el servidor simulado, no mediante un ingreso real de usuario. Las integraciones de usuarios iniciales y endpoints reales con conexion/correo simulados pasaron en PostgreSQL temporal autenticado SCRAM; el ejecutor detuvo y retiro ese cluster.

No hubo migraciones, cambios comerciales o de cuentas en Neon ni envios de correo. No se publico el codigo ni se ejecuto Sonar. Subir juntos los HTML, los seis archivos JavaScript del bloque y los cambios PHP; un despliegue parcial deja importaciones o dependencias ausentes. La revision anterior en REVISION_SEGURIDAD_SONAR.md queda como antecedente historico, no como peticion de aceptar los seis avisos de la version nueva.

## Decimoquinto bloque: firma explicita de la cookie de sesion

El analisis de 018b4fd0848eb1de5862ef3eff4283d1dd6b5e5c, del 15 de octubre a las 20:03 de Bogota, cerro los cinco javascript:S1523: quedo una php:S2092, con seguridad B, confiabilidad A y duplicacion 2,3 %. La cookie ya tenia Secure=true y se habia comprobado su cabecera real.

Se consulto la [implementacion oficial CookiesSecureCheck](https://github.com/SonarSource/sonar-php/blob/master/php-checks/src/main/java/org/sonar/php/checks/CookiesSecureCheck.java): busca el argumento secure por nombre o posicion 3 en session_set_cookie_params. Su tratamiento de un argumento unico no inspecciona el arreglo de opciones. Esto explica el aviso sobre la firma usada, sin demostrar un envio inseguro real.

Se usa ahora session_set_cookie_params(0, '/', '', true, true), una [firma documentada por PHP](https://www.php.net/manual/en/function.session-set-cookie-params.php). SameSite=Lax se configura antes mediante session.cookie_samesite. Se conservan duracion, alcance, Secure y HttpOnly; la validacion de transporte previa y la cookie CSRF no cambian. No se desactiva ni se suprime la regla.

La regresion de seguridad comprueba los parametros efectivos de PHP mediante session_get_cookie_params, incluidos Secure, HttpOnly y SameSite=Lax. Se verifican tambien la sintaxis y la cabecera real del captcha en XAMPP, sin conexiones a Neon ni envios de correo. El siguiente analisis publicado debe confirmar si cierra el ultimo aviso; no se ejecuta un analisis desde este bloque.
