// Verificação do caminho DIRETO ao NCBI, com rede real.
//
// Roda com `dart run tool/verificar_evidencias.dart` — e não com
// `flutter test`, porque o `flutter_test` instala um HttpOverrides que
// bloqueia rede: um teste de integração ali passaria sem falar com ninguém.
import 'package:vitta_app/features/evidencias/filtros_busca.dart';
import 'package:vitta_app/features/evidencias/ia/pico.dart';
import 'package:vitta_app/features/evidencias/phi_guard.dart';
import 'package:vitta_app/features/evidencias/pubmed_direct.dart';
import 'package:vitta_app/features/evidencias/pubmed_models.dart';

var falhas = 0;
void checar(String nome, bool ok, [String detalhe = '']) {
  print('  ${ok ? "OK   " : "FALHA"} $nome${detalhe.isEmpty ? "" : " — $detalhe"}');
  if (!ok) falhas++;
}

Future<void> main() async {
  final pm = PubmedDirect(tool: 'vitta_app_verificacao');

  print('\n=== 1. Busca ===');
  final r = await pm.buscar(
    'dapagliflozin[tiab] AND heart failure[tiab] AND 2019:2020[pdat]',
    limite: 5,
  );
  print('  total=${r.total}  pmids=${r.pmids.join(",")}');
  checar('achou artigos', r.total > 0, '${r.total}');
  checar('trouxe PMIDs', r.pmids.isNotEmpty, '${r.pmids.length}');
  checar('queryTraduzida preenchida', r.queryTraduzida.isNotEmpty);
  checar('marcado como caminho direto', !r.viaProxy);

  print('\n=== 2. Metadados ===');
  final artigos = await pm.resumos(r.pmids.take(3).toList());
  final a = artigos.first;
  print('  ${a.pmid} | ${a.ano} | ${a.desenhoEstudo}');
  print('  ${a.titulo}');
  print('  ${a.autoresCurto} — ${a.periodico}');
  print('  DOI: ${a.doi}');
  checar('normalizou artigos', artigos.length == 3, '${artigos.length}');
  checar('título preenchido', a.titulo.length > 10);
  checar('autores extraídos', a.autores.isNotEmpty, '${a.autores.length}');
  checar('ano extraído', a.ano != null, '${a.ano}');
  checar('desenho do estudo', a.desenhoEstudo != null, '${a.desenhoEstudo}');
  checar('DOI extraído', artigos.any((x) => x.doi != null));

  print('\n=== 3. Resumo estruturado (XML) ===');
  final abs = await pm.abstracts(r.pmids.take(2).toList());
  final secoes = abs[r.pmids.first] ?? const <SecaoResumo>[];
  print('  ${abs.length} artigo(s); o primeiro tem ${secoes.length} secao(oes)');
  for (final s in secoes.take(3)) {
    final t = s.texto.length > 88 ? '${s.texto.substring(0, 88)}...' : s.texto;
    print('    [${s.temRotulo ? s.rotuloPt : "sem rotulo"}] $t');
  }
  checar('separou por PMID', abs.length >= 2, '${abs.length}');
  checar('trouxe conteudo', secoes.isNotEmpty);
  final textoResumo = secoes.map((s) => s.texto).join(' ');
  checar('resumo com corpo', textoResumo.length > 200, '${textoResumo.length} chars');
  // O bug que motivou trocar `text` por `xml`: a linha de citacao quebrava e a
  // continuacao do DOI vazava para dentro do resumo.
  checar('SEM vazamento de DOI/citacao', !textoResumo.contains('doi:'));

  print('\n=== 4. Correção ortográfica ===');
  final corr = await pm.corrigirTermo('hipertenssion');
  print('  hipertenssion -> $corr');
  checar('sugeriu correção', corr.isNotEmpty, corr);

  print('\n=== 5. Guarda de PHI (cliente) ===');
  for (final caso in ['CPF 123.456.789-01', 'maria@clinica.com', '(11) 98765-4321']) {
    checar('bloqueia "$caso"', detectarPhi(caso).isNotEmpty);
  }
  for (final ok in ['diabetes[tiab] AND 2022:2026[pdat]', 'metformin 850 mg', '31452104']) {
    checar('libera "$ok"', detectarPhi(ok).isEmpty);
  }
  var bloqueou = false;
  try {
    await pm.buscar('diabetes do paciente CPF 123.456.789-01');
  } on EvidenciaErro catch (e) {
    bloqueou = e.bloqueadoPorDadoPessoal;
  }
  checar('busca com PHI recusa antes da rede', bloqueou);

  print('\n=== 6. Cache de sessão ===');
  final t0 = DateTime.now();
  await pm.buscar('dapagliflozin[tiab] AND heart failure[tiab] AND 2019:2020[pdat]', limite: 5);
  final ms = DateTime.now().difference(t0).inMilliseconds;
  checar('segunda busca sai do cache', ms < 50, '${ms}ms');

  print('\n=== 7. Consulta que o PICO gera (modo IA) ===');
  // O passo que o agente monta em codigo. Se a sintaxe estiver errada o PubMed
  // devolve 0 — indistinguivel de "nao ha literatura". Por isso vale conferir
  // contra o servico real, e nao so contra fixture.
  const pico = Pico(
    populacao: 'elderly OR aged',
    intervencao: 'metformin',
    comparador: 'sulfonylurea',
    desfecho: 'cardiovascular events',
    desenhosPreferidos: ['Meta-Analysis', 'Randomized Controlled Trial'],
    janelaAnos: 10,
  );
  final ano = DateTime.now().year;
  final consulta = pico.paraEntrez(anoAtual: ano);
  print('  $consulta');
  final rPico = await pm.buscar(consulta, limite: 5);
  print('  -> ${rPico.total} resultado(s)');
  checar('consulta do PICO acha literatura', rPico.total > 0, '${rPico.total}');

  final ampla = pico.paraEntrez(incluirDesfecho: false, anoAtual: ano);
  final rAmpla = await pm.buscar(ampla, limite: 5);
  print('  sem desfecho -> ${rAmpla.total} resultado(s)');
  checar('tirar o desfecho amplia', rAmpla.total >= rPico.total,
      '${rPico.total} -> ${rAmpla.total}');

  print('\n=== 8. Filtros da tela ===');
  const filtros = FiltrosBusca(
    desenhos: {DesenhoFiltro.metanalise},
    anosRecentes: 5,
    somenteHumanos: true,
  );
  final comFiltro = filtros.aplicar('heart failure', anoAtual: ano);
  print('  $comFiltro');
  final rSem = await pm.buscar('heart failure', limite: 1);
  final rCom = await pm.buscar(comFiltro, limite: 1);
  print('  sem filtro: ${rSem.total}   com filtro: ${rCom.total}');
  checar('consulta com filtros e valida', rCom.total > 0, '${rCom.total}');
  checar('o filtro realmente restringe', rCom.total < rSem.total);


  pm.dispose();
  print('\n${"=" * 58}');
  print(falhas == 0
      ? 'TUDO OK — o caminho direto funciona sem o proxy publicado.'
      : '$falhas FALHA(S)');
}
