import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'teleatendimento_service.dart';

class TeleatendimentoPage extends StatefulWidget {
  const TeleatendimentoPage({
    super.key,
    required this.teleatendimentoId,
    required this.teleatendimentoService,
  });

  final int teleatendimentoId;
  final TeleatendimentoService teleatendimentoService;

  @override
  State<TeleatendimentoPage> createState() => _TeleatendimentoPageState();
}

class _TeleatendimentoPageState extends State<TeleatendimentoPage> {
  Room? _room;

  bool _carregando = true;
  bool _conectado = false;
  bool _microfoneAtivo = true;
  bool _cameraAtiva = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _entrarNaSala();
  }

  Future<void> _entrarNaSala() async {
    try {
      setState(() {
        _carregando = true;
        _erro = null;
      });

      await widget.teleatendimentoService.entrarTeleatendimento(
        teleatendimentoId: widget.teleatendimentoId,
      );

      final tokenResposta =
      await widget.teleatendimentoService.obterTokenLiveKit(
        teleatendimentoId: widget.teleatendimentoId,
      );

      final liveKit = tokenResposta['livekit'];

      final liveKitUrl =
      liveKit is Map ? liveKit['url']?.toString() : null;

      final token =
      liveKit is Map ? liveKit['token']?.toString() : null;

      if (liveKitUrl == null || liveKitUrl.isEmpty) {
        throw const TeleatendimentoException(
          'URL do LiveKit não foi informada.',
        );
      }

      if (token == null || token.isEmpty) {
        throw const TeleatendimentoException(
          'Token do LiveKit não foi informado.',
        );
      }

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await room.connect(
        liveKitUrl,
        token,
      );

      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) {
        await room.disconnect();
        return;
      }

      setState(() {
        _room = room;
        _conectado = true;
        _carregando = false;
        _microfoneAtivo = true;
        _cameraAtiva = true;
      });

      room.addListener(_atualizarEstadoSala);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
        _conectado = false;
        _erro = e.toString();
      });
    }
  }

  void _atualizarEstadoSala() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _alternarMicrofone() async {
    final room = _room;
    if (room == null) {
      return;
    }

    final novoEstado = !_microfoneAtivo;

    try {
      await room.localParticipant?.setMicrophoneEnabled(novoEstado);

      if (!mounted) {
        return;
      }

      setState(() {
        _microfoneAtivo = novoEstado;
      });
    } catch (e) {
      _mostrarErro('Não foi possível alterar o microfone: $e');
    }
  }

  Future<void> _alternarCamera() async {
    final room = _room;
    if (room == null) {
      return;
    }

    final novoEstado = !_cameraAtiva;

    try {
      await room.localParticipant?.setCameraEnabled(novoEstado);

      if (!mounted) {
        return;
      }

      setState(() {
        _cameraAtiva = novoEstado;
      });
    } catch (e) {
      _mostrarErro('Não foi possível alterar a câmera: $e');
    }
  }

  Future<void> _sairDaSala() async {
    debugPrint(
      '>>> SAI DA SALA: _sairDaSala() foi chamado',
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair do teleatendimento'),
          content: const Text(
            'Deseja realmente sair da sala?\n\n'
                'O atendimento continuará ativo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      debugPrint(
        '>>> SAI DA SALA: usuário cancelou a saída',
      );
      return;
    }

    try {
      debugPrint(
        '>>> SAI DA SALA: chamando API para '
            'teleatendimento ${widget.teleatendimentoId}',
      );

      await widget.teleatendimentoService.sairTeleatendimento(
        teleatendimentoId: widget.teleatendimentoId,
      );

      debugPrint(
        '>>> SAI DA SALA: API de saída concluída com sucesso',
      );
    } catch (e) {
      debugPrint(
        '>>> SAI DA SALA: erro ao registrar saída: $e',
      );

      if (!mounted) {
        return;
      }

      _mostrarErro(
        'Não foi possível registrar a saída do teleatendimento: $e',
      );
      return;
    }

    debugPrint(
      '>>> SAI DA SALA: desconectando do LiveKit',
    );

    await _desconectar();

    debugPrint(
      '>>> SAI DA SALA: LiveKit desconectado',
    );

    if (!mounted) {
      return;
    }

    debugPrint(
      '>>> SAI DA SALA: retornando para a tela anterior',
    );

    Navigator.of(context).pop();
  }

  Future<void> _desconectar() async {
    final room = _room;

    if (room == null) {
      return;
    }

    // Remove imediatamente o listener e tira a sala da árvore
    // de widgets antes de iniciar a desconexão do WebRTC.
    room.removeListener(_atualizarEstadoSala);

    if (mounted) {
      setState(() {
        _conectado = false;
        _room = null;
      });
    }

    // Agora que os VideoTrackRenderer foram removidos da árvore,
    // podemos encerrar a conexão do LiveKit.
    try {
      await room.disconnect();
    } catch (e) {
      debugPrint(
        '>>> LIVEKIT: erro ao desconectar a sala: $e',
      );
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  void dispose() {
    final room = _room;

    if (room != null) {
      room.removeListener(_atualizarEstadoSala);
      room.disconnect();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Teleatendimento'),
      ),
      body: SafeArea(
        child: _buildConteudo(),
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Conectando ao teleatendimento...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                'Não foi possível entrar no teleatendimento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _entrarNaSala,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_conectado || _room == null) {
      return const Center(
        child: Text(
          'Teleatendimento desconectado.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _buildVideos(),
        ),
        _buildControles(),
      ],
    );
  }

  Widget _buildVideos() {
    final room = _room!;

    final participantesRemotos = room.remoteParticipants.values.toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: _buildVideoCard(
              title: 'Você',
              participant: room.localParticipant,
              local: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: participantesRemotos.isEmpty
                ? _buildAguardandoPaciente()
                : _buildVideoCard(
              title: participantesRemotos.first.name.isNotEmpty
                  ? participantesRemotos.first.name
                  : 'Participante',
              participant: participantesRemotos.first,
              local: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard({
    required String title,
    required Participant? participant,
    required bool local,
  }) {
    if (participant == null) {
      return _buildVideoPlaceholder(title);
    }

    VideoTrack? videoTrack;

    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack) {
        videoTrack = track;
        break;
      }
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: videoTrack == null
                ? _buildVideoPlaceholder(title)
                : VideoTrackRenderer(videoTrack),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder(String title) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade900,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAguardandoPaciente() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            color: Colors.white54,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Aguardando o profissional...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControles() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControle(
            icon: _microfoneAtivo ? Icons.mic : Icons.mic_off,
            ativo: _microfoneAtivo,
            onPressed: _alternarMicrofone,
          ),
          const SizedBox(width: 16),
          _buildControle(
            icon: _cameraAtiva ? Icons.videocam : Icons.videocam_off,
            ativo: _cameraAtiva,
            onPressed: _alternarCamera,
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'sair_teleatendimento',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: _sairDaSala,
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }

  Widget _buildControle({
    required IconData icon,
    required bool ativo,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: '${icon.codePoint}',
      backgroundColor: ativo ? Colors.white : Colors.grey.shade800,
      foregroundColor: ativo ? Colors.black : Colors.white,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}

