# Revisión del documento y desarrollo de la tercera fase

## Observaciones sobre el documento avanzado

El documento avanzado ya contiene una base sólida de la primera y segunda fase. Presenta correctamente la introducción, descripción del problema, justificación, objetivos, stakeholders, requerimientos funcionales y no funcionales, casos de uso, historias de usuario, usuarios del sistema, herramientas utilizadas y diseño del sistema.

Sin embargo, se recomienda ajustar los siguientes puntos antes de entregar:

1. Corregir errores de ortografía y acentuación.
   Ejemplos: "Descripcion" debe ser "Descripción", "reponsive" debe ser "responsive", "mercancia" debe ser "mercancía", "Telefono" debe ser "Teléfono", "entongithub..." debe eliminarse porque parece texto pegado por error.

2. Actualizar las tecnologías utilizadas.
   En la guía de tercera fase aparecen Python, Flask y MySQL como ejemplo, pero el proyecto real de Isa Boutique está desarrollado con HTML, CSS, JavaScript, PHP y PostgreSQL. El documento debe mantenerse coherente con PostgreSQL.

3. Ajustar algunos requerimientos que cambiaron durante el desarrollo.
   El sistema ya no solo maneja inventario y ventas básicas. Actualmente también incluye roles, facturación, IVA, descuentos, proveedores, compras de mercancía, trabajadores, pagos, finanzas, variantes por color y talla, imágenes múltiples y reportes.

4. Revisar el punto de códigos QR y cuotas.
   En el documento aparece como requerimiento, pero si no se implementó completamente, debe indicarse como funcionalidad pendiente o planeada para futuras versiones.

5. Actualizar la descripción del diseño.
   El sistema ahora cuenta con una tienda pública, panel administrador, panel vendedor, carrito, catálogo, inventario, ventas internas, facturas, reportes, finanzas, personas y configuración.

6. Mejorar la tabla de contenido.
   El capítulo 3 aparece incompleto con numerales vacíos. Debe reemplazarse por los apartados completos de la fase de desarrollo.

---

# CAPÍTULO 3: DESARROLLO DEL PROYECTO

## 3.1 Introducción de la fase

La fase de desarrollo del proyecto Isa Boutique corresponde a la construcción funcional del sistema web propuesto en las fases anteriores. En esta etapa se transformaron los requerimientos y diseños definidos previamente en módulos reales, programados e integrados para permitir la gestión administrativa, comercial y contable de la boutique.

Durante esta fase se desarrollaron las interfaces públicas e internas del sistema, se implementó la lógica de ventas, inventario, usuarios, roles, facturación, proveedores, trabajadores, compras de mercancía, reportes financieros y control de productos por color, talla e imágenes.

La programación fue una etapa fundamental porque permitió pasar de la planeación a una herramienta funcional. Gracias al desarrollo del sistema, Isa Boutique puede registrar productos, controlar existencias, vender productos desde el panel interno o desde la página web, generar facturas, calcular IVA, aplicar descuentos y consultar información importante para la toma de decisiones.

El objetivo principal de esta fase fue construir un sistema web funcional, organizado y conectado a una base de datos PostgreSQL, manteniendo una estructura clara y adaptable a las necesidades reales del negocio.

## 3.2 Tecnologías utilizadas

Para el desarrollo del sistema Isa Boutique se utilizaron diferentes tecnologías orientadas al desarrollo web, la gestión de datos y la organización del proyecto.

| Tecnología | Función dentro del proyecto |
|---|---|
| HTML5 | Estructura de las páginas públicas e internas del sistema. |
| CSS3 | Diseño visual, estilos, colores, formularios, tablas, paneles y adaptación responsive. |
| JavaScript | Interactividad del sistema, validaciones, actualización dinámica de datos, carrito, cálculos y comunicación con PHP. |
| PHP | Backend del sistema, procesamiento de formularios, conexión con la base de datos y lógica del negocio. |
| PostgreSQL | Base de datos relacional utilizada para almacenar productos, usuarios, ventas, clientes, facturas, proveedores, trabajadores y movimientos. |
| PDO | Mecanismo de conexión segura entre PHP y PostgreSQL. |
| XAMPP | Entorno local de desarrollo para ejecutar el servidor y probar el sistema. |
| Visual Studio Code | Editor de código utilizado para desarrollar y organizar los archivos. |
| GitHub | Repositorio para control de versiones y respaldo del proyecto. |

