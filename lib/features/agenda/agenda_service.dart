import '../../core/auth/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/notification_service.dart';
import '../../services/paciente_api_service.dart';

class AgendaService {
  AgendaService({
    required this._authService,
    required this._pacienteApiService,
    NotificationService? notificationService,
  }) : _notificationService =
      notificationService ?? NotificationService();

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;
  final NotificationService _notificationService;

  // ==========================================================
  // AGENDA
  // ==========================================================

  /// Carrega a agenda do paciente autenticado.
  Future<Map<String, dynamic>> carregarAgenda() async {
    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.obterAgenda(
      token: token,
    );

    final agenda = _normalizarMapa(resposta);

    if (agenda['ok'] == false) {
      throw AgendaException(
        _obterMensagem(
          agenda,
          fallback: 'Não foi possível carregar a agenda.',
        ),
      );
    }

    // ========================================================
    // LEMBRETES
    // ========================================================
    //
    // Falhas de notificação, inclusive limitações do Android
    // como exact_alarms_not_permitted, não podem impedir
    // o carregamento dos dados da Agenda.
    //
    try {
      await _sincronizarLembretes(agenda);
    } catch (_) {
      // Ignora falhas de notificações.
      //
      // A agenda já foi carregada corretamente pela API.
    }

    return agenda;
  }

  // ==========================================================
  // DISPONIBILIDADE
  // ==========================================================

  /// Consulta os horários disponíveis para uma determinada data.
  Future<Map<String, dynamic>> obterDisponibilidade({
    required String data,
  }) async {
    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.obterDisponibilidade(
      token: token,
      data: data,
    );

    final resultado = _normalizarMapa(resposta);

    if (resultado['ok'] == false) {
      throw AgendaException(
        _obterMensagem(
          resultado,
          fallback:
          'Não foi possível consultar a disponibilidade.',
        ),
      );
    }

    return resultado;
  }

  /// Retorna somente os horários disponíveis.
  Future<List<String>> obterHorariosDisponiveis({
    required String data,
  }) async {
    final resposta = await obterDisponibilidade(
      data: data,
    );

    final horarios = resposta['horarios'];

    if (horarios is! List) {
      return <String>[];
    }

    return horarios
        .map(
          (horario) => horario.toString().trim(),
    )
        .where(
          (horario) => horario.isNotEmpty,
    )
        .toList();
  }

  // ==========================================================
  // NOVO AGENDAMENTO
  // ==========================================================

  /// Cria um novo agendamento.
  ///
  /// Se já existir uma consulta futura, o backend retorna
  /// HTTP 409 com o código:
  ///
  /// CONSULTA_FUTURA_EXISTENTE
  ///
  /// Se o horário tiver sido ocupado:
  ///
  /// HORARIO_INDISPONIVEL
  ///
  /// Nesses casos lançamos AgendaConflitoException.
  Future<Map<String, dynamic>> agendarConsulta({
    required String data,
    required String hora,
    String? tipo,
    String? observacao,
  }) async {
    final token = await _obterToken();

    try {
      final resposta =
      await _pacienteApiService.agendarConsulta(
        token: token,
        data: data,
        hora: hora,
        tipo: tipo,
        observacao: observacao,
      );

      final resultado = _normalizarMapa(resposta);

      if (resultado['ok'] == false) {
        throw AgendaException(
          _obterMensagem(
            resultado,
            fallback:
            'Não foi possível realizar o agendamento.',
          ),
        );
      }

      return resultado;
    } on ApiException catch (erro) {
      return _tratarErroAgendamento(erro);
    }
  }

  // ==========================================================
  // REMARCAÇÃO
  // ==========================================================

  /// Remarca uma consulta existente.
  ///
  /// Endpoint utilizado pelo PacienteApiService:
  ///
  /// POST /api/app/paciente/agenda/remarcar
  ///
  /// Corpo:
  ///
  /// {
  ///   "agendamento_id": 44,
  ///   "data": "YYYY-MM-DD",
  ///   "hora": "HH:MM"
  /// }
  ///
  /// A remarcação somente deve acontecer depois que o paciente
  /// confirmar a alteração na interface.
  ///
  /// Se o novo horário estiver indisponível, o backend poderá
  /// retornar:
  ///
  /// HORARIO_INDISPONIVEL
  ///
  /// Nesse caso lançamos AgendaConflitoException.
  Future<Map<String, dynamic>> remarcarConsulta({
    required int agendamentoId,
    required String data,
    required String hora,
  }) async {
    final token = await _obterToken();

    try {
      final resposta =
      await _pacienteApiService.remarcarConsulta(
        token: token,
        agendamentoId: agendamentoId,
        data: data,
        hora: hora,
      );

      final resultado = _normalizarMapa(resposta);

      if (resultado['ok'] == false) {
        throw AgendaException(
          _obterMensagem(
            resultado,
            fallback:
            'Não foi possível remarcar a consulta.',
          ),
        );
      }

      return resultado;
    } on ApiException catch (erro) {
      return _tratarErroRemarcacao(erro);
    }
  }

