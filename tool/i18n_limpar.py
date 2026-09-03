"""Remove de `textos_pt.dart` as chaves que ninguém usa.

## Por que sobram chaves mortas

A migração adiciona a chave ao mapa **antes** de tentar trocar o literal no
código. Quando a troca falha — o literal no fonte não bate exatamente com o
texto capturado, tipicamente por escape (`\\n`) — a chave fica órfã.

Chave morta não quebra nada, mas custa: entra na contagem de cobertura de
tradução e alguém acaba traduzindo texto que nunca aparece na tela.

Uso:
    python tool/i18n_limpar.py            # lista
    python tool/i18n_limpar.py --aplicar  # remove
"""
import io
import os
import re
import sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RAIZ = os.path.join(BASE, 'lib')
I18N = os.path.join(RAIZ, 'core', 'i18n')

RE_PAR = re.compile(r"^(\s*'([^']+)':\s*.*?,)\s*$", re.M)


# `assistant_tours.dart` guarda ÂNCORAS do assistente de ajuda, não chaves de
# tradução — e o formato é idêntico (`nav.home`, `home.kpis`). Pior: `nav.agenda`
# e `nav.totem` são as DUAS coisas ao mesmo tempo.
#
# Sem esta exclusão, o `i18n_limpar` apagaria chaves de tradução por achar que
# são âncoras, e o `i18n_orfas` acusaria âncoras como tradução faltando. Foi
# assim que 14 chaves vivas do módulo de Evidências foram apagadas.
EXCLUIR = ('assistente/assistant_tours.dart',)


def ignorar(caminho):
    c = caminho.replace(chr(92), '/')
    return any(c.endswith(e) for e in EXCLUIR)


def usadas():
    """Chaves referenciadas em qualquer lugar de lib/ (fora dos mapas).

    Coleta **toda** string com cara de chave (`modulo.algumaCoisa`), não só a
    que vem logo depois de `.t(`. A versão anterior casava `\\.t2?\\('chave'` e
    por isso perdeu três formas legítimas:

        t.t(agente ? 'evid.a' : 'evid.b')     // condicional dentro da chamada
        t.plural(n, 'evid.um', 'evid.muitos') // chave em outra posição
        NavItem(chave: 'nav.home')            // resolvida na renderização

    O resultado foi apagar chaves vivas e quebrar a tela. Sobrar chave é
    inofensivo; faltar não é — então aqui se coleta demais de propósito.
    """
    achadas = set()
    # 'algo.algo' minúsculo com ponto: o formato das chaves deste projeto.
    re_chave = re.compile(r"'([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)'")
    for pasta, _, arquivos in os.walk(RAIZ):
        if os.path.abspath(pasta) == os.path.abspath(I18N):
            continue
        for nome in arquivos:
            if not nome.endswith('.dart'):
                continue
            caminho = os.path.join(pasta, nome)
            if ignorar(caminho):
                continue
            fonte = io.open(caminho, encoding='utf-8').read()
            achadas.update(re_chave.findall(fonte))
    return achadas


def main():
    aplicar = '--aplicar' in sys.argv
    vivas = usadas()

    for arq in ('textos_pt.dart', 'textos_en.dart', 'textos_es.dart'):
        caminho = os.path.join(I18N, arq)
        fonte = io.open(caminho, encoding='utf-8').read()
        mortas = []
        linhas = fonte.split('\n')
        manter = []
        i = 0
        while i < len(linhas):
            l = linhas[i]
            m = re.match(r"^\s*'([^']+)':", l)
            if m and m.group(1) not in vivas:
                mortas.append(m.group(1))
                # Uma entrada pode ocupar várias linhas — o formatador quebra
                # texto longo. Remover só a primeira deixava a continuação
                # órfã e o arquivo parava de compilar; foi o que aconteceu na
                # primeira versão. Consome até a linha que fecha a entrada.
                while i < len(linhas) and not linhas[i].rstrip().endswith(','):
                    i += 1
                i += 1
                continue
            manter.append(l)
            i += 1

        print(f'{arq}: {len(mortas)} morta(s)')
        for k in mortas[:10]:
            print(f'    {k}')
        if len(mortas) > 10:
            print(f'    … e mais {len(mortas) - 10}')

        if aplicar and mortas:
            io.open(caminho, 'w', encoding='utf-8', newline='').write(
                '\n'.join(manter))

    print('\nAPLICADO' if aplicar else '\nSIMULAÇÃO (use --aplicar)')


if __name__ == '__main__':
    main()
