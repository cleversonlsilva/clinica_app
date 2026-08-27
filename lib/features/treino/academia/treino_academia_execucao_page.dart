import 'dart:async';

import 'package:flutter/material.dart';

/// Tela exclusiva para execução de treinos de academia.
///
/// Responsabilidades:
/// - exercícios;
/// - séries;
/// - repetições;
/// - carga;
/// - tempo;
/// - descanso;
/// - conclusão do treino.
///
/// A execução de corrida possui sua própria tela em:
/// corrida/treino_corrida_execucao_page.dart
///
/// A tela não realiza requisições HTTP diretamente.
/// Ao concluir o treino, utiliza [onTreinoConcluido].
class TreinoAcademiaExecucaoPage extends StatefulWidget {
  const TreinoAcademiaExecucaoPage({
    super.key,
    required this.treino,
    required this.exercicios,
    this.exercicioInicial = 0,
    this.onTreinoConcluido,
  });

  final Map<String, dynamic> treino;
  final List<Map<String, dynamic>> exercicios;
  final int exercicioInicial;

  final Future<void> Function(
      int treinoId,
      int tempoTotalSegundos,
      )? onTreinoConcluido;

  @override
  State<TreinoAcademiaExecucaoPage> createState() =>
      _TreinoAcademiaExecucaoPageState();
}

