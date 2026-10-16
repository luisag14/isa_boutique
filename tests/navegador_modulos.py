"""Prueba las paginas reales en Chrome con API local simulada, sin Neon."""
import html
import json
import mimetypes
import re
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

RAIZ = Path(__file__).resolve().parent.parent
CHROME = Path('C:/Program Files/Google/Chrome/Application/chrome.exe')
PRODUCTO = dict(id_producto=3, codigo='P3', nombre='<img src=x onerror=alert(1)>',
                categoria='blusas', marca='Marca', precio=119, cantidad=2, estado='activo',
                imagenes=[dict(ruta='img/a.jpg'), dict(ruta='img/b.jpg', principal=True)],
                tallas=[dict(talla='M', cantidad=2)],
                colores=[dict(id_producto_color=31, color='Rojo', tallas=[dict(talla='M', cantidad=2)])])

CAPTURA = """
globalThis.fallosPrueba = [];
window.addEventListener('error', e => fallosPrueba.push(e.message));
window.addEventListener('unhandledrejection', e => fallosPrueba.push(String(e.reason)));
window.alert = () => {};
"""

VERIFICACION = """
const comprobar = (valor, mensaje) => { if (!valor) throw new Error(mensaje); };
const pausa = () => new Promise(resolve => setTimeout(resolve, 50));
async function esperar(condicion) {
    for (let intento=0; intento<60; intento++) {
        if (condicion()) return;
        await pausa();
    }
    throw new Error('Tiempo agotado esperando el DOM o las respuestas');
}
const porId = id => document.getElementById(id);
async function verificar() {
    if (location.pathname.endsWith('admin.html')) {
        comprobar(fallosPrueba.length===0, fallosPrueba.join('; '));
        window.usuarioActual = {rol:'admin'};
        await cargarInventarioBD();
        comprobar(porId('tablaInventario').querySelectorAll('tr').length===1, 'Inventario no carga desde el modulo');
        comprobar(porId('tablaInventario').textContent.includes('<img src=x'), 'Nombre de producto perdido');
        comprobar(!porId('tablaInventario').innerHTML.includes('<img src=x'), 'Nombre sin escapar');
        comprobar(porId('tablaInventario').querySelector('[data-inventario="editar"]'), 'Faltan acciones');
        await Promise.all([cargarMovimientosBD(), cargarTrabajadoresBD(), cargarPagosTrabajadoresBD()]);
        comprobar(porId('tablaMovimientos').textContent.includes('No hay movimientos'), 'Movimientos no carga');
    } else {
        await esperar(()=>document.querySelector('.boton-comprar'));
        comprobar(document.querySelector('.producto-card h3').textContent.includes('<img src=x'), 'Nombre de producto alterado');
        comprobar(!document.querySelector('.producto-card h3 img'), 'Inyeccion en nombre de producto');
        for (let intento=0; intento<3; intento++) {
            document.querySelector('.boton-comprar').click();
            porId('btnAgregarCarrito').click();
        }
        const guardado=JSON.parse(localStorage.getItem('isa_carrito'));
        comprobar(guardado.length===1 && guardado[0].cantidad===2, 'Se perdio el estado o el limite de stock');
        document.querySelector('.producto-img-click').click();
        comprobar(porId('modalImagenProducto').classList.contains('activo'), 'Carrusel no abre');
        const contadorAnterior=porId('contadorImagenProducto').textContent;
        porId('btnImagenSiguiente').click();
        comprobar(porId('contadorImagenProducto').textContent!==contadorAnterior && porId('contadorImagenProducto').textContent.endsWith(' / 2'), 'Carrusel no comparte el indice');
        porId('btnCerrarImagenProducto').click();
        porId('btnAbrirCarrito').click();
        for (const [id,valor] of Object.entries({carritoCliente:'Cliente',carritoTelefono:'3001234567',carritoCorreo:'cliente@example.test',carritoMedioPago:'efectivo',carritoEntrega:'recoger_tienda'})) porId(id).value=valor;
        porId('btnComprarCarrito').click();
        await esperar(()=>localStorage.getItem('isa_carrito')==='[]');
        comprobar(!porId('modalCarrito').classList.contains('activo'), 'Carrito no cierra tras confirmar');
    }
    await fetch('/prueba/cookie-inicio');
    const cookie=await (await fetch('/prueba/cookie-verificar')).json();
    comprobar(cookie.recibida, 'Chrome no reenvia cookie Secure por localhost');
    comprobar(!document.cookie.includes('isa_prueba='), 'Cookie HttpOnly accesible por JS');
    comprobar(fallosPrueba.length===0, fallosPrueba.join('; '));
}
verificar().then(()=>{ document.body.insertAdjacentHTML('beforeend','<pre id="resultado-prueba">PASS</pre>'); })
    .catch(error=>{ const resultado=document.createElement('pre'); resultado.id='resultado-prueba'; resultado.textContent='FAIL: '+error.message; document.body.appendChild(resultado); });
"""