Es importante aclarar que el proyecto se mantiene en PostgreSQL, por lo tanto no se realizó migración a MySQL.

## 3.3 Estructura del proyecto

El proyecto se organizó en carpetas para separar las responsabilidades del sistema y facilitar su mantenimiento.

Estructura general:

```text
isa_boutique/
│
├── css/
│   ├── styles.css
│   └── internal-system.css
│
├── database/
│   ├── migraciones SQL
│   ├── backups
│   └── archivos de estructura de base de datos
│
├── html/
│   ├── index.html
│   ├── Producto.html
│   ├── categoria.html
│   ├── admin.html
│   ├── vendedor.html
│   └── login.html
│
├── img/
│   ├── logo
│   └── productos
│
├── js/
│   ├── script.js
│   └── vendedor.js
│
└── php/
    ├── conexion.php
    ├── productos_guardar.php
    ├── productos_listar.php
    ├── venta_registrar.php
    ├── factura_obtener.php
    ├── reportes_admin.php
    └── demás archivos backend
```

La carpeta `html` contiene las vistas principales del sistema. La carpeta `css` almacena los estilos visuales. La carpeta `js` contiene la lógica del lado del cliente. La carpeta `php` se encarga de procesar la información, conectarse a PostgreSQL y responder a las solicitudes del sistema. Finalmente, la carpeta `database` contiene los scripts SQL, migraciones y respaldos de la base de datos.

## 3.4 Desarrollo del frontend

El frontend fue desarrollado con HTML, CSS y JavaScript. La interfaz se dividió en dos grandes áreas: la página pública para clientes y los paneles internos para administrador y vendedor.

### Página pública

La página pública permite a los clientes visualizar los productos disponibles, consultar categorías, ver imágenes de las prendas, seleccionar color y talla, agregar productos al carrito y registrar una solicitud de compra.

Se desarrollaron secciones como:

- Página de inicio.
- Catálogo general.
- Vista por categorías.
- Carrito de compras.
- Modal de compra.
- Visualización ampliada de imágenes.
- Enlaces de contacto como WhatsApp e Instagram.

El diseño público se orientó a una boutique femenina, usando una paleta suave con rosa, blanco, dorado y tonos cálidos. También se buscó que la experiencia fuera clara, visual y sencilla para los clientes.

### Panel administrador

El panel administrador se diseñó como un centro de gestión interna. Incluye los módulos principales:

- Inicio.
- Inventario.
- Ventas.
- Finanzas.
- Personas.
- Configuración.

Dentro del panel administrador se implementaron formularios para agregar productos, registrar ventas, consultar inventario, revisar facturas, administrar proveedores, trabajadores, clientes, gastos, inversiones y reportes.

El formulario de productos permite registrar información básica, variantes por color y talla, cantidad total automática, costo de compra, precio de venta, cálculo de IVA, ganancia estimada e imágenes múltiples.

### Panel vendedor

El panel vendedor fue desarrollado con un enfoque operativo. Permite registrar ventas, consultar inventario disponible, revisar historial y visualizar un resumen de ventas. Este rol no tiene acceso a funciones delicadas como eliminar productos, modificar usuarios o administrar configuraciones.

### Diseño responsive

El sistema fue adaptado para funcionar en diferentes tamaños de pantalla. Se utilizaron grids, formularios flexibles, scroll horizontal en tablas y ajustes para pantallas medianas y pequeñas.

## 3.5 Desarrollo del backend

El backend fue desarrollado en PHP. Su función principal es recibir las solicitudes del frontend, validar los datos, consultar o modificar la base de datos PostgreSQL y devolver respuestas en formato JSON.

Entre las principales funciones del backend se encuentran:

- Inicio de sesión.
- Validación de roles.
- Control de sesión única.
- Registro y consulta de productos.
- Registro de ventas.
- Confirmación y cancelación de pedidos.
- Gestión de devoluciones.
- Generación y consulta de facturas.
- Registro de clientes.
- Gestión de proveedores.
- Registro de compras de mercancía.
- Administración de trabajadores y pagos.
- Cálculo de reportes financieros.
- Consulta de movimientos de inventario.

