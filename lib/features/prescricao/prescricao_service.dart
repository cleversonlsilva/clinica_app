import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

/// Serviço responsável por carregar e normalizar
/// as prescrições do paciente.
///
/// A comunicação HTTP permanece no
/// PacienteApiService.
///
/// Este serviço concentra:
/// - recuperação do token;
/// - chamada da API;
/// - validação da resposta;
/// - normalização das prescrições;
/// - acesso aos dados da prescrição.
///
/// Importante:
/// Os dados apresentados são provenientes do backend.
/// Este serviço NÃO altera nem recalcula o conteúdo
/// da prescrição.
class PrescricaoService {
  PrescricaoService({
    required this.authService,
    required this.pacienteApiService,
  });

  final AuthService authService;
  final PacienteApiService pacienteApiService;

  // ==========================================================
  // PRESCRIÇÕES
  // ==========================================================

  /// Carrega todas as prescrições do paciente autenticado.
  ///
  /// Endpoint:
  ///
  /// GET /api/app/paciente/prescricao
  Future<Map<String, dynamic>> carregarPrescricoes() async {
    final token = await _obterToken();

    final resposta = await pacienteApiService.obterPrescricao(
      token: token,
    );

    final resultado = _normalizarMapa(resposta);

    if (resultado['ok'] == false) {
      throw PrescricaoException(
        _obterMensagem(
          resultado,
          fallback:
          'Não foi possível carregar as prescrições.',
        ),
      );
    }

    return resultado;
  }

  /// Retorna somente a lista de prescrições.
  Future<List<Map<String, dynamic>>> listarPrescricoes() async {
    final resposta = await carregarPrescricoes();

    final prescricoes = resposta['prescricoes'];

    if (prescricoes is! List) {
      return <Map<String, dynamic>>[];
    }

    return prescricoes
        .whereType<Map>()
        .map(
          (prescricao) => Map<String, dynamic>.from(
        prescricao,
      ),
    )
        .toList();
  }

  // ==========================================================
  // TOKEN
  // ==========================================================

  Future<String> _obterToken() async {
    final token = await authService.obterToken();

    if (token == null || token.trim().isEmpty) {
      throw const PrescricaoException(
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
  // TEXTO
  // ==========================================================

  /// Retorna o texto completo da prescrição.
  String obterTexto(
      Map<String, dynamic> prescricao,
      ) {
    final texto = prescricao['texto'];

    if (texto == null) {
      return '';
    }

    return texto.toString().trim();
  }

  /// Retorna o resumo fornecido pelo backend.
  ///
  /// Não recria o resumo localmente. O backend já fornece
  /// o campo "resumo" preparado para a listagem.
  String obterResumo(
      Map<String, dynamic> prescricao,
      ) {
    final resumo = prescricao['resumo'];

    if (resumo != null &&
        resumo.toString().trim().isNotEmpty) {
      return resumo.toString().trim();
    }

    return obterTexto(prescricao);
  }

  // ==========================================================
  // PROFISSIONAL
  // ==========================================================

  /// Retorna o nome do profissional responsável.
  String obterProfissional(
      Map<String, dynamic> prescricao,
      ) {
    final profissional =
    prescricao['profissional_nome'];

    if (profissional == null) {
      return '';
    }

    return profissional.toString().trim();
  }

  // ==========================================================
  // STATUS
  // ==========================================================

  /// Retorna o status original enviado pela API.
  String obterStatus(
      Map<String, dynamic> prescricao,
      ) {
    final status = prescricao['status'];

    if (status == null) {
      return '';
    }

    return status.toString().trim();
  }

  /// Retorna uma versão amigável do status.
  ///
  /// O valor original continua disponível através
  /// de obterStatus().
  String obterStatusFormatado(
      Map<String, dynamic> prescricao,
      ) {
    final status = obterStatus(prescricao);

    if (status.isEmpty) {
      return 'Não informado';
    }

    switch (status.toLowerCase()) {
      case 'ativa':
        return 'Ativa';

      case 'cancelada':
        return 'Cancelada';

      case 'inativa':
        return 'Inativa';

      case 'finalizada':
        return 'Finalizada';

      default:
        return status;
    }
  }

  // ==========================================================
  // DATA
  // ==========================================================

  /// Retorna a data já formatada pelo backend.
  ///
  /// A API fornece o campo "data" no formato:
  ///
  /// DD/MM/YYYY
  ///
  /// Portanto não fazemos uma nova conversão aqui.
  String obterData(
      Map<String, dynamic> prescricao,
      ) {
    final data = prescricao['data'];

    if (data == null) {
      return '';
    }

    return data.toString().trim();
  }

  // ==========================================================
  // IDENTIFICAÇÃO
  // ==========================================================

  /// Retorna o ID da prescrição.
  int? obterId(
      Map<String, dynamic> prescricao,
      ) {
    final id = prescricao['id'];

    if (id is int) {
      return id;
    }

    if (id is num) {
      return id.toInt();
    }

    return int.tryParse(
      id?.toString() ?? '',
    );
  }

  /// Retorna o ID do paciente associado.
  int? obterPacienteId(
      Map<String, dynamic> prescricao,
      ) {
    final id = prescricao['paciente_id'];

    if (id is int) {
      return id;
    }

    if (id is num) {
      return id.toInt();
    }

    return int.tryParse(
      id?.toString() ?? '',
    );
  }

  // ==========================================================
  // INFORMAÇÕES AUXILIARES
  // ==========================================================

  /// Retorna a quantidade de caracteres do texto.
  int obterTotalCaracteres(
      Map<String, dynamic> prescricao,
      ) {
    final total =
    prescricao['total_caracteres'];

    if (total is int) {
      return total;
    }

    if (total is num) {
      return total.toInt();
    }

    return obterTexto(prescricao).length;
  }

  /// Retorna a origem da prescrição.
  String obterOrigem(
      Map<String, dynamic> prescricao,
      ) {
    final origem = prescricao['origem'];

    if (origem == null) {
      return '';
    }

    return origem.toString().trim();
  }

  // ==========================================================
  // VALIDAÇÃO
  // ==========================================================

  /// Verifica se existe conteúdo válido na prescrição.
  bool possuiConteudo(
      Map<String, dynamic> prescricao,
      ) {
    return obterTexto(prescricao).isNotEmpty;
  }
}

/// Exceção específica do módulo de Prescrições.
class PrescricaoException implements Exception {
  const PrescricaoException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}