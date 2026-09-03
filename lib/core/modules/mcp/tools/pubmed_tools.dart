import '../../../../features/evidencias/pubmed_models.dart';
import '../../../../features/evidencias/pubmed_service.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP de evidência científica (PubMed/NCBI) — `.specify/MCP.md`
/// §6.20 e `.specify/EVIDENCIAS.md` §7.
///
/// Dão ao agente do `/ia` a capacidade de responder pergunta clínica com fonte
/// verificável, em vez de com o que o modelo "lembra" do treino.
///
/// **Diferença importante das demais tools do catálogo.** Todas as outras
/// operam sobre dados da clínica e são escopadas por `clinicaId`. Estas
/// consultam **literatura pública**: o PMID 31452104 é o mesmo artigo para
/// qualquer clínica. O isolamento multi-tenant continua valendo — a guarda de
/// `McpServer.callTool` recusa sem clínica resolvida, como para qualquer
/// tool — mas o *resultado* não é dado de tenant. Ver EVIDENCIAS.md §4.
///
/// **Nada de dado de paciente sai daqui.** O `pubmedProxy` bloqueia CPF,
/// telefone, e-mail e sequências longas de dígitos antes de qualquer chamada
/// de rede; a descrição de cada tool instrui o modelo no mesmo sentido, mas a
/// garantia é a do servidor, não a do prompt.
///
/// [service] é opcional de propósito: o `pubmedProxy` exige usuário
/// autenticado, então em modo demonstração e em teste não há serviço. Sem ele
/// as tools continuam **registradas** — para o modelo saber que a capacidade
/// existe — mas devolvem um erro explicativo em vez de falhar de forma opaca.
List<McpTool> buildPubmedTools(McpContext ctx, {PubmedService? service}) {
  PubmedService? svc() => service;

  return [
    _buscar(ctx, svc),
    _artigo(ctx, svc),
    _relacionados(ctx, svc),
    _corrigirTermo(ctx, svc),
  ];
}

const String _semServico =
    'Módulo de evidências indisponível nesta sessão (sem serviço PubMed '
    'configurado). Responda sem citar literatura e diga que a busca não pôde '
    'ser feita.';

McpTool _buscar(McpContext ctx, PubmedService? Function() svc) {
  return McpTool(
    name: 'pubmed_buscar',
    description:
        'Pesquisa literatura científica no PubMed e devolve artigos com PMID, '
        'título, autores, periódico, ano e tipo de estudo. '
        'USE SEMPRE que a pergunta for clínica, de tratamento, diagnóstico, '
        'prognóstico ou de evidência — e cite os PMIDs devolvidos na resposta. '
        'NUNCA invente PMID: só cite os que esta ferramenta retornar. '
        'NUNCA inclua nome, CPF, telefone ou qualquer dado de paciente no termo — '
        'use apenas os elementos clínicos (condição, intervenção, desfecho). '
        'O termo aceita sintaxe Entrez: campos como [tiab] (título/resumo), '
        '[mesh], [ptyp] (tipo de publicação) e janela de datas 2022:2026[pdat]; '
        'operadores AND, OR e NOT. Prefira termos em inglês — é o idioma da '
        'indexação, e buscar em português reduz drasticamente o resultado.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'termo': {
          'type': 'string',
          'description':
              'Consulta Entrez. Ex.: "SGLT2 inhibitor[tiab] AND heart failure[tiab] '
                  'AND 2022:2026[pdat]".',
        },
        'limite': {
          'type': 'integer',
          'description': 'Quantos artigos trazer (1–50). Padrão 10.',
          'default': 10,
        },
        'ordem': {
          'type': 'string',
          'enum': ['relevancia', 'data'],
          'description':
              'relevancia = Best Match do PubMed (padrão). data = mais recentes '
                  'primeiro; use quando a pergunta for sobre novidades.',
          'default': 'relevancia',
        },
      },
      'required': ['termo'],
    },
    handler: (args) async {
      final servico = svc();
      if (servico == null) return err(_semServico);

      final termo = args.str('termo') ?? '';
      if (termo.trim().isEmpty) return err('Informe o termo de busca.');

      final limite = (args.intArg('limite') ?? 10).clamp(1, 50);
      final ordem = (args.str('ordem') ?? 'relevancia') == 'data'
          ? OrdemBusca.data
          : OrdemBusca.relevancia;

      try {
        final r = await servico.buscarComMetadados(
          termo,
          limite: limite,
          ordem: ordem,
        );
        if (r.vazio) {
          return ok({
            'total': 0,
            'artigos': const [],
            'queryTraduzida': r.queryTraduzida,
            'orientacao':
                'Nenhum artigo encontrado. Diga isso explicitamente ao usuário '
                    'em vez de responder de memória. Se fizer sentido, sugira '
                    'termos mais amplos ou remova filtros de data.',
          });
        }
        return ok({
          'total': r.total,
          'retornados': r.artigos.length,
          // A consulta como o PubMed a interpretou. Vale mostrar ao médico:
          // explica por que veio o que veio.
          'queryEnviada': r.queryEnviada,
          'queryTraduzida': r.queryTraduzida,
          'artigos': r.artigos.map((x) => x.paraJson()).toList(),
          'orientacao':
              'Cite os PMIDs acima ao afirmar qualquer coisa baseada nestes '
                  'artigos. Não afirme mais do que o título/tipo de estudo '
                  'sustenta — para conclusões, leia o resumo com pubmed_artigo.',
        });
      } on EvidenciaErro catch (e) {
        return err(_mensagem(e));
      } catch (e) {
        return err('pubmed_buscar: $e');
      }
    },
  );
}

