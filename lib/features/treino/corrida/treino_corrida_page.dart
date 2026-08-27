import 'package:flutter/material.dart';

import '../treino_detalhe_page.dart';
import '../treino_service.dart';

/// Tela de listagem dos treinos de corrida do paciente.
///
/// Responsabilidades:
/// - carregar os treinos através do TreinoService;
/// - apresentar somente treinos do tipo corrida;
/// - identificar cada treino como A, B, C, D...;
/// - apresentar período, objetivo e quantidade de exercícios;
/// - apresentar a quantidade de execuções no período;
/// - encaminhar o usuário para os detalhes do treino;
/// - atualizar os dados quando retornar da execução.
///
/// A execução da corrida é responsabilidade de:
///
/// corrida/treino_corrida_execucao_page.dart
class TreinoCorridaPage extends StatefulWidget {
  const TreinoCorridaPage({
    super.key,
    required this.treinoService,
  });

  final TreinoService treinoService;

  @override
  State<TreinoCorridaPage> createState() =>
      _TreinoCorridaPageState();
}

class _TreinoCorridaPageState
    extends State<TreinoCorridaPage> {
  bool _carregando = true;
  String? _erro;

  List<Map<String, dynamic>> _treinos =
  <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // ==========================================================
  // CARREGAMENTO
  // ==========================================================

  Future<void> _carregar() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final treinos =
      await widget.treinoService.listarTreinos();

      final treinosCorrida = treinos.where((treino) {
        final tipo = widget.treinoService
            .tipoTreino(treino)
            .trim()
            .toLowerCase();

        return tipo == 'corrida';
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _treinos = treinosCorrida;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = _mensagemErro(e);
        _carregando = false;
      });
    }
  }

  String _mensagemErro(Object erro) {
    if (erro is TreinoException) {
      return erro.message;
    }

    return 'Não foi possível carregar os treinos de corrida.';
  }

  // ==========================================================
  // IDENTIFICAÇÃO A / B / C
  // ==========================================================

  String _codigoTreino(int indice) {
    if (indice < 0) {
      return 'A';
    }

    const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    if (indice < letras.length) {
      return letras[indice];
    }

    return 'T${indice + 1}';
  }

  // ==========================================================
  // NOME DO TREINO
  // ==========================================================

  String _nomeTreino(
      Map<String, dynamic> treino,
      String codigo,
      ) {
    final nome = treino['nome']
        ?.toString()
        .trim();

    if (nome == null || nome.isEmpty) {
      return 'Treino $codigo';
    }

    return _capitalizarNomeTreino(nome);
  }

  String _capitalizarNomeTreino(String nome) {
    return nome
        .trim()
        .split(RegExp(r'\s+'))
        .map((palavra) {
      if (palavra.isEmpty) {
        return palavra;
      }

      if (palavra.length == 1) {
        return palavra.toUpperCase();
      }

      return palavra[0].toUpperCase() +
          palavra.substring(1);
    })
        .join(' ');
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Treinos de corrida',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _buildBody(),
      ),
    );
  }

  // ==========================================================
  // BODY
  // ==========================================================

  Widget _buildBody() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erro != null) {
      return _buildErro();
    }

    if (_treinos.isEmpty) {
      return _buildVazio();
    }

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ),
      children: [
        _buildCabecalho(),
        const SizedBox(height: 20),
        ...List.generate(
          _treinos.length,
              (indice) => _buildTreinoCard(
            _treinos[indice],
            indice,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CABEÇALHO
  // ==========================================================

  Widget _buildCabecalho() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF3B82F6),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
              Colors.white.withValues(alpha: 0.18),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Treinos de corrida',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _textoQuantidadeTreinos(),
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.9,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _textoQuantidadeTreinos() {
    if (_treinos.length == 1) {
      return '1 treino de corrida prescrito';
    }

    return '${_treinos.length} treinos de corrida prescritos';
  }

  // ==========================================================
  // CARD DO TREINO
  // ==========================================================

  Widget _buildTreinoCard(
      Map<String, dynamic> treino,
      int indice,
      ) {
    final objetivo =
    widget.treinoService.objetivoTreino(treino);

    final observacoes =
    widget.treinoService.observacoesTreino(treino);

    final exercicios =
    widget.treinoService.obterExercicios(treino);

    final dataInicio =
    widget.treinoService.dataInicioTreino(treino);

    final dataFim =
    widget.treinoService.dataFimTreino(treino);

    final id =
    widget.treinoService.idTreino(treino);

    final totalExecucoes =
    _totalExecucoes(treino);

    final codigo = _codigoTreino(indice);

    final nomeTreino =
    _nomeTreino(treino, codigo);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _abrirDetalhes(treino);
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFF2563EB),
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        codigo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomeTreino,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w900,
                              color:
                              Color(0xFF1F2937),
                            ),
                          ),
                          if (objetivo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              objetivo,
                              style:
                              const TextStyle(
                                fontSize: 13,
                                color:
                                Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _buildInformacoes(
                  exercicios: exercicios.length,
                  dataInicio: dataInicio,
                  dataFim: dataFim,
                  totalExecucoes:
                  totalExecucoes,
                ),

                if (observacoes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFF8FAFC),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color:
                          Color(0xFF64748B),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            observacoes,
                            style:
                            const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color:
                              Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _abrirDetalhes(treino);
                    },
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      exercicios.isEmpty
                          ? 'Ver $nomeTreino'
                          : 'Ver exercícios de '
                          '$nomeTreino',
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                    style:
                    OutlinedButton.styleFrom(
                      minimumSize:
                      const Size.fromHeight(46),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      side: const BorderSide(
                        color: Color(0xFF2563EB),
                      ),
                      foregroundColor:
                      const Color(0xFF2563EB),
                    ),
                  ),
                ),

                if (id != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '$nomeTreino • #$id',
                      style: const TextStyle(
                        fontSize: 11,
                        color:
                        Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // TOTAL DE EXECUÇÕES
  // ==========================================================

  int _totalExecucoes(
      Map<String, dynamic> treino,
      ) {
    final valor = treino['total_execucoes'];

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    if (valor is String) {
      return int.tryParse(valor) ?? 0;
    }

    return 0;
  }

  // ==========================================================
  // INFORMAÇÕES
  // ==========================================================

  Widget _buildInformacoes({
    required int exercicios,
    required String? dataInicio,
    required String? dataFim,
    required int totalExecucoes,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoItem(
                icone:
                Icons.format_list_numbered_rounded,
                titulo: 'Exercícios',
                valor: exercicios.toString(),
              ),
            ),
            Expanded(
              child: _InfoItem(
                icone:
                Icons.calendar_month_rounded,
                titulo: 'Período',
                valor: _formatarPeriodo(
                  dataInicio,
                  dataFim,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFDBEAFE),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFF2563EB),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  totalExecucoes == 1
                      ? '1 execução no período'
                      : '$totalExecucoes '
                      'execuções no período',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              Text(
                '$totalExecucoes',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DATAS
  // ==========================================================

  String _formatarPeriodo(
      String? inicio,
      String? fim,
      ) {
    final dataInicio =
    _formatarData(inicio);

    final dataFim =
    _formatarData(fim);

    if (dataInicio.isEmpty &&
        dataFim.isEmpty) {
      return 'Não informado';
    }

    if (dataInicio.isEmpty) {
      return dataFim;
    }

    if (dataFim.isEmpty) {
      return dataInicio;
    }

    if (dataInicio == dataFim) {
      return dataInicio;
    }

    return '$dataInicio - $dataFim';
  }

  String _formatarData(String? data) {
    if (data == null ||
        data.trim().isEmpty) {
      return '';
    }

    final partes = data.split('-');

    if (partes.length != 3) {
      return data;
    }

    final ano = partes[0];
    final mes = partes[1];
    final dia = partes[2];

    if (ano.length != 4 ||
        mes.length != 2 ||
        dia.length != 2) {
      return data;
    }

    return '$dia/$mes/$ano';
  }

  // ==========================================================
  // DETALHES
  // ==========================================================

  Future<void> _abrirDetalhes(
      Map<String, dynamic> treino,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TreinoDetalhePage(
          treino: treino,
          treinoService:
          widget.treinoService,
          onTreinoConcluido:
          _treinoConcluido,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _carregar();
  }

  // ==========================================================
  // CALLBACK DE CONCLUSÃO
  // ==========================================================

  Future<void> _treinoConcluido(
      int treinoId,
      int tempoTotalSegundos,
      ) async {
    if (!mounted) {
      return;
    }

    await _carregar();
  }

  // ==========================================================
  // ERRO
  // ==========================================================

  Widget _buildErro() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        Center(
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius:
              BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Não foi possível carregar '
              'seus treinos de corrida',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _erro!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _carregar,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label:
            const Text('Tentar novamente'),
            style:
            ElevatedButton.styleFrom(
              minimumSize:
              const Size(180, 48),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // VAZIO
  // ==========================================================

  Widget _buildVazio() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius:
              BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              color: Color(0xFF2563EB),
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Nenhuma corrida disponível',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Quando um profissional prescrever '
              'um treino de corrida, ele aparecerá aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ITEM DE INFORMAÇÃO
// ============================================================

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  final IconData icone;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icone,
          size: 19,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}