const assert = require('node:assert/strict');
const fs = require('node:fs');
const {crearTablasAdmin} = require('../js/admin-tablas.js');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const html = fs.readFileSync(path.join(__dirname,'../html/admin.html'),'utf8');
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)].filter(m=>!/\bsrc\s*=/.test(m[1])).map(m=>m[2]);
// Comprobar sintaxis sin crear funciones ejecutables con el texto del archivo.
for (const fuente of scripts) {
    const revision = spawnSync(process.execPath,['--check'],{input:fuente,encoding:'utf8',timeout:5000,windowsHide:true});
    assert.ifError(revision.error);
    assert.equal(revision.status,0,revision.stderr);
}
function nodo() {
    return {value:'',innerHTML:'',textContent:'',children:[],eventos:{},botones:new Map(),
        appendChild(hijo){this.children.push(hijo);},
        addEventListener(evento,fn){this.eventos[evento]=fn;},
        querySelector(selector){
            const atributo=selector.slice(1,-1);
            if (!this.innerHTML.includes(atributo)) return null;
            if(!this.botones.has(selector))this.botones.set(selector,nodo());
            return this.botones.get(selector);
        }
    };
}
const ataque=`O'Hara " ><img src=x onerror=globalThis.atacado=true> & cierre`;
const productos=[1,2].map(id=>({id_producto:id,nombre:ataque,codigo:ataque,marca:ataque,categoria:ataque,
    estado:'activo',cantidad:3,precio:119,costo_unitario:60,imagenes:[{ruta:'img/foto.jpg" onerror="ataque()'}],
    tallas:[{talla:ataque,cantidad:3}],colores:[{color:ataque,tallas:[{talla:ataque,cantidad:3,codigo_barras:ataque}]}]}));
const elementos=new Map();const llamadas=[];let respuesta=productos;
const document={getElementById(id){if(!elementos.has(id))elementos.set(id,nodo());return elementos.get(id);},createElement(){return nodo();}};
const contexto=crearTablasAdmin({document,console,fetch:async()=>({json:async()=>respuesta})}, {
    prepararPaginaAdmin:datos=>datos,ocultarPaginacionAdmin(){},usuarioEsAdmin:()=>true,
    editarProductoBD:id=>llamadas.push(['editar',id]),cambiarEstadoProductoBD:(...datos)=>llamadas.push(['estado',...datos]),
    eliminarProductoBD:(...datos)=>llamadas.push(['eliminar',...datos]),abrirCodigosBarrasVariantesProducto:(...datos)=>llamadas.push(['variantes',...datos])});
function verificarHtml(texto){
    assert.ok(!texto.includes('<img src=x'),texto);
    assert.ok(!texto.includes(' onerror="ataque()'),texto);
    assert.ok(texto.includes('&lt;img'));
}
(async()=>{
    await contexto.cargarInventarioBD();
    const filas=elementos.get('tablaInventario').children;
    assert.equal(filas.length,2);
    for(const fila of filas){
        verificarHtml(fila.innerHTML);
        assert.ok(!/\bonclick\s*=/.test(fila.innerHTML));
        for(const accion of ['editar','estado','eliminar','variantes']) fila.querySelector(`[data-inventario="${accion}"]`).eventos.click();
    }
    assert.equal(llamadas[0][1],1);assert.equal(llamadas[4][1],2);
    assert.equal(llamadas[2][2],ataque);
    assert.equal(llamadas[3][2],ataque);
    assert.equal(llamadas[3][1][0].codigo,ataque);
    assert.equal(contexto.rutaImagenAdmin({imagen:'javascript:alert(1)'}),'../img/logo.png.png');
    assert.equal(globalThis.atacado,undefined);
    console.log('PASS inventario: texto escapado y acciones conservadas para nombres y variantes con comillas/HTML');
    for(const [nombre,tabla,datos] of [
        ['cargarMovimientosBD','tablaMovimientos',{fecha:'2026-10-15',tipo:ataque,codigo:ataque,producto:ataque,marca:ataque,detalle:ataque,cantidad:2}],
        ['cargarTrabajadoresBD','tablaTrabajadores',{nombre:ataque,documento:ataque,telefono:ataque,cargo:ataque,salario_base:2000000,fecha_ingreso:'2026-10-15',estado:true}],
        ['cargarPagosTrabajadoresBD','tablaPagosTrabajadores',{fecha:'2026-10-15',trabajador:ataque,cargo:ataque,tipo_pago:ataque,usuario:ataque,detalle:ataque,valor:2000000}]
    ]) {
        respuesta=[datos];await contexto[nombre]();verificarHtml(elementos.get(tabla).innerHTML);
    }
    respuesta={error:true,mensaje:ataque};await contexto.cargarInventarioBD();verificarHtml(elementos.get('tablaInventario').innerHTML);
    console.log('PASS movimientos, trabajadores, pagos y mensajes de error como texto');
})().catch(error=>{console.error(error);process.exitCode=1;});
