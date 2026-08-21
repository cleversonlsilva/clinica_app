import '../../core/auth/auth_service.dart';
import '../../services/paciente_api_service.dart';

/// Serviço responsável por carregar e normalizar os dados
/// necessários para a Home do paciente.
///
/// As regras de comunicação permanecem no
/// PacienteApiService.
///
/// A HomeService apenas:
///
/// - recupera o token da sessão;
/// - consulta os endpoints necessários;
/// - identifica individualmente eventuais falhas;
/// - normaliza as respostas para a Home.
class HomeService {
  HomeService({
    required this._authService,
    required this._pacienteApiService,
  });

  final AuthService _authService;
  final PacienteApiService _pacienteApiService;

  /// Carrega os dados necessários para a Home.
  Future<Map<String, dynamic>> carregar() async {
    final token = await _authService.obterToken();

    if (token == null || token.isEmpty) {
      throw const HomeException(
        'Sessão de autenticação não encontrada.',
      );
    }

    final resumo = await _executar(
      nome: 'RESUMO',
      chamada: () => _pacienteApiService.obterResumo(
        token: token,
      ),
    );

    final perfil = await _executar(
      nome: 'PERFIL',
      chamada: () => _pacienteApiService.obterPerfil(
        token: token,
      ),
    );

    final agenda = await _executar(
      nome: 'AGENDA',
      chamada: () => _pacienteApiService.obterAgenda(
        token: token,
      ),
    );

    final plano = await _executar(
      nome: 'PLANO',
      chamada: () => _pacienteApiService.obterPlano(
        token: token,
      ),
    );

    final exames = await _executar(
      nome: 'EXAMES',
      chamada: () => _pacienteApiService.obterExames(
        token: token,
      ),
    );

    final avaliacao = await _executar(
      nome: 'AVALIAÇÃO',
      chamada: () => _pacienteApiService.obterAvaliacao(
        token: token,
      ),
    );

    final prescricao = await _executar(
      nome: 'PRESCRIÇÃO',
      chamada: () => _pacienteApiService.obterPrescricao(
        token: token,
      ),
    );

    final medidas = await _executar(
      nome: 'MEDIDAS',
      chamada: () => _pacienteApiService.obterMedidas(
        token: token,
      ),
    );

    return {
      'resumo': _mapa(resumo),
      'perfil': _mapa(perfil),
      'agenda': _normalizarLista(
        _mapa(agenda),
        'agenda',
      ),
      'plano': _normalizarLista(
        _mapa(plano),
        'planos',
      ),
      'exames': _normalizarLista(
        _mapa(exames),
        'exames',
      ),
      'avaliacao': _normalizarLista(
        _mapa(avaliacao),
        'avaliacoes',
      ),
      'prescricao': _normalizarLista(
        _mapa(prescricao),
        'prescricoes',
      ),
      'medidas': _normalizarLista(
        _mapa(medidas),
        'medidas',
      ),
    };
  }

  /// Executa uma chamada da API identificando exatamente
  /// qual módulo apresentou erro.
  Future<Map<String, dynamic>> _executar({
    required String nome,
    required Future<Map<String, dynamic>> Function() chamada,
  }) async {
    try {
      return await chamada();
    } catch (e) {
      throw HomeException(
        'Erro ao carregar $nome: $e',
      );
    }
  }

  /// Garante que a resposta da API seja tratada
  /// como um mapa.
  Map<String, dynamic> _mapa(
      dynamic resposta,
      ) {
    if (resposta is Map<String, dynamic>) {
      return resposta;
    }

    return {};
  }

  /// Extrai uma lista da resposta da API.
  List<dynamic> _normalizarLista(
      Map<String, dynamic> resposta,
      String chave,
      ) {
    final valor = resposta[chave];

    if (valor is List) {
      return valor;
    }

    return [];
  }
}

/// Exceção específica da Home.
class HomeException implements Exception {
  const HomeException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}