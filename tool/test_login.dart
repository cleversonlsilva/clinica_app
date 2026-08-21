import 'dart:io';

import 'package:clinica_app/core/network/api_client.dart';
import 'package:clinica_app/services/login_api_service.dart';

Future<void> main() async {
  stdout.write('CPF ou telefone: ');
  final login = stdin.readLineSync()?.trim() ?? '';

  stdout.write('Senha: ');
  final senha = stdin.readLineSync()?.trim() ?? '';

  if (login.isEmpty || senha.isEmpty) {
    stdout.writeln('');
    stdout.writeln('Login e senha são obrigatórios.');
    exitCode = 1;
    return;
  }

  final apiClient = ApiClient();

  final loginService = LoginApiService(
    apiClient: apiClient,
  );

  try {
    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('TESTE DE LOGIN - CLÍNICA WEB');
    stdout.writeln('========================================');

    final resposta = await loginService.loginPaciente(
      login: login,
      senha: senha,
    );

    stdout.writeln('STATUS: OK');
    stdout.writeln('RESPOSTA: $resposta');

    final token = resposta['token'];

    if (token is String && token.isNotEmpty) {
      stdout.writeln('TOKEN RECEBIDO: SIM');
      stdout.writeln('LOGIN AUTENTICADO COM SUCESSO.');
    } else {
      stdout.writeln('TOKEN RECEBIDO: NÃO');
      stdout.writeln(
        'A API respondeu, mas não retornou um token válido.',
      );
    }

    stdout.writeln('========================================');
  } on ApiException catch (e) {
    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('ERRO DA API - LOGIN');
    stdout.writeln('STATUS: ${e.statusCode}');
    stdout.writeln('MENSAGEM: ${e.message}');
    stdout.writeln('========================================');

    exitCode = 1;
  } catch (e) {
    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('ERRO DE CONEXÃO - LOGIN');
    stdout.writeln('$e');
    stdout.writeln('========================================');

    exitCode = 1;
  } finally {
    apiClient.dispose();
  }
}