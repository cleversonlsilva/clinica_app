import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

/// Serviço responsável por carregar e normalizar
/// os dados de um Plano Alimentar específico do paciente.
///
/// A comunicação HTTP permanece no PacienteApiService.
///
/// Este serviço concentra:
/// - recuperação do token;
/// - chamada da API;
/// - validação da resposta;
/// - normalização dos dados para a interface;
/// - normalização das refeições;
/// - normalização dos alimentos;
/// - normalização das substituições A/B/C.
class PlanoAlimentarService {
  PlanoAlimentarService({
    required this._authService,
    required this._pacienteApiService,
  });

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;

  /// Carrega um plano alimentar específico.
  ///
  /// Endpoint utilizado:
  ///
  /// GET /api/app/paciente/plano/{planoId}
  ///
  /// O backend retorna o plano completo, incluindo:
  /// - dados do plano;
  /// - refeições;
  /// - alimentos;
  /// - quantidades;
  /// - kcal;
  /// - substituições A, B e C.
  Future<Map<String, dynamic>> carregar({
    required int planoId,
  }) async {
    if (planoId <= 0) {
      throw const PlanoAlimentarException(
        'Plano alimentar inválido.',
      );
    }

    final token = await _authService.obterToken();

    if (token == null || token.isEmpty) {
      throw const PlanoAlimentarException(
        'Sessão de autenticação não encontrada.',
      );
    }

    final resposta = await _pacienteApiService.obterPlanoPorId(
      token: token,
      planoId: planoId,
    );

    if (resposta['ok'] != true) {
      throw PlanoAlimentarException(
        resposta['erro']?.toString() ??
            resposta['message']?.toString() ??
            'Não foi possível carregar o plano alimentar.',
      );
    }

    return _normalizarPlano(resposta);
  }

  /// Normaliza a resposta recebida da API.
  Map<String, dynamic> _normalizarPlano(
      Map<String, dynamic> resposta,
      ) {
    return {
      'id': resposta['id'],
      'nome': resposta['nome']?.toString() ?? '',
      'paciente_id': resposta['paciente_id'],
      'clinica_id': resposta['clinica_id'],
      'profissional_id': resposta['profissional_id'],
      'criado_em': resposta['criado_em'],
      'total_kcal': _numero(
        resposta['total_kcal'],
      ),
      'total_refeicoes': _inteiro(
        resposta['total_refeicoes'],
      ),
      'refeicoes': _normalizarRefeicoes(
        resposta['refeicoes'],
      ),
    };
  }

  /// Normaliza a lista de refeições.
  List<Map<String, dynamic>> _normalizarRefeicoes(
      dynamic valor,
      ) {
    if (valor is! List) {
      return [];
    }

    return valor
        .whereType<Map>()
        .map(
          (refeicao) => {
        'id': refeicao['id'],
        'hora': refeicao['hora'],
        'nome': refeicao['nome']?.toString() ?? '',
        'ordem': _inteiro(
          refeicao['ordem'],
        ),
        'total_kcal': _numero(
          refeicao['total_kcal'],
        ),
        'itens': _normalizarItens(
          refeicao['itens'],
        ),
      },
    )
        .toList();
  }

  /// Normaliza os itens de uma refeição.
  List<Map<String, dynamic>> _normalizarItens(
      dynamic valor,
      ) {
    if (valor is! List) {
      return [];
    }

    return valor
        .whereType<Map>()
        .map(
          (item) => {
        'id': item['id'],
        'tabela': item['tabela'],
        'alimento_id': item['alimento_id'],
        'descricao': item['descricao']?.toString() ?? '',
        'quantidade': _numero(
          item['quantidade'],
        ),
        'unidade': item['unidade']?.toString() ?? '',
        'unidade_id': item['unidade_id'],
        'kcal_100': _numero(
          item['kcal_100'],
        ),
        'kcal_total': _numero(
          item['kcal_total'],
        ),
        'observacao': item['observacao']?.toString() ?? '',
        'tipo_alimento':
        item['tipo_alimento']?.toString() ?? '',
        'gramas': _numero(
          item['gramas'],
        ),
        'substituicoes': _normalizarSubstituicoes(
          item['substituicoes'],
        ),
      },
    )
        .toList();
  }

  /// Normaliza as substituições de um alimento.
  ///
  /// Cada alimento pode possuir as opções:
  /// A, B e C.
  ///
  /// Exemplo:
  ///
  /// [
  ///   {
  ///     "opcao": "A",
  ///     "nome": "Alimento substituto",
  ///     "quantidade": 1.0,
  ///     "unidade": "un",
  ///     "kcal": 120.0
  ///   }
  /// ]
  List<Map<String, dynamic>> _normalizarSubstituicoes(
      dynamic valor,
      ) {
    if (valor is! List) {
      return [];
    }

    return valor
        .whereType<Map>()
        .map(
          (substituicao) => {
        'id': substituicao['id'],
        'alimento_id': substituicao['alimento_id'],
        'opcao':
        substituicao['opcao']?.toString() ?? '',
        'nome':
        substituicao['nome']?.toString() ?? '',
        'quantidade': _numero(
          substituicao['quantidade'],
        ),
        'unidade':
        substituicao['unidade']?.toString() ?? '',
        'kcal': _numero(
          substituicao['kcal'],
        ),
        'observacao':
        substituicao['observacao']?.toString() ?? '',
        'origem':
        substituicao['origem']?.toString() ?? '',
      },
    )
        .toList();
  }

  /// Converte valores numéricos para double.
  double _numero(dynamic valor) {
    if (valor is num) {
      return valor.toDouble();
    }

    if (valor is String) {
      return double.tryParse(valor) ?? 0;
    }

    return 0;
  }

  /// Converte valores numéricos para int.
  int _inteiro(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    if (valor is String) {
      return int.tryParse(valor) ?? 0;
    }

    return 0;
  }
}

/// Exceção específica do Plano Alimentar.
class PlanoAlimentarException implements Exception {
  const PlanoAlimentarException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}