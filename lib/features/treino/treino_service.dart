import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

/// Serviço responsável por carregar e normalizar
/// os treinos do paciente.
///
/// A comunicação HTTP permanece no
/// PacienteApiService.
///
/// Este serviço concentra:
/// - recuperação do token;
/// - chamada da API;
/// - validação da resposta;
/// - normalização dos treinos;
/// - normalização dos exercícios;
/// - identificação do tipo de treino.
///
/// Importante:
/// Este serviço NÃO calcula carga, gasto calórico,
/// pace, distância ou qualquer outro indicador.
///
/// Os dados são preservados conforme enviados
/// pelo backend.
class TreinoService {
  TreinoService({
    required this._authService,
    required this._pacienteApiService,
  });

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;

  // ==========================================================
  // TREINOS
  // ==========================================================

  /// Carrega os treinos do paciente autenticado.
  ///
  /// Endpoint:
  ///
  /// GET /api/app/paciente/treino
  Future<Map<String, dynamic>> carregarTreinos() async {
    final token = await _obterToken();

    final resposta = await _pacienteApiService.obterTreinos(
      token: token,
    );

    final resultado = _normalizarMapa(resposta);

    if (resultado['ok'] == false) {
      throw TreinoException(
        _obterMensagem(
          resultado,
          fallback:
          'Não foi possível carregar os treinos.',
        ),
      );
    }

    return resultado;
  }

  /// Retorna somente a lista de treinos.
  Future<List<Map<String, dynamic>>> listarTreinos() async {
    final resposta = await carregarTreinos();

    final treinos = resposta['treinos'];

    if (treinos is! List) {
      return <Map<String, dynamic>>[];
    }

    return treinos
        .whereType<Map>()
        .map(
          (treino) => Map<String, dynamic>.from(treino),
    )
        .toList();
  }

  // ==========================================================
  // EXERCÍCIOS
  // ==========================================================

  /// Retorna os exercícios de um treino.
  List<Map<String, dynamic>> obterExercicios(
      Map<String, dynamic> treino,
      ) {
    final exercicios = treino['exercicios'];

    if (exercicios is! List) {
      return <Map<String, dynamic>>[];
    }

    return exercicios
        .whereType<Map>()
        .map(
          (exercicio) =>
      Map<String, dynamic>.from(exercicio),
    )
        .toList();
  }

  /// Retorna somente os exercícios preenchidos.
  List<Map<String, dynamic>> obterExerciciosPreenchidos(
      Map<String, dynamic> treino,
      ) {
    return obterExercicios(treino).where((exercicio) {
      final nome = exercicio['nome'];

      return nome != null &&
          nome.toString().trim().isNotEmpty;
    }).toList();
  }

  // ==========================================================
  // TIPO DE TREINO
  // ==========================================================

  /// Retorna o tipo do treino.
  ///
  /// Exemplos encontrados na API:
  ///
  /// - academia
  /// - corrida
  /// - cardio
  String tipoTreino(
      Map<String, dynamic> treino,
      ) {
    final tipo = treino['tipo'];

    if (tipo == null) {
      return '';
    }

    return tipo.toString().trim().toLowerCase();
  }

  /// Verifica se o treino é de academia.
  bool isAcademia(
      Map<String, dynamic> treino,
      ) {
    return tipoTreino(treino) == 'academia';
  }

  /// Verifica se o treino é de corrida.
  bool isCorrida(
      Map<String, dynamic> treino,
      ) {
    return tipoTreino(treino) == 'corrida';
  }

  /// Verifica se o treino é de cardio.
  bool isCardio(
      Map<String, dynamic> treino,
      ) {
    final tipo = tipoTreino(treino);

    return tipo == 'cardio' || tipo == 'corrida';
  }

  // ==========================================================
  // DADOS DO EXERCÍCIO
  // ==========================================================

  /// Retorna o nome do exercício.
  String nomeExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final nome = exercicio['nome'];

    if (nome == null) {
      return 'Exercício';
    }

    final texto = nome.toString().trim();

    if (texto.isEmpty) {
      return 'Exercício';
    }

    return texto;
  }

  /// Retorna o número de séries.
  int? seriesExercicio(
      Map<String, dynamic> exercicio,
      ) {
    return _intOrNull(exercicio['series']);
  }

  /// Retorna o número de repetições.
  ///
  /// O backend pode enviar esse valor como número
  /// ou como texto.
  String repeticoesExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['repeticoes'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna a carga original do exercício.
  ///
  /// O valor não é convertido nem arredondado.
  String cargaExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['carga'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna o tempo definido para o exercício.
  int? tempoExercicio(
      Map<String, dynamic> exercicio,
      ) {
    return _intOrNull(exercicio['tempo']);
  }

  /// Retorna a unidade de tempo.
  String unidadeTempoExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['unidade_tempo'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna o tempo de descanso em segundos.
  int? descansoExercicio(
      Map<String, dynamic> exercicio,
      ) {
    return _intOrNull(exercicio['descanso']);
  }

  /// Retorna o grupo muscular.
  String grupoMuscular(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['grupo_muscular'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna o equipamento utilizado.
  String equipamentoExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['equipamento'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna o nível do exercício.
  String nivelExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['nivel'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna o tipo de execução.
  String tipoExecucao(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['tipo_execucao'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim().toLowerCase();
  }

  /// Retorna a URL do vídeo, quando disponível.
  String? videoUrl(
      Map<String, dynamic> exercicio,
      ) {
    return _textoOuNull(exercicio['video_url']);
  }

  /// Retorna a URL da imagem, quando disponível.
  String? imagemUrl(
      Map<String, dynamic> exercicio,
      ) {
    return _textoOuNull(exercicio['imagem_url']);
  }

  /// Retorna as observações do exercício.
  String observacoesExercicio(
      Map<String, dynamic> exercicio,
      ) {
    final valor = exercicio['observacoes'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna a ordem do exercício.
  int? ordemExercicio(
      Map<String, dynamic> exercicio,
      ) {
    return _intOrNull(exercicio['ordem']);
  }

  // ==========================================================
  // DADOS DO TREINO
  // ==========================================================

  /// Retorna o objetivo do treino.
  String objetivoTreino(
      Map<String, dynamic> treino,
      ) {
    final valor = treino['objetivo'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna as observações do treino.
  String observacoesTreino(
      Map<String, dynamic> treino,
      ) {
    final valor = treino['observacoes'];

    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  /// Retorna a data inicial do treino.
  String? dataInicioTreino(
      Map<String, dynamic> treino,
      ) {
    return _textoOuNull(treino['data_inicio']);
  }

  /// Retorna a data final do treino.
  String? dataFimTreino(
      Map<String, dynamic> treino,
      ) {
    return _textoOuNull(treino['data_fim']);
  }

  /// Retorna o ID do treino.
  int? idTreino(
      Map<String, dynamic> treino,
      ) {
    return _intOrNull(treino['id']);
  }

  // ==========================================================
  // TOKEN
  // ==========================================================

  Future<String> _obterToken() async {
    final token = await _authService.obterToken();

    if (token == null || token.trim().isEmpty) {
      throw const TreinoException(
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
  // CONVERSÕES INTERNAS
  // ==========================================================

  int? _intOrNull(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(
      valor.toString().trim(),
    );
  }

  String? _textoOuNull(dynamic valor) {
    if (valor == null) {
      return null;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return texto;
  }
}

/// Exceção específica do módulo de Treinos.
class TreinoException implements Exception {
  const TreinoException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}