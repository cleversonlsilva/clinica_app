import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Tela interativa para execuÃ§Ã£o de um treino.
///
/// Responsabilidades:
/// - controlar o exercÃ­cio atual;
/// - controlar a sÃ©rie atual;
/// - controlar o tempo de execuÃ§Ã£o;
/// - controlar o descanso;
/// - avanÃ§ar entre sÃ©ries;
/// - avanÃ§ar entre exercÃ­cios;
/// - finalizar o treino;
/// - informar ao responsÃ¡vel pela navegaÃ§Ã£o quando o treino
///   for concluÃ­do.
///
/// Os valores de sÃ©ries, repetiÃ§Ãµes, carga, tempo e descanso
/// sÃ£o recebidos do backend atravÃ©s do mapa do exercÃ­cio.
///
/// Esta tela nÃ£o realiza diretamente requisiÃ§Ãµes HTTP.
/// O registro persistente da execuÃ§Ã£o Ã© realizado pelo
/// responsÃ¡vel pela navegaÃ§Ã£o atravÃ©s do callback
/// [onTreinoConcluido].
class TreinoExecucaoPage extends StatefulWidget {
  const TreinoExecucaoPage({
    super.key,
    required this.treino,
    required this.exercicios,
    this.exercicioInicial = 0,
    this.onTreinoConcluido,
    this.onCorridaConcluida,
  });

  final Map<String, dynamic> treino;
  final List<Map<String, dynamic>> exercicios;
  final int exercicioInicial;

  /// Callback chamado somente quando todos os exercÃ­cios
  /// e todas as sÃ©ries do treino forem concluÃ­dos.
  ///
  /// ParÃ¢metros:
  /// - primeiro: ID do treino;
  /// - segundo: tempo total da execuÃ§Ã£o em segundos.
  final Future<void> Function(
      int treinoId,
      int tempoTotalSegundos,
      )? onTreinoConcluido;

  /// Callback opcional específico para registrar uma corrida.
  ///
  /// Recebe ID do treino, tempo em segundos, distância em metros,
  /// pace médio em minutos/km e a rota com latitude/longitude.
  final Future<void> Function(
      int treinoId,
      int tempoTotalSegundos,
      double distanciaMetros,
      double paceMedio,
      List<Map<String, double>> rota,
      )? onCorridaConcluida;

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

  /// Tempo total efetivamente decorrido durante a execuÃ§Ã£o.
  int _tempoTotalExecucao = 0;

  bool _executando = false;
  bool _emDescanso = false;
  bool _treinoConcluido = false;
  bool _registrandoExecucao = false;
  bool _execucaoRegistrada = false;

  DateTime? _inicioExecucao;

  // ==========================================================
  // CORRIDA / GPS
  // ==========================================================

  StreamSubscription<Position>? _corridaPosicaoSubscription;
  Timer? _corridaTimer;

  DateTime? _corridaInicio;
  Duration _corridaTempoAcumulado = Duration.zero;

  double _corridaDistanciaMetros = 0;
  final List<Map<String, double>> _corridaRota = [];

  bool _corridaPreparando = false;
  bool _corridaEmAndamento = false;
  bool _corridaPausada = false;
  bool _corridaFinalizada = false;

  String? _corridaErro;

  bool get _ehCorrida {
    final tipo = widget.treino['tipo'] ??
        widget.treino['tipo_treino'];

    return tipo?.toString().toLowerCase().trim() == 'corrida';
  }

  int get _corridaTempoSegundos {
    var total = _corridaTempoAcumulado.inSeconds;

    if (_corridaEmAndamento &&
        _corridaInicio != null) {
      total += DateTime.now()
          .difference(_corridaInicio!)
          .inSeconds;
    }

    return total;
  }

  double get _corridaDistanciaKm {
    return _corridaDistanciaMetros / 1000;
  }

  String get _corridaPace {
    if (_corridaDistanciaKm <= 0) {
      return '--:--';
    }

    final minutosPorKm =
        (_corridaTempoSegundos / 60) /
            _corridaDistanciaKm;

    if (!minutosPorKm.isFinite ||
        minutosPorKm <= 0) {
      return '--:--';
    }

    final minutos = minutosPorKm.floor();
    final segundos =
    ((minutosPorKm - minutos) * 60).round();

    if (segundos >= 60) {
      return '${(minutos + 1).toString().padLeft(2, '0')}:00';
    }

    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
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

    if (_ehCorrida) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepararCorrida();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _corridaTimer?.cancel();
    _corridaPosicaoSubscription?.cancel();
    super.dispose();
  }

