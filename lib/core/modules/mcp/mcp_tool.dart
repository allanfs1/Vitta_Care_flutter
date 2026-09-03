import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Núcleo do servidor MCP em Dart — espelha os helpers `ok()`/`err()`,
/// o contexto multi-tenant e os utilitários de `src/core/modules/mcp/mcp.server.js`
/// (ver `.specify/MCP.md`).
///
/// Cada grupo de ferramentas vive num arquivo isolado em `tools/` e expõe uma
/// função `List<McpTool> build<Grupo>Tools(McpContext ctx)`. A factory
/// [createMcpServer] (em `mcp_server.dart`) registra todos os grupos.

/// Resultado uniforme de uma tool — `content: [{ type: "text", text }]`.
class McpResult {
  const McpResult(this.text, {this.isError = false});

  final String text;
  final bool isError;

  /// Formato MCP (`content` + flag de erro), útil para transportar p/ o LLM.
  Map<String, dynamic> toContent() => {
        'content': [
          {'type': 'text', 'text': text},
        ],
        if (isError) 'isError': true,
      };
}

/// `ok(data)` — serializa o dado como JSON **compacto**.
///
/// Sem indentação de propósito: o consumidor é um LLM, não uma pessoa. Cada
/// espaço de recuo é token pago, e o resultado é reenviado a cada rodada
/// seguinte do loop de ferramentas — o custo se multiplica.
McpResult ok(Object? data) => McpResult(jsonEncode(jsonSafe(data)));

/// `err(msg)` — mensagem de erro padronizada (nunca lança p/ fora do handler).
McpResult err(String message) => McpResult('Erro: $message', isError: true);

/// Lançada quando uma tool pede a clínica do contexto e ela ainda não foi
/// resolvida. `McpServer.callTool` captura e devolve como [McpResult] de erro,
/// então o LLM recebe uma recusa clara em vez de operar em clínica arbitrária.
class McpSemClinica implements Exception {
  const McpSemClinica();

  @override
  String toString() =>
      'a clínica ativa ainda não foi resolvida — nenhuma operação pode ser '
      'executada sem saber de qual clínica são os dados';
}

/// Assinatura do executor de uma ferramenta.
typedef McpHandler = Future<McpResult> Function(Map<String, dynamic> args);

/// Definição de uma ferramenta MCP.
///
/// [inputSchema] é um JSON-Schema simplificado (`type: object`, `properties`,
/// `required`) cujas descrições alimentam o LLM — equivalente aos schemas Zod
/// do servidor Node original.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.handler,
    this.inputSchema = const {'type': 'object', 'properties': {}},
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final McpHandler handler;

  /// Representação exposta ao LLM (`name`, `description`, `inputSchema`).
  Map<String, dynamic> toSpec() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Contexto compartilhado injetado em cada grupo de tools — carrega o escopo
/// multi-tenant (clínica do usuário logado) e utilitários do Firestore.
class McpContext {
  McpContext({
    FirebaseFirestore? db,
    String? defaultClinicaId,
  })  : _db = db,
        defaultClinicaId = defaultClinicaId ?? '';

  FirebaseFirestore? _db;

  /// Instância do Firestore, resolvida sob demanda. Em modo demonstração (sem
  /// Firebase inicializado) o acesso lança — mas só quando um handler realmente
  /// usa o banco, e o erro é capturado por `McpServer.callTool`, virando um
  /// [McpResult] de erro em vez de derrubar a UI/construção do servidor.
  FirebaseFirestore get db => _db ??= FirebaseFirestore.instance;

  /// Clínica da requisição — a do usuário logado. Vazia enquanto o app ainda
  /// não resolveu qual é (ver `clinicaResolvidaProvider`).
  ///
  /// **Sem fallback.** Havia aqui uma clínica de produção fixa
  /// (`JuhdNt7NG3GYOFKOKOXP`) usada quando o id chegava vazio. Como todo o
  /// isolamento multi-tenant — [clinicaId], [clinicRef], [belongsToClinic],
  /// [isForeignClinic] — se ancora neste campo, esse fallback fazia a IA ler e
  /// gravar em uma clínica alheia sempre que o contexto subisse sem clínica.
  /// Agora o campo fica vazio e as tools recusam: falhar é fail-closed,
  /// adivinhar não é.
  final String defaultClinicaId;

  /// `true` quando há clínica para operar. Sem ela, toda tool recusa.
  bool get temClinica => defaultClinicaId.isNotEmpty;

  /// Limite padrão das listagens.
  static const int defaultLimit = 50;

  /// **Isolamento multi-tenant (LOCK).** Todo acesso ao sistema via MCP é
  /// restrito à clínica do usuário logado: este método **ignora** qualquer
  /// `clinicaId` vindo dos argumentos (ou seja, do LLM) e sempre devolve a
  /// clínica do contexto. Assim um usuário nunca consegue ler/escrever dados
  /// de outra clínica, mesmo que a ferramenta aceite o parâmetro.
  String clinicaId([Object? _]) {
    if (!temClinica) throw const McpSemClinica();
    return defaultClinicaId;
  }

  /// Referência da clínica do usuário logado (para filtros e gravações).
  DocumentReference<Map<String, dynamic>> get clinicRef =>
      db.collection('tb_clinica').doc(clinicaId());