La conexión con la base de datos se realiza mediante PDO, lo cual permite trabajar de forma segura con PostgreSQL y manejar errores de conexión o consultas.

El archivo `conexion.php` centraliza la conexión a la base de datos. Además, el proyecto permite usar configuración local mediante `config.local.php` o variables de entorno, lo que facilita futuras publicaciones sin exponer credenciales sensibles.

## 3.6 Base de datos

La base de datos se desarrolló en PostgreSQL. Se eligió este motor por su estabilidad, seguridad, soporte para relaciones complejas y cumplimiento de propiedades ACID, importantes para evitar inconsistencias en inventario, ventas y registros financieros.

Entre las principales tablas utilizadas se encuentran:

| Tabla | Función |
|---|---|
| producto | Almacena la información principal de los productos. |
| producto_talla | Registra tallas y cantidades generales por producto. |
| producto_color | Registra los colores disponibles de cada producto. |
| producto_color_talla | Relaciona colores con tallas y cantidades específicas. |
| producto_imagen | Permite guardar varias imágenes por producto. |
| categoria | Organiza los productos por categorías. |
| usuario_sistema | Almacena usuarios internos y roles. |
| cliente | Registra los datos de compradores. |
| venta | Guarda las ventas realizadas. |
| detalle_venta | Guarda los productos vendidos en cada venta. |
| factura | Registra las facturas emitidas. |
| devolucion | Registra devoluciones aprobadas. |
| proveedor | Almacena información de proveedores. |
| compra_mercancia | Registra compras realizadas para abastecer inventario. |
| trabajador | Guarda información de empleados o colaboradores. |
| pago_trabajador | Registra pagos, bonos, adelantos o deducciones. |
| movimiento_inventario | Permite controlar entradas, ventas y ajustes de stock. |

La base de datos permite relacionar productos con categorías, ventas con clientes, ventas con facturas, productos con variantes, proveedores con compras y trabajadores con pagos.

## 3.7 Integración de funcionalidades

Durante el desarrollo se integraron las principales funcionalidades del sistema:

### Login y seguridad

El sistema cuenta con inicio de sesión para usuarios internos. Se implementaron roles para administrador y vendedor. El administrador tiene acceso completo a la gestión del sistema, mientras que el vendedor solo accede a funciones operativas.

También se implementó control de sesión única, lo que evita que un mismo usuario tenga sesiones activas en varios dispositivos.

### Inventario

El inventario permite registrar productos con código, nombre, marca, categoría, costo, precio, imágenes, color, talla y cantidad. Además, el sistema calcula automáticamente la cantidad total a partir de las tallas registradas por color.

El inventario también permite buscar productos, consultar estado, visualizar bajo stock y controlar movimientos.

### Ventas

Las ventas pueden registrarse desde el panel administrador o desde el panel vendedor. Para realizar una venta se selecciona producto, color, talla, cliente, teléfono, correo, cantidad, medio de pago, canal de venta y tipo de entrega.

Al registrar la venta, el sistema descuenta automáticamente el stock de la combinación exacta de color y talla.

### Facturación

El sistema genera facturas para ventas pagadas. La factura incluye datos del cliente, producto, talla, color, cantidad, precio, IVA incluido, descuento, base gravable y total.

La factura puede abrirse en una vista imprimible y también permite preparar el envío por correo mediante enlace de correo.

### IVA y descuentos

Se implementó cálculo de IVA colombiano incluido en el precio final. El sistema calcula base gravable, IVA, subtotal, descuento y total de venta.

También se agregó una calculadora de precio en el formulario de productos, la cual permite estimar precio sugerido con IVA incluido, ganancia y margen.

### Finanzas

El módulo financiero permite registrar gastos, inversiones, compras de mercancía y consultar utilidad neta, margen de ganancia, ventas netas, costo de mercancía vendida y gastos del negocio.

### Personas

El sistema permite gestionar trabajadores, pagos, proveedores y clientes. Esto amplía el alcance del proyecto hacia una administración más completa del negocio.

