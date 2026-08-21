import 'dart:async';

import 'package:flutter/material.dart';

/// Tela interativa para execução de um treino.
///
/// Responsabilidades:
/// - controlar o exercício atual;
/// - controlar a série atual;
/// - controlar o tempo de execução;
/// - controlar o descanso;
/// - avançar entre séries;
/// - avançar entre exercícios;
/// - finalizar o treino;
/// - informar ao responsável pela navegação quando o treino
///   for concluído.
///
/// Os valores de séries, repetições, carga, tempo e descanso
/// são recebidos do backend através do mapa do exercício.
///
/// Esta tela não realiza diretamente requisições HTTP.
/// O registro persistente da execução é realizado pelo
/// responsável pela navegação através do callback
/// [onTreinoConcluido].
class TreinoExecucaoPage extends StatefulWidget {
  const TreinoExecucaoPage({
    super.key,
    required this.treino,
    required this.exercicios,
    this.exercicioInicial = 0,
    this.onTreinoConcluido,
  });

  final Map<String, dynamic> treino;
  final List<Map<String, dynamic>> exercicios;
  final int exercicioInicial;

  /// Callback chamado somente quando todos os exercícios
  /// e todas as séries do treino forem concluídos.
  ///
  /// Parâmetros:
  /// - primeiro: ID do treino;
  /// - segundo: tempo total da execução em segundos.
  final Future<void> Function(
      int treinoId,
      int tempoTotalSegundos,
      )? onTreinoConcluido;

  @override
  State<TreinoExecucaoPage> createState() =>
      _TreinoExecucaoPageState();
}

