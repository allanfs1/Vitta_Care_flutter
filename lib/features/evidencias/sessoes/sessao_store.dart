import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sessao_models.dart';

/// Persistência das sessões de pesquisa.
///
/// ## Por que `SharedPreferences` e não Firestore
///
/// Uma sessão é **anotação de estudo de um profissional**, não dado da
/// clínica. Guardá-la no Firestore traria três problemas sem trazer benefício:
///
/// 1. **Custo por leitura.** Uma sessão carrega 20 artigos com resumo; a lista
///    de sessões viraria dezenas de leituras a cada abertura da tela.
/// 2. **Escopo errado.** `tb_*` é por clínica. A pesquisa do Dr. A não é da
///    clínica nem do Dr. B, e um médico atende em mais de uma clínica.
/// 3. **Dado do NIH replicado.** Resumo de artigo é conteúdo público de
///    terceiro; espelhá-lo em base própria é custo e superfície sem retorno.
///
/// A troca é honesta e está dita na tela: **as sessões ficam neste
/// dispositivo**. Sincronizar entre aparelhos é backlog — e aí o lugar certo é
/// uma coleção por usuário, não por clínica.
///
/// ## O histórico é separado das sessões
///
/// Histórico é rastro automático (toda busca entra, some sozinho); sessão é
/// ato deliberado de guardar. Misturar os dois faria o médico caçar o que
/// salvou no meio do que apenas passou.
class SessaoStore {
  SessaoStore(this._prefs);

  final SharedPreferences _prefs;

  static const _chaveSessoes = 'evidencias_sessoes_v1';
  static const _chaveHistorico = 'evidencias_historico_v1';

  /// Teto de sessões guardadas.
  ///
  /// `SharedPreferences` carrega tudo na memória no boot, e cada sessão pode
  /// ter ~50 KB de resumos. Sem teto, o app ficaria mais lento para iniciar a
  /// cada pesquisa salva — uma degradação lenta e difícil de atribuir depois.
  static const int maxSessoes = 50;
  static const int maxHistorico = 40;

  // ── Sessões ──────────────────────────────────────────────────────────

  List<SessaoPesquisa> listar() {
    final bruto = _prefs.getStringList(_chaveSessoes) ?? const [];
    final out = <SessaoPesquisa>[];
    for (final s in bruto) {
      try {
        final j = jsonDecode(s);
        if (j is Map<String, dynamic>) out.add(SessaoPesquisa.doJson(j));
      } catch (_) {
        // Entrada corrompida é ignorada, não fatal: perder UMA sessão é muito
        // melhor que a lista inteira deixar de abrir.
      }
    }
    out.sort((a, b) => (b.atualizadaEm ?? b.salvaEm)
        .compareTo(a.atualizadaEm ?? a.salvaEm));
    return out;
  }

  Future<void> salvar(SessaoPesquisa sessao) async {
    final atuais = listar()..removeWhere((s) => s.id == sessao.id);
    final novas = [sessao, ...atuais].take(maxSessoes).toList();
    await _gravar(novas);
  }

  Future<void> excluir(String id) async {
    await _gravar(listar()..removeWhere((s) => s.id == id));
  }

  Future<void> renomear(String id, String titulo) async {
    final lista = listar();
    final i = lista.indexWhere((s) => s.id == id);
    if (i < 0) return;
    lista[i] = lista[i].copyWith(titulo: titulo);
    await _gravar(lista);
  }

  SessaoPesquisa? porId(String id) {
    for (final s in listar()) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> limparTudo() async {
    await _prefs.remove(_chaveSessoes);
  }

  Future<void> _gravar(List<SessaoPesquisa> lista) async {
    await _prefs.setStringList(
      _chaveSessoes,
      lista.map((s) => jsonEncode(s.paraJson())).toList(),
    );
  }

  // ── Histórico ────────────────────────────────────────────────────────

  List<ItemHistorico> historico() {
    final bruto = _prefs.getStringList(_chaveHistorico) ?? const [];
    final out = <ItemHistorico>[];
    for (final s in bruto) {
      try {
        final j = jsonDecode(s);
        if (j is Map<String, dynamic>) out.add(ItemHistorico.doJson(j));
      } catch (_) {
        // idem: entrada ruim não derruba a lista.
      }
    }
    return out;
  }

  /// Registra uma busca. Repetir o mesmo termo **move para o topo** em vez de
  /// duplicar — o histórico serve para voltar a algo, não para contar quantas
  /// vezes se buscou.
  Future<List<ItemHistorico>> registrar(ItemHistorico item) async {
    final lista = [
      item,
      ...historico().where((h) => h.termo != item.termo),
    ].take(maxHistorico).toList();
    await _prefs.setStringList(
      _chaveHistorico,
      lista.map((h) => jsonEncode(h.paraJson())).toList(),
    );
    return lista;
  }

  Future<void> limparHistorico() async {
    await _prefs.remove(_chaveHistorico);
  }
}

/// Uma entrada do histórico de buscas.
class ItemHistorico {
  const ItemHistorico({
    required this.termo,
    required this.total,
    required this.quando,
    this.modo = 'busca',
  });

  final String termo;
  final int total;
  final DateTime quando;
  final String modo;

  Map<String, dynamic> paraJson() => {
        'termo': termo,
        'total': total,
        'quando': quando.toIso8601String(),
        'modo': modo,
      };

  factory ItemHistorico.doJson(Map<String, dynamic> j) => ItemHistorico(
        termo: '${j['termo'] ?? ''}',
        total: j['total'] is num ? (j['total'] as num).toInt() : 0,
        quando: DateTime.tryParse('${j['quando'] ?? ''}') ?? DateTime.now(),
        modo: '${j['modo'] ?? 'busca'}',
      );
}
