import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/nota.dart';
import 'models/nota_enums.dart';
import 'vault_demo.dart';

/// Erro de escrita já traduzido para linguagem de usuário.
class CerebroException implements Exception {
  const CerebroException(this.mensagem, {this.conflito = false});

  final String mensagem;

  /// `true` quando a nota mudou em outro lugar (§4.10).
  final bool conflito;

  @override
  String toString() => mensagem;
}

/// Contrato de persistência das notas (`obsidian.md` §11 › `data/`).
///
/// A UI nunca fala com o Firestore diretamente — sempre por aqui (§12, regra 5).
abstract class NotaRepository {
  Future<List<Nota>> carregarTodas(String clinicaId);

  /// Cria ou atualiza. A versão é incrementada aqui; conflito de versão vira
  /// [CerebroException] com `conflito: true`.
  Future<Nota> salvar(Nota nota, {required String autor});

  /// Soft delete — a purga física é responsabilidade da Cloud Function.
  Future<void> excluir(String notaId);

  /// Semeia o vault inicial (§20.1). Devolve as notas criadas.
  Future<List<Nota>> semear(String clinicaId);

  /// Grava um lote de notas de uma vez (carga de demonstração / import).
  /// Não incrementa versão nem valida conflito — é uma carga, não uma edição.
  Future<void> salvarLote(List<Nota> notas);

  /// Popula o vault com um volume sintético realista (`vault_demo.dart`),
  /// para exercitar a interface com carga de verdade.
  Future<List<Nota>> popularDemo(String clinicaId, int alvo);

  /// Apaga **fisicamente** as notas de demonstração da clínica — as que o
  /// [VaultDemo] cria com id `nt_demo_*`. Notas escritas por pessoas nunca
  /// têm esse prefixo, então a limpeza não toca no conteúdo real.
  ///
  /// Devolve quantas notas foram removidas.
  Future<int> limparDemo(String clinicaId);
}

/// Prefixo dos ids gerados pelo [VaultDemo] — a marca que separa carga
/// sintética de nota escrita por gente.
const String prefixoDemo = 'nt_demo_';

/// Implementação em memória — usada quando o Firebase não está disponível
/// (o app roda em modo demonstração com `MockAuthService`) e nos testes.
///
/// Mantém o mesmo contrato de versão do Firestore para que o fluxo de
/// conflito seja exercitado igual nos dois modos.
class MemoriaNotaRepository implements NotaRepository {
  final Map<String, Map<String, Nota>> _porClinica = {};

  @override
  Future<List<Nota>> carregarTodas(String clinicaId) async {
    final vault = _porClinica[clinicaId];
    if (vault == null) return const [];
    return vault.values.where((n) => !n.excluida).toList();
  }

  @override
  Future<Nota> salvar(Nota nota, {required String autor}) async {
    final vault = _porClinica.putIfAbsent(nota.clinicaId, () => {});
    final atual = vault[nota.id];
    if (atual != null && atual.versao > nota.versao) {
      throw const CerebroException(
        'Esta nota mudou em outro lugar desde que você abriu.',
        conflito: true,
      );
    }
    final salva = nota.copyWith(
      versao: (atual?.versao ?? 0) + 1,
      updatedAt: DateTime.now(),
      updatedBy: autor,
    );
    vault[salva.id] = salva;
    return salva;
  }

  @override
  Future<void> excluir(String notaId) async {
    for (final vault in _porClinica.values) {
      final n = vault[notaId];
      if (n == null) continue;
      vault[notaId] = n.copyWith(deletedAt: DateTime.now());
      return;
    }
  }

  @override
  Future<List<Nota>> semear(String clinicaId) async {
    final vault = _porClinica.putIfAbsent(clinicaId, () => {});
    final notas = VaultDemo.gerar(clinicaId, alvo: 1200);
    for (final n in notas) {
      vault[n.id] = n;
    }
    return notas;
  }

  @override
  Future<void> salvarLote(List<Nota> notas) async {
    for (final n in notas) {
      _porClinica.putIfAbsent(n.clinicaId, () => {})[n.id] = n;
    }
  }

  @override
  Future<List<Nota>> popularDemo(String clinicaId, int alvo) async {
    final notas = VaultDemo.gerar(clinicaId, alvo: alvo);
    await salvarLote(notas);
    return notas;
  }

  @override
  Future<int> limparDemo(String clinicaId) async {
    final vault = _porClinica[clinicaId];
    if (vault == null) return 0;
    final alvos = vault.keys.where((id) => id.startsWith(prefixoDemo)).toList();
    for (final id in alvos) {
      vault.remove(id);
    }
    return alvos.length;
  }
}

/// Implementação Firestore (`tb_cerebro_notas`, §4.2).
class FirestoreNotaRepository implements NotaRepository {
  FirestoreNotaRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String colecao = 'tb_cerebro_notas';