class _TreinoExecucaoPageState
    extends State<TreinoExecucaoPage> {
  Timer? _timer;

  late int _indiceExercicio;

  int _serieAtual = 1;

  int _segundosRestantes = 0;

  /// Tempo total efetivamente decorrido durante a execução.
  int _tempoTotalExecucao = 0;

  bool _executando = false;
  bool _emDescanso = false;
  bool _treinoConcluido = false;
  bool _registrandoExecucao = false;
  bool _execucaoRegistrada = false;

  DateTime? _inicioExecucao;

  @override
  void initState() {
    super.initState();

    if (widget.exercicios.isEmpty) {
      _indiceExercicio = 0;
    } else {
      _indiceExercicio = widget.exercicioInicial.clamp(
        0,
        widget.exercicios.length - 1,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // EXERCÍCIO ATUAL
  // ==========================================================

  Map<String, dynamic>? get _exercicioAtual {
    if (_indiceExercicio < 0 ||
        _indiceExercicio >= widget.exercicios.length) {
      return null;
    }

    return widget.exercicios[_indiceExercicio];
  }

  int get _totalExercicios => widget.exercicios.length;

  int get _numeroExercicio => _indiceExercicio + 1;

  int get _totalSeries {
    final valor = _exercicioAtual?['series'];

    if (valor is int) {
      return valor > 0 ? valor : 1;
    }

    return int.tryParse(
      valor?.toString() ?? '',
    ) ??
        1;
  }

  int get _descanso {
    final valor = _exercicioAtual?['descanso'];

    if (valor is int) {
      return valor > 0 ? valor : 0;
    }

    return int.tryParse(
      valor?.toString() ?? '',
    ) ??
        0;
  }

  int get _tempoExercicio {
    final valor = _exercicioAtual?['tempo'];

    if (valor is int) {
      return valor > 0 ? valor : 0;
    }

    if (valor is double) {
      return valor > 0 ? valor.round() : 0;
    }

    return int.tryParse(
      valor?.toString() ?? '',
    ) ??
        0;
  }

  int get _tempoExercicioSegundos {
    final tempo = _tempoExercicio;

    if (tempo <= 0) {
      return 0;
    }

    switch (_unidadeTempo.toLowerCase().trim()) {
      case 'min':
      case 'm':
      case 'minuto':
      case 'minutos':
        return tempo * 60;

      case 'seg':
      case 's':
      case 'segundo':
      case 'segundos':
        return tempo;

      default:
        return tempo;
    }
  }

  String get _nomeExercicio {
    return _exercicioAtual?['nome']?.toString() ??
        'Exercício';
  }

  String get _repeticoes {
    final valor = _exercicioAtual?['repeticoes'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  String get _carga {
    final valor = _exercicioAtual?['carga'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  String get _grupoMuscular {
    final valor = _exercicioAtual?['grupo_muscular'];

    return valor?.toString().trim() ?? '';
  }

  String get _equipamento {
    final valor = _exercicioAtual?['equipamento'];

    return valor?.toString().trim() ?? '';
  }

  String get _tipoExecucao {
    final valor = _exercicioAtual?['tipo_execucao'];

    return valor?.toString().trim() ?? '';
  }

  String get _unidadeTempo {
    final valor = _exercicioAtual?['unidade_tempo'];

    final texto = valor?.toString().trim() ?? '';

    return texto.isEmpty ? 'seg' : texto;
  }

  String? get _imagemUrl {
    final valor = _exercicioAtual?['imagem_url'];

    if (valor == null) {
      return null;
    }

    final texto = valor.toString().trim();

    return texto.isEmpty ? null : texto;
  }

  // ==========================================================
  // ID DO TREINO
  // ==========================================================

  int? get _treinoId {
    final valor = widget.treino['id'];

    if (valor is int) {
      return valor;
    }

    return int.tryParse(
      valor?.toString() ?? '',
    );
  }

  // ==========================================================
  // CONTROLE PRINCIPAL
  // ==========================================================

  void _iniciarExercicio() {
    if (_treinoConcluido || _emDescanso) {
      return;
    }

    _iniciarContagemExecucao();

    final tempoEmSegundos = _tempoExercicioSegundos;

    if (tempoEmSegundos > 0) {
      _iniciarCronometro(
        tempoEmSegundos,
        aoFinalizar: _finalizarExecucao,
      );
      return;
    }

    setState(() {
      _executando = true;
    });
  }

  void _iniciarContagemExecucao() {
    if (_inicioExecucao != null) {
      return;
    }

    _inicioExecucao = DateTime.now();
  }

  void _iniciarCronometro(
      int segundos, {
        required VoidCallback aoFinalizar,
      }) {
    _timer?.cancel();

    if (segundos <= 0) {
      aoFinalizar();
      return;
    }

    setState(() {
      _segundosRestantes = segundos;
      _executando = true;
      _emDescanso = false;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        _incrementarTempoExecucao();

        if (_segundosRestantes <= 1) {
          timer.cancel();

          setState(() {
            _segundosRestantes = 0;
          });

          aoFinalizar();
          return;
        }

        setState(() {
          _segundosRestantes--;
        });
      },
    );
  }

  void _incrementarTempoExecucao() {
    if (_inicioExecucao == null) {
      return;
    }

    final decorrido = DateTime.now()
        .difference(_inicioExecucao!)
        .inSeconds;

    if (decorrido > _tempoTotalExecucao) {
      _tempoTotalExecucao = decorrido;
    }
  }

  void _finalizarExecucao() {
    if (!mounted) {
      return;
    }

    _atualizarTempoTotal();

    setState(() {
      _executando = false;
    });

    _mostrarConclusaoSerie();
  }

  void _concluirSerie() {
    _timer?.cancel();

    _atualizarTempoTotal();

    if (!mounted) {
      return;
    }

    setState(() {
      _executando = false;
    });

    _mostrarConclusaoSerie();
  }

  void _atualizarTempoTotal() {
    if (_inicioExecucao == null) {
      return;
    }

    final decorrido = DateTime.now()
        .difference(_inicioExecucao!)
        .inSeconds;

    if (decorrido > _tempoTotalExecucao) {
      _tempoTotalExecucao = decorrido;
    }
  }

  // ==========================================================
  // CONCLUSÃO DA SÉRIE
  // ==========================================================

  void _mostrarConclusaoSerie() {
    if (_serieAtual < _totalSeries) {
      _iniciarDescanso();
      return;
    }

    _finalizarExercicio();
  }

  void _iniciarDescanso() {
    final descanso = _descanso;

    if (descanso <= 0) {
      _proximaSerie();
      return;
    }

    _timer?.cancel();

    setState(() {
      _emDescanso = true;
      _executando = false;
      _segundosRestantes = descanso;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_segundosRestantes <= 1) {
          timer.cancel();

          setState(() {
            _segundosRestantes = 0;
            _emDescanso = false;
          });

          _proximaSerie();
          return;
        }

        setState(() {
          _segundosRestantes--;
        });
      },
    );
  }

  void _pularDescanso() {
    _timer?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _segundosRestantes = 0;
      _emDescanso = false;
    });

    _proximaSerie();
  }

  void _proximaSerie() {
    if (!mounted) {
      return;
    }

    if (_serieAtual >= _totalSeries) {
      _finalizarExercicio();
      return;
    }

    setState(() {
      _serieAtual++;
      _executando = false;
      _emDescanso = false;
      _segundosRestantes = 0;
    });
  }

  // ==========================================================
  // PRÓXIMO EXERCÍCIO
  // ==========================================================

  void _finalizarExercicio() {
    _timer?.cancel();

    if (_indiceExercicio >=
        widget.exercicios.length - 1) {
      _finalizarTreino();
      return;
    }

    setState(() {
      _indiceExercicio++;
      _serieAtual = 1;
      _executando = false;
      _emDescanso = false;
      _segundosRestantes = 0;
    });

    _mostrarProximoExercicio();
  }

  void _mostrarProximoExercicio() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Próximo exercício: $_nomeExercicio',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ==========================================================
  // FINALIZAÇÃO DO TREINO
  // ==========================================================

  Future<void> _finalizarTreino() async {
    if (_treinoConcluido || _registrandoExecucao) {
      return;
    }

    _timer?.cancel();

    _atualizarTempoTotal();

    if (!mounted) {
      return;
    }

    setState(() {
      _treinoConcluido = true;
      _executando = false;
      _emDescanso = false;
      _segundosRestantes = 0;
      _registrandoExecucao = true;
    });

    await _registrarExecucao();
  }

  Future<void> _registrarExecucao() async {
    if (_execucaoRegistrada) {
      return;
    }

    final treinoId = _treinoId;

    if (treinoId == null) {
      if (mounted) {
        setState(() {
          _registrandoExecucao = false;
        });
      }
      return;
    }

    final callback = widget.onTreinoConcluido;

    if (callback == null) {
      if (mounted) {
        setState(() {
          _registrandoExecucao = false;
        });
      }
      return;
    }

    try {
      await callback(
        treinoId,
        _tempoTotalExecucao,
      );

      _execucaoRegistrada = true;

      if (!mounted) {
        return;
      }

      setState(() {
        _registrandoExecucao = false;
      });
    } catch (e) {
      _execucaoRegistrada = false;

      if (!mounted) {
        return;
      }

      setState(() {
        _registrandoExecucao = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'O treino foi concluído, mas não foi possível '
                  'registrar a execução.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
    }
  }

  // ==========================================================
  // PAUSAR
  // ==========================================================

  void _pausar() {
    _timer?.cancel();

    _atualizarTempoTotal();

    if (!mounted) {
      return;
    }

    setState(() {
      _executando = false;
    });
  }

  // ==========================================================
  // FORMATADORES
  // ==========================================================

  String _formatarTempo(int segundos) {
    final minutos = segundos ~/ 60;
    final segundosRestantes = segundos % 60;

    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundosRestantes.toString().padLeft(2, '0')}';
  }

  String _formatarUnidade(String valor) {
    switch (valor.toLowerCase()) {
      case 'min':
      case 'm':
      case 'minuto':
      case 'minutos':
        return 'min';

      case 'seg':
      case 's':
      case 'segundo':
      case 'segundos':
        return 'seg';

      default:
        return valor;
    }
  }

  String _formatarTexto(String valor) {
    if (valor.trim().isEmpty) {
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

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (widget.exercicios.isEmpty) {
      return _buildSemExercicios();
    }

    if (_treinoConcluido) {
      return _buildTreinoConcluido();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Execução do treino',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            30,
          ),
          children: [
            _buildProgresso(),
            const SizedBox(height: 14),
            _buildExercicio(),
            const SizedBox(height: 16),
            if (_emDescanso)
              _buildDescanso()
            else
              _buildControle(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PROGRESSO
  // ==========================================================

  Widget _buildProgresso() {
    final progresso = _totalExercicios == 0
        ? 0.0
        : _numeroExercicio / _totalExercicios;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progresso do treino',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                '$_numeroExercicio/$_totalExercicios',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
              const Color(0xFFE2E8F0),
              valueColor:
              const AlwaysStoppedAnimation<Color>(
                Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EXERCÍCIO
  // ==========================================================

  Widget _buildExercicio() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_imagemUrl != null) _buildImagem(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'EXERCÍCIO $_numeroExercicio',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _nomeExercicio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (_grupoMuscular.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _grupoMuscular,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildSerieAtual(),
                const SizedBox(height: 16),
                _buildParametrosExecucao(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagem() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 8,
        child: Image.network(
          _imagemUrl!,
          fit: BoxFit.cover,
          errorBuilder: (
              context,
              error,
              stackTrace,
              ) {
            return Container(
              color: const Color(0xFFF1F5F9),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 42,
                color: Color(0xFF94A3B8),
              ),
            );
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
              child: const CircularProgressIndicator(
                strokeWidth: 2,
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // SÉRIE
  // ==========================================================

  Widget _buildSerieAtual() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'SÉRIE ATUAL',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF15803D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_serieAtual / $_totalSeries',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PARÂMETROS
  // ==========================================================

  Widget _buildParametrosExecucao() {
    final itens = <Widget>[];

    if (_repeticoes.isNotEmpty) {
      itens.add(
        _InfoExecucao(
          icone:
          Icons.format_list_numbered_rounded,
          titulo: 'Repetições',
          valor: _repeticoes,
        ),
      );
    }

    if (_carga.isNotEmpty) {
      itens.add(
        _InfoExecucao(
          icone: Icons.fitness_center_rounded,
          titulo: 'Carga',
          valor: _carga,
        ),
      );
    }

    if (_tempoExercicio > 0) {
      itens.add(
        _InfoExecucao(
          icone: Icons.timer_outlined,
          titulo: 'Tempo',
          valor:
          '$_tempoExercicio '
              '${_formatarUnidade(_unidadeTempo)}',
        ),
      );
    }

    if (_descanso > 0) {
      itens.add(
        _InfoExecucao(
          icone:
          Icons.hourglass_bottom_rounded,
          titulo: 'Descanso',
          valor: _formatarTempo(_descanso),
        ),
      );
    }

    if (_equipamento.isNotEmpty) {
      itens.add(
        _InfoExecucao(
          icone:
          Icons.sports_gymnastics_rounded,
          titulo: 'Equipamento',
          valor: _equipamento,
        ),
      );
    }

    if (_tipoExecucao.isNotEmpty) {
      itens.add(
        _InfoExecucao(
          icone:
          Icons.directions_run_rounded,
          titulo: 'Execução',
          valor: _formatarTexto(_tipoExecucao),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: itens,
    );
  }

  // ==========================================================
  // CONTROLE
  // ==========================================================

  Widget _buildControle() {
    return Column(
      children: [
        if (_executando &&
            _tempoExercicioSegundos > 0) ...[
          _buildCronometro(
            titulo: 'Tempo do exercício',
          ),
          const SizedBox(height: 14),
        ],
        if (!_executando)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _iniciarExercicio,
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: Text(
                _tempoExercicioSegundos > 0
                    ? 'Iniciar exercício'
                    : 'Iniciar série',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(54),
                backgroundColor:
                const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        if (_executando) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pausar,
              icon: const Icon(
                Icons.pause_rounded,
              ),
              label: const Text('Pausar'),
              style: OutlinedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(52),
                foregroundColor:
                const Color(0xFF475569),
                side: const BorderSide(
                  color: Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _concluirSerie,
              icon: const Icon(
                Icons.check_rounded,
              ),
              label: const Text(
                'Concluir série',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(52),
                backgroundColor:
                const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================
  // CRONÔMETRO
  // ==========================================================

  Widget _buildCronometro({
    required String titulo,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatarTempo(_segundosRestantes),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DESCANSO
  // ==========================================================

  Widget _buildDescanso() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFED7AA),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.hourglass_bottom_rounded,
              color: Color(0xFFEA580C),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Hora do descanso',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prepare-se para a próxima série.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _formatarTempo(_segundosRestantes),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Color(0xFFC2410C),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pularDescanso,
              style: ElevatedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(50),
                backgroundColor:
                const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Pular descanso',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TREINO CONCLUÍDO
  // ==========================================================

  Widget _buildTreinoConcluido() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Treino concluído',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 58,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Treino concluído!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Parabéns! Você completou todos '
                    'os exercícios deste treino.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              if (_registrandoExecucao)
                const Column(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Registrando seu treino...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                )
              else if (_execucaoRegistrada)
                const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Treino registrado com sucesso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _registrandoExecucao
                      ? null
                      : () async {
                    Navigator.of(context).pop(
                      true,
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                  label: const Text(
                    'Voltar para o treino',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                    const Size.fromHeight(54),
                    backgroundColor:
                    const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SEM EXERCÍCIOS
  // ==========================================================

  Widget _buildSemExercicios() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Execução do treino',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center_outlined,
                size: 58,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 16),
              Text(
                'Nenhum exercício disponível',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Este treino não possui exercícios '
                    'para execução.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INFORMAÇÃO DE EXECUÇÃO
// ============================================================

class _InfoExecucao extends StatelessWidget {
  const _InfoExecucao({
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
        minWidth: 105,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
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
            size: 18,
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