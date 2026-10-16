const assert = require('node:assert/strict');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const nodos = new Map();
const eventosVentana = new Map();
const errores = [];
function nodo() {
    return {value:'1',textContent:'',innerHTML:'',style:{},dataset:{},selectedOptions:[{textContent:'Color'}],eventos:new Map(),resets:0,
        classList:{add(){},remove(){},toggle(){}},closest(){return null;},appendChild(){},
        addEventListener(tipo,accion){this.eventos.set(tipo,accion);},reset(){this.resets++;}};
}
global.document = {body:{dataset:{}},getElementById(id){if(!nodos.has(id))nodos.set(id,nodo());return nodos.get(id);},
    querySelector(){return null;},querySelectorAll(){return [];},createElement:nodo,addEventListener(){}};
global.window = {location:{href:'http://localhost/isa_boutique/html/vendedor.html',pathname:'/isa_boutique/html/vendedor.html',hash:'',origin:'http://localhost'},
    addEventListener(tipo,accion){eventosVentana.set(tipo,accion);}};
global.sessionStorage = {setItem(){}};
global.alert = () => {};
const consolaError = console.error;
console.error = (...datos) => errores.push(datos);
const paso = () => new Promise(resolve=>setImmediate(resolve));
const respuestaError = () => ({json:async()=>({error:true,mensaje:'Fallo controlado de prueba'})});
function verificarSoloErroresControlados() {
    for(const datos of errores) assert.ok(datos.some(dato=>String(dato).includes('Fallo controlado de prueba')),String(datos));
    errores.length=0;
}
(async()=>{
    // require carga el archivo local como modulo; no se extraen ni evaluan strings de codigo.
    const pendientes=[];
    global.fetch = async()=>new Promise(resolve=>pendientes.push(resolve));
    require('../js/vendedor.js');
    let completado=false;
    const inicio=eventosVentana.get('sesion-lista')().then(()=>{completado=true;});
    assert.equal(pendientes.length,3);
    pendientes[0](respuestaError());pendientes[1](respuestaError());await paso();
    assert.equal(completado,false,'El panel termina sin esperar sus tres cargas');
    pendientes[2](respuestaError());await inicio;verificarSoloErroresControlados();

    let liberarHistorial;
    global.fetch=async()=>new Promise(resolve=>{liberarHistorial=resolve;});
    const busqueda=document.getElementById('buscadorHistorialVendedor').eventos.get('input')();
    assert.ok(busqueda instanceof Promise,'La busqueda no devuelve su trabajo asincrono');
    liberarHistorial(respuestaError());await busqueda;

    let liberarFactura;
    global.fetch=async url=>{
        if(url.includes('venta_registrar.php'))return {json:async()=>({error:false,id_venta:17,total:119,factura:{numero_factura:'PRUEBA'}})};
        if(url.includes('factura_obtener.php'))return new Promise(resolve=>{liberarFactura=resolve;});
        return respuestaError();
    };
    const formulario=document.getElementById('formVenta');
    const venta=formulario.eventos.get('submit')({preventDefault(){}});await paso();
    assert.equal(formulario.resets,0,'La venta no espera a terminar la apertura de factura');
    liberarFactura(respuestaError());await venta;
    assert.equal(formulario.resets,1);verificarSoloErroresControlados();
    console.log('PASS vendedor: espera de cargas, busqueda y factura con errores controlados');

    let liberarCaptcha;
    const peticiones=[];
    global.fetch=async(url,opciones)=>{
        peticiones.push([String(url),opciones]);
        if(String(url).endsWith('/login.php'))return {json:async()=>({error:true,mensaje:'Credenciales incorrectas'})};
        return new Promise(resolve=>{liberarCaptcha=resolve;});
    };
    window.fetch=global.fetch;
    const auth=await import(pathToFileURL(path.join(__dirname,'../js/auth.js')).href);
    let loginTerminado=false;
    const mensaje=nodo();
    const login=auth.iniciarSesion(' prueba@example.test ',' Clave propia 123 ',nodo(),nodo(),mensaje).then(()=>{loginTerminado=true;});
    await paso();assert.equal(loginTerminado,false,'El login no espera al captcha nuevo');
    assert.equal(peticiones[0][1].body.get('contrasena'),' Clave propia 123 ','La interfaz altera la contrasena');
    liberarCaptcha({ok:true,json:async()=>({pregunta:'2 + 2',token:'token-de-prueba'})});await login;
    assert.equal(document.getElementById('captchaPregunta').textContent,'2 + 2');
    assert.equal(mensaje.textContent,'Credenciales incorrectas');
    assert.equal(errores.length,0);
    console.log('PASS acceso: espera del captcha y contrasena conservada');
})().finally(()=>{console.error=consolaError;}).catch(error=>{consolaError(error);process.exitCode=1;});
