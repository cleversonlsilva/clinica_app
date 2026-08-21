import '../../services/login_api_service.dart';
import '../../services/primeiro_acesso_api_service.dart';
import 'session_service.dart';

/// Serviço central de autenticação do Clínica App.
///
/// Responsável por coordenar:
///
/// - Login normal do paciente;
/// - Primeiro acesso do paciente;
/// - Armazenamento do token;
/// - Encerramento da sessão.
///
/// A interface do aplicativo não precisa conhecer diretamente
/// os serviços responsáveis pela comunicação com a API.
class AuthService {
  AuthService({
    required this._loginApiService,
    required this._primeiroAcessoApiService,
    required this._sessionService,
  });

  final LoginApiService _loginApiService;
  final PrimeiroAcessoApiService _primeiroAcessoApiService;
  final SessionService _sessionService;

  /// Realiza o login normal do paciente.
  ///
  /// Em caso de sucesso:
  ///
  /// 1. A API autentica o paciente;
  /// 2. Retorna o token;
  /// 3. O token é salvo localmente;
  /// 4. A resposta completa da API é devolvida.
  Future<Map<String, dynamic>> login({
    required String login,
    required String senha,
  }) async {
    final resposta = await _loginApiService.loginPaciente(
      login: login,
      senha: senha,
    );

    await _salvarTokenDaResposta(resposta);

    return resposta;
  }

  /// Realiza o primeiro acesso do paciente.
  ///
  /// O backend cadastra a senha e, em caso de sucesso,
  /// realiza automaticamente a autenticação e retorna
  /// um token.
  ///
  /// O token também é armazenado localmente.
  Future<Map<String, dynamic>> primeiroAcesso({
    required String login,
    required String senha,
  }) async {
    final resposta =
    await _primeiroAcessoApiService.cadastrarSenha(
      login: login,
      senha: senha,
    );

    await _salvarTokenDaResposta(resposta);

    return resposta;
  }

  /// Recupera o token da sessão atual.
  Future<String?> obterToken() async {
    return _sessionService.obterToken();
  }

  /// Verifica se existe uma sessão autenticada.
  Future<bool> possuiSessao() async {
    return _sessionService.possuiSessao();
  }

  /// Encerra a sessão atual.
  Future<void> logout() async {
    await _sessionService.encerrarSessao();
  }

  /// Extrai e salva o token retornado pela API.
  Future<void> _salvarTokenDaResposta(
      Map<String, dynamic> resposta,
      ) async {
    final token = resposta['token'];

    if (token is! String || token.isEmpty) {
      throw const AuthException(
        'A API não retornou um token de autenticação válido.',
      );
    }

    await _sessionService.salvarToken(token);
  }
}

/// Exceção específica para problemas relacionados
/// ao processo de autenticação.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}