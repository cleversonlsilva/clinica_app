import 'package:shared_preferences/shared_preferences.dart';

/// Serviço responsável pelo gerenciamento da sessão
/// do paciente no Clínica App.
///
/// Mantém o token de autenticação localmente para que
/// o aplicativo possa reutilizá-lo entre as telas e
/// entre inicializações do aplicativo.
class SessionService {
  static const String _tokenKey = 'clinica_app_token';

  /// Salva o token de autenticação da sessão atual.
  Future<void> salvarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      token,
    );
  }

  /// Retorna o token atualmente armazenado.
  ///
  /// Retorna null quando não existe uma sessão autenticada.
  Future<String?> obterToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_tokenKey);
  }

  /// Verifica se existe uma sessão autenticada.
  Future<bool> possuiSessao() async {
    final token = await obterToken();

    return token != null && token.isNotEmpty;
  }

  /// Remove o token e encerra a sessão local.
  Future<void> encerrarSessao() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
  }
}