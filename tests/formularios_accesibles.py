"""Comprueba referencias y nombres accesibles del HTML estatico, sin red ni navegador."""
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path


class Formulario(HTMLParser):
    def __init__(self, texto):
        super().__init__(convert_charrefs=True)
        self.nodos = []
        self.pila = []
        self.feed(texto)

    def handle_starttag(self, etiqueta, atributos):
        nodo = {"tag": etiqueta, "atributos": dict(atributos), "texto": "", "padres": list(self.pila)}
        self.nodos.append(nodo)
        if etiqueta not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.pila.append(nodo)

    def handle_endtag(self, etiqueta):
        for indice in range(len(self.pila) - 1, -1, -1):
            if self.pila[indice]["tag"] == etiqueta:
                self.pila = self.pila[:indice]
                break

    def handle_data(self, texto):
        for nodo in self.pila:
            nodo["texto"] += texto


def problemas_formulario(texto):
    nodos = Formulario(texto).nodos
    ids = Counter(n["atributos"]["id"] for n in nodos if n["atributos"].get("id"))
    por_id = {n["atributos"]["id"]: n for n in nodos if n["atributos"].get("id")}
    problemas = ["ID duplicado: " + identificador for identificador, cantidad in ids.items() if cantidad > 1]
    etiquetas = {}
    controles = [n for n in nodos if n["tag"] in {"input", "select", "textarea"} and n["atributos"].get("type", "").lower() not in {"hidden", "submit", "button", "reset"}]
    for etiqueta in (n for n in nodos if n["tag"] == "label"):
        destino = etiqueta["atributos"].get("for")
        vinculados = [c for c in controles if destino and c["atributos"].get("id") == destino]
        if not destino:
            vinculados = [c for c in controles if any(p is etiqueta for p in c["padres"])]
        if len(vinculados) != 1 or not etiqueta["texto"].strip():
            problemas.append("Etiqueta sin control unico o sin texto: " + (destino or etiqueta["texto"].strip()))
        elif destino:
            etiquetas[destino] = etiqueta
    for control in controles:
        atributos = control["atributos"]
        nombre = bool(atributos.get("aria-label", "").strip())
        referencias = atributos.get("aria-labelledby", "").split()
        if referencias:
            if any(r not in por_id or not por_id[r]["texto"].strip() for r in referencias):
                problemas.append("aria-labelledby roto: " + atributos.get("id", "sin ID"))
            else:
                nombre = True
        nombre = nombre or atributos.get("id") in etiquetas or any(p["tag"] == "label" and p["texto"].strip() for p in control["padres"])
        if not nombre:
            problemas.append("Control sin nombre accesible: " + atributos.get("id", "sin ID"))
    return problemas, len(controles)


if __name__ == "__main__":
    # La comprobacion debe detectar fallos, no dar por bueno cualquier HTML.
    for roto in ['<label for="otro">Nombre</label><input id="nombre">', '<input placeholder="Correo">', '<input aria-labelledby="inexistente">', '<input id="igual" aria-label="A"><input id="igual" aria-label="B">']:
        if not problemas_formulario(roto)[0]:
            raise AssertionError("El validador no detecta una referencia o nombre roto")
    raiz = Path(__file__).resolve().parent.parent
    for archivo in ["admin.html", "vendedor.html", "restablecer_password.html"]:
        errores, controles = problemas_formulario((raiz / "html" / archivo).read_text(encoding="utf-8-sig"))
        if errores:
            raise AssertionError(archivo + ": " + "; ".join(errores))
        print(f"PASS {archivo}: {controles} controles con nombre; etiquetas y referencias validas")