  // ==========================================================
  // CONFIRMAÇÃO
  // ==========================================================

  /// Confirma uma consulta existente.
  ///
  /// Endpoint utilizado pelo PacienteApiService:
  ///
  /// POST /api/app/paciente/agenda/confirmar
  ///
  /// Corpo:
  ///
  /// {
  ///   "agendamento_id": 44
  /// }
  ///
  /// A confirmação é utilizada quando a consulta está
  /// próxima do horário agendado e o paciente precisa
  /// confirmar sua presença.
  ///
  /// O backend é responsável por validar se a consulta
  /// pode ser confirmada e por alterar seu status.
  Future<Map<String, dynamic>> confirmarConsulta({
    required int agendamentoId,
  }) async {
    final token = await _obterToken();

    try {
      final resposta =
      await _pacienteApiService.confirmarConsulta(
        token: token,
        agendamentoId: agendamentoId,
      );

      final resultado = _normalizarMapa(resposta);

      if (resultado['ok'] == false) {
        throw AgendaException(
          _obterMensagem(
            resultado,
            fallback:
            'Não foi possível confirmar a consulta.',
          ),
        );
      }

      return resultado;
    } on ApiException catch (erro) {
      final dados = erro.data;

      if (dados == null) {
        throw AgendaException(
          erro.message,
        );
      }

      throw AgendaException(
        _obterMensagem(
          dados,
          fallback: erro.message,
        ),
      );
    }
  }

  // ==========================================================
  // TRATAMENTO DE ERROS DO AGENDAMENTO
  // ==========================================================

  /// Interpreta os erros retornados pela API.
  ///
  /// O ApiClient preserva o corpo JSON em ApiException.data.
  Map<String, dynamic> _tratarErroAgendamento(
      ApiException erro,
      ) {
    final dados = erro.data;

    if (dados == null) {
      throw AgendaException(
        erro.message,
      );
    }

    final codigo =
    dados['codigo']?.toString();

    // --------------------------------------------------------
    // CONSULTA FUTURA EXISTENTE
    // --------------------------------------------------------

    if (codigo == 'CONSULTA_FUTURA_EXISTENTE') {
      throw AgendaConflitoException(
        codigo: 'CONSULTA_FUTURA_EXISTENTE',
        mensagem: _obterMensagem(
          dados,
          fallback: erro.message,
        ),
        agendamento: _normalizarAgendamento(
          dados['agendamento'],
        ),
        statusCode: erro.statusCode,
      );
    }

    // --------------------------------------------------------
    // HORÁRIO INDISPONÍVEL
    // --------------------------------------------------------

    if (codigo == 'HORARIO_INDISPONIVEL') {
      throw AgendaConflitoException(
        codigo: 'HORARIO_INDISPONIVEL',
        mensagem: _obterMensagem(
          dados,
          fallback: erro.message,
        ),
        agendamento: null,
        statusCode: erro.statusCode,
      );
    }

    // --------------------------------------------------------
    // OUTROS ERROS DE NEGÓCIO
    // --------------------------------------------------------

    throw AgendaException(
      _obterMensagem(
        dados,
        fallback: erro.message,
      ),
    );
  }

  // ==========================================================
  // TRATAMENTO DE ERROS DA REMARCAÇÃO
  // ==========================================================

  /// Interpreta os erros retornados pela API durante a
  /// remarcação da consulta.
  Map<String, dynamic> _tratarErroRemarcacao(
      ApiException erro,
      ) {
    final dados = erro.data;

    if (dados == null) {
      throw AgendaException(
        erro.message,
      );
    }

    final codigo =
    dados['codigo']?.toString();

    // --------------------------------------------------------
    // HORÁRIO INDISPONÍVEL
    // --------------------------------------------------------

    if (codigo == 'HORARIO_INDISPONIVEL') {
      throw AgendaConflitoException(
        codigo: 'HORARIO_INDISPONIVEL',
        mensagem: _obterMensagem(
          dados,
          fallback: erro.message,
        ),
        agendamento: null,
        statusCode: erro.statusCode,
      );
    }

    // --------------------------------------------------------
    // OUTROS ERROS
    // --------------------------------------------------------

    throw AgendaException(
      _obterMensagem(
        dados,
        fallback: erro.message,
      ),
    );
  }

