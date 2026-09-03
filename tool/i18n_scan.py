"""Levanta as strings de interface do app.

Não conta "toda string entre aspas" — isso mistura chave de mapa, campo do
Firestore, nome de rota e mensagem de debug com o que o usuário lê. Aqui só
entra string em posição de UI: `Text('...')`, `label:`, `title:`, `hintText:`
e afins.

Uso:
    python tool/i18n_scan.py            # resumo por módulo
    python tool/i18n_scan.py --lista    # cada string, com arquivo e linha
    python tool/i18n_scan.py --modulo X # só um módulo
"""
import os
import re
import sys
from collections import defaultdict

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib')

# Posições que quase sempre são texto lido pelo usuário.
PADROES = [
    # Text('...') e SelectableText('...')
    (r"\b(?:Selectable)?Text\(\s*'((?:[^'\\]|\\.)+)'", 'Text'),
    # Parâmetros nomeados de widget
    (r"\b(label|title|subtitle|hintText|helperText|labelText|tooltip|message|"
     r"semanticLabel|errorText|counterText|prefixText|suffixText|"
     r"confirmText|cancelText|actionLabel|placeholder)\s*:\s*'((?:[^'\\]|\\.)+)'",
     'param'),
]

# O que NÃO é texto de interface, mesmo aparecendo nessas posições.
IGNORAR = [
    re.compile(r'^\s*$'),
    re.compile(r'^[\d\s\W]*$'),          # só símbolos/números: '—', '·', '%'
    re.compile(r'^[a-z_]+$'),            # identificador solto: 'id', 'nome'
    re.compile(r'^[a-z_]+(\.[a-z_]+)+$'),  # chave já no formato i18n
    re.compile(r'^\$'),                  # começa com interpolação
    re.compile(r'^(http|/|assets/|package:)'),
    re.compile(r'^[A-Z_]{2,}$'),         # CONSTANTE
    re.compile(r'^\d'),                  # começa com dígito
]

# Interpolação embutida: precisa virar marcador {x}, não dá para migrar cru.
RE_INTERP = re.compile(r'\$\{?\w')


def interessa(s):
    if len(s) < 3:
        return False
    for re_ig in IGNORAR:
        if re_ig.match(s):
            return False
    # Precisa ter ao menos uma letra acentuada ou uma palavra de 3+ letras.
    return bool(re.search(r'[A-Za-zÀ-ú]{3}', s))


def modulo_de(caminho):
    rel = os.path.relpath(caminho, RAIZ).replace('\\', '/')
    partes = rel.split('/')
    if partes[0] == 'features' and len(partes) > 1:
        return partes[1]
    return partes[0]


def varrer():
    achados = defaultdict(list)
    for pasta, _, arquivos in os.walk(RAIZ):
        for nome in arquivos:
            if not nome.endswith('.dart'):
                continue
            caminho = os.path.join(pasta, nome)
            try:
                linhas = open(caminho, encoding='utf-8').read().split('\n')
            except Exception:
                continue
            for n, linha in enumerate(linhas, 1):
                if linha.lstrip().startswith('//'):
                    continue
                for padrao, tipo in PADROES:
                    for m in re.finditer(padrao, linha):
                        s = m.group(m.lastindex)
                        if not interessa(s):
                            continue
                        achados[modulo_de(caminho)].append({
                            'arquivo': os.path.relpath(caminho, RAIZ).replace('\\', '/'),
                            'linha': n,
                            'texto': s,
                            'tipo': tipo,
                            'interp': bool(RE_INTERP.search(s)),
                        })
    return achados


def main():
    achados = varrer()
    lista = '--lista' in sys.argv
    filtro = None
    if '--modulo' in sys.argv:
        filtro = sys.argv[sys.argv.index('--modulo') + 1]

    total = 0
    interp = 0
    print(f'{"módulo":<28} {"strings":>8} {"c/ interp":>10}')
    print('-' * 50)
    for mod in sorted(achados, key=lambda m: -len(achados[m])):
        if filtro and mod != filtro:
            continue
        itens = achados[mod]
        n_interp = sum(1 for i in itens if i['interp'])
        total += len(itens)
        interp += n_interp
        print(f'{mod:<28} {len(itens):>8} {n_interp:>10}')
        if lista:
            for i in itens:
                marca = ' [interp]' if i['interp'] else ''
                print(f'    {i["arquivo"]}:{i["linha"]}  "{i["texto"][:70]}"{marca}')
    print('-' * 50)
    print(f'{"TOTAL":<28} {total:>8} {interp:>10}')
    print()
    print(f'Únicas: {len({i["texto"] for m in achados.values() for i in m})}')


if __name__ == '__main__':
    main()
