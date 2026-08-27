import '../core/network/api_client.dart';

/// Serviço responsável pelas operações relacionadas
/// aos dados do paciente no Clínica App.
///
/// Este serviço não realiza diretamente requisições HTTP.
/// A comunicação é delegada ao ApiClient.
class PacienteApiService {
  PacienteApiService({
    required this._apiClient,
  });

  final ApiClient _apiClient;

  // ==========================================================
  // RESUMO
  // ==========================================================

  /// Carrega o resumo do paciente autenticado.
  ///
  /// GET /api/app/paciente/resumo
  Future<Map<String, dynamic>> obterResumo({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/resumo',
      token: token,
    );
  }

  // ==========================================================
  // PERFIL
  // ==========================================================

  /// Carrega o perfil do paciente autenticado.
  ///
  /// GET /api/app/paciente/perfil
  Future<Map<String, dynamic>> obterPerfil({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/perfil',
      token: token,
    );
  }

  // ==========================================================
  // AGENDA
  // ==========================================================

  /// Carrega os agendamentos do paciente autenticado.
  ///
  /// GET /api/app/paciente/agenda
  Future<Map<String, dynamic>> obterAgenda({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/agenda',
      token: token,
    );
  }

  /// Consulta os horários disponíveis para agendamento.
  ///
  /// GET /api/app/paciente/agenda/disponibilidade?data=YYYY-MM-DD
  Future<Map<String, dynamic>> obterDisponibilidade({
    required String token,
    required String data,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/agenda/disponibilidade?data=$data',
      token: token,
    );
  }

  /// Cria um novo agendamento pelo aplicativo.
  ///
  /// POST /api/app/paciente/agenda/agendar
  ///
  /// Corpo:
  ///
  /// {
  ///   "data": "YYYY-MM-DD",
  ///   "hora": "HH:MM"
  /// }
  ///
  /// Campos opcionais:
  ///
  /// - tipo
  /// - observacao
  Future<Map<String, dynamic>> agendarConsulta({
    required String token,
    required String data,
    required String hora,
    String? tipo,
    String? observacao,
  }) async {
    final body = <String, dynamic>{
      'data': data,
      'hora': hora,
    };

    if (tipo != null && tipo.trim().isNotEmpty) {
      body['tipo'] = tipo.trim();
    }

    if (observacao != null &&
        observacao.trim().isNotEmpty) {
      body['observacao'] = observacao.trim();
    }

    return _apiClient.post(
      '/api/app/paciente/agenda/agendar',
      token: token,
      body: body,
    );
  }

  /// Solicita a remarcação de uma consulta.
  ///
  /// POST /api/app/paciente/agenda/remarcar
  Future<Map<String, dynamic>> remarcarConsulta({
    required String token,
    required int agendamentoId,
    required String data,
    required String hora,
  }) async {
    final body = <String, dynamic>{
      'agendamento_id': agendamentoId,
      'data': data,
      'hora': hora,
    };

    return _apiClient.post(
      '/api/app/paciente/agenda/remarcar',
      token: token,
      body: body,
    );
  }

  /// Confirma uma consulta pelo aplicativo.
  ///
  /// POST /api/app/paciente/agenda/confirmar
  Future<Map<String, dynamic>> confirmarConsulta({
    required String token,
    required int agendamentoId,
  }) async {
    final body = <String, dynamic>{
      'agendamento_id': agendamentoId,
    };

    return _apiClient.post(
      '/api/app/paciente/agenda/confirmar',
      token: token,
      body: body,
    );
  }

  // ==========================================================
  // PLANO ALIMENTAR
  // ==========================================================

  /// Carrega a lista resumida dos planos alimentares.
  ///
  /// GET /api/app/paciente/plano
  Future<Map<String, dynamic>> obterPlano({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/plano',
      token: token,
    );
  }

  /// Carrega o plano alimentar completo.
  ///
  /// GET /api/app/paciente/plano/{plano_id}
  Future<Map<String, dynamic>> obterDetalhePlano({
    required String token,
    required int planoId,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/plano/$planoId',
      token: token,
    );
  }

  /// Alias para obter o plano alimentar específico.
  Future<Map<String, dynamic>> obterPlanoPorId({
    required String token,
    required int planoId,
  }) async {
    return obterDetalhePlano(
      token: token,
      planoId: planoId,
    );
  }

  // ==========================================================
  // EXAMES
  // ==========================================================