  // ==========================================================
  // CONFLITOS
  // ==========================================================

  /// Verifica se uma resposta representa uma consulta futura.
  bool possuiConsultaFutura(
      Map<String, dynamic> resposta,
      ) {
    return resposta['codigo'] ==
        'CONSULTA_FUTURA_EXISTENTE';
  }

  /// Verifica se o horário ficou indisponível.
  bool horarioIndisponivel(
      Map<String, dynamic> resposta,
      ) {
    return resposta['codigo'] ==
        'HORARIO_INDISPONIVEL';
  }

  /// Obtém a mensagem de erro da API.
  String obterMensagemErro(
      Map<String, dynamic> resposta,
      ) {
    return _obterMensagem(
      resposta,
      fallback:
      'Não foi possível realizar o agendamento.',
    );
  }

  /// Obtém a mensagem utilizando os campos possíveis
  /// retornados pela API.
  String _obterMensagem(
      Map<String, dynamic> resposta, {
        required String fallback,
      }) {
    final mensagem =
    resposta['mensagem']?.toString().trim();

    if (mensagem != null && mensagem.isNotEmpty) {
      return mensagem;
    }

    final erro =
    resposta['erro']?.toString().trim();

    if (erro != null && erro.isNotEmpty) {
      return erro;
    }

    final message =
    resposta['message']?.toString().trim();

    if (message != null && message.isNotEmpty) {
      return message;
    }

    return fallback;
  }

  /// Normaliza o agendamento retornado pela API.
  Map<String, dynamic>? _normalizarAgendamento(
      dynamic valor,
      ) {
    if (valor is Map<String, dynamic>) {
      return valor;
    }

    if (valor is Map) {
      return Map<String, dynamic>.from(valor);
    }

    return null;
  }

  // ==========================================================
  // LEMBRETES
  // ==========================================================

  /// Sincroniza os lembretes das consultas retornadas pela API.
  Future<void> _sincronizarLembretes(
      Map<String, dynamic> resposta,
      ) async {
    final agenda = resposta['agenda'];

    if (agenda is! List) {
      return;
    }

    await _notificationService.inicializar();
    await _notificationService.solicitarPermissao();

    for (final item in agenda) {
      if (item is! Map) {
        continue;
      }

      await _processarAgendamento(item);
    }
  }

  /// Processa um agendamento individual.
  Future<void> _processarAgendamento(
      Map<dynamic, dynamic> agendamento,
      ) async {
    final id = _obterIdAgendamento(
      agendamento,
    );

    if (id == null) {
      return;
    }

    final status = _obterTexto(
      agendamento['status'],
    );

    if (_statusNaoDeveNotificar(status)) {
      await _notificationService.cancelar(
        _idNotificacao(id),
      );

      return;
    }

    final data = _obterTexto(
      agendamento['data'],
    );

    final hora = _obterTexto(
      agendamento['hora_inicio'] ??
          agendamento['hora'],
    );

    if (data == null || hora == null) {
      return;
    }

    final consulta = _converterDataHora(
      data: data,
      hora: hora,
    );

    if (consulta == null) {
      return;
    }

    final agora = DateTime.now();

    if (!consulta.isAfter(agora)) {
      await _notificationService.cancelar(
        _idNotificacao(id),
      );

      return;
    }

    final lembrete = consulta.subtract(
      const Duration(days: 1),
    );

    if (!lembrete.isAfter(agora)) {
      await _notificationService.cancelar(
        _idNotificacao(id),
      );

      return;
    }

    await _notificationService.agendar(
      id: _idNotificacao(id),
      titulo: 'Lembrete de consulta',
      mensagem: _montarMensagem(consulta),
      dataHora: lembrete,
    );
  }

  // ==========================================================
  // DATA E HORA
  // ==========================================================