## 3.8 Problemas encontrados y soluciones

| Problema encontrado | Solución aplicada |
|---|---|
| Desorden inicial en inventario y tablas extensas. | Se reorganizaron módulos por secciones y submenús. |
| Necesidad de manejar productos con diferentes tallas. | Se creó estructura para tallas y cantidades. |
| Necesidad de manejar colores con tallas específicas. | Se implementaron variantes por color y talla. |
| Riesgo de vender productos sin stock. | Se validó disponibilidad antes de registrar ventas. |
| Necesidad de controlar ventas online y tienda física. | Se agregó canal de venta y tipo de entrega. |
| Necesidad de facturación. | Se implementó módulo de facturas imprimibles. |
| Cálculo de IVA y descuentos. | Se agregó lógica de base gravable, IVA, descuento y total. |
| Panel administrador muy cargado. | Se reorganizó en módulos: Inicio, Inventario, Ventas, Finanzas, Personas y Configuración. |
| Manejo de proveedores y compras. | Se agregó módulo para proveedores y compras de mercancía. |
| Seguridad de usuarios. | Se implementaron roles, restricciones y sesión única. |

## 3.9 Pruebas del sistema

Durante el desarrollo se realizaron pruebas funcionales para verificar el comportamiento del sistema.

| Prueba realizada | Resultado |
|---|---|
| Inicio de sesión con administrador | Correcto. |
| Inicio de sesión con vendedor | Correcto. |
| Restricción de funciones según rol | Correcto. |
| Registro de productos | Correcto. |
| Registro de productos con colores, tallas e imágenes | Correcto. |
| Consulta de inventario | Correcto. |
| Registro de ventas internas | Correcto. |
| Descuento automático de stock | Correcto. |
| Registro de clientes desde venta | Correcto. |
| Generación de factura | Correcto. |
| Cálculo de IVA incluido | Correcto. |
| Aplicación de descuentos | Correcto. |
| Registro de devoluciones | Correcto. |
| Registro de gastos e inversiones | Correcto. |
| Consulta de reportes | Correcto. |
| Diseño responsive | Correcto en pantallas principales. |

Las pruebas permitieron comprobar que el sistema responde correctamente a los procesos principales de Isa Boutique y que la información se almacena en PostgreSQL.

## 3.10 Resultados finales

Como resultado de esta fase se obtuvo un sistema web funcional para la administración de Isa Boutique. El sistema permite controlar inventario, registrar ventas, consultar reportes, generar facturas, gestionar clientes, proveedores, trabajadores, compras y finanzas.

El administrador cuenta con una vista completa del negocio y puede tomar decisiones a partir de datos reales como ventas, ganancias, costos, gastos y productos con bajo stock. El vendedor cuenta con un panel más limitado, enfocado en registrar ventas y consultar inventario sin acceso a opciones delicadas.

La tienda pública permite que los clientes visualicen los productos disponibles, seleccionen tallas y colores, usen el carrito y registren compras desde la página web.

El proyecto logró pasar de una idea basada en procesos manuales a una plataforma web organizada, conectada a base de datos y preparada para futuras mejoras.

## 3.11 Conclusión de la fase

Durante la fase de desarrollo se logró implementar gran parte de las funcionalidades planteadas para el sistema Isa Boutique. Se construyeron las interfaces públicas e internas, se programó la lógica del backend, se diseñó la conexión con PostgreSQL y se integraron módulos administrativos, comerciales y financieros.

Esta fase permitió evidenciar la importancia de la programación en la solución de problemas reales de negocio. El sistema desarrollado ayuda a reducir errores manuales, mejorar el control del inventario, organizar las ventas, calcular ganancias y facilitar la gestión general de la boutique.

El estado final del sistema es funcional y cuenta con una base sólida para continuar con futuras fases de pruebas, despliegue, documentación de usuario y publicación en la web.

Como aprendizaje principal, el equipo comprendió la importancia de planear correctamente la estructura de datos, separar roles de usuario, validar la información antes de guardarla y mantener una interfaz clara para que el sistema sea útil tanto para el administrador como para el vendedor y los clientes.

