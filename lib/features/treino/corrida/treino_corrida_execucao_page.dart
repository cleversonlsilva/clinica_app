import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../treino_service.dart';

/// Tela exclusiva para execução de treinos do tipo corrida.
///
/// Responsabilidades:
/// - preparar e validar o GPS;
/// - iniciar, pausar e retomar a corrida;
/// - acompanhar tempo e distância;
/// - calcular pace médio;
/// - registrar a rota percorrida;
/// - finalizar a corrida;
/// - registrar a execução através do [TreinoService].
class TreinoCorridaExecucaoPage extends StatefulWidget {
  const TreinoCorridaExecucaoPage({
    super.key,
    required this.treino,
    required this.treinoService,
  });

  final Map<String, dynamic> treino;
  final TreinoService treinoService;

  @override
  State<TreinoCorridaExecucaoPage> createState() =>
      _TreinoCorridaExecucaoPageState();
}

class _TreinoCorridaExecucaoPageState
    extends State<TreinoCorridaExecucaoPage> {
  StreamSubscription<Position>? _posicaoSubscription;
  Timer? _timer;

  DateTime? _inicio;
  Duration _tempoAcumulado = Duration.zero;

  double _distanciaMetros = 0;
  final List<Map<String, double>> _rota = [];

  bool _preparando = false;
  bool _emAndamento = false;
  bool _pausada = false;
  bool _finalizada = false;
  bool _registrando = false;
  bool _registrada = false;

  String? _erro;

  int get _tempoSegundos {
    var total = _tempoAcumulado.inSeconds;

    if (_emAndamento && _inicio != null) {
      total += DateTime.now().difference(_inicio!).inSeconds;
    }

    return total;
  }

  double get _distanciaKm => _distanciaMetros / 1000;

  String get _pace {
    if (_distanciaKm < 0.1) {
      return '--:--';
    }

    final minutosPorKm =
        (_tempoSegundos / 60) / _distanciaKm;

    if (!minutosPorKm.isFinite || minutosPorKm <= 0) {
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

  int? get _treinoId {
    final valor = widget.treino['id'];

    if (valor is int) {
      return valor;
    }

    return int.tryParse(
      valor?.toString() ?? '',
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepararCorrida();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _posicaoSubscription?.cancel();
    super.dispose();
  }

  // ==========================================================
  // GPS
  // ==========================================================

  Future<void> _prepararCorrida() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _preparando = true;
      _erro = null;
    });

    try {
      final servicoAtivo =
      await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        if (!mounted) return;

        setState(() {
          _preparando = false;
          _erro =
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
          _preparando = false;
          _erro = 'Permissão de localização negada.';
        });
        return;
      }

      if (permissao == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _preparando = false;
          _erro =
          'A localização foi bloqueada nas configurações '
              'do aplicativo.';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _preparando = false;
        _erro = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _preparando = false;
        _erro = 'Não foi possível preparar o GPS.';
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

  // ==========================================================
  // CONTROLE DA CORRIDA
  // ==========================================================

  Future<void> _iniciarCorrida() async {
    if (_emAndamento || _finalizada || _preparando) {
      return;
    }

    await _prepararCorrida();

    if (_erro != null || !mounted) {
      return;
    }

    _inicio = DateTime.now();

    setState(() {
      _emAndamento = true;
      _pausada = false;
      _erro = null;
    });

    _iniciarTimer();
    await _iniciarRastreamento();
  }

  void _iniciarTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted || !_emAndamento) {
          return;
        }

        setState(() {});
      },
    );
  }

  Future<void> _iniciarRastreamento() async {
    await _posicaoSubscription?.cancel();

    try {
      // ==========================================================
      // RASTREAMENTO CONTÍNUO
      // ==========================================================
      //
      // O stream é iniciado antes da solicitação de uma posição
      // imediata. Assim, a corrida não fica dependente da resposta
      // de getCurrentPosition() para começar a receber eventos.

      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig:
        const ForegroundNotificationConfig(
          notificationTitle: 'Nexo Saúde',
          notificationText:
          'A corrida está sendo acompanhada em segundo plano.',
          notificationChannelName: 'Rastreamento de corrida',
          setOngoing: true,
        ),
      );

      _posicaoSubscription =
          Geolocator.getPositionStream(
            locationSettings: settings,
          ).listen(
            _receberPosicao,
            onError: (erro) {
              if (!mounted) {
                return;
              }

              debugPrint(
                '[CORRIDA][GPS] Erro no stream: $erro',
              );

              setState(() {
                _erro =
                'Não foi possível receber a localização.';
              });
            },
          );

      // ==========================================================
      // PRIMEIRA POSIÇÃO IMEDIATA
      // ==========================================================
      //
      // Esta chamada é complementar. Se demorar ou falhar, o
      // stream já estará ativo e o cronômetro continuará normal.

      try {
        final posicaoInicial =
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        if (mounted && _emAndamento) {
          _receberPosicao(posicaoInicial);
        }
      } catch (erroInicial) {
        debugPrint(
          '[CORRIDA][GPS] '
              'Não foi possível obter a posição inicial: '
              '$erroInicial',
        );
      }
    } catch (erro) {
      debugPrint(
        '[CORRIDA][GPS] Erro ao iniciar rastreamento: $erro',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _erro =
        'Não foi possível iniciar o rastreamento GPS.';
      });
    }
  }

  void _receberPosicao(Position position) {
    if (!_emAndamento || !mounted) {
      return;
    }

    debugPrint(
      '[CORRIDA][GPS] '
          'lat=${position.latitude} '
          'lng=${position.longitude} '
          'accuracy=${position.accuracy} '
          'speed=${position.speed}',
    );

    if (position.latitude == 0 &&
        position.longitude == 0) {
      debugPrint(
        '[CORRIDA][GPS] Posição inválida: coordenadas 0,0.',
      );

      return;
    }

    // ==========================================================
    // PRECISÃO GPS
    // ==========================================================

    if (position.accuracy.isFinite &&
        position.accuracy > 50) {
      debugPrint(
        '[CORRIDA][GPS] Posição descartada '
            'por baixa precisão: ${position.accuracy}m',
      );

      return;
    }

    final pontoAtual = <String, double>{
      'lat': position.latitude,
      'lng': position.longitude,
    };

    // ==========================================================
    // PRIMEIRO PONTO
    // ==========================================================

    if (_rota.isEmpty) {
      _rota.add(pontoAtual);

      debugPrint(
        '[CORRIDA][GPS] Primeiro ponto registrado.',
      );

      setState(() {});
      return;
    }

    // ==========================================================
    // DISTÂNCIA ENTRE OS PONTOS
    // ==========================================================

    final ultima = _rota.last;

    final distancia = Geolocator.distanceBetween(
      ultima['lat']!,
      ultima['lng']!,
      position.latitude,
      position.longitude,
    );

    debugPrint(
      '[CORRIDA][GPS] '
          'distancia_desde_ultimo_ponto='
          '${distancia.toStringAsFixed(2)}m',
    );

    // ==========================================================
    // FILTRO DE OSCILAÇÃO
    // ==========================================================

    const distanciaMinimaMetros = 2.0;

    if (distancia < distanciaMinimaMetros) {
      debugPrint(
        '[CORRIDA][GPS] Movimento menor que '
            '$distanciaMinimaMetros m. Ignorado.',
      );

      return;
    }

    // ==========================================================
    // FILTRO DE SALTO GPS
    // ==========================================================

    const distanciaMaximaMetros = 500.0;

    if (distancia > distanciaMaximaMetros) {
      debugPrint(
        '[CORRIDA][GPS] Salto GPS descartado: '
            '${distancia.toStringAsFixed(2)}m',
      );

      return;
    }

    // ==========================================================
    // REGISTRA DISTÂNCIA
    // ==========================================================

    _distanciaMetros += distancia;

    _rota.add(pontoAtual);

    debugPrint(
      '[CORRIDA][GPS] '
          'distancia_total='
          '${_distanciaMetros.toStringAsFixed(2)}m '
          'pontos=${_rota.length}',
    );

    // ==========================================================
    // LIMITE DE PONTOS
    // ==========================================================

    if (_rota.length > 5000) {
      _rota.removeAt(0);
    }

    setState(() {});
  }

  void _pausarCorrida() {
    if (!_emAndamento) {
      return;
    }

    if (_inicio != null) {
      _tempoAcumulado +=
          DateTime.now().difference(_inicio!);
    }

    _inicio = null;
    _timer?.cancel();
    _posicaoSubscription?.pause();

    if (!mounted) return;

    setState(() {
      _emAndamento = false;
      _pausada = true;
    });
  }

  Future<void> _retomarCorrida() async {
    if (_finalizada || _emAndamento) {
      return;
    }

    await _prepararCorrida();

    if (_erro != null || !mounted) {
      return;
    }

    _inicio = DateTime.now();

    setState(() {
      _emAndamento = true;
      _pausada = false;
      _erro = null;
    });

    _iniciarTimer();
    await _iniciarRastreamento();
  }

  Future<void> _confirmarFinalizacaoCorrida() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Finalizar corrida?'),
          content: const Text(
            'A distância, o tempo e a rota registrados '
                'até este momento serão mantidos.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Continuar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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

  Future<void> _finalizarCorrida() async {
    if (_finalizada) {
      return;
    }

    if (_emAndamento && _inicio != null) {
      _tempoAcumulado +=
          DateTime.now().difference(_inicio!);
    }

    _inicio = null;
    _timer?.cancel();
    await _posicaoSubscription?.cancel();

    if (!mounted) return;

    setState(() {
      _emAndamento = false;
      _pausada = false;
      _finalizada = true;
      _registrando = true;
    });

    await _registrarExecucao();
  }

  // ==========================================================
  // REGISTRO DA EXECUÇÃO
  // ==========================================================

  Future<void> _registrarExecucao() async {
    if (_registrada) {
      return;
    }

    final treinoId = _treinoId;

    if (treinoId == null) {
      if (mounted) {
        setState(() {
          _registrando = false;
        });
      }
      return;
    }

    try {
      final distancia = _distanciaMetros;

      final pace = _distanciaKm > 0
          ? (_tempoSegundos / 60) / _distanciaKm
          : 0.0;

      await widget.treinoService.registrarExecucao(
        treinoId: treinoId,
        tempo: _tempoSegundos,
        distancia: distancia,
        pace: pace,
        rota: List<Map<String, double>>.from(
          _rota,
        ),
      );

      _registrada = true;

      if (!mounted) {
        return;
      }

      setState(() {
        _registrando = false;
      });
    } catch (e) {
      _registrada = false;

      if (!mounted) {
        return;
      }

      setState(() {
        _registrando = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(
                'TreinoException: ',
                '',
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  // ==========================================================
  // MAPA DO PERCURSO
  // ==========================================================

  List<LatLng> get _pontosRota {
    return _rota
        .where(
          (ponto) =>
      ponto['lat'] != null &&
          ponto['lng'] != null,
    )
        .map(
          (ponto) => LatLng(
        ponto['lat']!,
        ponto['lng']!,
      ),
    )
        .toList();
  }

  CameraFit? get _ajusteInicialMapa {
    final pontos = _pontosRota;

    if (pontos.length < 2) {
      return null;
    }

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pontos),
      padding: const EdgeInsets.all(42),
    );
  }

  Widget _buildMapaPercurso() {
    final pontos = _pontosRota;

    if (pontos.isEmpty) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 42,
                  color: Color(0xFF64748B),
                ),
                SizedBox(height: 10),
                Text(
                  'Nenhum percurso GPS foi registrado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'O mapa aparecerá quando houver posições '
                      'registradas durante a corrida.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final primeiro = pontos.first;
    final ultimo = pontos.last;
    final ajusteInicial = _ajusteInicialMapa;

    return Container(
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
        ),
      ),
      child: Stack(
        children: [
          FlutterMap(
            key: ValueKey(
              'rota_${pontos.length}_${primeiro.latitude}_${primeiro.longitude}_'
                  '${ultimo.latitude}_${ultimo.longitude}',
            ),
            options: MapOptions(
              initialCenter: ultimo,
              initialZoom: 16,
              initialCameraFit: ajusteInicial,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                'br.com.nexosaude.clinica_app',
              ),
              if (pontos.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: pontos,
                      strokeWidth: 5,
                      color: const Color(0xFF2563EB),
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: primeiro,
                    width: 42,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                  if (pontos.length >= 2)
                    Marker(
                      point: ultimo,
                      width: 42,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route_rounded,
                      size: 17,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Seu percurso',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FORMATADORES
  // ==========================================================

  String _formatarTempo(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    final segundosRestantes = segundos % 60;

    if (horas > 0) {
      return '${horas.toString().padLeft(2, '0')}:'
          '${minutos.toString().padLeft(2, '0')}:'
          '${segundosRestantes.toString().padLeft(2, '0')}';
    }

    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundosRestantes.toString().padLeft(2, '0')}';
  }

  String _formatarDistancia(double km) {
    if (km < 10) {
      return km.toStringAsFixed(2);
    }

    return km.toStringAsFixed(1);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_finalizada) {
      return _buildCorridaConcluida();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Corrida',
          style: TextStyle(fontWeight: FontWeight.w800),
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
            _buildCabecalho(),
            const SizedBox(height: 14),
            _buildMetricas(),
            const SizedBox(height: 14),
            _buildStatusGps(),
            const SizedBox(height: 16),
            _buildControles(),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
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
        boxShadow: const [
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

  Widget _buildMetricas() {
    return Row(
      children: [
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.timer_outlined,
            titulo: 'Tempo',
            valor: _formatarTempo(_tempoSegundos),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.straighten_rounded,
            titulo: 'Distância',
            valor:
            '${_formatarDistancia(_distanciaKm)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.speed_rounded,
            titulo: 'Pace',
            valor: _pace,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGps() {
    final erro = _erro;

    if (_preparando) {
      return const _CaixaStatusCorrida(
        icone: Icons.gps_fixed_rounded,
        titulo: 'Preparando GPS',
        mensagem:
        'Solicitando acesso à localização do aparelho...',
        cor: Color(0xFF2563EB),
        carregando: true,
      );
    }

    if (erro != null) {
      final bloqueado = erro.contains('bloqueada');

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
                    label: const Text('Ativar GPS'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (_emAndamento) {
      return const _CaixaStatusCorrida(
        icone: Icons.gps_fixed_rounded,
        titulo: 'GPS ativo',
        mensagem:
        'Sua posição está sendo acompanhada durante a corrida.',
        cor: Color(0xFF16A34A),
      );
    }

    if (_pausada) {
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

  Widget _buildControles() {
    if (_finalizada) {
      return const SizedBox.shrink();
    }

    if (_preparando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_emAndamento) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pausarCorrida,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pausar corrida'),
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
              onPressed:
              _confirmarFinalizacaoCorrida,
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Finalizar corrida'),
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

    if (_pausada) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _retomarCorrida,
              icon:
              const Icon(Icons.play_arrow_rounded),
              label: const Text('Retomar corrida'),
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
              onPressed:
              _confirmarFinalizacaoCorrida,
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Finalizar corrida'),
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
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Iniciar corrida'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _compartilharTreino() async {
    final tempo = _formatarTempo(_tempoSegundos);
    final distancia = _formatarDistancia(_distanciaKm);
    final pace = _pace;

    final texto = [
      '🏃 Minha corrida',
      '',
      '⏱️ Tempo: $tempo',
      '📏 Distância: $distancia km',
      '⚡ Pace: $pace min/km',
      '',
      'Nexo Saúde',
    ].join('\n');

    final sharePositionOrigin = Rect.fromLTWH(
      0,
      0,
      MediaQuery.sizeOf(context).width,
      kToolbarHeight,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Minha corrida',
          subject: 'Minha corrida',
          text: texto,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível compartilhar o treino: $e',
            ),
          ),
        );
    }
  }

  Widget _buildCorridaConcluida() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Corrida concluída',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                'Corrida concluída!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Parabéns! Os dados da sua corrida foram '
                    'processados.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),
              _buildMapaPercurso(),
              const SizedBox(height: 18),
              _buildResumoFinal(),
              const SizedBox(height: 28),
              if (_registrando)
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
                      'Registrando sua corrida...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                )
              else if (_registrada)
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
                      'Corrida registrada com sucesso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                  _registrando ? null : _compartilharTreino,
                  icon: const Icon(
                    Icons.share_rounded,
                  ),
                  label: const Text(
                    'Compartilhar treino',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                    const Size.fromHeight(52),
                    foregroundColor:
                    const Color(0xFF2563EB),
                    side: const BorderSide(
                      color: Color(0xFF93C5FD),
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
                  onPressed: _registrando
                      ? null
                      : () async {
                    Navigator.of(context).pop(true);
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

  Widget _buildResumoFinal() {
    return Row(
      children: [
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.timer_outlined,
            titulo: 'Tempo',
            valor: _formatarTempo(_tempoSegundos),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.straighten_rounded,
            titulo: 'Distância',
            valor:
            '${_formatarDistancia(_distanciaKm)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricaCorrida(
            icone: Icons.speed_rounded,
            titulo: 'Pace',
            valor: _pace,
          ),
        ),
      ],
    );
  }
}

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