class ServidorPrueba(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def responder(self, contenido, tipo='application/json', cabeceras=None):
        datos = contenido.encode('utf-8') if isinstance(contenido, str) else contenido
        self.send_response(200)
        self.send_header('Content-Type', tipo)
        self.send_header('Content-Length', str(len(datos)))
        for clave, valor in (cabeceras or {}).items():
            self.send_header(clave, valor)
        self.end_headers()
        self.wfile.write(datos)

    def do_GET(self):
        ruta = urlsplit(self.path).path
        if ruta == '/prueba/captura.js':
            self.responder(CAPTURA, 'text/javascript')
        elif ruta == '/prueba/verificar.js':
            self.responder(VERIFICACION, 'text/javascript')
        elif ruta == '/prueba/cookie-inicio':
            self.responder('{}', cabeceras={'Set-Cookie': 'isa_prueba=continuidad; Path=/; Secure; HttpOnly; SameSite=Lax'})
        elif ruta == '/prueba/cookie-verificar':
            self.responder(json.dumps({'recibida': 'isa_prueba=continuidad' in self.headers.get('Cookie', '')}))
        elif ruta.startswith('/php/'):
            if ruta.endswith('productos_listar.php'):
                respuesta = [PRODUCTO]
            elif ruta.endswith('categorias_listar.php'):
                respuesta = [dict(id_categoria=1, nombre='blusas', estado=True)]
            elif ruta.endswith('sesion_actual.php'):
                respuesta = dict(autenticado=False, csrf_token='fixture')
            elif ruta.endswith('captcha_login.php'):
                respuesta = dict(token='fixture', imagen='')
            else:
                respuesta = []
            self.responder(json.dumps(respuesta))
        else:
            archivo = (RAIZ / ruta.lstrip('/')).resolve()
            if (not ruta.startswith(('/html/', '/js/', '/css/', '/img/'))
                    or not archivo.is_relative_to(RAIZ) or not archivo.is_file()
                    or archivo.suffix.lower() not in ('.html', '.js', '.css', '.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg', '.ico')):
                self.responder(b'', 'image/png')
                return
            if archivo.suffix == '.html':
                pagina = archivo.read_text(encoding='utf-8')
                pagina = re.sub(r'<script\b[^>]*src="https://[^>]*></script>', '', pagina)
                pagina = pagina.replace('<head>', '<head><script src="/prueba/captura.js"></script>', 1)
                inicio, cierre, final = pagina.rpartition('</body>')
                pagina = inicio + '<script type="module" src="/prueba/verificar.js"></script>' + cierre + final
                self.responder(pagina, 'text/html; charset=utf-8')
            else:
                tipo = 'text/javascript' if archivo.suffix == '.js' else mimetypes.guess_type(archivo)[0] or 'application/octet-stream'
                self.responder(archivo.read_bytes(), tipo)

    def do_POST(self):
        datos = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        if urlsplit(self.path).path != '/php/pedido_carrito_registrar.php' or b'clave_pedido' not in datos:
            self.send_error(400)
            return
        self.responder(json.dumps(dict(error=False, mensaje='Pedido de prueba', id_venta=17, total=238)))


def main():
    servidor = ThreadingHTTPServer(('127.0.0.1', 0), ServidorPrueba)
    hilo = threading.Thread(target=servidor.serve_forever, daemon=True)
    hilo.start()
    try:
        for pagina in ['Producto.html', 'categoria.html?tipo=blusas', 'admin.html']:
            with tempfile.TemporaryDirectory(prefix='isa_chrome_modulos_') as perfil:
                comando = [str(CHROME), '--headless=new', '--disable-gpu', '--no-first-run',
                           '--disable-background-networking', '--no-default-browser-check',
                           '--user-data-dir='+perfil, '--virtual-time-budget=8000', '--dump-dom',
                           f'http://localhost:{servidor.server_port}/html/{pagina}']
                salida = subprocess.run(comando, capture_output=True, timeout=40,
                                        creationflags=subprocess.CREATE_NO_WINDOW)
                dom = salida.stdout.decode('utf-8', errors='replace')
                resultado = re.search(r'<pre id="resultado-prueba">(.*?)</pre>', dom, re.S)
                if salida.returncode or not resultado or resultado[1] != 'PASS':
                    detalle = html.unescape(resultado[1]) if resultado else 'Sin resultado de la pagina'
                    raise AssertionError(pagina+': '+detalle)
                print('PASS Chrome: '+pagina+' y cookie Secure/HttpOnly en localhost', flush=True)
    finally:
        servidor.shutdown()
        servidor.server_close()
        hilo.join(timeout=3)


if __name__ == '__main__':
    main()
