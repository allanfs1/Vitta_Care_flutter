"""Migra as strings de interface de um módulo para o sistema de idiomas.

Uso:
    python tool/i18n_migrar.py navigation           # simula (não grava)
    python tool/i18n_migrar.py navigation --aplicar # grava

## O que faz

1. Acha as strings de UI do módulo (mesmo critério de `i18n_scan.py`).
2. Gera uma chave estável `modulo.slug` para cada texto.
3. Acrescenta as chaves novas em `textos_pt.dart`.
4. Troca o literal por `context.txt.t('chave')` no código.
5. Garante o import de `textos.dart`.

## O que NÃO faz, de propósito

- **String com interpolação** (`'Olá $nome'`) é pulada. Ela precisa virar
  `{marcador}` e a decisão de qual é o marcador é semântica, não mecânica.
- **Não tenta adivinhar `const`.** Decidir por regex se uma string está dentro
  de um `const` não funciona: uma expressão (`const WeekSelector(),`) parece
  uma declaração. A primeira versão tentou e pulou 25 de 54 strings de um
  módulo — quase todas sem necessidade.

  O compilador sabe a resposta exata, então o fluxo é:

      migrar tudo  →  flutter analyze  →  i18n_consertar.py

  `i18n_consertar.py` devolve ao literal só o que o analisador recusou.

- **String com interpolação** continua pulada aqui: virar `{marcador}` é
  decisão semântica, não mecânica.

Nunca migre vários módulos sem analisar entre eles.
"""
import os
import re
import sys
import unicodedata

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RAIZ = os.path.join(BASE, 'lib')
ARQ_PT = os.path.join(RAIZ, 'core', 'i18n', 'textos_pt.dart')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from i18n_scan import varrer, RE_INTERP  # noqa: E402

# Prefixo de chave por módulo — curto, para a chave não virar um parágrafo.
PREFIXO = {
    'navigation': 'nav',
    'configuracoes': 'cfg',
    'agendamentos': 'agenda',
    'equipe_medica': 'equipe',
    'admin_agentes': 'agentes',
    'tarefas_agendadas': 'tarefas',
    'notificacoes_centro': 'notif',
    'agenda_publica': 'agpub',
    'perfil_usuario': 'perfil',
    'perfil_clinica': 'clinica',
    'agent_dashboard': 'agdash',
    'health_score': 'health',
    'monte_carlo': 'montecarlo',
    'evidencias': 'evid',
}


def slug(texto, limite=42):
    s = unicodedata.normalize('NFKD', texto)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'[^A-Za-z0-9]+', ' ', s).strip().lower()
    palavras = [p for p in s.split() if p]
    saida = []
    for i, p in enumerate(palavras):
        saida.append(p if i == 0 else p.capitalize())
        if len(''.join(saida)) >= limite:
            break
    return ''.join(saida) or 'texto'


def chaves_existentes():
    """Devolve (fonte, chaves, texto->chave).

    O terceiro mapa evita o pior efeito de rodar a migração duas vezes no mesmo
    módulo: sem ele, um texto já migrado ganharia uma chave `nome2`, depois
    `nome3`, enchendo o mapa de sinônimos. Com ele, texto repetido reencontra a
    chave que já tem.
    """
    conteudo = open(ARQ_PT, encoding='utf-8').read()
    chaves = set()
    por_texto = {}
    for m in re.finditer(r"^\s*'([^']+)':\s*'((?:[^'\]|\.)*)',\s*$",
                         conteudo, re.M):
        chaves.add(m.group(1))
        por_texto.setdefault(m.group(2), m.group(1))
    return conteudo, chaves, por_texto


def dart_literal(texto):
    """Reescreve o texto como literal Dart de uma linha."""
    return texto.replace('\\', '\\\\').replace("'", r"\'")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    modulo = sys.argv[1]
    aplicar = '--aplicar' in sys.argv

    achados = varrer().get(modulo, [])
    if not achados:
        print(f'nada a migrar em "{modulo}"')
        return

    conteudo_pt, existentes, chave_por_texto = chaves_existentes()
    prefixo = PREFIXO.get(modulo, modulo.replace('_', ''))

    # texto -> chave (texto repetido reaproveita a mesma chave)
    chave_de = {}
    novas = []
    puladas = []

    for item in achados:
        texto = item['texto']
        if item['interp'] or RE_INTERP.search(texto):
            puladas.append(item)
            continue
        if texto in chave_de:
            continue
        # Texto que já tem chave reaproveita — nada de sinônimos.
        ja = chave_por_texto.get(dart_literal(texto)) or chave_por_texto.get(texto)
        if ja:
            chave_de[texto] = ja
            continue
        base = f'{prefixo}.{slug(texto)}'
        chave = base
        n = 2
        usadas = {c for _, c in novas}
        while chave in existentes or chave in usadas:
            chave = f'{base}{n}'
            n += 1
        chave_de[texto] = chave
        novas.append((texto, chave))

    # ── edição dos arquivos ──────────────────────────────────────────────
    por_arquivo = {}
    for item in achados:
        if item['interp']:
            continue
        por_arquivo.setdefault(item['arquivo'], []).append(item)

    trocas = 0
    for rel, itens in sorted(por_arquivo.items()):
        caminho = os.path.join(RAIZ, rel)
        original = open(caminho, encoding='utf-8').read()
        texto = original

        for item in itens:
            chave = chave_de.get(item['texto'])
            if not chave:
                continue
            lit = f"'{dart_literal(item['texto'])}'"
            if lit not in texto:
                continue
            texto = texto.replace(lit, f"context.txt.t('{chave}')")
            trocas += texto.count(f"t('{chave}')")

        if texto != original:
            # import do sistema de textos
            if 'core/i18n/textos.dart' not in texto:
                prof = rel.count('/')
                subir = '../' * prof
                imp = f"import '{subir}core/i18n/textos.dart';"
                m = re.search(r"^import 'package:flutter/material\.dart';$",
                              texto, re.M)
                if m:
                    texto = texto[:m.end()] + '\n\n' + imp + texto[m.end():]
                else:
                    texto = imp + '\n' + texto
            if aplicar:
                open(caminho, 'w', encoding='utf-8', newline='').write(texto)

    # ── textos_pt.dart ───────────────────────────────────────────────────
    if novas and aplicar:
        bloco = [f'\n  // ── {modulo} ' + '─' * max(0, 56 - len(modulo)) + '\n']
        for t, c in novas:
            bloco.append(f"  '{c}': '{dart_literal(t)}',\n")
        conteudo_pt = conteudo_pt.rstrip()
        assert conteudo_pt.endswith('};')
        conteudo_pt = conteudo_pt[:-2] + ''.join(bloco) + '};\n'
        open(ARQ_PT, 'w', encoding='utf-8', newline='').write(conteudo_pt)

    print(f'módulo      : {modulo}')
    print(f'chaves novas: {len(novas)}')
    print(f'arquivos    : {len(por_arquivo)}')
    print(f'puladas     : {len(puladas)} (interpolação — tratar à mão)')
    for p in puladas[:8]:
        print(f'    {p["arquivo"]}:{p["linha"]}  "{p["texto"][:60]}"')
    if len(puladas) > 8:
        print(f'    … e mais {len(puladas) - 8}')
    print()
    print('APLICADO' if aplicar else 'SIMULAÇÃO (use --aplicar para gravar)')


if __name__ == '__main__':
    main()
