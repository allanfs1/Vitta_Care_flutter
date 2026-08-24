import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import 'assistant_knowledge.dart';
import 'assistant_models.dart';
import 'assistant_tours.dart';

/// Estado do assistente de ajuda.
class AssistantState {
  const AssistantState({
    this.isOpen = false,
    this.messages = const [],
    this.activeTour,
    this.stepIndex = 0,
    this.thinking = false,
  });

  final bool isOpen;
  final List<AssistantMessage> messages;
  final HelpTour? activeTour;
  final int stepIndex;
  final bool thinking;

  bool get inTour => activeTour != null;
  HelpStep? get currentStep => inTour && stepIndex < activeTour!.steps.length
      ? activeTour!.steps[stepIndex]
      : null;

  AssistantState copyWith({
    bool? isOpen,
    List<AssistantMessage>? messages,
    HelpTour? activeTour,
    bool clearTour = false,
    int? stepIndex,
    bool? thinking,
  }) {
    return AssistantState(
      isOpen: isOpen ?? this.isOpen,
      messages: messages ?? this.messages,
      activeTour: clearTour ? null : (activeTour ?? this.activeTour),
      stepIndex: stepIndex ?? this.stepIndex,
      thinking: thinking ?? this.thinking,
    );
  }
}

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._ref)
      : super(const AssistantState(messages: [_welcome]));

  final Ref _ref;

  static const _welcome = AssistantMessage(
    role: AssistantRole.assistant,
    text: 'Olá! 👋 Sou o assistente do Vitta. Posso explicar qualquer '
        'funcionalidade e te guiar na tela, passo a passo. Pergunte algo ou '
        'escolha uma sugestão abaixo.',
  );

  List<String> get starterQuestions => kSuggestedQuestions;

  // ---- abertura / fechamento
  void open() => state = state.copyWith(isOpen: true);
  void close() => state = state.copyWith(isOpen: false);
  void toggle() => state.isOpen && !state.inTour
      ? close()
      : state = state.copyWith(isOpen: true);

  // ---- chat híbrido (FAQ local + IA + sugestão/início de tour)
  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.thinking) return;
    _append(AssistantMessage(role: AssistantRole.user, text: t));

    final nq = normalizeText(t);
    final tours = _relevantTours(nq);

    // 1) Pediu explicitamente para ser guiado → inicia o tour mais relevante.
    if (wantsGuidedTour(nq) && tours.isNotEmpty) {
      final tour = tourById(tours.first)!;
      _appendAssistant('Perfeito! Vou te guiar em “${tour.title}”. 👇',
          tours: [tour.id]);
      startTour(tour.id);
      return;
    }

    // 2) Resposta local (base de conhecimento) — instantânea e confiável.
    final faq = _bestAnswer(nq);
    if (faq != null) {
      final suggestions = <String>{
        if (faq.tour != null) faq.tour!,
        ...tours,
      }.take(3).toList();
      _appendAssistant(faq.answer, tours: suggestions);
      return;
    }

    // 3) IA real (Cloud Function chatProxy) para perguntas abertas.
    state = state.copyWith(thinking: true);
    _appendAssistant('', streaming: true);
    final idx = state.messages.length - 1;
    final reply = await _ref.read(aiServiceProvider).helpReply(_history());
    _replaceAt(
      idx,
      text: reply,
      streaming: false,
      tours: tours.isNotEmpty ? tours.take(3).toList() : const ['visao_geral'],
    );
    state = state.copyWith(thinking: false);
  }

  /// Reenvia uma pergunta sugerida (chip).
  Future<void> ask(String question) => send(question);

  // ---- relevância
  List<String> _relevantTours(String nq, {int max = 3}) {
    final scored = <MapEntry<String, double>>[];
    for (final tour in kHelpTours) {
      var s = scoreKeywords(nq, tour.keywords);
      s += scoreKeywords(nq, tour.title.split(' ').where((w) => w.length > 3).toList());
      if (s > 0) scored.add(MapEntry(tour.id, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in scored.take(max)) e.key];
  }

  HelpAnswer? _bestAnswer(String nq) {
    HelpAnswer? best;
    var bestScore = 0.0;
    for (final a in kHelpAnswers) {
      final s = scoreKeywords(nq, a.keywords);
      if (s > bestScore) {
        bestScore = s;
        best = a;
      }
    }
    return bestScore > 0 ? best : null;
  }

  // ---- IA
  List<Map<String, String>> _history() {
    final msgs = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt()},
    ];
    for (final m in state.messages) {
      if (m.streaming || m.text.trim().isEmpty) continue;
      msgs.add({
        'role': m.role == AssistantRole.user ? 'user' : 'assistant',
        'content': m.text,
      });
    }
    return msgs;
  }

  String _systemPrompt() {
    final tours = kHelpTours.map((t) => '- ${t.title}: ${t.description}').join('\n');
    return 'Você é o assistente de ajuda do Vitta, um sistema de gestão de '
        'clínicas (agendamentos, recepção, totem de autoatendimento, IA, '
        'relatórios e configurações). Responda em português do Brasil, de forma '
        'curta, prática e amigável, focada em ENSINAR a usar o sistema.\n'
        'FORMATO: use Markdown legível — negrito (**) para termos e botões, '
        'listas com "-" ou passos numerados para procedimentos, títulos curtos '
        'quando ajudar. Seja conciso (evite parágrafos longos). Se fizer '
        'sentido, sugira iniciar um destes tours guiados:\n$tours';
  }

  // ---- helpers de estado
  void _append(AssistantMessage m) =>
      state = state.copyWith(messages: [...state.messages, m]);

  void _appendAssistant(String text,
      {List<String> tours = const [], bool streaming = false}) {
    _append(AssistantMessage(
      role: AssistantRole.assistant,
      text: text,
      tourSuggestions: tours,
      streaming: streaming,
    ));
  }

  void _replaceAt(int index,
      {required String text,
      required bool streaming,
      List<String>? tours}) {
    if (index < 0 || index >= state.messages.length) return;
    final list = [...state.messages];
    list[index] =
        list[index].copyWith(text: text, streaming: streaming, tourSuggestions: tours);
    state = state.copyWith(messages: list);
  }

  // ---- tours guiados
  HelpTour? tourById(String id) {
    for (final t in kHelpTours) {
      if (t.id == id) return t;
    }
    return null;
  }

  void startTour(String id) {
    final tour = tourById(id);
    if (tour == null) return;
    state = state.copyWith(activeTour: tour, stepIndex: 0, isOpen: true);
  }

  void nextStep() {
    final tour = state.activeTour;
    if (tour == null) return;
    if (state.stepIndex < tour.steps.length - 1) {
      state = state.copyWith(stepIndex: state.stepIndex + 1);
    } else {
      endTour();
    }
  }

  void prevStep() {
    if (state.stepIndex > 0) {
      state = state.copyWith(stepIndex: state.stepIndex - 1);
    }
  }

  void endTour() => state = state.copyWith(clearTour: true, stepIndex: 0);

  /// Limpa a conversa, mantendo a saudação inicial.
  void clearChat() => state = state.copyWith(messages: const [_welcome]);
}

final assistantProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
        (ref) => AssistantController(ref));