  /// Acima deste tamanho o corpo migra para o Cloud Storage (§4.2).
  static const int limiteCorpoBytes = 900000;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(colecao);

  /// Teto de notas trazidas no boot.
  static const int limiteCarga = 1000;

  @override
  Future<List<Nota>> carregarTodas(String clinicaId) async {
    if (clinicaId.isEmpty) return const [];

    final base = _col.where('clinicaId', isEqualTo: clinicaId);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap =
          await base.orderBy('updatedAt', descending: true).limit(limiteCarga).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const CerebroException(
          'Você não tem permissão para ler o Cérebro desta clínica.',
        );
      }
      // `clinicaId ==` combinado com `orderBy updatedAt` exige índice composto.
      // Enquanto ele não estiver publicado o Firestore devolve
      // `failed-precondition` — e o vault abria vazio, como se não houvesse
      // nota nenhuma. Carrega sem ordenação e ordena no cliente: o índice vira
      // otimização, não requisito para a tela funcionar.
      if (e.code != 'failed-precondition') {
        throw CerebroException('Não foi possível carregar as notas: ${e.code}');
      }
      snap = await base.limit(limiteCarga).get();
    }

    final out = <Nota>[];
    for (final d in snap.docs) {
      final nota = Nota.fromMap(d.id, d.data());
      // Isolamento multi-tenant reforçado no cliente (§14.1).
      if (nota.clinicaId != clinicaId) continue;
      if (nota.excluida) continue;
      out.add(nota);
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  @override
  Future<Nota> salvar(Nota nota, {required String autor}) async {
    if (nota.conteudo.length > limiteCorpoBytes) {
      throw const CerebroException(
        'Esta nota passou de 900 KB. Divida o conteúdo em notas menores.',
      );
    }

    final ref = _col.doc(nota.id);
    try {
      return await _db.runTransaction<Nota>((tx) async {
        final snap = await tx.get(ref);
        final versaoAtual =
            snap.exists ? ((snap.data()?['versao'] as num?)?.toInt() ?? 0) : 0;

        if (snap.exists && versaoAtual > nota.versao) {
          throw const CerebroException(
            'Esta nota mudou em outro lugar desde que você abriu.',
            conflito: true,
          );
        }

        final salva = nota.copyWith(
          versao: versaoAtual + 1,
          updatedAt: DateTime.now(),
          updatedBy: autor,
        );
        final dados = salva.toMap();
        if (!snap.exists) {
          dados['createdBy'] = autor;
          dados['createdAt'] = Timestamp.fromDate(salva.createdAt);
        }
        tx.set(ref, dados, SetOptions(merge: true));
        return salva;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const CerebroException(
          'Você não tem permissão para editar o Cérebro desta clínica.',
        );
      }
      throw CerebroException('Não foi possível salvar: ${e.code}');
    }
  }

  @override
  Future<void> excluir(String notaId) async {
    await _col.doc(notaId).set(
      {
        'deletedAt': Timestamp.fromDate(DateTime.now()),
        'estado': NotaEstado.arquivada.id,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<List<Nota>> semear(String clinicaId) async {
    final notas = VaultDemo.gerar(clinicaId, alvo: 1200);
    await salvarLote(notas);
    return notas;
  }

  @override
  Future<void> salvarLote(List<Nota> notas) async {
    // Firestore aceita no máximo 500 operações por batch (§4.4).
    const tamanhoLote = 450;
    for (var i = 0; i < notas.length; i += tamanhoLote) {
      final fim = (i + tamanhoLote).clamp(0, notas.length);
      final batch = _db.batch();
      for (final n in notas.sublist(i, fim)) {
        batch.set(_col.doc(n.id), n.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  @override
  Future<List<Nota>> popularDemo(String clinicaId, int alvo) async {
    final notas = VaultDemo.gerar(clinicaId, alvo: alvo);
    await salvarLote(notas);
    return notas;
  }

  @override
  Future<int> limparDemo(String clinicaId) async {
    if (clinicaId.isEmpty) return 0;

    // Varre por `clinicaId` e filtra o prefixo no cliente: o `documentId`
    // range query exigiria outro índice, e o volume aqui é o do próprio vault.
    final snap = await _col.where('clinicaId', isEqualTo: clinicaId).get();
    final alvos = snap.docs
        .where((d) => d.id.startsWith(prefixoDemo))
        .map((d) => d.reference)
        .toList();

    const tamanhoLote = 450;
    for (var i = 0; i < alvos.length; i += tamanhoLote) {
      final fim = (i + tamanhoLote).clamp(0, alvos.length);
      final batch = _db.batch();
      for (final ref in alvos.sublist(i, fim)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
    return alvos.length;
  }
}