  /// Verifica se um documento (campos `idClinica`/`idclinica`/`clinicaId`/
  /// `idagendamento`) pertence à clínica do contexto. Aceita o valor como
  /// `DocumentReference`, caminho `tb_clinica/{id}` ou id puro. Usado para
  /// barrar leitura cruzada em buscas por id e coleções genéricas.
  bool belongsToClinic(Map<String, dynamic>? data) {
    if (data == null || !temClinica) return false;
    for (final f in _clinicFields) {
      final v = data[f];
      if (v == null) continue;
      final id = _clinicIdOf(v);
      if (id != null && id == defaultClinicaId) return true;
    }
    // Não pertence à clínica (outra clínica) ou não tem campo de clínica.
    return false;
  }

  /// `true` quando o documento carrega um campo de clínica que aponta para
  /// **outra** clínica. Usado como filtro leniente: documentos sem campo de
  /// clínica (coleções globais) passam; documentos de clínica alheia são
  /// barrados. É a barreira central de isolamento multi-tenant aplicada em
  /// [toJsonList]/[toJsonOne].
  bool isForeignClinic(Map<String, dynamic>? data) {
    if (data == null) return false;
    // Sem clínica resolvida nada é "da minha clínica": barra tudo em vez de
    // deixar passar por comparação com string vazia.
    if (!temClinica) return true;
    for (final f in _clinicFields) {
      final v = data[f];
      if (v == null) continue;
      final id = _clinicIdOf(v);
      if (id != null && id != defaultClinicaId) return true;
    }
    return false;
  }

  static const List<String> _clinicFields = [
    'idClinica',
    'idclinica',
    'clinicaId',
    'idClinic',
    'clinica',
    'id_clinica',
  ];

  static String? _clinicIdOf(Object? v) {
    if (v is DocumentReference) return v.id;
    if (v is String) {
      if (v.contains('/')) return v.split('/').last;
      return v;
    }
    return null;
  }

  /// Teto absoluto de itens numa listagem.
  ///
  /// O `limite` vem dos argumentos da tool, ou seja, **do LLM**. Sem teto, um
  /// `limite: 50000` devolve 50 mil registros que entram no contexto e são
  /// reenviados a cada rodada seguinte do loop de ferramentas. Valor negativo
  /// também era aceito e explodia em `Iterable.take`.
  static const int maxLimit = 200;

  /// Resolve o limite de uma listagem (int, num ou string numérica),
  /// **sempre dentro de [1, maxLimit]**.
  int limit([Object? arg]) {
    final bruto = switch (arg) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? defaultLimit,
      _ => defaultLimit,
    };
    return bruto.clamp(1, maxLimit);
  }

  /// Referência de documento — filtros por entidade usam refs, não strings:
  /// `ctx.docRef('tb_clinica', id)`.
  DocumentReference<Map<String, dynamic>> docRef(String collection, String id) =>
      db.collection(collection).doc(id);

  /// Mapeia docs do Firestore para `{ id, ...data }`, serializando timestamps,
  /// referências e geopoints (equivalente a `toJSON(docs)`).
  ///
  /// **Isolamento multi-tenant (LOCK central):** documentos que pertencem a
  /// **outra** clínica ([isForeignClinic]) são removidos automaticamente.
  /// Toda ferramenta de leitura passa por aqui, então nenhum dado de clínica
  /// alheia é exposto, mesmo que o filtro da query não cubra todos os casos.
  List<Map<String, dynamic>> toJsonList(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final out = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = d.data();
      if (isForeignClinic(data)) continue; // barra clínica alheia
      out.add(<String, dynamic>{
        'id': d.id,
        ...?(jsonSafe(data) as Map<String, dynamic>?),
      });
    }
    return out;
  }

  /// Versão para um único snapshot (pode não existir → null). Retorna `null`
  /// também quando o documento pertence a outra clínica (isolamento).
  Map<String, dynamic>? toJsonOne(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (isForeignClinic(data)) return null; // barra clínica alheia
    return <String, dynamic>{
      'id': snap.id,
      ...?(jsonSafe(data) as Map<String, dynamic>?),
    };
  }
}

/// Converte valores do Firestore (Timestamp, DocumentReference, GeoPoint, etc.)
/// para formas serializáveis em JSON. Recursivo em mapas e listas.
Object? jsonSafe(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is DocumentReference) return value.path;
  if (value is GeoPoint) {
    return {'lat': value.latitude, 'lng': value.longitude};
  }
  if (value is Map) {
    return value
        .map((k, v) => MapEntry(k.toString(), jsonSafe(v)));
  }
  if (value is Iterable) return value.map(jsonSafe).toList();
  if (value is num || value is bool || value is String) return value;
  return value.toString();
}

/// Helpers de leitura de argumentos (tolerantes a tipos vindos do LLM).
extension McpArgs on Map<String, dynamic> {
  String? str(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? intArg(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  num? numArg(String key) {
    final v = this[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  bool? boolArg(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1' || s == 'sim') return true;
      if (s == 'false' || s == '0' || s == 'nao' || s == 'não') return false;
    }
    return null;
  }

  List<String> strList(String key) {
    final v = this[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) {
      return v.split(',').map((e) => e.trim()).toList();
    }
    return const [];
  }
}
