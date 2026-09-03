"""Lista chaves referenciadas no código que NÃO existem no mapa de textos.

É o inverso de `i18n_limpar.py`. Uma chave assim não quebra o build — `Textos.t`
devolve a própria chave — mas aparece crua na tela, que é pior que um texto
errado: parece bug de dados.

Vale rodar depois de qualquer limpeza ou renomeação em massa.

Uso:
    python tool/i18n_orfas.py
"""
import io
import os
import re
import sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RAIZ = os.path.join(BASE, 'lib')
I18N = os.path.join(RAIZ, 'core', 'i18n')

RE_CHAVE = re.compile(r"'([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)'")
RE_PAR = re.compile(r"^\s*'([^']+)':", re.M)

# Prefixos que são chave de tradução. Sem isto entrariam nomes de pacote,
# caminhos de asset e campos do Firestore, que também têm ponto.
PREFIXOS = (
    'comum.', 'evid.', 'nav.', 'home.', 'auth.', 'pacientes.', 'relatorios.',
    'perfil.', 'clinica.', 'notif.', 'satisfacao.', 'health.', 'cfg.',
    'agenda.', 'equipe.', 'agentes.', 'tarefas.', 'agpub.', 'agdash.',
    'montecarlo.',
)


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


def main():
    no_mapa = set(RE_PAR.findall(
        io.open(os.path.join(I18N, 'textos_pt.dart'), encoding='utf-8').read()))

    orfas = {}
    for pasta, _, arquivos in os.walk(RAIZ):
        if os.path.abspath(pasta) == os.path.abspath(I18N):
            continue
        for nome in arquivos:
            if not nome.endswith('.dart'):
                continue
            caminho = os.path.join(pasta, nome)
            if ignorar(caminho):
                continue
            for n, linha in enumerate(
                    io.open(caminho, encoding='utf-8').read().split('\n'), 1):
                for chave in RE_CHAVE.findall(linha):
                    if not chave.startswith(PREFIXOS):
                        continue
                    if chave in no_mapa:
                        continue
                    orfas.setdefault(chave, []).append(
                        f'{os.path.relpath(caminho, RAIZ)}:{n}')

    for chave in sorted(orfas):
        print(f'{chave}\t{orfas[chave][0]}')
    print(f'{len(orfas)} chave(s) órfã(s)', file=sys.stderr)


if __name__ == '__main__':
    main()
