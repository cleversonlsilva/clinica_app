import '../core/network/api_client.dart';

/// ServiÃ§o responsÃ¡vel pelas operaÃ§Ãµes relacionadas
/// aos dados do paciente no ClÃ­nica App.
///
/// Este serviÃ§o nÃ£o realiza diretamente requisiÃ§Ãµes HTTP.
/// A comunicaÃ§Ã£o Ã© delegada ao ApiClient.
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

  /// Consulta os horÃ¡rios disponÃ­veis para agendamento.
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

  /// Solicita a remarcaÃ§Ã£o de uma consulta.
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

  /// Alias para obter o plano alimentar especÃ­fico.
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

  /// Carrega os detalhes de uma solicitaÃ§Ã£o de exames.
  ///
  /// GET /api/app/paciente/exames/{solicitacao_id}
  ///
  /// Retorna:
  /// - dados da solicitaÃ§Ã£o;
  /// - paciente;
  /// - profissional;
  /// - exames solicitados;
  /// - resultados anexados;
  /// - observaÃ§Ãµes;
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
  // AVALIAÃ‡ÃƒO
  // ==========================================================

  /// Carrega as avaliaÃ§Ãµes corporais do paciente autenticado.
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
  // PRESCRIÃ‡ÃƒO
  // ==========================================================

  /// Carrega as prescriÃ§Ãµes do paciente autenticado.
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

  /// Carrega o PDF de uma prescriÃ§Ã£o ativa.
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
  /// - perÃ­odo;
  /// - observaÃ§Ãµes;
  /// - exercÃ­cios;
  /// - ordem dos exercÃ­cios;
  /// - sÃ©ries;
  /// - repetiÃ§Ãµes;
  /// - carga;
  /// - tempo;
  /// - descanso;
  /// - grupo muscular;
  /// - equipamento;
  /// - vÃ­deo;
  /// - imagem;
  /// - tipo de execuÃ§Ã£o;
  /// - total de execuÃ§Ãµes no perÃ­odo.
  Future<Map<String, dynamic>> obterTreinos({
    required String token,
  }) async {
    return _apiClient.get(
      '/api/app/paciente/treino',
      token: token,
    );
  }

  /// Registra a conclusÃ£o de um treino.
  ///
  /// POST /api/app/paciente/treino/:treino_id/executar
  ///
  /// O registro deve acontecer somente quando
  /// o paciente concluir o treino.
  ///
  /// O backend Ã© responsÃ¡vel por:
  /// - validar o paciente;
  /// - validar a clÃ­nica;
  /// - validar o perÃ­odo do treino;
  /// - registrar a execuÃ§Ã£o;
  /// - atualizar o total de execuÃ§Ãµes.
  ///
  /// O campo [tempo] Ã© opcional e representa o tempo
  /// total de execuÃ§Ã£o em segundos.
  Future<Map<String, dynamic>> registrarExecucaoTreino({
    required String token,
    required int treinoId,
    int? tempo,
  }) async {
    final body = <String, dynamic>{};

    if (tempo != null && tempo > 0) {
      body['tempo'] = tempo;
    }

    return _apiClient.post(
      '/api/app/paciente/treino/$treinoId/executar',
      token: token,
      body: body,
    );
  }
}
