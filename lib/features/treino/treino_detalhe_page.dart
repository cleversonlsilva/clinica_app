import 'package:flutter/material.dart';

import 'treino_execucao_page.dart';
import 'treino_service.dart';

/// Tela de detalhes de um treino.
///
/// Apresenta:
/// - tipo do treino;
/// - objetivo;
/// - período;
/// - observações;
/// - exercícios;
/// - séries;
/// - repetições;
/// - carga;
/// - tempo;
/// - descanso;
/// - grupo muscular;
/// - equipamento;
/// - vídeo e imagem quando disponíveis.
///
/// A execução interativa é realizada pela
/// TreinoExecucaoPage.
///
/// O registro da execução é delegado ao callback
/// [onTreinoConcluido], mantendo a comunicação HTTP
/// fora desta tela.
class TreinoDetalhePage extends StatelessWidget {
  const TreinoDetalhePage({
    super.key,
    required this.treino,
    required this.treinoService,
    this.onTreinoConcluido,
  });

  final Map<String, dynamic> treino;
  final TreinoService treinoService;

  /// Callback chamado quando o paciente conclui
  /// todos os exercícios e séries do treino.
  ///
  /// Parâmetros:
  /// - primeiro: ID do treino;
  /// - segundo: tempo total da execução em segundos.
  ///
  /// O callback é opcional para manter compatibilidade
  /// com chamadas existentes da tela.
  final Future<void> Function(
      int treinoId,
      int tempoTotalSegundos,
      )? onTreinoConcluido;

