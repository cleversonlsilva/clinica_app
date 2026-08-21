import 'dart:io';

import 'package:clinica_app/core/auth/auth_service.dart';
import 'package:clinica_app/core/auth/session_service.dart';
import 'package:clinica_app/core/network/api_client.dart';
import 'package:clinica_app/services/login_api_service.dart';
import 'package:clinica_app/services/primeiro_acesso_api_service.dart';

Future<void> main() async {
  const login = '00555627950';

  final apiClient = ApiClient();

  final loginApiService = LoginApiService(
    apiClient: apiClient,
  );

  final primeiroAcessoApiService = PrimeiroAcessoApiService(
    apiClient: apiClient,
  );

  final sessionService = SessionService();

  final authService = AuthService(
    loginApiService: loginApiService,
    primeiroAcessoApiService: primeiroAcessoApiService,
    sessionService: sessionService,
  );

  try {
    stdout.writeln('========================================');
    stdout.writeln('TESTE DO AUTHSERVICE - CLÍNICA WEB');
    stdout.writeln('========================================');

    stdout.writeln('');
    stdout.writeln('1. Verificando sessão existente...');

    final sessaoAntes = await authService.possuiSessao();

    stdout.writeln('Sessão existente: $sessaoAntes');

    stdout.writeln('');
    stdout.writeln('2. Realizando login...');

    final resposta = await authService.login(
      login: login,
      senha: '12345678',
    );

    stdout.writeln('LOGIN: OK');
    stdout.writeln('USUÁRIO: ${resposta['usuario']}');

    stdout.writeln('');
    stdout.writeln('3. Verificando token salvo...');

    final token = await authService.obterToken();

    if (token != null && token.isNotEmpty) {
      stdout.writeln('TOKEN SALVO: SIM');
      stdout.writeln('TAMANHO DO TOKEN: ${token.length}');
    } else {
      stdout.writeln('TOKEN SALVO: NÃO');
    }

    stdout.writeln('');
    stdout.writeln('4. Verificando sessão após login...');

    final sessaoDepois = await authService.possuiSessao();

    stdout.writeln('Sessão autenticada: $sessaoDepois');

    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('TESTE CONCLUÍDO');
    stdout.writeln('========================================');
  } on ApiException catch (e) {
    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('ERRO DA API');
    stdout.writeln('STATUS: ${e.statusCode}');
    stdout.writeln('MENSAGEM: ${e.message}');
    stdout.writeln('========================================');

    exitCode = 1;
  } on AuthException catch (e) {
    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('ERRO DE AUTENTICAÇÃO');
    stdout.writeln('MENSAGEM: ${e.message}');
    stdout.writeln('========================================');

    exitCode = 1;
  } catch (e) {
    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('ERRO NO TESTE');
    stdout.writeln('$e');
    stdout.writeln('========================================');

    exitCode = 1;
  } finally {
    apiClient.dispose();
  }
}