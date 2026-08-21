import '../../services/login_api_service.dart';
import '../../services/primeiro_acesso_api_service.dart';
import '../network/api_client.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// Fábrica responsável por montar o AuthService
/// com todas as suas dependências.
///
/// A interface do aplicativo não precisa conhecer
/// a implementação dos serviços de autenticação.
class AuthServiceFactory {
  AuthServiceFactory._();

  /// Cria uma instância completa do AuthService.
  ///
  /// A mesma instância do ApiClient é compartilhada
  /// pelos serviços de autenticação.
  static AuthService create() {
    final apiClient = ApiClient();

    final loginApiService = LoginApiService(
      apiClient: apiClient,
    );

    final primeiroAcessoApiService = PrimeiroAcessoApiService(
      apiClient: apiClient,
    );

    final sessionService = SessionService();

    return AuthService(
      loginApiService: loginApiService,
      primeiroAcessoApiService: primeiroAcessoApiService,
      sessionService: sessionService,
    );
  }
}