  /// Converte data e hora retornadas pela API para DateTime.
  ///
  /// Aceita:
  ///
  /// 2026-08-19 + 14:00
  /// 2026-08-19 + 14:00:00
  /// 19/08/2026 + 14:00
  DateTime? _converterDataHora({
    required String data,
    required String hora,
  }) {
    final dataNormalizada = data.trim();
    final horaNormalizada = hora.trim();

    final resultado = DateTime.tryParse(
      '$dataNormalizada $horaNormalizada',
    );

    if (resultado != null) {
      return resultado;
    }

    final partesData =
    dataNormalizada.split('/');

    if (partesData.length != 3) {
      return null;
    }

    final dia = int.tryParse(
      partesData[0],
    );

    final mes = int.tryParse(
      partesData[1],
    );

    final ano = int.tryParse(
      partesData[2],
    );

    if (dia == null ||
        mes == null ||
        ano == null) {
      return null;
    }

    final partesHora =
    horaNormalizada.split(':');

    final horaValor =
    partesHora.isNotEmpty
        ? int.tryParse(partesHora[0])
        : null;

    final minutoValor =
    partesHora.length > 1
        ? int.tryParse(partesHora[1])
        : 0;

    final segundoValor =
    partesHora.length > 2
        ? int.tryParse(partesHora[2])
        : 0;

    if (horaValor == null ||
        minutoValor == null ||
        segundoValor == null) {
      return null;
    }

    if (horaValor < 0 ||
        horaValor > 23 ||
        minutoValor < 0 ||
        minutoValor > 59 ||
        segundoValor < 0 ||
        segundoValor > 59) {
      return null;
    }

    return DateTime(
      ano,
      mes,
      dia,
      horaValor,
      minutoValor,
      segundoValor,
    );
  }

  // ==========================================================
  // FORMATAÇÃO
  // ==========================================================

  String _montarMensagem(
      DateTime consulta,
      ) {
    return 'Seu horário está agendado para '
        '${_formatarData(consulta)} às '
        '${_formatarHora(consulta)}.';
  }

  String _formatarData(
      DateTime data,
      ) {
    final dia = data.day
        .toString()
        .padLeft(2, '0');

    final mes = data.month
        .toString()
        .padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  String _formatarHora(
      DateTime data,
      ) {
    final hora = data.hour
        .toString()
        .padLeft(2, '0');

    final minuto = data.minute
        .toString()
        .padLeft(2, '0');

    return '$hora:$minuto';
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  int? _obterIdAgendamento(
      Map<dynamic, dynamic> agendamento,
      ) {
    final valor = agendamento['id'];

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    if (valor is String) {
      return int.tryParse(valor);
    }

    return null;
  }

  String? _obterTexto(
      dynamic valor,
      ) {
    if (valor == null) {
      return null;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }

  /// Status que não devem gerar lembrete.
  bool _statusNaoDeveNotificar(
      String? status,
      ) {
    if (status == null) {
      return false;
    }

    final normalizado = status
        .trim()
        .toLowerCase();

    return normalizado == 'cancelado' ||
        normalizado == 'cancelada' ||
        normalizado == 'finalizado' ||
        normalizado == 'finalizada' ||
        normalizado == 'falta' ||
        normalizado == 'remarcado' ||
        normalizado == 'remarcada';
  }

  /// Gera um ID exclusivo para a notificação.
  int _idNotificacao(
      int agendamentoId,
      ) {
    return 100000 + agendamentoId;
  }

  // ==========================================================
  // AUTENTICAÇÃO
  // ==========================================================

  Future<String> _obterToken() async {
    final tokenRecebido =
    await _authService.obterToken();

    if (tokenRecebido == null) {
      throw const AgendaException(
        'Sessão de autenticação não encontrada.',
      );
    }

    final token = tokenRecebido.trim();

    if (token.isEmpty) {
      throw const AgendaException(
        'Sessão de autenticação não encontrada.',
      );
    }

    return token;
  }

  // ==========================================================
  // NORMALIZAÇÃO
  // ==========================================================

  Map<String, dynamic> _normalizarMapa(
      dynamic resposta,
      ) {
    if (resposta is Map<String, dynamic>) {
      return resposta;
    }

    if (resposta is Map) {
      return Map<String, dynamic>.from(
        resposta,
      );
    }

    return <String, dynamic>{};
  }
}

// ============================================================
// EXCEÇÕES DA AGENDA
// ============================================================

class AgendaException implements Exception {
  const AgendaException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

/// Conflito de negócio retornado pela API.
///
/// Exemplos:
///
/// - CONSULTA_FUTURA_EXISTENTE
/// - HORARIO_INDISPONIVEL
class AgendaConflitoException implements Exception {
  const AgendaConflitoException({
    required this.codigo,
    required this.mensagem,
    required this.agendamento,
    this.statusCode,
  });

  final String codigo;
  final String mensagem;
  final Map<String, dynamic>? agendamento;
  final int? statusCode;

  bool get possuiConsultaFutura =>
      codigo == 'CONSULTA_FUTURA_EXISTENTE';

  bool get horarioIndisponivel =>
      codigo == 'HORARIO_INDISPONIVEL';

  @override
  String toString() {
    return mensagem;
  }
}