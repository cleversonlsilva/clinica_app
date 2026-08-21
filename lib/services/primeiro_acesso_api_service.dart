import '../core/network/api_client.dart';

/// Serviço responsável pelo primeiro acesso do paciente
/// no Clínica App.
///
/// O paciente utiliza CPF ou telefone para se identificar
/// e cadastra sua primeira senha.
///
/// A comunicação HTTP é delegada ao ApiClient.
class PrimeiroAcessoApiService {
  PrimeiroAcessoApiService({
    required this._apiClient,
  });

  final ApiClient _apiClient;

  /// Cadastra a senha do paciente no primeiro acesso.
  ///
  /// Endpoint:
  ///
  /// POST /api/app/auth/paciente/primeiro-acesso
  ///
  /// O backend exige:
  ///
  /// - login: CPF ou telefone;
  /// - senha: nova senha com pelo menos 6 caracteres.
  ///
  /// Após o cadastro da senha, o backend realiza
  /// automaticamente a autenticação e retorna o token.
  Future<Map<String, dynamic>> cadastrarSenha({
    required String login,
    required String senha,
  }) async {
    return _apiClient.post(
      '/api/app/auth/paciente/primeiro-acesso',
      body: {
        'login': login,
        'senha': senha,
      },
    );
  }
}