  // ==========================================================
  // GPS / CORRIDA
  // ==========================================================

  Future<void> _prepararCorrida() async {
    if (!_ehCorrida || !mounted) {
      return;
    }

    setState(() {
      _corridaPreparando = true;
      _corridaErro = null;
    });

    try {
      final servicoAtivo =
      await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        if (!mounted) return;

        setState(() {
          _corridaPreparando = false;
          _corridaErro =
          'O GPS do aparelho está desligado. '
              'Ative a localização e tente novamente.';
        });
        return;
      }

      var permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _corridaPreparando = false;
          _corridaErro = 'Permissão de localização negada.';
        });
        return;
      }

      if (permissao == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _corridaPreparando = false;
          _corridaErro =
          'A localização foi bloqueada nas configurações '
              'do aplicativo.';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _corridaPreparando = false;
        _corridaErro = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _corridaPreparando = false;
        _corridaErro = 'Não foi possível preparar o GPS.';
      });
    }
  }

  Future<void> _abrirConfiguracoesLocalizacao() async {
    await Geolocator.openLocationSettings();
    await _prepararCorrida();
  }

  Future<void> _abrirConfiguracoesAplicativo() async {
    await Geolocator.openAppSettings();
    await _prepararCorrida();
  }

  Future<void> _iniciarCorrida() async {
    if (_corridaEmAndamento ||
        _corridaFinalizada ||
        _corridaPreparando) {
      return;
    }

    await _prepararCorrida();

    if (_corridaErro != null || !mounted) {
      return;
    }

    _corridaInicio = DateTime.now();

    setState(() {
      _corridaEmAndamento = true;
      _corridaPausada = false;
      _corridaErro = null;
    });

    _corridaTimer?.cancel();
    _corridaTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted || !_corridaEmAndamento) {
          return;
        }
        setState(() {});
      },
    );

    await _iniciarRastreamento();
  }

  Future<void> _iniciarRastreamento() async {
    await _corridaPosicaoSubscription?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _corridaPosicaoSubscription =
        Geolocator.getPositionStream(
          locationSettings: settings,
        ).listen(
          _receberPosicao,
          onError: (_) {
            if (!mounted) return;

            setState(() {
              _corridaErro =
              'Não foi possível receber a localização.';
            });
          },
        );
  }

  void _receberPosicao(Position position) {
    if (!_corridaEmAndamento || !mounted) {
      return;
    }

    if (position.latitude == 0 &&
        position.longitude == 0) {
      return;
    }

    final ultima = _corridaRota.isEmpty
        ? null
        : _corridaRota.last;

    if (ultima != null) {
      final distancia = Geolocator.distanceBetween(
        ultima['lat']!,
        ultima['lng']!,
        position.latitude,
        position.longitude,
      );

      // Ignora pequenas oscilações do GPS e saltos
      // incompatíveis com uma corrida normal.
      if (distancia >= 1 && distancia < 1000) {
        _corridaDistanciaMetros += distancia;
      }
    }

    _corridaRota.add({
      'lat': position.latitude,
      'lng': position.longitude,
    });

    if (_corridaRota.length > 5000) {
      _corridaRota.removeAt(0);
    }

    setState(() {});
  }

  void _pausarCorrida() {
    if (!_corridaEmAndamento) {
      return;
    }

    if (_corridaInicio != null) {
      _corridaTempoAcumulado +=
          DateTime.now().difference(_corridaInicio!);
    }

    _corridaInicio = null;
    _corridaTimer?.cancel();
    _corridaPosicaoSubscription?.pause();

    if (!mounted) return;

    setState(() {
      _corridaEmAndamento = false;
      _corridaPausada = true;
    });
  }

  Future<void> _retomarCorrida() async {
    if (_corridaFinalizada || _corridaEmAndamento) {
      return;
    }

    await _prepararCorrida();

    if (_corridaErro != null || !mounted) {
      return;
    }

    _corridaInicio = DateTime.now();

    setState(() {
      _corridaEmAndamento = true;
      _corridaPausada = false;
      _corridaErro = null;
    });

    _corridaTimer?.cancel();
    _corridaTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted || !_corridaEmAndamento) {
          return;
        }
        setState(() {});
      },
    );

    await _iniciarRastreamento();
  }

  Future<void> _finalizarCorrida() async {
    if (_corridaFinalizada) {
      return;
    }

    if (_corridaEmAndamento &&
        _corridaInicio != null) {
      _corridaTempoAcumulado +=
          DateTime.now().difference(_corridaInicio!);
    }

    _corridaInicio = null;
    _corridaTimer?.cancel();
    await _corridaPosicaoSubscription?.cancel();

    if (!mounted) return;

    setState(() {
      _corridaEmAndamento = false;
      _corridaPausada = false;
      _corridaFinalizada = true;
      _tempoTotalExecucao = _corridaTempoSegundos;
      _treinoConcluido = true;
      _registrandoExecucao = true;
    });

    await _registrarExecucao();
  }

  String _formatarDistancia(double km) {
    if (km < 10) {
      return km.toStringAsFixed(2);
    }

    return km.toStringAsFixed(1);
  }

  // ==========================================================
  // EXERCÃCIO ATUAL
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
        'ExercÃ­cio';
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
  // CONCLUSÃƒO DA SÃ‰RIE
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
  // PRÃ“XIMO EXERCÃCIO
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
            'PrÃ³ximo exercÃ­cio: $_nomeExercicio',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ==========================================================
  // FINALIZAÃ‡ÃƒO DO TREINO
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

    if (!_ehCorrida && callback == null) {
      if (mounted) {
        setState(() {
          _registrandoExecucao = false;
        });
      }
      return;
    }

    if (_ehCorrida && widget.onCorridaConcluida == null &&
        callback == null) {
      if (mounted) {
        setState(() {
          _registrandoExecucao = false;
        });
      }
      return;
    }

    try {
      if (_ehCorrida &&
          widget.onCorridaConcluida != null) {
        final distancia = _corridaDistanciaMetros;
        final pace = _corridaDistanciaKm > 0
            ? (_corridaTempoSegundos / 60) /
            _corridaDistanciaKm
            : 0.0;

        await widget.onCorridaConcluida!(
          treinoId,
          _corridaTempoSegundos,
          distancia,
          pace,
          List<Map<String, double>>.from(
            _corridaRota,
          ),
        );
      } else {
        await callback!(
          treinoId,
          _tempoTotalExecucao,
        );
      }

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
              'O treino foi concluÃ­do, mas nÃ£o foi possÃ­vel '
                  'registrar a execuÃ§Ã£o.',
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
    if (_ehCorrida) {
      if (_treinoConcluido) {
        return _buildTreinoConcluido();
      }

      return _buildCorrida();
    }

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
          'ExecuÃ§Ã£o do treino',
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
  // INTERFACE DA CORRIDA
  // ==========================================================

  Widget _buildCorrida() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Corrida',
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
            _buildCabecalhoCorrida(),
            const SizedBox(height: 14),
            _buildMetricasCorrida(),
            const SizedBox(height: 14),
            _buildStatusGps(),
            const SizedBox(height: 16),
            _buildControlesCorrida(),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalhoCorrida() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E2563EB),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(
              Icons.directions_run_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Corrida em execução',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'O aplicativo acompanhará tempo, distância e rota.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricasCorrida() {
    return Row(
      children: [
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.timer_outlined,
            titulo: 'Tempo',
            valor: _formatarTempo(
              _corridaTempoSegundos,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.straighten_rounded,
            titulo: 'Distância',
            valor:
            '${_formatarDistancia(_corridaDistanciaKm)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.speed_rounded,
            titulo: 'Pace',
            valor: _corridaPace,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGps() {
    final erro = _corridaErro;

    if (_corridaPreparando) {
      return _CaixaStatusCorrida(
        icone: Icons.gps_fixed_rounded,
        titulo: 'Preparando GPS',
        mensagem:
        'Solicitando acesso à localização do aparelho...',
        cor: const Color(0xFF2563EB),
        carregando: true,
      );
    }

    if (erro != null) {
      final bloqueado = erro.contains(
        'bloqueada',
      );

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFECACA),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: Color(0xFFDC2626),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'GPS indisponível',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              erro,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF7F1D1D),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (bloqueado)
                  OutlinedButton.icon(
                    onPressed:
                    _abrirConfiguracoesAplicativo,
                    icon: const Icon(
                      Icons.settings_rounded,
                    ),
                    label: const Text(
                      'Abrir configurações',
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _prepararCorrida,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text(
                      'Tentar novamente',
                    ),
                  ),
                if (erro.contains('GPS'))
                  OutlinedButton.icon(
                    onPressed:
                    _abrirConfiguracoesLocalizacao,
                    icon: const Icon(
                      Icons.location_on_rounded,
                    ),
                    label: const Text(
                      'Ativar GPS',
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (_corridaEmAndamento) {
      return const _CaixaStatusCorrida(
        icone: Icons.gps_fixed_rounded,
        titulo: 'GPS ativo',
        mensagem:
        'Sua posição está sendo acompanhada durante a corrida.',
        cor: Color(0xFF16A34A),
      );
    }

    if (_corridaPausada) {
      return const _CaixaStatusCorrida(
        icone: Icons.pause_circle_outline_rounded,
        titulo: 'Corrida pausada',
        mensagem:
        'A rota e o cronômetro estão pausados.',
        cor: Color(0xFFEA580C),
      );
    }

    return const _CaixaStatusCorrida(
      icone: Icons.location_on_rounded,
      titulo: 'GPS pronto',
      mensagem:
      'Tudo pronto. Toque em iniciar para começar o rastreamento.',
      cor: Color(0xFF2563EB),
    );
  }

  Widget _buildControlesCorrida() {
    if (_corridaFinalizada) {
      return const SizedBox.shrink();
    }

    if (_corridaPreparando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_corridaEmAndamento) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pausarCorrida,
              icon: const Icon(
                Icons.pause_rounded,
              ),
              label: const Text(
                'Pausar corrida',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(54),
                backgroundColor:
                const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
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
            child: OutlinedButton.icon(
              onPressed: _confirmarFinalizacaoCorrida,
              icon: const Icon(
                Icons.flag_rounded,
              ),
              label: const Text(
                'Finalizar corrida',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(52),
                foregroundColor:
                const Color(0xFFDC2626),
                side: const BorderSide(
                  color: Color(0xFFFCA5A5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_corridaPausada) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _retomarCorrida,
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: const Text(
                'Retomar corrida',
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmarFinalizacaoCorrida,
              icon: const Icon(
                Icons.flag_rounded,
              ),
              label: const Text(
                'Finalizar corrida',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize:
                const Size.fromHeight(52),
                foregroundColor:
                const Color(0xFFDC2626),
                side: const BorderSide(
                  color: Color(0xFFFCA5A5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _iniciarCorrida,
        icon: const Icon(
          Icons.play_arrow_rounded,
        ),
        label: const Text(
          'Iniciar corrida',
        ),
        style: ElevatedButton.styleFrom(
          minimumSize:
          const Size.fromHeight(56),
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
    );
  }

  Future<void> _confirmarFinalizacaoCorrida() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Finalizar corrida?',
          ),
          content: const Text(
            'A distância, o tempo e a rota registrados '
                'até este momento serão mantidos.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text('Continuar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await _finalizarCorrida();
    }
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
  // EXERCÃCIO
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
                  'EXERCÃCIO $_numeroExercicio',
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
  // SÃ‰RIE
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
            'SÃ‰RIE ATUAL',
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
  // PARÃ‚METROS
  // ==========================================================

  Widget _buildParametrosExecucao() {
    final itens = <Widget>[];

    if (_repeticoes.isNotEmpty) {
      itens.add(
        _InfoExecucao(
          icone:
          Icons.format_list_numbered_rounded,
          titulo: 'RepetiÃ§Ãµes',
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
          titulo: 'ExecuÃ§Ã£o',
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
            titulo: 'Tempo do exercÃ­cio',
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
                    ? 'Iniciar exercÃ­cio'
                    : 'Iniciar sÃ©rie',
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
                'Concluir sÃ©rie',
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
  // CRONÃ”METRO
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
            'Prepare-se para a prÃ³xima sÃ©rie.',
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
  // TREINO CONCLUÃDO
  // ==========================================================

  Widget _buildTreinoConcluido() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Treino concluÃ­do',
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
                'Treino concluÃ­do!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'ParabÃ©ns! VocÃª completou todos '
                    'os exercÃ­cios deste treino.',
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
  // SEM EXERCÃCIOS
  // ==========================================================

  Widget _buildSemExercicios() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'ExecuÃ§Ã£o do treino',
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
                'Nenhum exercÃ­cio disponÃ­vel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Este treino nÃ£o possui exercÃ­cios '
                    'para execuÃ§Ã£o.',
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
// INFORMAÃ‡ÃƒO DE EXECUÃ‡ÃƒO
// ============================================================


// ============================================================
// COMPONENTES DA CORRIDA
// ============================================================

class _MetricaCorrida extends StatelessWidget {
  const _MetricaCorrida({
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icone,
            size: 20,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaixaStatusCorrida extends StatelessWidget {
  const _CaixaStatusCorrida({
    required this.icone,
    required this.titulo,
    required this.mensagem,
    required this.cor,
    this.carregando = false,
  });

  final IconData icone;
  final String titulo;
  final String mensagem;
  final Color cor;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cor.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (carregando)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cor,
              ),
            )
          else
            Icon(
              icone,
              color: cor,
              size: 22,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mensagem,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