class _TreinoAcademiaExecucaoPageState
    extends State<TreinoAcademiaExecucaoPage> {
  Timer? _timer;

  late int _indiceExercicio;

  int _serieAtual = 1;
  int _segundosRestantes = 0;
  int _tempoTotalExecucao = 0;

  bool _executando = false;
  bool _emDescanso = false;
  bool _treinoConcluido = false;
  bool _registrandoExecucao = false;
  bool _execucaoRegistrada = false;

  int get _totalExercicios => widget.exercicios.length;

  int get _numeroExercicio => _indiceExercicio + 1;

  Map<String, dynamic> get _exercicioAtual {
    if (widget.exercicios.isEmpty ||
        _indiceExercicio < 0 ||
        _indiceExercicio >= widget.exercicios.length) {
      return <String, dynamic>{};
    }

    return widget.exercicios[_indiceExercicio];
  }

  int get _totalSeries {
    final valor = _valor(
      _exercicioAtual,
      const [
        'series',
        'serie',
        'numero_series',
        'quantidade_series',
      ],
    );

    return _int(valor, fallback: 1).clamp(1, 999);
  }

  int get _descanso {
    final valor = _valor(
      _exercicioAtual,
      const [
        'descanso',
        'descanso_segundos',
        'intervalo',
      ],
    );

    return _int(valor);
  }

  int get _tempoExercicio {
    final valorSegundos = _valor(
      _exercicioAtual,
      const [
        'tempo_segundos',
      ],
    );

    if (valorSegundos != null) {
      return _int(valorSegundos);
    }

    final valor = _valor(
      _exercicioAtual,
      const [
        'tempo',
        'duracao',
      ],
    );

    final segundos = _int(valor);

    final unidade = _texto(
      _valor(
        _exercicioAtual,
        const [
          'tempo_unidade',
          'unidade_tempo',
          'unidade',
        ],
      ),
    ).toLowerCase();

    if (unidade.contains('min')) {
      return segundos * 60;
    }

    return segundos;
  }

  String get _nomeExercicio {
    return _texto(
      _valor(
        _exercicioAtual,
        const [
          'nome',
          'exercicio',
          'nome_exercicio',
          'titulo',
        ],
      ),
      fallback: 'Exercício',
    );
  }

  String get _repeticoes {
    final valor = _valor(
      _exercicioAtual,
      const [
        'repeticoes',
        'repeticao',
        'quantidade_repeticoes',
      ],
    );

    if (valor == null) {
      return '—';
    }

    return _texto(
      valor,
      fallback: '—',
    );
  }

  String get _carga {
    final valor = _valor(
      _exercicioAtual,
      const [
        'carga',
        'peso',
        'peso_kg',
      ],
    );

    if (valor == null ||
        _texto(valor).trim().isEmpty) {
      return 'Sem carga';
    }

    return _texto(valor);
  }

  String get _grupoMuscular {
    return _texto(
      _valor(
        _exercicioAtual,
        const [
          'grupo_muscular',
          'grupo',
          'musculo',
        ],
      ),
      fallback: '—',
    );
  }

  String get _equipamento {
    return _texto(
      _valor(
        _exercicioAtual,
        const [
          'equipamento',
          'aparelho',
        ],
      ),
      fallback: '—',
    );
  }

  String get _tipoExecucao {
    return _texto(
      _valor(
        _exercicioAtual,
        const [
          'tipo_execucao',
          'tipo',
          'modo',
        ],
      ),
      fallback: '—',
    );
  }

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

    _segundosRestantes = _tempoExercicio;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarExercicio() {
    if (_treinoConcluido ||
        _registrandoExecucao ||
        _emDescanso ||
        widget.exercicios.isEmpty) {
      return;
    }

    if (!_executando) {
      _executando = true;

      if (_tempoExercicio > 0) {
        _segundosRestantes = _tempoExercicio;
      }

      _iniciarContagemExecucao();
    }

    setState(() {});
  }

  void _iniciarContagemExecucao() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted || !_executando) {
          return;
        }

        setState(() {
          _tempoTotalExecucao++;

          if (_tempoExercicio > 0 &&
              _segundosRestantes > 0) {
            _segundosRestantes--;

            if (_segundosRestantes <= 0) {
              _timer?.cancel();
              _executando = false;
            }
          }
        });
      },
    );
  }

  void _finalizarExecucao() {
    _timer?.cancel();
    _executando = false;
  }

  void _concluirSerie() {
    if (_treinoConcluido ||
        _emDescanso ||
        _registrandoExecucao) {
      return;
    }

    _finalizarExecucao();

    if (_serieAtual < _totalSeries) {
      _mostrarConclusaoSerie();
      return;
    }

    _finalizarExercicio();
  }

  void _mostrarConclusaoSerie() {
    if (!mounted) {
      return;
    }

    final descanso = _descanso;

    if (descanso > 0) {
      _iniciarDescanso();
      return;
    }

    _proximaSerie();
  }

  void _iniciarDescanso() {
    _timer?.cancel();

    final descanso = _descanso;

    if (descanso <= 0) {
      _proximaSerie();
      return;
    }

    setState(() {
      _emDescanso = true;
      _executando = false;
      _segundosRestantes = descanso;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          if (_segundosRestantes > 0) {
            _segundosRestantes--;
          }

          if (_segundosRestantes <= 0) {
            _timer?.cancel();
            _emDescanso = false;
          }
        });

        if (_segundosRestantes <= 0) {
          _proximaSerie();
        }
      },
    );
  }

  void _pularDescanso() {
    _timer?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _emDescanso = false;
      _segundosRestantes = _tempoExercicio;
    });

    _proximaSerie();
  }

  void _proximaSerie() {
    if (!mounted) {
      return;
    }

    final proximaSerie = _serieAtual + 1;

    if (proximaSerie > _totalSeries) {
      _finalizarExercicio();
      return;
    }

    setState(() {
      _serieAtual = proximaSerie;
      _segundosRestantes = _tempoExercicio;
      _executando = false;
    });
  }

  void _finalizarExercicio() {
    _timer?.cancel();

    if (_indiceExercicio >=
        widget.exercicios.length - 1) {
      _finalizarTreino();
      return;
    }

    setState(() {
      _executando = false;
      _emDescanso = false;
      _serieAtual = 1;
      _indiceExercicio++;
      _segundosRestantes = _tempoExercicio;
    });
  }

  Future<void> _finalizarTreino() async {
    if (_treinoConcluido ||
        _registrandoExecucao) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _executando = false;
      _emDescanso = false;
      _treinoConcluido = true;
    });

    await _registrarExecucao();
  }

  Future<void> _registrarExecucao() async {
    if (_execucaoRegistrada ||
        _registrandoExecucao) {
      return;
    }

    final treinoId = _int(
      widget.treino['id'],
    );

    if (treinoId <= 0) {
      if (mounted) {
        setState(() {
          _registrandoExecucao = false;
        });
      }
      return;
    }

    setState(() {
      _registrandoExecucao = true;
    });

    try {
      final callback = widget.onTreinoConcluido;

      if (callback != null) {
        await callback(
          treinoId,
          _tempoTotalExecucao,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _execucaoRegistrada = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _treinoConcluido = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível registrar a execução: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _registrandoExecucao = false;
        });
      }
    }
  }

  void _pausar() {
    if (!_executando) {
      return;
    }

    _finalizarExecucao();
    setState(() {});
  }

  String _formatarTempo(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    final seg = segundos % 60;

    if (horas > 0) {
      return '${horas.toString().padLeft(2, '0')}:'
          '${minutos.toString().padLeft(2, '0')}:'
          '${seg.toString().padLeft(2, '0')}';
    }

    return '${minutos.toString().padLeft(2, '0')}:'
        '${seg.toString().padLeft(2, '0')}';
  }

  String _formatarTempoParametro(int segundos) {
    if (segundos < 60) {
      return '${segundos}s';
    }

    final minutos = segundos ~/ 60;
    final segundosRestantes = segundos % 60;

    if (segundosRestantes == 0) {
      return '${minutos}min';
    }

    return '${minutos}min '
        '${segundosRestantes}s';
  }

  String _formatarTexto(String valor) {
    return valor
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map(
          (e) => e[0].toUpperCase() + e.substring(1),
    )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercicios.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Execução do treino'),
        ),
        body: _buildSemExercicios(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Execução do treino',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: SafeArea(
        child: _treinoConcluido
            ? _buildTreinoConcluido()
            : _emDescanso
            ? _buildDescanso()
            : ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            _buildProgresso(),
            const SizedBox(height: 14),
            _buildExercicio(),
            const SizedBox(height: 14),
            _buildSerieAtual(),
            const SizedBox(height: 14),
            _buildParametrosExecucao(),
            const SizedBox(height: 18),
            _buildControle(),
            const SizedBox(height: 18),
            _buildCronometro(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgresso() {
    final total = _totalExercicios;
    final atual = _numeroExercicio.clamp(1, total);

    final progresso = total <= 0
        ? 0.0
        : atual / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progresso',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Text(
                '$atual / $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: const Color(
                0xFFE5E7EB,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercicio() {
    final imagem = _texto(
      _valor(
        _exercicioAtual,
        const [
          'imagem_url',
          'imagem',
          'foto_url',
        ],
      ),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (imagem.isNotEmpty)
            Image.network(
              imagem,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              18,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _nomeExercicio,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                if (_grupoMuscular != '—')
                  _InfoLinha(
                    icone:
                    Icons.fitness_center_rounded,
                    titulo: 'Grupo muscular',
                    valor: _formatarTexto(
                      _grupoMuscular,
                    ),
                  ),
                if (_equipamento != '—')
                  _InfoLinha(
                    icone:
                    Icons.sports_gymnastics_rounded,
                    titulo: 'Equipamento',
                    valor: _formatarTexto(
                      _equipamento,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerieAtual() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.10,
              ),
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: Text(
              '$_serieAtual',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Série atual',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'de $_totalSeries',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParametrosExecucao() {
    final itens = <Widget>[
      _Parametro(
        icone: Icons.repeat_rounded,
        titulo: 'Repetições',
        valor: _repeticoes,
      ),
      _Parametro(
        icone: Icons.monitor_weight_outlined,
        titulo: 'Carga',
        valor: _carga,
      ),
    ];

    if (_tempoExercicio > 0) {
      itens.add(
        _Parametro(
          icone: Icons.timer_outlined,
          titulo: 'Tempo',
          valor: _formatarTempoParametro(
            _tempoExercicio,
          ),
        ),
      );
    }

    if (_descanso > 0) {
      itens.add(
        _Parametro(
          icone:
          Icons.pause_circle_outline_rounded,
          titulo: 'Descanso',
          valor: '${_descanso}s',
        ),
      );
    }

    if (_tipoExecucao != '—') {
      itens.add(
        _Parametro(
          icone:
          Icons.directions_run_rounded,
          titulo: 'Execução',
          valor: _formatarTexto(
            _tipoExecucao,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: itens,
    );
  }

  Widget _buildControle() {
    if (_registrandoExecucao) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        if (_executando)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pausar,
              icon: const Icon(
                Icons.pause_rounded,
              ),
              label: const Text('Pausar'),
              style: FilledButton.styleFrom(
                minimumSize:
                const Size.fromHeight(54),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _iniciarExercicio,
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: Text(
                _serieAtual == 1 &&
                    _tempoTotalExecucao == 0
                    ? 'Iniciar exercício'
                    : 'Continuar',
              ),
              style: FilledButton.styleFrom(
                minimumSize:
                const Size.fromHeight(54),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _concluirSerie,
            icon: const Icon(
              Icons.check_rounded,
            ),
            label: const Text(
              'Concluir série',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize:
              const Size.fromHeight(52),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCronometro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'Tempo total',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatarTempo(
              _tempoTotalExecucao,
            ),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          if (_tempoExercicio > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Tempo da série: '
                  '${_formatarTempo(_segundosRestantes)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescanso() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 64,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 18),
            const Text(
              'Descanso',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _formatarTempo(
                _segundosRestantes,
              ),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pularDescanso,
                icon: const Icon(
                  Icons.skip_next_rounded,
                ),
                label: const Text(
                  'Pular descanso',
                ),
                style: FilledButton.styleFrom(
                  minimumSize:
                  const Size.fromHeight(54),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreinoConcluido() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius:
                BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Treino concluído!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tempo total: '
                  '${_formatarTempo(_tempoTotalExecucao)}',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            if (_registrandoExecucao)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  style:
                  FilledButton.styleFrom(
                    minimumSize:
                    const Size.fromHeight(54),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Voltar',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemExercicios() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center_outlined,
              size: 58,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum exercício disponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Este treino não possui exercícios '
                  'para execução.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  dynamic _valor(
      Map<String, dynamic> mapa,
      List<String> chaves,
      ) {
    for (final chave in chaves) {
      if (mapa.containsKey(chave) &&
          mapa[chave] != null) {
        return mapa[chave];
      }
    }

    return null;
  }

  int _int(
      dynamic valor, {
        int fallback = 0,
      }) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.round();
    }

    final texto =
        valor?.toString().trim() ?? '';

    if (texto.isEmpty) {
      return fallback;
    }

    return int.tryParse(texto) ??
        double.tryParse(texto)?.round() ??
        fallback;
  }

  String _texto(
      dynamic valor, {
        String fallback = '',
      }) {
    if (valor == null) {
      return fallback;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return fallback;
    }

    return texto;
  }
}

class _Parametro extends StatelessWidget {
  const _Parametro({
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
        minWidth: 135,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius:
        BorderRadius.circular(14),
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
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLinha extends StatelessWidget {
  const _InfoLinha({
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  final IconData icone;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(
            icone,
            size: 17,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Text(
            '$titulo: ',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
