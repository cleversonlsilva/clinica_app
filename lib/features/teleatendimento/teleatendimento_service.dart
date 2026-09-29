import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

/// Serviço responsável pelas operações de teleatendimento
/// do paciente no Clínica App.
///
/// Coordena a autenticação da sessão e o acesso aos dados
/// do teleatendimento através do PacienteApiService.
class TeleatendimentoService {
  TeleatendimentoService({
    required this._authService,
    required this._pacienteApiService,
  });

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;

  // ==========================================================
  // TELEATENDIMENTO
  // ==========================================================

  /// Carrega os dados de um teleatendimento do paciente
  /// autenticado.
  ///
  /// O backend valida:
  /// - o paciente identificado pelo token;
  /// - a clínica da sessão;
  /// - a propriedade do teleatendimento;
  /// - o status do atendimento.
  Future<Map<String, dynamic>> obterTeleatendimento({
    required int teleatendimentoId,
  }) async {
    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.obterTeleatendimento(
      token: token,
      teleatendimentoId: teleatendimentoId,
    );

    return resposta;
  }

  // ==========================================================
  // LIVEKIT
  // ==========================================================

  /// Obtém um token temporário do LiveKit para o paciente
  /// entrar na mesma sala do teleatendimento.
  ///
  /// O backend é responsável por:
  /// - identificar o paciente pelo token;
  /// - validar a clínica;
  /// - validar o teleatendimento;
  /// - validar a situação do atendimento;
  /// - gerar o JWT temporário do LiveKit;
  /// - liberar somente a sala correspondente ao atendimento.
  ///
  /// O JWT do LiveKit não é armazenado no aplicativo.
  Future<Map<String, dynamic>> obterTokenLiveKit({
    required int teleatendimentoId,
  }) async {
    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.obterTokenTeleatendimento(
      token: token,
      teleatendimentoId: teleatendimentoId,
    );

    return resposta;
  }

  // ==========================================================
  // ENTRADA NO TELEATENDIMENTO
  // ==========================================================

  /// Registra a entrada do paciente no teleatendimento.
  ///
  /// O backend é responsável por:
  /// - identificar o paciente através do token;
  /// - validar a clínica;
  /// - validar o teleatendimento;
  /// - validar que o paciente pertence ao atendimento;
  /// - registrar PACIENTE_ENTROU;
  /// - registrar INICIO_ATENDIMENTO;
  /// - alterar o status para EM_ANDAMENTO quando aplicável.
  ///
  /// Não cria outro teleatendimento e não cria outra sala.
  Future<Map<String, dynamic>> entrarTeleatendimento({
    required int teleatendimentoId,
  }) async {
    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.entrarTeleatendimento(
      token: token,
      teleatendimentoId: teleatendimentoId,
    );

    return resposta;
  }

  // ==========================================================
  // SAÍDA DO TELEATENDIMENTO
  // ==========================================================

  /// Registra a saída do paciente do teleatendimento.
  ///
  /// O backend identifica o paciente através do token
  /// autenticado, valida o teleatendimento e registra
  /// o evento PACIENTE_SAIU.
  ///
  /// A saída do paciente não encerra o atendimento.
  /// O profissional continua responsável pelo encerramento.
  Future<Map<String, dynamic>> sairTeleatendimento({
    required int teleatendimentoId,
  }) async {
    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.sairTeleatendimento(
      token: token,
      teleatendimentoId: teleatendimentoId,
    );

    return resposta;
  }

  // ==========================================================
  // AUTENTICAÇÃO
  // ==========================================================

  /// Obtém o token da sessão atual.
  Future<String> _obterToken() async {
    final tokenRecebido =
    await _authService.obterToken();

    if (tokenRecebido == null) {
      throw const TeleatendimentoException(
        'Sessão de autenticação não encontrada.',
      );
    }

    final token = tokenRecebido.trim();

    if (token.isEmpty) {
      throw const TeleatendimentoException(
        'Sessão de autenticação não encontrada.',
      );
    }

    return token;
  }
}

/// Exceção específica para problemas relacionados
/// ao teleatendimento no aplicativo.
class TeleatendimentoException implements Exception {
  const TeleatendimentoException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
