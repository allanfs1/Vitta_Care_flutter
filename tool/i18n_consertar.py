"""Desfaz as trocas de i18n que o compilador recusou.

## Por que existe

Decidir por regex se uma string está dentro de um `const` não funciona: uma
expressão (`const WeekSelector(),`) parece uma declaração. A primeira versão
da migração tentou adivinhar e pulou 25 de 54 strings de um módulo — quase
todas sem necessidade.

O compilador sabe a resposta exata. Então o fluxo passou a ser:

    migrar tudo  →  flutter analyze  →  desfazer só o que ele recusou

Este script é a terceira etapa. Ele lê a saída do analisador, e nas linhas com
erro devolve `context.txt.t('chave')` ao literal original (buscado em
`textos_pt.dart`). A chave permanece no mapa — sobra inofensiva, e o
`i18n_scan` volta a listar a string na próxima passagem.

Uso:
    flutter analyze lib > erros.txt
    python tool/i18n_consertar.py erros.txt
"""
import os
import re
import sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RAIZ = os.path.join(BASE, 'lib')
ARQ_PT = os.path.join(RAIZ, 'core', 'i18n', 'textos_pt.dart')

# Erros que significam "aqui não dá para chamar função".
MOTIVOS = (
    'invalid_constant',
    'const_eval_method_invocation',
    'undefined_identifier',
    'non_constant_',
    'const_with_non_const',
    'const_initialized_with_non_constant_value',
    'not_enough_positional_arguments',
    'invalid_constant_value',
)

RE_ERRO = re.compile(
    r'^\s*error\s+-\s+.*?-\s+(.+?\.dart):(\d+):\d+\s+-\s+(\w+)\s*$')


def textos():
    """chave -> literal, como está em textos_pt.dart."""
    fonte = open(ARQ_PT, encoding='utf-8').read()
    fora = {}
    for m in re.finditer(r"^\s*'([^']+)':\s*'((?:[^'\\]|\\.)*)',\s*$", fonte, re.M):
        fora[m.group(1)] = m.group(2)
    return fora


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    saida = open(sys.argv[1], encoding='utf-8', errors='replace').read()
    mapa = textos()

    # arquivo -> conjunto de linhas com erro
    alvos = {}
    for linha in saida.split('\n'):
        m = RE_ERRO.match(linha)
        if not m:
            continue
        arquivo, num, motivo = m.group(1), int(m.group(2)), m.group(3)
        if not any(k in motivo for k in MOTIVOS):
            continue
        caminho = arquivo.replace('\\', '/')
        if '/lib/' in caminho:
            caminho = caminho.split('/lib/', 1)[1]
        elif caminho.startswith('lib/'):
            caminho = caminho[4:]
        alvos.setdefault(caminho, set()).add(num)

    if not alvos:
        print('nenhum erro de i18n a desfazer')
        return

    desfeitas = 0
    for rel, nums in sorted(alvos.items()):
        caminho = os.path.join(RAIZ, rel)
        if not os.path.exists(caminho):
            continue
        linhas = open(caminho, encoding='utf-8').read().split('\n')
        mudou = False
        # Uma linha pode ter várias trocas; e o erro às vezes aponta a linha
        # da abertura do widget, não a da string. Por isso a janela de ±2.
        # Janela ESTREITA (a própria linha e a de cima). Uma janela larga
        # derruba migrações boas que estejam perto de um `const` — foi o que
        # aconteceu na primeira tentativa: 125 reversões para 117 erros, muitas
        # desnecessárias. O erro às vezes aponta a abertura do widget uma linha
        # acima da string, e por isso a janela não é zero.
        #
        # Quem garante a convergência é o ciclo: desfaz o mínimo, reanalisa,
        # repete. Ver `--ciclo` em i18n_lote.py.
        for n in sorted(nums):
            for i in range(max(0, n - 2), min(len(linhas), n + 1)):
                def volta(m):
                    nonlocal mudou, desfeitas
                    lit = mapa.get(m.group(1))
                    if lit is None:
                        return m.group(0)
                    mudou = True
                    desfeitas += 1
                    return f"'{lit}'"

                nova = re.sub(r"context\.txt\.t\('([^']+)'\)", volta, linhas[i])
                linhas[i] = nova

        if mudou:
            open(caminho, 'w', encoding='utf-8', newline='').write(
                '\n'.join(linhas))
            print(f'  {rel}: {len(nums)} linha(s)')

    print(f'\n{desfeitas} troca(s) desfeita(s)')


if __name__ == '__main__':
    main()