  @override
  Widget build(BuildContext context) {
    final tipo = treinoService.tipoTreino(treino);

    final objetivo =
    treinoService.objetivoTreino(treino);

    final observacoes =
    treinoService.observacoesTreino(treino);

    final exercicios =
    treinoService.obterExercicios(treino);

    final dataInicio =
    treinoService.dataInicioTreino(treino);

    final dataFim =
    treinoService.dataFimTreino(treino);

    final tipoInfo = _tipoInfo(tipo);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Treino',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),
        children: [
          _buildCabecalho(
            context,
            tipoInfo,
            objetivo,
            dataInicio,
            dataFim,
          ),
          if (observacoes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildObservacoes(observacoes),
          ],
          const SizedBox(height: 22),
          _buildTituloExercicios(
            exercicios.length,
          ),
          const SizedBox(height: 12),
          if (exercicios.isEmpty)
            _buildSemExercicios()
          else
            ...exercicios.asMap().entries.map(
                  (entry) {
                return Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom: 14,
                  ),
                  child: _buildExercicioCard(
                    context,
                    entry.value,
                    entry.key + 1,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // CABEÇALHO
  // ==========================================================

  Widget _buildCabecalho(
      BuildContext context,
      _TipoTreinoInfo tipoInfo,
      String objetivo,
      String? dataInicio,
      String? dataFim,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tipoInfo.cor,
            tipoInfo.cor.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tipoInfo.cor.withValues(
              alpha: 0.18,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.18,
                  ),
                  borderRadius:
                  BorderRadius.circular(17),
                ),
                child: Icon(
                  tipoInfo.icone,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipoInfo.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (objetivo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        objetivo,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: 0.92,
                          ),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _formatarPeriodo(
                      dataInicio,
                      dataFim,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // OBSERVAÇÕES
  // ==========================================================

  Widget _buildObservacoes(
      String observacoes,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notes_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orientações',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  observacoes,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TÍTULO DOS EXERCÍCIOS
  // ==========================================================

  Widget _buildTituloExercicios(
      int quantidade,
      ) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Exercícios',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius:
            BorderRadius.circular(20),
          ),
          child: Text(
            '$quantidade',
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CARD DO EXERCÍCIO
  // ==========================================================

  Widget _buildExercicioCard(
      BuildContext context,
      Map<String, dynamic> exercicio,
      int numero,
      ) {
    final nome =
    treinoService.nomeExercicio(exercicio);

    final grupo =
    treinoService.grupoMuscular(exercicio);

    final equipamento =
    treinoService.equipamentoExercicio(
      exercicio,
    );

    final nivel =
    treinoService.nivelExercicio(exercicio);

    final series =
    treinoService.seriesExercicio(exercicio);

    final repeticoes =
    treinoService.repeticoesExercicio(
      exercicio,
    );

    final carga =
    treinoService.cargaExercicio(exercicio);

    final tempo =
    treinoService.tempoExercicio(exercicio);

    final unidadeTempo =
    treinoService.unidadeTempoExercicio(
      exercicio,
    );

    final descanso =
    treinoService.descansoExercicio(
      exercicio,
    );

    final tipoExecucao =
    treinoService.tipoExecucao(exercicio);

    final videoUrl =
    treinoService.videoUrl(exercicio);

    final imagemUrl =
    treinoService.imagemUrl(exercicio);

    final observacoes =
    treinoService.observacoesExercicio(
      exercicio,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.045,
            ),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildNumero(numero),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (grupo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          grupo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (videoUrl != null)
                  IconButton(
                    onPressed: () {
                      _mostrarVideoDisponivel(
                        context,
                        videoUrl,
                      );
                    },
                    tooltip: 'Ver vídeo',
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xFF2563EB),
                      size: 29,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (imagemUrl != null)
              _buildImagem(imagemUrl),
            if (imagemUrl != null)
              const SizedBox(height: 14),
            _buildParametros(
              series: series,
              repeticoes: repeticoes,
              carga: carga,
              tempo: tempo,
              unidadeTempo: unidadeTempo,
              descanso: descanso,
            ),
            if (equipamento.isNotEmpty ||
                nivel.isNotEmpty ||
                tipoExecucao.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildDetalhesSecundarios(
                equipamento: equipamento,
                nivel: nivel,
                tipoExecucao: tipoExecucao,
              ),
            ],
            if (observacoes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildObservacaoExercicio(
                observacoes,
              ),
            ],
            const SizedBox(height: 16),
            _buildBotaoExecucao(
              context,
              exercicio,
              numero,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // NÚMERO
  // ==========================================================

  Widget _buildNumero(
      int numero,
      ) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: const TextStyle(
          color: Color(0xFF15803D),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ==========================================================
  // IMAGEM
  // ==========================================================

  Widget _buildImagem(
      String url,
      ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 8,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (
              context,
              error,
              stackTrace,
              ) {
            return _buildImagemIndisponivel();
          },
          loadingBuilder: (
              context,
              child,
              progress,
              ) {
            if (progress == null) {
              return child;
            }

            return Container(
              color: const Color(0xFFF1F5F9),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagemIndisponivel() {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF94A3B8),
        size: 34,
      ),
    );
  }

  // ==========================================================
  // PARÂMETROS
  // ==========================================================

  Widget _buildParametros({
    required int? series,
    required String repeticoes,
    required String carga,
    required int? tempo,
    required String unidadeTempo,
    required int? descanso,
  }) {
    final itens = <Widget>[];

    if (series != null && series > 0) {
      itens.add(
        _ParametroItem(
          icone: Icons.repeat_rounded,
          titulo: 'Séries',
          valor: series.toString(),
        ),
      );
    }

    if (repeticoes.isNotEmpty) {
      itens.add(
        _ParametroItem(
          icone:
          Icons.format_list_numbered_rounded,
          titulo: 'Repetições',
          valor: repeticoes,
        ),
      );
    }

    if (carga.isNotEmpty) {
      itens.add(
        _ParametroItem(
          icone: Icons.fitness_center_rounded,
          titulo: 'Carga',
          valor: carga,
        ),
      );
    }

    if (tempo != null && tempo > 0) {
      itens.add(
        _ParametroItem(
          icone: Icons.timer_outlined,
          titulo: 'Tempo',
          valor: unidadeTempo.isEmpty
              ? tempo.toString()
              : '$tempo $unidadeTempo',
        ),
      );
    }

    if (descanso != null && descanso > 0) {
      itens.add(
        _ParametroItem(
          icone:
          Icons.hourglass_bottom_rounded,
          titulo: 'Descanso',
          valor: _formatarDescanso(descanso),
        ),
      );
    }

    if (itens.isEmpty) {
      return _buildSemParametros();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: itens,
    );
  }

  Widget _buildSemParametros() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Text(
        'Parâmetros do exercício não informados.',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  String _formatarDescanso(
      int segundos,
      ) {
    if (segundos < 60) {
      return '${segundos}s';
    }

    final minutos = segundos ~/ 60;
    final resto = segundos % 60;

    if (resto == 0) {
      return '${minutos}min';
    }

    return '${minutos}min ${resto}s';
  }

  // ==========================================================
  // DETALHES SECUNDÁRIOS
  // ==========================================================

  Widget _buildDetalhesSecundarios({
    required String equipamento,
    required String nivel,
    required String tipoExecucao,
  }) {
    final itens = <String>[];

    if (equipamento.isNotEmpty) {
      itens.add(
        'Equipamento: $equipamento',
      );
    }

    if (nivel.isNotEmpty) {
      itens.add(
        'Nível: $nivel',
      );
    }

    if (tipoExecucao.isNotEmpty) {
      itens.add(
        'Execução: ${_formatarTexto(tipoExecucao)}',
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: itens.map(
            (texto) {
          return Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius:
              BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ==========================================================
  // OBSERVAÇÃO DO EXERCÍCIO
  // ==========================================================

  Widget _buildObservacaoExercicio(
      String observacoes,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              observacoes,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EXECUÇÃO
  // ==========================================================

  Widget _buildBotaoExecucao(
      BuildContext context,
      Map<String, dynamic> exercicio,
      int numero,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          _abrirExecucao(
            context,
            exercicio,
            numero,
          );
        },
        icon: const Icon(
          Icons.play_arrow_rounded,
        ),
        label: const Text(
          'Iniciar exercício',
        ),
        style: ElevatedButton.styleFrom(
          minimumSize:
          const Size.fromHeight(46),
          backgroundColor:
          const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// Abre a tela de execução interativa.
  ///
  /// A tela recebe:
  /// - o treino completo;
  /// - todos os exercícios;
  /// - o índice do exercício selecionado;
  /// - o callback de conclusão do treino.
  ///
  /// Dessa forma o paciente pode iniciar pelo exercício
  /// escolhido e continuar normalmente pelos exercícios
  /// seguintes.
  void _abrirExecucao(
      BuildContext context,
      Map<String, dynamic> exercicio,
      int numero,
      ) {
    final exercicios =
    treinoService.obterExercicios(treino);

    final indice = numero - 1;

    if (exercicios.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return TreinoExecucaoPage(
            treino: treino,
            exercicios: exercicios,
            exercicioInicial: indice.clamp(
              0,
              exercicios.length - 1,
            ),
            onTreinoConcluido:
            onTreinoConcluido,
          );
        },
      ),
    );
  }

  // ==========================================================
  // VÍDEO
  // ==========================================================

  void _mostrarVideoDisponivel(
      BuildContext context,
      String url,
      ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Vídeo do exercício',
          ),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // SEM EXERCÍCIOS
  // ==========================================================

  Widget _buildSemExercicios() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 42,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 12),
          Text(
            'Nenhum exercício cadastrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Este treino ainda não possui exercícios '
                'disponíveis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TIPO DO TREINO
  // ==========================================================

  _TipoTreinoInfo _tipoInfo(
      String tipo,
      ) {
    switch (tipo) {
      case 'corrida':
        return const _TipoTreinoInfo(
          nome: 'Corrida',
          icone: Icons.directions_run_rounded,
          cor: Color(0xFF2563EB),
        );

      case 'cardio':
        return const _TipoTreinoInfo(
          nome: 'Cardio',
          icone: Icons.monitor_heart_rounded,
          cor: Color(0xFFDC2626),
        );

      case 'academia':
        return const _TipoTreinoInfo(
          nome: 'Academia',
          icone: Icons.fitness_center_rounded,
          cor: Color(0xFF16A34A),
        );

      default:
        return const _TipoTreinoInfo(
          nome: 'Treino',
          icone:
          Icons.sports_gymnastics_rounded,
          cor: Color(0xFF7C3AED),
        );
    }
  }

  // ==========================================================
  // DATA
  // ==========================================================

  String _formatarPeriodo(
      String? inicio,
      String? fim,
      ) {
    final dataInicio = _formatarData(inicio);
    final dataFim = _formatarData(fim);

    if (dataInicio.isEmpty &&
        dataFim.isEmpty) {
      return 'Período não informado';
    }

    if (dataInicio.isEmpty) {
      return 'Até $dataFim';
    }

    if (dataFim.isEmpty) {
      return 'A partir de $dataInicio';
    }

    if (dataInicio == dataFim) {
      return dataInicio;
    }

    return '$dataInicio até $dataFim';
  }

  String _formatarData(
      String? data,
      ) {
    if (data == null || data.trim().isEmpty) {
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
  // TEXTO
  // ==========================================================

  String _formatarTexto(
      String valor,
      ) {
    if (valor.isEmpty) {
      return '';
    }

    return valor
        .split('_')
        .map(
          (parte) {
        if (parte.isEmpty) {
          return parte;
        }

        return parte[0].toUpperCase() +
            parte.substring(1);
      },
    )
        .join(' ');
  }
}

// ============================================================
// TIPO DO TREINO
// ============================================================

class _TipoTreinoInfo {
  const _TipoTreinoInfo({
    required this.nome,
    required this.icone,
    required this.cor,
  });

  final String nome;
  final IconData icone;
  final Color cor;
}

// ============================================================
// PARÂMETRO DO EXERCÍCIO
// ============================================================

class _ParametroItem extends StatelessWidget {
  const _ParametroItem({
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  final IconData icone;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 92,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icone,
            size: 17,
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}