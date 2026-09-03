import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Trava de catraca sobre a chave de tenant.
///
/// A base tem cinco grafias para "id da clínica" (`database.md` → Problemas
/// estruturais, P1). Consertar isso exige migração e não cabe num teste. O que
/// cabe é **impedir que piore**: este arquivo congela o conjunto conhecido e
/// falha se alguém publicar índice com uma sexta grafia, ou introduzir uma
/// grafia nova numa coleção que hoje só tem uma.
///
/// Quando a migração acontecer, os conjuntos abaixo diminuem — e o teste passa
/// a proteger o resultado em vez da dívida.
void main() {
  /// Toda forma de escrever "id da clínica" que já apareceu na base.
  const grafiasConhecidas = {
    'idclinica',
    'idClinica',
    'id_clinica',
    'clinicaId',
    'clinicId',
    'clinica',
  };

  /// Grafia canônica escolhida: 18 índices em `tb_agendamentos`, todas as
  /// Cloud Functions e a maioria da base legada.
  const canonica = 'idclinica';

  /// Coleções que hoje convivem com mais de uma grafia. Esta é a dívida
  /// registrada — a lista **não pode crescer**.
  const conhecidasComMistura = {
    'tb_agendamentos': {'idclinica', 'idClinica', 'id_clinica'},
    'queue_realoc': {'idclinica', 'idClinica'},
    'historico_agenda_clinica': {'idclinica', 'clinicaId'},
  };

  bool ehTenant(String campo) =>
      grafiasConhecidas.contains(campo) ||
      (campo.toLowerCase().contains('clinic') &&
          !campo.toLowerCase().contains('nome') &&
          !campo.toLowerCase().contains('photo'));

  Map<String, Set<String>> lerIndices() {
    final f = File('firestore.indexes.json');
    expect(f.existsSync(), isTrue,
        reason: 'firestore.indexes.json precisa estar versionado');

    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final porColecao = <String, Set<String>>{};

    for (final idx in (json['indexes'] as List? ?? const [])) {
      final m = idx as Map<String, dynamic>;
      final col = m['collectionGroup']?.toString() ?? '';
      for (final campo in (m['fields'] as List? ?? const [])) {
        final nome =
            (campo as Map<String, dynamic>)['fieldPath']?.toString() ?? '';
        if (ehTenant(nome)) {
          porColecao.putIfAbsent(col, () => <String>{}).add(nome);
        }
      }
    }
    return porColecao;
  }

  test('nenhuma grafia de tenant nova nos índices', () {
    final porColecao = lerIndices();
    final vistas = <String>{};
    for (final s in porColecao.values) {
      vistas.addAll(s);
    }

    final novas = vistas.difference(grafiasConhecidas);
    expect(novas, isEmpty,
        reason: 'grafia(s) de tenant não catalogada(s): $novas\n'
            'Se for deliberado, use "$canonica" e atualize database.md → P1.');
  });

  test('a lista de coleções com grafia misturada não cresceu', () {
    final porColecao = lerIndices();
    final misturadas = <String, Set<String>>{
      for (final e in porColecao.entries)
        if (e.value.length > 1) e.key: e.value,
    };

    final novasColecoes =
        misturadas.keys.toSet().difference(conhecidasComMistura.keys.toSet());
    expect(novasColecoes, isEmpty,
        reason: 'coleção(ões) com mais de uma grafia de tenant e ainda não '
            'registradas: $novasColecoes\n'
            'Cada uma dessas obriga o app a abrir uma query por grafia.');
  });

  test('as coleções já misturadas não ganharam grafia adicional', () {
    final porColecao = lerIndices();
    for (final e in conhecidasComMistura.entries) {
      final atual = porColecao[e.key] ?? const <String>{};
      final extras = atual.difference(e.value);
      expect(extras, isEmpty,
          reason: '${e.key} ganhou grafia(s) nova(s): $extras');
    }
  });

  test('a canônica está entre as grafias de toda coleção misturada', () {
    // Se uma coleção misturada perder a canônica, a migração fica sem alvo.
    for (final e in conhecidasComMistura.entries) {
      expect(e.value, contains(canonica),
          reason: '${e.key} não tem a grafia canônica "$canonica"');
    }
  });
}
