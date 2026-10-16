# Pruebas finales Isa Boutique

Marca cada punto después de probarlo en el navegador.

## Acceso y seguridad

- [ ] Iniciar sesión como administrador.
- [ ] Iniciar sesión como vendedor dentro del horario permitido.
- [ ] Verificar que vendedor no vea funciones exclusivas del administrador.
- [ ] Verificar que vendedor no pueda cambiar contraseñas.
- [ ] Verificar sesión única: intentar entrar con el mismo usuario en otro navegador.
- [ ] Cerrar sesión y confirmar que permite entrar nuevamente.

## Catálogo público

- [ ] Abrir la raíz del sitio y confirmar la redirección a `html/index.html`.
- [ ] Entrar a `html/Producto.html`.
- [ ] Entrar a una categoría desde el menú.
- [ ] Ver productos activos desde PostgreSQL.
- [ ] Seleccionar una talla disponible.
- [ ] Ver talla agotada o inactiva cuando no tenga stock.
- [ ] Registrar un pedido desde la página pública.

## Inventario

- [ ] Crear producto con código, categoría, precio, costo, imagen y tallas.
- [ ] Confirmar que aparece en inventario.
- [ ] Confirmar que aparece en la tienda pública.
- [ ] Editar producto.
- [ ] Cambiar precio y revisar historial de cambios.
- [ ] Desactivar producto y confirmar que no se venda.

## Ventas y pedidos

- [ ] Registrar venta desde administrador.
- [ ] Registrar venta desde vendedor.
- [ ] Registrar pedido desde la página pública.
- [ ] Confirmar que el pedido público queda como pendiente.
- [ ] Confirmar pago desde historial.
- [ ] Cancelar pedido pendiente y verificar que devuelve stock.
- [ ] Registrar devolución de una venta pagada.
- [ ] Revisar canal de venta y tipo de entrega.

## Finanzas y reportes

- [ ] Revisar ventas de hoy.
- [ ] Revisar ventas del mes.
- [ ] Revisar productos más vendidos.
- [ ] Revisar productos con menor rotación.
- [ ] Revisar medios de pago.
- [ ] Revisar canales de venta.
- [ ] Registrar gasto.
- [ ] Registrar inversion.
- [ ] Registrar compra a proveedor.
- [ ] Registrar trabajador y pago.

## Base de datos

- [ ] Confirmar que productos se guardan en PostgreSQL.
- [ ] Confirmar que ventas se guardan en PostgreSQL.
- [ ] Confirmar que clientes se guardan en PostgreSQL.
- [ ] Confirmar que movimientos se guardan en PostgreSQL.
- [ ] Confirmar que `php/config.local.php` no se publica ni se sube a GitHub.

## Entrega

- [ ] Entregar solo las carpetas y archivos reales del proyecto.
- [ ] Explicar que la base final es PostgreSQL.
- [ ] Mencionar mejoras futuras: plan separe, QR, backups automáticos y promociones.