  /// Carrega os exames do paciente autenticado.
  ///
  /// GET /api/app/paciente/exames
  Future<Map<String, dynamic>> obterExames({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/exames',
      token: token,
    );
  }

  /// Carrega os detalhes de uma solicitação de exames.
  ///
  /// GET /api/app/paciente/exames/{solicitacao_id}
  ///
  /// Retorna:
  /// - dados da solicitação;
  /// - paciente;
  /// - profissional;
  /// - exames solicitados;
  /// - resultados anexados;
  /// - observações;
  /// - validade;
  /// - status.
  Future<Map<String, dynamic>> obterDetalheExame({
    required String token,
    required int solicitacaoId,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/exames/$solicitacaoId',
      token: token,
    );
  }

  // ==========================================================
  // AVALIAÇÃO
  // ==========================================================

  /// Carrega as avaliações corporais do paciente autenticado.
  ///
  /// GET /api/app/paciente/avaliacao
  Future<Map<String, dynamic>> obterAvaliacao({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/avaliacao',
      token: token,
    );
  }

  // ==========================================================
  // PRESCRIÇÃO
  // ==========================================================

  /// Carrega as prescrições do paciente autenticado.
  ///
  /// GET /api/app/paciente/prescricao
  Future<Map<String, dynamic>> obterPrescricao({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/prescricao',
      token: token,
    );
  }

  /// Carrega o PDF de uma prescrição ativa.
  ///
  /// GET /api/app/paciente/prescricao/:prescricao_id/pdf
  ///
  /// Retorna os bytes do arquivo PDF.
  Future<List<int>> obterPrescricaoPdf({
    required String token,
    required int prescricaoId,
  }) async {
    return _apiClient.getBytes(
      '/api/app/paciente/prescricao/$prescricaoId/pdf',
      token: token,
    );
  }

  // ==========================================================
  // MEDIDAS
  // ==========================================================

  /// Carrega as medidas corporais do paciente autenticado.
  ///
  /// GET /api/app/paciente/medidas
  Future<Map<String, dynamic>> obterMedidas({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/medidas',
      token: token,
    );
  }

  // ==========================================================
  // TREINOS
  // ==========================================================

  /// Carrega os treinos prescritos para o paciente autenticado.
  ///
  /// GET /api/app/paciente/treino
  ///
  /// Retorna:
  /// - dados do treino;
  /// - objetivo;
  /// - tipo;
  /// - período;
  /// - observações;
  /// - exercícios;
  /// - ordem dos exercícios;
  /// - séries;
  /// - repetições;
  /// - carga;
  /// - tempo;
  /// - descanso;
  /// - grupo muscular;
  /// - equipamento;
  /// - vídeo;
  /// - imagem;
  /// - tipo de execução;
  /// - total de execuções no período.
  Future<Map<String, dynamic>> obterTreinos({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/treino',
      token: token,
    );
  }

  /// Registra a conclusão de um treino.
  ///
  /// POST /api/app/paciente/treino/:treino_id/executar
  ///
  /// Para treino de academia:
  /// - tempo pode ser informado.
  ///
  /// Para corrida:
  /// - tempo;
  /// - distância;
  /// - pace;
  /// - calorias;
  /// - rota GPS.
  ///
  /// O backend é responsável por:
  /// - validar o paciente;
  /// - validar a clínica;
  /// - validar o período do treino;
  /// - registrar a execução;
  /// - atualizar o total de execuções.
  Future<Map<String, dynamic>> registrarExecucaoTreino({
    required String token,
    required int treinoId,
    int? tempo,
    double? distancia,
    double? pace,
    double? calorias,
    List<Map<String, double>>? rota,
  }) async {
    final body = <String, dynamic>{};

    // --------------------------------------------------------
    // TEMPO
    // --------------------------------------------------------

    if (tempo != null && tempo > 0) {
      body['tempo'] = tempo;
    }

    // --------------------------------------------------------
    // CORRIDA
    // --------------------------------------------------------

    if (distancia != null && distancia >= 0) {
      body['distancia'] = distancia;
    }

    if (pace != null && pace >= 0) {
      body['pace'] = pace;
    }

    if (calorias != null && calorias >= 0) {
      body['calorias'] = calorias;
    }

    if (rota != null) {
      body['rota'] = rota;
    }

    return _apiClient.post(
      '/api/app/paciente/treino/$treinoId/executar',
      token: token,
      body: body,
    );
  }
}