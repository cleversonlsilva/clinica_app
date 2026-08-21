import '../core/network/api_client.dart';

/// Serviço responsável pela autenticação do paciente
/// no Clínica App.
///
/// A comunicação HTTP é delegada ao ApiClient.
/// Este serviço não contém regras de interface.
class LoginApiService {
  LoginApiService({
    required this._apiClient,
  });

  final ApiClient _apiClient;

  /// Realiza o login do paciente.
  ///
  /// O paciente pode utilizar CPF ou telefone
  /// como identificador.
  ///
  /// Endpoint:
  ///
  /// POST /api/app/auth/paciente
  Future<Map<String, dynamic>> loginPaciente({
    required String login,
    required String senha,
  }) async {
    return _apiClient.post(
      '/api/app/auth/paciente',
      body: {
        'login': login,
        'senha': senha,
      },
    );
  }
}