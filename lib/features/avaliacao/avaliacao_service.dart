import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

/// Serviço responsável por carregar e normalizar
/// as avaliações corporais do paciente.
///
/// A comunicação HTTP permanece no
/// PacienteApiService.
///
/// Este serviço concentra:
/// - recuperação do token;
/// - chamada da API;
/// - validação da resposta;
/// - normalização das avaliações;
/// - normalização dos valores;
/// - acesso aos campos preenchidos.
///
/// Importante:
/// Os valores calculados da avaliação corporal são
/// responsabilidade do backend.
///
/// Este serviço NÃO recalcula IMC, RCQ, RCE
/// ou qualquer outro indicador.
class AvaliacaoService {
  AvaliacaoService({
    required this._authService,
    required this._pacienteApiService,
  });

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;

  // ==========================================================
  // AVALIAÇÕES
  // ==========================================================

  /// Carrega todas as avaliações corporais
  /// do paciente autenticado.
  ///
  /// Endpoint:
  ///
  /// GET /api/app/paciente/avaliacao
  Future<Map<String, dynamic>> carregarAvaliacoes() async {
    final token = await _obterToken();

    final resposta = await _pacienteApiService.obterAvaliacao(
      token: token,
    );

    final resultado = _normalizarMapa(resposta);

    if (resultado['ok'] == false) {
      throw AvaliacaoException(
        _obterMensagem(
          resultado,
          fallback:
          'Não foi possível carregar as avaliações corporais.',
        ),
      );
    }

    return resultado;
  }

  /// Retorna somente a lista de avaliações.
  Future<List<Map<String, dynamic>>> listarAvaliacoes() async {
    final resposta = await carregarAvaliacoes();

    final avaliacoes = resposta['avaliacoes'];

    if (avaliacoes is! List) {
      return <Map<String, dynamic>>[];
    }

    return avaliacoes
        .whereType<Map>()
        .map(
          (avaliacao) => Map<String, dynamic>.from(avaliacao),
    )
        .toList();
  }

  // ==========================================================
  // TOKEN
  // ==========================================================

  Future<String> _obterToken() async {
    final token = await _authService.obterToken();

    if (token == null || token.trim().isEmpty) {
      throw const AvaliacaoException(
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

  // ==========================================================
  // VALORES
  // ==========================================================

  /// Retorna os valores registrados em uma avaliação.
  ///
  /// A API fornece os valores no formato:
  ///
  /// {
  ///   "id": ...,
  ///   "campo_id": ...,
  ///   "valor": ...,
  ///   "campo": {
  ///     "codigo": ...,
  ///     "descricao": ...,
  ///     "unidade": ...,
  ///     ...
  ///   }
  /// }
  List<Map<String, dynamic>> obterValores(
      Map<String, dynamic> avaliacao,
      ) {
    final valores = avaliacao['valores'];

    if (valores is! List) {
      return <Map<String, dynamic>>[];
    }

    return valores
        .whereType<Map>()
        .map(
          (valor) => Map<String, dynamic>.from(valor),
    )
        .toList();
  }

  /// Retorna somente os valores preenchidos.
  List<Map<String, dynamic>> obterValoresPreenchidos(
      Map<String, dynamic> avaliacao,
      ) {
    final valores = obterValores(avaliacao);

    return valores.where((registro) {
      final valor = registro['valor'];

      if (valor == null) {
        return false;
      }

      return valor.toString().trim().isNotEmpty;
    }).toList();
  }

  // ==========================================================
  // CAMPOS
  // ==========================================================

  /// Retorna os dados do campo associado a um valor.
  Map<String, dynamic> obterCampo(
      Map<String, dynamic> registro,
      ) {
    final campo = registro['campo'];

    if (campo is Map<String, dynamic>) {
      return campo;
    }

    if (campo is Map) {
      return Map<String, dynamic>.from(campo);
    }

    return <String, dynamic>{};
  }

  /// Retorna a descrição do campo.
  String descricaoCampo(
      Map<String, dynamic> registro,
      ) {
    final campo = obterCampo(registro);

    final descricao = campo['descricao'];

    if (descricao != null &&
        descricao.toString().trim().isNotEmpty) {
      return descricao.toString().trim();
    }

    final codigo = campo['codigo'];

    if (codigo != null &&
        codigo.toString().trim().isNotEmpty) {
      return codigo.toString().trim();
    }

    return 'Campo';
  }

  /// Retorna a unidade do campo, quando existente.
  String? unidadeCampo(
      Map<String, dynamic> registro,
      ) {
    final campo = obterCampo(registro);

    final unidade = campo['unidade'];

    if (unidade == null) {
      return null;
    }

    final texto = unidade.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }

  /// Retorna o valor original para apresentação.
  ///
  /// IMPORTANTE:
  /// Este método NÃO converte, arredonda ou recalcula
  /// valores vindos da API.
  String valorFormatado(
      Map<String, dynamic> registro,
      ) {
    final valor = registro['valor'];

    if (valor == null) {
      return '';
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return '';
    }

    final unidade = unidadeCampo(registro);

    if (unidade == null) {
      return texto;
    }

    return '$texto $unidade';
  }
}

/// Exceção específica da Avaliação Corporal.
class AvaliacaoException implements Exception {
  const AvaliacaoException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}