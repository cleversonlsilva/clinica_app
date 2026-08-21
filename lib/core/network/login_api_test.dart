import 'package:flutter/foundation.dart';

import '../../services/login_api_service.dart';
import 'api_client.dart';

/// Teste da autenticação do paciente
/// através da API Flask do Clínica Web.
Future<void> testarLogin({
  required String login,
  required String senha,
}) async {
  final apiClient = ApiClient();

  final loginService = LoginApiService(
    apiClient: apiClient,
  );

  try {
    final resposta = await loginService.loginPaciente(
      login: login,
      senha: senha,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - LOGIN');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $resposta');
    debugPrint('========================================');

    final token = resposta['token'];

    if (token is String && token.isNotEmpty) {
      debugPrint('TOKEN RECEBIDO: SIM');
    } else {
      debugPrint('TOKEN RECEBIDO: NÃO');
    }
  } on ApiException catch (e) {
    debugPrint('========================================');
    debugPrint('ERRO DA API - LOGIN');
    debugPrint('STATUS: ${e.statusCode}');
    debugPrint('MENSAGEM: ${e.message}');
    debugPrint('========================================');
  } catch (e) {
    debugPrint('========================================');
    debugPrint('ERRO DE CONEXÃO - LOGIN');
    debugPrint('$e');
    debugPrint('========================================');
  } finally {
    apiClient.dispose();
  }
}