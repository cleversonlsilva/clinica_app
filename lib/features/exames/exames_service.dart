import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

class ExamesService {
  ExamesService({
    required this._authService,
    required this._pacienteApiService,
  });

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;

  // ==========================================================
  // EXAMES
  // ==========================================================

  /// Carrega as solicitações de exames do paciente autenticado.
  ///
  /// A comunicação HTTP permanece no PacienteApiService.
  ///
  /// Endpoint:
  ///
  /// GET /api/app/paciente/exames
  Future<Map<String, dynamic>> carregarExames() async {
    final token = await _obterToken();

    final resposta = await _pacienteApiService.obterExames(
      token: token,
    );

    final resultado = _normalizarMapa(resposta);

    if (resultado['ok'] == false) {
      throw ExamesException(
        _obterMensagem(
          resultado,
          fallback: 'Não foi possível carregar os exames.',
        ),
      );
    }

    return resultado;
  }

  /// Retorna somente a lista de exames.
  ///
  /// A API retorna a lista no campo:
  ///
  /// "exames"
  Future<List<Map<String, dynamic>>> listarExames() async {
    final resposta = await carregarExames();

    final exames = resposta['exames'];

    if (exames is! List) {
      return <Map<String, dynamic>>[];
    }

    return exames
        .whereType<Map>()
        .map(
          (exame) => Map<String, dynamic>.from(exame),
    )
        .toList();
  }

  // ==========================================================
  // DETALHE DA SOLICITAÇÃO
  // ==========================================================

  /// Carrega os detalhes de uma solicitação de exames.
  ///
  /// Endpoint:
  ///
  /// GET /api/app/paciente/exames/{solicitacao_id}
  ///
  /// Retorna os dados completos da solicitação,
  /// incluindo:
  ///
  /// - dados da solicitação;
  /// - paciente;
  /// - profissional;
  /// - exames solicitados;
  /// - resultados;
  /// - observações;
  /// - validade;
  /// - status.
  Future<Map<String, dynamic>> carregarDetalhe({
    required int solicitacaoId,
  }) async {
    if (solicitacaoId <= 0) {
      throw ExamesException(
        'Solicitação de exame inválida.',
      );
    }

    final token = await _obterToken();

    final resposta =
    await _pacienteApiService.obterDetalheExame(
      token: token,
      solicitacaoId: solicitacaoId,
    );

    final resultado = _normalizarMapa(resposta);

    if (resultado['ok'] != true) {
      throw ExamesException(
        _obterMensagem(
          resultado,
          fallback:
          'Não foi possível carregar os detalhes dos exames.',
        ),
      );
    }

    return _normalizarDetalhe(resultado);
  }

  // ==========================================================
  // NORMALIZAÇÃO DO DETALHE
  // ==========================================================

  Map<String, dynamic> _normalizarDetalhe(
      Map<String, dynamic> resposta,
      ) {
    final solicitacao = resposta['solicitacao'];

    final paciente = resposta['paciente'];

    final profissional = resposta['profissional'];

    final exames = resposta['exames'];

    final resultados = resposta['resultados'];

    return {
      ...resposta,

      'solicitacao':
      solicitacao is Map
          ? Map<String, dynamic>.from(solicitacao)
          : <String, dynamic>{},

      'paciente':
      paciente is Map
          ? Map<String, dynamic>.from(paciente)
          : <String, dynamic>{},

      'profissional':
      profissional is Map
          ? Map<String, dynamic>.from(profissional)
          : <String, dynamic>{},

      'exames':
      exames is List
          ? exames
          .whereType<Map>()
          .map(
            (exame) =>
        Map<String, dynamic>.from(exame),
      )
          .toList()
          : <Map<String, dynamic>>[],

      'resultados':
      resultados is List
          ? resultados
          .whereType<Map>()
          .map(
            (resultado) =>
        Map<String, dynamic>.from(resultado),
      )
          .toList()
          : <Map<String, dynamic>>[],
    };
  }

  // ==========================================================
  // TOKEN
  // ==========================================================

  Future<String> _obterToken() async {
    final token = await _authService.obterToken();

    if (token == null || token.trim().isEmpty) {
      throw ExamesException(
        'Sessão do paciente não encontrada.',
      );
    }

    return token.trim();
  }

  // ==========================================================
  // NORMALIZAÇÃO
  // ==========================================================

  Map<String, dynamic> _normalizarMapa(
      Map<String, dynamic>? resposta,
      ) {
    if (resposta == null) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(resposta);
  }

  // ==========================================================
  // MENSAGEM
  // ==========================================================

  String _obterMensagem(
      Map<String, dynamic> dados, {
        required String fallback,
      }) {
    final mensagem =
        dados['mensagem'] ??
            dados['message'] ??
            dados['erro'];

    if (mensagem == null) {
      return fallback;
    }

    final texto = mensagem.toString().trim();

    if (texto.isEmpty) {
      return fallback;
    }

    return texto;
  }
}

// ============================================================
// EXCEÇÃO
// ============================================================

class ExamesException implements Exception {
  ExamesException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}