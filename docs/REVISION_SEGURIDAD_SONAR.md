# Revision de las seis incidencias de seguridad

**Estado posterior:** esta es la revision historica del commit indicado abajo. El siguiente bloque de codigo elimina las cinco llamadas vm y mantiene Secure tambien en desarrollo. Sus pruebas ahora usan modulos nativos y el navegador; ver el decimocuarto bloque de `CORRECCIONES_SEGURIDAD.md`. Las conclusiones sobre excepciones y cierre manual de este documento describen el codigo anterior, no una accion pendiente para la nueva version. El cierre efectivo requiere verificar el siguiente analisis de Sonar.

Revision del 15 de octubre de 2026 sobre el commit `1576bd2a39626429e16808782ff3c554bce76d18`, analizado a las 15:09 de Bogota. El resultado publicado es confiabilidad A (cero incidencias abiertas), seguridad D (seis abiertas). Este documento no cambia esos estados ni acredita una puerta aprobada.

## Resultado de la revision del codigo

No se identifico un flujo de datos externos hacia el codigo ejecutado en las cinco llamadas indicadas. Son cargas intencionales de codigo del repositorio para pruebas. La cookie permite HTTP exclusivamente en el entorno local autorizado o CLI; HTTPS conserva Secure. Estas conclusiones dependen de las condiciones descritas abajo y no equivalen a certificar todo el proyecto.

| Incidencia y linea del analisis | Fuente y controles comprobados | Conclusion y limite |
| --- | --- | --- |
| `php:S2092`, `php/auth_guard.php:13` | Las opciones vienen de `opciones_cookie_actuales()` y `opciones_cookie_sesion()`. Secure es true por defecto. HTTP web exige simultaneamente app_env=local, IP de conexion loopback y Host local. Produccion HTTP se rechaza antes de iniciar la sesion. | Excepcion deliberada de desarrollo, no una ausencia general de Secure. Debe revisarse como excepcion contextual; no afirmar que toda cookie lleva Secure. Un proxy local de produccion requiere configuracion y comprobacion propias. |
| `javascript:S1523`, `tests/catalogo_comun.cjs:9` | El texto proviene exclusivamente de `js/catalogo-comun.js`, ruta fijada desde __dirname. El contenido corrupto de localStorage entra como dato, no se concatena al codigo. | Uso intencional de codigo local confiable en pruebas. No ejecutar esta copia si su contenido no es confiable. |
| `javascript:S1523`, `tests/catalogo_comun.cjs:57` | Se carga el mismo archivo compartido fijo para cada pagina con DOM, almacenamiento y fetch simulados. | Mismo requisito de confianza en la copia local. No hay descarga de codigo ni fuente elegida por el usuario. |
| `javascript:S1523`, `tests/catalogo_comun.cjs:60` | Los scripts se extraen de Producto.html o categoria.html; existe una lista literal de esas dos paginas. Se omiten etiquetas con src. Los productos maliciosos se entregan despues mediante fetch simulado. | Se prueba el arranque del codigo real de esas paginas. No se ejecutan scripts recibidos del servidor ni nombres de archivo de parametros externos. |
| `javascript:S1523`, `tests/carrito_envio.cjs:18` | Solo se carga `js/catalogo-comun.js`. El carrito se entrega como objeto, con JSON.parse; los cambios se hacen mediante llamadas a funciones. | Las cantidades y productos de prueba no se transforman en instrucciones. El archivo fuente sigue necesitando confianza. |
| `javascript:S1523`, `tests/panel_xss.cjs:47` | Se extraen funciones de admin.html con una lista literal de trece nombres. Los nombres y HTML maliciosos entran en respuestas simuladas despues de cargar las funciones. | La extraccion no es un parser general de JavaScript; solo sirve para la estructura actual. No usar este ejecutor con HTML de terceros. |

Todos los contextos vm indicados deshabilitan generacion de codigo por strings y WebAssembly; cada llamada tiene timeout de 1000 ms. Esos controles reducen errores accidentales, pero **vm no es una barrera para ejecutar codigo no confiable**. El timeout tampoco garantiza limitar todo el trabajo asincrono. Los contextos reciben funciones del proceso de prueba y no constituyen aislamiento del equipo.

## Verificacion

Pasaron `node tests/catalogo_comun.cjs`, `node tests/carrito_envio.cjs`, `node tests/panel_xss.cjs`, `php tests/usuarios_iniciales.php` sin puerto y `php tests/seguridad.php`. Cubren escape de datos de productos, arranque de ambas paginas, stock, reintentos y doble clic, acciones del inventario y texto de movimientos/trabajadores/pagos. Las pruebas de cookies incluyen HTTPS, HTTP local autorizado, produccion HTTP, falsificacion de Host y encabezados X-Forwarded-Proto/X-Forwarded-For. No conectan a Neon ni envian correo.

No se probo HTTPS con un proxy real ni se demuestra que codigo arbitrario quede confinado por vm. No se eliminaron pruebas, no se sustituyo vm por otra API equivalente y no se agregaron exclusiones o NOSONAR.

## Que falta para cerrar estas incidencias

Los cinco avisos describen una ejecucion dinamica que realmente existe y la cookie tiene una excepcion real de desarrollo. Un commit que solo documente la revision no elimina los avisos.

Una persona responsable del proyecto debe evaluar esta evidencia y registrar la decision individual en Sonar si admite estos usos. No se deben marcar automaticamente como falsos positivos o aceptados para obtener A. No se modifico ningun estado en Sonar en esta revision.

Si el requisito es eliminar estos patrones del codigo, hace falta otro cambio funcional: extraer los scripts clasicos a modulos con dependencias explicitas y migrar las pruebas a importaciones o a navegador; para la cookie, usar HTTPS tambien en desarrollo y retirar la excepcion HTTP. Esos cambios necesitan conservar los manejadores HTML existentes y verificar acceso local, carga de ambas paginas y operaciones del panel. No se hicieron cambios parciales de arquitectura ni se impuso HTTPS a XAMPP en esta revision.

Referencias: [Node.js sobre vm](https://nodejs.org/api/vm.html), [PHP sobre parametros de cookies de sesion](https://www.php.net/manual/en/function.session-set-cookie-params.php), [Sonar sobre decisiones de revision y estados de incidencias](https://docs.sonarsource.com/sonarqube-cloud/managing-your-projects/issues/editing).
