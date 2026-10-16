const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const raiz = path.resolve(__dirname, '..');
(async()=>{
const {crearCatalogo} = await import(pathToFileURL(path.join(raiz,'js/catalogo-comun.js')).href);
const {iniciarProductos} = await import(pathToFileURL(path.join(raiz,'js/catalogo-productos.js')).href);
const {iniciarCategoria} = await import(pathToFileURL(path.join(raiz,'js/catalogo-categoria.js')).href);
const entorno = {localStorage:{getItem:()=>'{invalido'}};
const contexto = crearCatalogo(entorno, {});
assert.equal(contexto.cargarCarritoCatalogo().length, 0);
for (const valor of ['{}','null','false','[null,1,"texto"]','{roto']) {
    assert.equal(contexto.leerImagenesProducto(valor).length, 0);
    assert.equal(contexto.leerTallas(valor).length, 0);
    assert.equal(contexto.leerColores(valor).length, 0);
}
const producto={nombre:'Prenda " onerror="alert(1)',imagenes:[{ruta:'img/a.jpg" data-prueba="x'},{ruta:'img/b.jpg'}]};
const miniaturas=contexto.miniaturasProducto(producto);
assert.ok(miniaturas.includes('&quot;'));
assert.ok(!miniaturas.includes('data-prueba="x'));
assert.ok(!miniaturas.includes('onerror="alert'));
assert.equal(contexto.rutaImagenProducto('javascript:alert(1)'),'../img/logo.png.png');
assert.equal(contexto.rutaImagenProducto('img/prenda.jpg'),'../img/prenda.jpg');
assert.ok(!contexto.textoTallas([{talla:'<img src=x onerror=alert(1)>',cantidad:9}]).includes('<img'));
assert.equal(contexto.imagenPrincipalProducto({imagenes:'[{"ruta":"a.jpg"},{"ruta":"b.jpg","principal":true}]'}),'b.jpg');
entorno.localStorage.getItem=()=>JSON.stringify([{id_producto:1,cantidad:2,precio:100,nombre:'Prenda'}]);
assert.equal(contexto.cargarCarritoCatalogo().length,1);
entorno.localStorage.getItem=()=>JSON.stringify([{id_producto:1,cantidad:-1,precio:100}]);
assert.equal(contexto.cargarCarritoCatalogo().length,0);
console.log('PASS lectores JSON, carrito e interpolacion segura de imagenes');

// Cargar ambos scripts reales en un DOM simulado para verificar dependencias y arranque.
function elemento(etiqueta) {
    const eventos={};
    return {value:'',textContent:'',innerHTML:'',style:{},dataset:{},options:[],children:[],
        tagName:etiqueta,classList:{add(){},remove(){},toggle(){}},addEventListener(tipo,accion){eventos[tipo]=accion;},setAttribute(){},
        click(){if(eventos.click)eventos.click({target:this});},
        appendChild(hijo){this.children.push(hijo);this.options.push(hijo);},querySelector(selector){return this.children.find(hijo=>hijo.tagName==='button'&&!hijo.disabled)||elemento();},
        querySelectorAll(){return[];},getBoundingClientRect(){return{top:0};},scrollIntoView(){}};
}
async function cargarPagina(archivo) {
    assert.ok(['Producto.html','categoria.html'].includes(archivo),'Solo se cargan las dos paginas locales previstas');
    const html=fs.readFileSync(path.join(raiz,'html',archivo),'utf8');
    assert.ok(html.includes('type="module" src="../js/'+(archivo==='Producto.html'?'catalogo-productos':'catalogo-categoria')+'-inicio.js?'));
    assert.ok(!/function formatoPrecio\(/.test(html),'La pagina conserva una copia del helper');
    const nodos=new Map();
    const document={getElementById(id){if(!nodos.has(id))nodos.set(id,elemento());return nodos.get(id);},
        querySelector(){return elemento();},querySelectorAll(){return[];},createElement:elemento,
        addEventListener(){},body:elemento()};
    const errores=[];
    const almacen=new Map([['isa_carrito','{carrito-roto']]);
    const window={location:{href:'http://localhost/isa_boutique/html/'+archivo,search:'?tipo=blusas',pathname:'/isa_boutique/html/'+archivo},
        addEventListener(){},scrollTo(){},innerWidth:1024};
    const entornoPagina={document,window,URL,URLSearchParams,
        localStorage:{getItem:clave=>almacen.get(clave)??null,setItem:(clave,valor)=>almacen.set(clave,valor)},sessionStorage:{getItem:()=>null},
        fetch:async()=>({ok:true,json:async()=>[]}),console:{error(...args){errores.push(args);},log(){}},
        alert(){},setTimeout(){},clearTimeout(){}};
    // La referencia estable permite simular respuestas sin cambiar el modulo cargado.
    const ctx=(archivo==='Producto.html'?iniciarProductos:iniciarCategoria)({...entornoPagina,fetch:(...args)=>entornoPagina.fetch(...args)});
    await new Promise(resolve=>setImmediate(resolve));
    assert.equal(errores.length,0,'Error de arranque en '+archivo+': '+JSON.stringify(errores));
    assert.equal(ctx.cargarCarritoCatalogo().length,0);
    assert.equal(typeof ctx.llenarColoresCompra,'function');
    assert.equal(typeof ctx.cambiarImagenCarrusel,'function');
    const productoPrueba={id_producto:1,nombre:'<img src=x onerror=alert(1)>',codigo:'P" onclick="x',marca:'<b>Marca</b>',
        categoria:'<img src=x onerror=alert(1)>',precio:100,cantidad:2,estado:'activo',imagenes:[],colores:[],tallas:[]};
    if (archivo==='Producto.html') {
        document.getElementById('filtroPrecioMaximo').disabled=true;
        entornoPagina.fetch=async()=>({json:async()=>[productoPrueba]});
        await ctx.cargarProductos();
    } else {
        window.location.search='?tipo='+encodeURIComponent(productoPrueba.categoria);
        entornoPagina.fetch=async()=>({json:async()=>[productoPrueba]});
        await ctx.cargarCategoria();
    }
    const tarjeta=document.getElementById(archivo==='Producto.html'?'contenedor-productos':'contenedor').children[0];
    assert.ok(tarjeta && tarjeta.innerHTML.includes('&lt;img'),'Falta escape en ficha de '+archivo);
    assert.ok(!tarjeta.innerHTML.includes('<img src=x onerror='),'HTML de producto sin escapar');
    const comprable={id_producto:3,codigo:'P3',nombre:'Prenda',precio:119,cantidad:2,estado:'activo',
        tallas:[{talla:'M',cantidad:2}],colores:[{id_producto_color:31,color:'Rojo',tallas:[{talla:'M',cantidad:2}]}]};
    for(let intento=0;intento<3;intento++) {
        ctx.abrirModalCompra(comprable);
        ctx.agregarProductoAlCarrito();
    }
    const guardado=JSON.parse(almacen.get('isa_carrito'));
    assert.equal(guardado.length,1);
    assert.equal(guardado[0].cantidad,2,'El carrito supera el stock por talla');
    assert.equal(Number(guardado[0].id_producto_color),31);
    console.log('PASS arranque con dependencia compartida y carrito corrupto: '+archivo);
}
await cargarPagina('Producto.html');await cargarPagina('categoria.html');
})().catch(error=>{console.error(error);process.exitCode=1;});