McpTool _artigo(McpContext ctx, PubmedService? Function() svc) {
  return McpTool(
    name: 'pubmed_artigo',
    description:
        'Recupera o RESUMO (abstract) completo de um ou mais artigos pelo PMID. '
        'Use depois de pubmed_buscar, quando precisar do achado real do estudo '
        '— o título sozinho não sustenta conclusão clínica. '
        'Se um artigo não tiver resumo, diga isso em vez de inferir o conteúdo.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'pmids': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'PMIDs (máx. 10 por chamada).',
        },
      },
      'required': ['pmids'],
    },
    handler: (args) async {
      final servico = svc();
      if (servico == null) return err(_semServico);

      final pmids = args.strList('pmids').take(10).toList();
      if (pmids.isEmpty) return err('Informe ao menos um PMID.');

      try {
        final resumos = await servico.resumos(pmids);
        final secoes = await servico.abstracts(pmids);
        final artigos = resumos
            .map((art) => art.comSecoes(secoes[art.pmid]))
            .map((art) => art.paraJson())
            .toList();

        final semResumo = resumos
            .where((art) => (secoes[art.pmid] ?? const []).isEmpty)
            .map((art) => art.pmid)
            .toList();

        return ok({
          'artigos': artigos,
          if (semResumo.isNotEmpty) 'semResumo': semResumo,
          'orientacao':
              'Baseie as afirmações no texto do resumo. O resumo não é o texto '
                  'completo: não afirme detalhe metodológico que ele não traz.',
        });
      } on EvidenciaErro catch (e) {
        return err(_mensagem(e));
      } catch (e) {
        return err('pubmed_artigo: $e');
      }
    },
  );
}

McpTool _relacionados(McpContext ctx, PubmedService? Function() svc) {
  return McpTool(
    name: 'pubmed_relacionados',
    description:
        'Lista artigos relacionados a um PMID (ELink do NCBI). Útil para ampliar '
        'a busca quando o primeiro resultado é bom mas insuficiente. '
        'Devolve só os PMIDs — use pubmed_artigo para os detalhes.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'pmid': {'type': 'string', 'description': 'PMID de origem.'},
        'limite': {'type': 'integer', 'default': 10},
      },
      'required': ['pmid'],
    },
    handler: (args) async {
      final servico = svc();
      if (servico == null) return err(_semServico);

      final pmid = args.str('pmid') ?? '';
      if (pmid.trim().isEmpty) return err('Informe o PMID de origem.');

      try {
        final lista = await servico.relacionados(
          pmid,
          limite: (args.intArg('limite') ?? 10).clamp(1, 25),
        );
        if (lista.isEmpty) {
          // Verificado em 2026-09-01: o NCBI não vem computando
          // `pubmed_pubmed`. Lista vazia é o normal hoje, não falha — e sem
          // esta orientação o modelo tende a repetir a chamada.
          return ok({
            'origem': pmid,
            'relacionados': const [],
            'orientacao':
                'O NCBI não retornou artigos relacionados para este PMID — é o '
                    'comportamento atual do serviço, não um erro. Não repita '
                    'esta chamada: para ampliar, use pubmed_buscar com os '
                    'termos centrais do artigo.',
          });
        }
        return ok({'origem': pmid, 'relacionados': lista});
      } on EvidenciaErro catch (e) {
        return err(_mensagem(e));
      } catch (e) {
        return err('pubmed_relacionados: $e');
      }
    },
  );
}

McpTool _corrigirTermo(McpContext ctx, PubmedService? Function() svc) {
  return McpTool(
    name: 'pubmed_corrigir_termo',
    description:
        'Sugere correção ortográfica para um termo de busca (ESpell do NCBI). '
        'Use quando pubmed_buscar devolver zero resultados e houver suspeita de '
        'grafia errada, antes de concluir que não existe literatura.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'termo': {'type': 'string'},
      },
      'required': ['termo'],
    },
    handler: (args) async {
      final servico = svc();
      if (servico == null) return err(_semServico);

      final termo = args.str('termo') ?? '';
      if (termo.trim().isEmpty) return err('Informe o termo.');

      try {
        final corrigido = await servico.corrigirTermo(termo);
        return ok({
          'original': termo,
          'corrigido': corrigido,
          'houveCorrecao': corrigido.isNotEmpty && corrigido != termo,
        });
      } on EvidenciaErro catch (e) {
        return err(_mensagem(e));
      } catch (e) {
        return err('pubmed_corrigir_termo: $e');
      }
    },
  );
}

/// Converte o erro em orientação para o modelo.
///
/// PHI bloqueado ganha texto próprio porque não é falha: é a guarda agindo, e o
/// modelo precisa entender que deve **reescrever** a busca, não tentar de novo
/// igual nem desistir da pergunta.
String _mensagem(EvidenciaErro e) {
  if (e.bloqueadoPorDadoPessoal) {
    return 'Busca bloqueada: o termo continha dado pessoal. Reescreva usando '
        'apenas os elementos clínicos (condição, intervenção, desfecho, faixa '
        'etária) e tente de novo. Nunca inclua nome, CPF, telefone ou e-mail.';
  }
  if (e.precisaLogin) {
    return 'Sessão expirada — a busca de evidências exige usuário autenticado. '
        'Informe o usuário em vez de tentar novamente.';
  }
  if (e.naoConfigurado) {
    return 'O conector do PubMed ainda não foi configurado (NCBI_TOOL/NCBI_EMAIL). '
        'Informe que a busca de literatura está indisponível.';
  }
  if (e.limiteAtingido) {
    return 'Limite de requisições ao PubMed atingido. Aguarde alguns segundos '
        'antes de nova busca; evite repetir a mesma consulta.';
  }
  return e.mensagem;
}
