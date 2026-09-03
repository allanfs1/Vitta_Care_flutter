"""Lista as chaves que existem em pt e faltam em en/es.

Uso:
    python tool/i18n_faltando.py en
    python tool/i18n_faltando.py es
"""
import io
import os
import re
import sys

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib',
                    'core', 'i18n')

RE_PAR = re.compile(r"^\s*'([^']+)':\s*'((?:[^'\\]|\\.)*)',\s*$", re.M)


def ler(nome):
    fonte = io.open(os.path.join(RAIZ, nome), encoding='utf-8').read()
    return dict(RE_PAR.findall(fonte))


def main():
    idioma = sys.argv[1] if len(sys.argv) > 1 else 'en'
    saida = sys.argv[2] if len(sys.argv) > 2 else None

    pt = ler('textos_pt.dart')
    outro = ler(f'textos_{idioma}.dart')
    faltando = [(k, v) for k, v in pt.items() if k not in outro]

    linhas = [f'{k}\t{v}' for k, v in faltando]
    if saida:
        # Grava em UTF-8 explícito: o stdout do Windows é cp1252 e engasga em
        # '≤', '—' e afins, que aparecem nas strings da interface.
        io.open(saida, 'w', encoding='utf-8', newline='').write(
            '\n'.join(linhas) + '\n')
    else:
        for l in linhas:
            print(l)
    print(f'{len(faltando)} de {len(pt)} faltando em {idioma}',
          file=sys.stderr)


if __name__ == '__main__':
    main()
