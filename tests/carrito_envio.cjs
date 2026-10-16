const assert=require('node:assert/strict');
const {webcrypto}=require('node:crypto');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
(async()=>{
const {crearCatalogo}=await import(pathToFileURL(path.join(__dirname,'../js/catalogo-comun.js')).href);
const original=[{id_producto:1,id_producto_color:11,talla:'M',cantidad:1,precio:119},{id_producto:2,id_producto_color:21,talla:'L',cantidad:1,precio:238}];
function pagina(almacen,enviar){
 const nodos=new Map();
 const valores={carritoCliente:'Cliente',carritoTelefono:'3001234567',carritoCorreo:'cliente@example.test',carritoMedioPago:'efectivo',carritoEntrega:'recoger_tienda'};
 const document={cookie:'isa_csrf_token=token-prueba',getElementById(id){if(!nodos.has(id))nodos.set(id,{value:valores[id]||'',textContent:'',disabled:false});return nodos.get(id);}};
 const avisos=[];
 const estado={carrito:JSON.parse(almacen.get('isa_carrito'))};
 const entorno={document,crypto:webcrypto,TextEncoder,FormData,
  localStorage:{getItem:clave=>almacen.get(clave)??null,setItem:(clave,valor)=>almacen.set(clave,valor),removeItem:clave=>almacen.delete(clave)},
  fetch:enviar,alert:mensaje=>avisos.push(mensaje),console:{error(){}}};
 const ctx=crearCatalogo({...entorno,fetch:(...args)=>entorno.fetch(...args)},estado,
  {renderizarCarrito(){},cerrarCarrito(){},cargarProductos:async()=>{}});
 return {ctx,estado,entorno,nodos,avisos,confirmar:()=>ctx.finalizarCompraCarrito()};
}
const exito={ok:true,json:async()=>({error:false,mensaje:'Pedido #17 registrado',id_venta:17,total:357,estado:'pendiente'})};
 const almacen=new Map([['isa_carrito',JSON.stringify(original)]]);
 let liberar,empezo;
 const inicio=new Promise(resolve=>{empezo=resolve;});
 let llamadas=0,primeraClave;
 const primera=pagina(almacen,async(url,opciones)=>{
  llamadas++;
  assert.equal(url,'../php/pedido_carrito_registrar.php');
  assert.equal(JSON.parse(opciones.body.get('items')).length,2);
  primeraClave=opciones.body.get('clave_pedido');
  empezo();await new Promise(resolve=>{liberar=resolve;});
  throw new Error('Respuesta perdida');
 });
 const envio=primera.confirmar();await inicio;
 await primera.confirmar();assert.equal(llamadas,1,'Doble clic genera dos solicitudes');
 assert.equal(primera.nodos.get('btnComprarCarrito').disabled,true);
 liberar();await envio;
 assert.equal(JSON.parse(almacen.get('isa_carrito')).length,2,'Fallo incierto vacia el carrito');
 assert.ok(almacen.has('isa_pedido_pendiente'),'No se conserva la clave tras perdida de respuesta');
 const segunda=pagina(almacen,async(url,opciones)=>{
  llamadas++;assert.equal(opciones.body.get('clave_pedido'),primeraClave,'Recarga cambia la clave del reintento');
  assert.equal(opciones.headers['X-CSRF-Token'],'token-prueba');
  return exito;
 });
 await segunda.confirmar();assert.equal(llamadas,2);
 assert.equal(almacen.get('isa_carrito'),'[]');assert.equal(almacen.has('isa_pedido_pendiente'),false);
 assert.equal(segunda.avisos[0],'Pedido #17 registrado');
 console.log('PASS una solicitud, doble clic, carrito conservado y misma clave tras recarga');

 almacen.set('isa_carrito',JSON.stringify(original));let claveRechazada;
 const rechazada=pagina(almacen,async(url,opciones)=>{
  claveRechazada=opciones.body.get('clave_pedido');
  return {ok:false,json:async()=>({error:true,mensaje:'Sin stock',conservar_clave:false})};
 });
 await rechazada.confirmar();assert.equal(almacen.has('isa_pedido_pendiente'),false);
 assert.equal(JSON.parse(almacen.get('isa_carrito')).length,2);
 const corregida=pagina(almacen,async(url,opciones)=>{assert.notEqual(opciones.body.get('clave_pedido'),claveRechazada);return exito;});
 await corregida.confirmar();
 console.log('PASS rechazo confirmado permite corregir el pedido sin perder el carrito');

 almacen.set('isa_carrito',JSON.stringify(original));
 const incierta=pagina(almacen,async()=>{throw new Error('Sin conexion');});
 await incierta.confirmar();let nuevosEnvios=0;
 incierta.estado.carrito[0].cantidad=2;
 incierta.ctx.guardarCarrito();
 incierta.entorno.fetch=async()=>{nuevosEnvios++;return exito;};
 await incierta.confirmar();assert.equal(nuevosEnvios,0,'Un pedido incierto se reemplaza silenciosamente');
 assert.ok(incierta.nodos.get('mensajeCarrito').textContent.includes('pedido anterior'));
 console.log('PASS resultado incierto impide cambiar silenciosamente el contenido del pedido');
})().catch(error=>{console.error(error);process.exitCode=1;});
