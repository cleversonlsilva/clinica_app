import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/notifications/notification_service.dart';
import 'agenda_service.dart';

/// Tela principal da Agenda do paciente.
///
/// Responsabilidades:
///
/// - apresentar as consultas existentes;
/// - destacar a próxima consulta;
/// - consultar horários disponíveis;
/// - realizar novo agendamento;
/// - tratar conflito de consulta futura;
/// - permitir remarcação após confirmação do paciente;
/// - programar lembretes locais.
class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    required this.agendaService,
  });

  final AgendaService agendaService;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  bool _carregandoAgenda = true;
  bool _carregandoDisponibilidade = false;
  bool _agendando = false;

  String? _erroAgenda;
  String? _erroDisponibilidade;

  List<dynamic> _consultas = [];

  Map<String, dynamic>? _proximaConsulta;

  DateTime? _dataSelecionada;
  List<String> _horariosDisponiveis = [];

  String? _horarioSelecionado;

  final NotificationService _notificationService =
  NotificationService();

  @override
  void initState() {
    super.initState();

    _carregarAgenda();
  }

  // ==========================================================
  // AGENDA
  // ==========================================================

  Future<void> _carregarAgenda() async {
    if (mounted) {
      setState(() {
        _carregandoAgenda = true;
        _erroAgenda = null;
      });
    }

    try {
      final resposta =
      await widget.agendaService.carregarAgenda();

      if (!mounted) {
        return;
      }

      final agenda = resposta['agenda'];
      final proxima = resposta['proxima_consulta'];

      final proximaConsulta =
      proxima is Map<String, dynamic>
          ? proxima
          : null;

      setState(() {
        _consultas = agenda is List ? agenda : [];
        _proximaConsulta = proximaConsulta;
        _carregandoAgenda = false;
      });

      await _programarLembreteProximaConsulta(
        proximaConsulta,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregandoAgenda = false;
        _erroAgenda = e.toString();
      });
    }
  }

  // ==========================================================
  // LEMBRETE DA PRÓXIMA CONSULTA
  // ==========================================================

  Future<void> _programarLembreteProximaConsulta(
      Map<String, dynamic>? consulta,
      ) async {
    if (consulta == null) {
      return;
    }

    final id = _obterIdAgendamento(consulta);

    if (id == null) {
      return;
    }

    final data = _obterDataConsulta(consulta);

    if (data == null) {
      return;
    }

    final hora = _obterHoraConsulta(consulta);

    if (hora == null) {
      return;
    }

    final partesHora = hora.split(':');

    if (partesHora.length < 2) {
      return;
    }

    final horaInteira = int.tryParse(partesHora[0]);
    final minuto = int.tryParse(partesHora[1]);

    if (horaInteira == null || minuto == null) {
      return;
    }

    if (horaInteira < 0 ||
        horaInteira > 23 ||
        minuto < 0 ||
        minuto > 59) {
      return;
    }

    final dataHoraConsulta = DateTime(
      data.year,
      data.month,
      data.day,
      horaInteira,
      minuto,
    );

    final dataHoraLembrete =
    dataHoraConsulta.subtract(
      const Duration(days: 1),
    );

    if (!dataHoraLembrete.isAfter(DateTime.now())) {
      return;
    }

    try {
      await _notificationService.solicitarPermissao();

      await _notificationService.cancelar(id);

      final dataTexto = _formatarData(data);

      final horaTexto =
          '${horaInteira.toString().padLeft(2, '0')}:'
          '${minuto.toString().padLeft(2, '0')}';

      await _notificationService.agendar(
        id: id,
        titulo: 'Lembrete de consulta',
        mensagem:
        'Seu horário está agendado para '
            '$dataTexto às $horaTexto.',
        dataHora: dataHoraLembrete,
      );
    } catch (_) {
      // Falha da notificação não deve impedir
      // o funcionamento da Agenda.
    }
  }

  int? _obterIdAgendamento(
      Map<String, dynamic> consulta,
      ) {
    final valor = consulta['id'];

    if (valor is int) {
      return valor;
    }

    return int.tryParse(
      valor?.toString() ?? '',
    );
  }

  DateTime? _obterDataConsulta(
      Map<String, dynamic> consulta,
      ) {
    final valor = consulta['data'];

    if (valor == null) {
      return null;
    }

    try {
      return DateTime.parse(
        valor.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  String? _obterHoraConsulta(
      Map<String, dynamic> consulta,
      ) {
    final valor =
        consulta['hora_inicio'] ??
            consulta['hora'];

    if (valor == null) {
      return null;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }

  // ==========================================================
  // CONFIRMAÇÃO DA CONSULTA
  // ==========================================================

  /// Verifica se a consulta precisa ser confirmada pelo paciente.
  ///
  /// A regra visual do aplicativo é:
  /// - consulta ainda pendente;
  /// - consulta futura;
  /// - faltam menos de 24 horas para o horário.
  ///
  /// A validação definitiva permanece no backend.
  bool _precisaConfirmarConsulta(
      Map<String, dynamic> consulta,
      ) {
    final status = _valorTexto(
      consulta['status'],
    ).toLowerCase();

    if (status != 'pendente') {
      return false;
    }

    final data = _obterDataConsulta(consulta);
    final hora = _obterHoraConsulta(consulta);

    if (data == null || hora == null) {
      return false;
    }

    final partesHora = hora.split(':');

    if (partesHora.length < 2) {
      return false;
    }

    final horaInteira = int.tryParse(partesHora[0]);
    final minuto = int.tryParse(partesHora[1]);

    if (horaInteira == null || minuto == null) {
      return false;
    }

    if (horaInteira < 0 ||
        horaInteira > 23 ||
        minuto < 0 ||
        minuto > 59) {
      return false;
    }

    final dataHoraConsulta = DateTime(
      data.year,
      data.month,
      data.day,
      horaInteira,
      minuto,
    );

    final agora = DateTime.now();

    if (!dataHoraConsulta.isAfter(agora)) {
      return false;
    }

    final diferenca = dataHoraConsulta.difference(agora);

    return diferenca <= const Duration(hours: 24);
  }

  /// Confirma a consulta selecionada através da API.
  Future<void> _confirmarConsulta(
      Map<String, dynamic> consulta,
      ) async {
    if (_agendando) {
      return;
    }

    final agendamentoId =
    _obterIdAgendamento(consulta);

    if (agendamentoId == null) {
      await _mostrarErro(
        'Não foi possível identificar a consulta para confirmação.',
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final data = _valorTexto(
          consulta['data'],
        );
        final hora = _valorTexto(
          consulta['hora_inicio'] ??
              consulta['hora'],
        );

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.event_available_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text('Confirmar consulta'),
              ),
            ],
          ),
          content: Text(
            'Deseja confirmar sua presença na consulta '
                'de ${_formatarDataTexto(data)} às $hora?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    setState(() {
      _agendando = true;
    });

    try {
      final resposta =
      await widget.agendaService.confirmarConsulta(
        agendamentoId: agendamentoId,
      );

      if (!mounted) {
        return;
      }

      if (resposta['ok'] == true) {
        await _mostrarSucesso(
          resposta['mensagem']?.toString() ??
              'Consulta confirmada com sucesso.',
        );

        await _carregarAgenda();
        return;
      }

      await _mostrarErro(
        resposta['mensagem']?.toString() ??
            resposta['erro']?.toString() ??
            'Não foi possível confirmar a consulta.',
      );
    } on AgendaException catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(e.message);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(
        e.data?['erro']?.toString() ??
            e.data?['mensagem']?.toString() ??
            e.message,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _agendando = false;
        });
      }
    }
  }

  // ==========================================================
  // SELEÇÃO DA DATA
  // ==========================================================

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? hoje,
      firstDate: hoje,
      lastDate: hoje.add(
        const Duration(days: 30),
      ),
      helpText: 'Escolha a data da consulta',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data',
      fieldHintText: 'DD/MM/AAAA',
    );

    if (data == null || !mounted) {
      return;
    }

    setState(() {
      _dataSelecionada = data;
      _horarioSelecionado = null;
      _horariosDisponiveis = [];
      _erroDisponibilidade = null;
    });

    await _carregarDisponibilidade(data);
  }

  // ==========================================================
  // DISPONIBILIDADE
  // ==========================================================

  Future<void> _carregarDisponibilidade(
      DateTime data,
      ) async {
    setState(() {
      _carregandoDisponibilidade = true;
      _erroDisponibilidade = null;
      _horariosDisponiveis = [];
      _horarioSelecionado = null;
    });

    final dataApi = _formatarDataApi(data);

    try {
      final horarios =
      await widget.agendaService
          .obterHorariosDisponiveis(
        data: dataApi,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _horariosDisponiveis = horarios;
        _carregandoDisponibilidade = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregandoDisponibilidade = false;
        _erroDisponibilidade = e.toString();
      });
    }
  }

  // ==========================================================
  // SELECIONAR HORÁRIO
  // ==========================================================

  Future<void> _mostrarHorarioSelecionado(
      String horario,
      ) async {
    if (_dataSelecionada == null) {
      return;
    }

    setState(() {
      _horarioSelecionado = horario;
    });

    await _mostrarConfirmacaoAgendamento(
      horario,
    );
  }

  // ==========================================================
  // CONFIRMAR AGENDAMENTO
  // ==========================================================

  Future<void> _mostrarConfirmacaoAgendamento(
      String horario,
      ) async {
    if (_dataSelecionada == null) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Confirmar consulta',
          ),
          content: Text(
            'Deseja agendar sua consulta para '
                '${_formatarData(_dataSelecionada)} '
                'às $horario?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Confirmar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    await _agendarConsulta(
      horario,
    );
  }

  // ==========================================================
  // AGENDAR
  // ==========================================================

  Future<void> _agendarConsulta(
      String horario,
      ) async {
    if (_dataSelecionada == null) {
      return;
    }

    if (_agendando) {
      return;
    }

    setState(() {
      _agendando = true;
    });

    final dataApi =
    _formatarDataApi(_dataSelecionada!);

    try {
      final resposta =
      await widget.agendaService.agendarConsulta(
        data: dataApi,
        hora: horario,
      );

      if (!mounted) {
        return;
      }

      final sucesso =
          resposta['ok'] == true;

      if (sucesso) {
        await _mostrarSucesso(
          resposta['mensagem']?.toString() ??
              'Consulta agendada com sucesso.',
        );

        _limparSelecao();

        await _carregarAgenda();

        return;
      }

      await _mostrarErro(
        resposta['mensagem']?.toString() ??
            resposta['erro']?.toString() ??
            'Não foi possível realizar o agendamento.',
      );
    }

    // ========================================================
    // CONFLITO DE CONSULTA FUTURA
    // ========================================================
    //
    // O AgendaService converte o HTTP 409
    // CONSULTA_FUTURA_EXISTENTE em AgendaConflitoException.
    //
    // Portanto, esse fluxo precisa ser tratado aqui antes
    // de cair no tratamento genérico de erro.
    //
    on AgendaConflitoException catch (e) {
      if (!mounted) {
        return;
      }

      // A operação de criação terminou.
      //
      // Liberamos o estado antes de abrir o diálogo porque,
      // se o paciente confirmar a remarcação, o método
      // _remarcarConsulta() precisa poder iniciar uma nova
      // operação.
      setState(() {
        _agendando = false;
      });

      if (e.possuiConsultaFutura) {
        await _tratarConsultaFuturaExistente(
          e,
        );
      } else {
        await _mostrarErro(
          e.mensagem,
        );
      }
    }

    // ========================================================
    // ERROS HTTP
    // ========================================================

    on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      if (e.statusCode == 409) {
        await _mostrarErro(
          e.data?['erro']?.toString() ??
              e.data?['mensagem']?.toString() ??
              e.message,
        );
      } else {
        await _mostrarErro(
          e.message,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _agendando = false;
        });
      }
    }
  }

  // ==========================================================
  // CONSULTA FUTURA EXISTENTE
  // ==========================================================

  Future<void> _tratarConsultaFuturaExistente(
      AgendaConflitoException conflito,
      ) async {
    final consultaExistente =
        conflito.agendamento;

    final deveRemarcar =
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dataExistente =
        _valorTexto(
          consultaExistente?['data'],
        );

        final horaExistente =
        _valorTexto(
          consultaExistente?['hora_inicio'] ??
              consultaExistente?['hora'],
        );

        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.info_outline,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Atenção',
                ),
              ),
            ],
          ),
          content: Text(
            'Você já possui uma consulta agendada'
                '${dataExistente != '-' ? ' para ${_formatarDataTexto(dataExistente)}' : ''}'
                '${horaExistente != '-' ? ' às $horaExistente' : ''}.\n\n'
                'Deseja realmente alterar o horário?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Confirmar',
              ),
            ),
          ],
        );
      },
    );

    // ========================================================
    // CANCELAR
    // ========================================================

    if (deveRemarcar != true || !mounted) {
      return;
    }

    // ========================================================
    // VALIDAR CONSULTA EXISTENTE
    // ========================================================

    if (consultaExistente == null) {
      await _mostrarErro(
        'Não foi possível identificar a consulta atual.',
      );
      return;
    }

    final agendamentoId =
    _obterIdAgendamento(
      consultaExistente,
    );

    if (agendamentoId == null) {
      await _mostrarErro(
        'Não foi possível identificar o agendamento atual.',
      );
      return;
    }

    // ========================================================
    // VALIDAR NOVA DATA/HORÁRIO
    // ========================================================

    if (_dataSelecionada == null ||
        _horarioSelecionado == null) {
      await _mostrarErro(
        'Selecione novamente a data e o horário desejados.',
      );
      return;
    }

    // ========================================================
    // CONFIRMAR REMARCAÇÃO
    // ========================================================

    await _remarcarConsulta(
      agendamentoId: agendamentoId,
      horario: _horarioSelecionado!,
    );
  }

  // ==========================================================
  // REMARCAR
  // ==========================================================

  Future<void> _remarcarConsulta({
    required int agendamentoId,
    required String horario,
  }) async {
    if (_dataSelecionada == null) {
      return;
    }

    if (_agendando) {
      return;
    }

    setState(() {
      _agendando = true;
    });

    final dataApi =
    _formatarDataApi(_dataSelecionada!);

    try {
      final resposta =
      await widget.agendaService.remarcarConsulta(
        agendamentoId: agendamentoId,
        data: dataApi,
        hora: horario,
      );

      if (!mounted) {
        return;
      }

      if (resposta['ok'] == true) {
        await _mostrarSucesso(
          resposta['mensagem']?.toString() ??
              'Consulta remarcada com sucesso.',
        );

        _limparSelecao();

        await _carregarAgenda();

        return;
      }

      await _mostrarErro(
        resposta['mensagem']?.toString() ??
            resposta['erro']?.toString() ??
            'Não foi possível remarcar a consulta.',
      );
    } on AgendaConflitoException catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(
        e.mensagem,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(
        e.data?['erro']?.toString() ??
            e.data?['mensagem']?.toString() ??
            e.message,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _mostrarErro(
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _agendando = false;
        });
      }
    }
  }

  // ==========================================================
  // LIMPAR SELEÇÃO
  // ==========================================================

  void _limparSelecao() {
    if (!mounted) {
      return;
    }

    setState(() {
      _dataSelecionada = null;
      _horariosDisponiveis = [];
      _horarioSelecionado = null;
      _erroDisponibilidade = null;
    });
  }

  // ==========================================================
  // MENSAGENS
  // ==========================================================

  Future<void> _mostrarSucesso(
      String mensagem,
      ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
              ),
              SizedBox(width: 10),
              Text(
                'Sucesso',
              ),
            ],
          ),
          content: Text(
            mensagem,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'OK',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarErro(
      String mensagem,
      ) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.error_outline,
              ),
              SizedBox(width: 10),
              Text(
                'Atenção',
              ),
            ],
          ),
          content: Text(
            mensagem,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Fechar',
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // FORMATAÇÃO
  // ==========================================================

  String _formatarDataApi(
      DateTime data,
      ) {
    final ano =
    data.year.toString().padLeft(4, '0');

    final mes =
    data.month.toString().padLeft(2, '0');

    final dia =
    data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  String _formatarData(
      DateTime? data,
      ) {
    if (data == null) {
      return '-';
    }

    final dia =
    data.day.toString().padLeft(2, '0');

    final mes =
    data.month.toString().padLeft(2, '0');

    final ano =
    data.year.toString();

    return '$dia/$mes/$ano';
  }

  String _formatarDataTexto(
      String? valor,
      ) {
    if (valor == null || valor.isEmpty) {
      return '-';
    }

    try {
      final data = DateTime.parse(valor);

      return _formatarData(data);
    } catch (_) {
      return valor;
    }
  }

  String _valorTexto(
      dynamic valor,
      ) {
    if (valor == null) {
      return '-';
    }

    final texto =
    valor.toString().trim();

    if (texto.isEmpty) {
      return '-';
    }

    return texto;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _carregarAgenda,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32,
          ),
          children: [
            _buildCabecalho(),
            const SizedBox(height: 20),
            _buildProximaConsulta(),
            const SizedBox(height: 24),
            _buildBotaoAgendar(),
            const SizedBox(height: 24),
            _buildDisponibilidade(),
            const SizedBox(height: 28),
            _buildHistorico(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // CABEÇALHO
  // ==========================================================

  Widget _buildCabecalho() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Minha agenda',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Acompanhe suas consultas e agende um novo horário.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // PRÓXIMA CONSULTA
  // ==========================================================

  Widget _buildProximaConsulta() {
    if (_carregandoAgenda) {
      return _buildCardCarregando();
    }

    if (_erroAgenda != null) {
      return _buildCardErro(
        mensagem: _erroAgenda!,
        onRetry: _carregarAgenda,
      );
    }

    if (_proximaConsulta == null) {
      return _buildCardVazio(
        icone: Icons.event_available_outlined,
        titulo: 'Nenhuma consulta agendada',
        descricao:
        'Você pode consultar os horários disponíveis e escolher uma nova data.',
      );
    }

    final consulta =
    _proximaConsulta!;

    final data = _valorTexto(
      consulta['data'],
    );

    final hora = _valorTexto(
      consulta['hora_inicio'] ??
          consulta['hora'],
    );

    final tipo = _valorTexto(
      consulta['tipo'],
    );

    final status = _valorTexto(
      consulta['status'],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .primaryContainer,
      ),
      padding:
      const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Próxima consulta',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatarDataTexto(data),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hora,
            style: Theme.of(context)
                .textTheme
                .titleLarge,
          ),
          if (tipo != '-') ...[
            const SizedBox(height: 8),
            Text(
              tipo,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          _buildStatusChip(
            status,
          ),
          if (_precisaConfirmarConsulta(consulta)) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _agendando
                    ? null
                    : () => _confirmarConsulta(consulta),
                icon: _agendando
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.check_circle_outline,
                ),
                label: Text(
                  _agendando
                      ? 'Confirmando...'
                      : 'Confirmar consulta',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // BOTÃO AGENDAR
  // ==========================================================

  Widget _buildBotaoAgendar() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed:
        _agendando ? null : _selecionarData,
        icon: _agendando
            ? const SizedBox(
          width: 18,
          height: 18,
          child:
          CircularProgressIndicator(
            strokeWidth: 2,
          ),
        )
            : const Icon(
          Icons.add_circle_outline,
        ),
        label: Text(
          _agendando
              ? 'Processando...'
              : 'Agendar consulta',
        ),
        style: FilledButton.styleFrom(
          padding:
          const EdgeInsets.symmetric(
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DISPONIBILIDADE
  // ==========================================================

  Widget _buildDisponibilidade() {
    if (_dataSelecionada == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius:
          BorderRadius.circular(18),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
        padding:
        const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Escolha uma data para consultar os horários disponíveis.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Horários disponíveis',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed:
              _agendando
                  ? null
                  : _selecionarData,
              child: const Text(
                'Alterar data',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatarData(
            _dataSelecionada,
          ),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        _buildConteudoDisponibilidade(),
      ],
    );
  }

  Widget _buildConteudoDisponibilidade() {
    if (_carregandoDisponibilidade) {
      return const Center(
        child: Padding(
          padding:
          EdgeInsets.all(24),
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_erroDisponibilidade != null) {
      return _buildCardErro(
        mensagem:
        _erroDisponibilidade!,
        onRetry: () {
          if (_dataSelecionada != null) {
            _carregarDisponibilidade(
              _dataSelecionada!,
            );
          }
        },
      );
    }

    if (_horariosDisponiveis.isEmpty) {
      return _buildCardVazio(
        icone:
        Icons.schedule_outlined,
        titulo:
        'Nenhum horário disponível',
        descricao:
        'Não existem horários liberados para esta data.',
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
      _horariosDisponiveis
          .map(
            (horario) =>
            _buildHorario(
              horario,
            ),
      )
          .toList(),
    );
  }

  Widget _buildHorario(
      String horario,
      ) {
    final selecionado =
        _horarioSelecionado ==
            horario;

    return OutlinedButton(
      onPressed:
      _agendando
          ? null
          : () {
        _mostrarHorarioSelecionado(
          horario,
        );
      },
      style:
      OutlinedButton.styleFrom(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(12),
        ),
        backgroundColor:
        selecionado
            ? Theme.of(context)
            .colorScheme
            .primaryContainer
            : null,
      ),
      child: Text(
        horario,
        style: const TextStyle(
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  // ==========================================================
  // HISTÓRICO
  // ==========================================================

  Widget _buildHistorico() {
    if (_carregandoAgenda) {
      return const SizedBox.shrink();
    }

    if (_consultas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Minhas consultas',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight:
            FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        ..._consultas.map(
              (consulta) {
            if (consulta is! Map) {
              return const SizedBox.shrink();
            }

            return _buildConsultaCard(
              Map<String, dynamic>.from(
                consulta,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildConsultaCard(
      Map<String, dynamic> consulta,
      ) {
    final data = _valorTexto(
      consulta['data'],
    );

    final hora = _valorTexto(
      consulta['hora_inicio'] ??
          consulta['hora'],
    );

    final tipo = _valorTexto(
      consulta['tipo'],
    );

    final status = _valorTexto(
      consulta['status'],
    );

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor:
          Theme.of(context)
              .colorScheme
              .primaryContainer,
          child: Icon(
            Icons.calendar_month_outlined,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
        ),
        title: Text(
          _formatarDataTexto(data),
          style: const TextStyle(
            fontWeight:
            FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding:
          const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            [
              hora,
              if (tipo != '-') tipo,
            ].join(' • '),
          ),
        ),
        trailing:
        _buildStatusChip(
          status,
          compacto: true,
        ),
      ),
    );
  }

  // ==========================================================
  // COMPONENTES AUXILIARES
  // ==========================================================

  Widget _buildStatusChip(
      String status, {
        bool compacto = false,
      }) {
    final texto =
    status == '-'
        ? 'Sem status'
        : status;

    return Container(
      padding:
      EdgeInsets.symmetric(
        horizontal:
        compacto ? 8 : 10,
        vertical:
        compacto ? 4 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .surface,
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize:
          compacto ? 11 : 12,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCardCarregando() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: const Center(
        child:
        CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildCardVazio({
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      padding:
      const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            size: 30,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descricao,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardErro({
    required String mensagem,
    required VoidCallback onRetry,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
      ),
      padding:
      const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context)
                    .colorScheme
                    .onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Não foi possível carregar os dados.',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mensagem,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Tentar novamente',
            ),
          ),
        ],
      ),
    );
  }
}
