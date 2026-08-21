import 'package:flutter/foundation.dart';

import '../../services/paciente_api_service.dart';
import 'api_client.dart';

/// Teste da comunicação entre o Flutter
/// e a API Flask através do PacienteApiService.
Future<void> testarApi(String token) async {
  final apiClient = ApiClient();

  final pacienteService = PacienteApiService(
    apiClient: apiClient,
  );

  try {
    final resumo = await pacienteService.obterResumo(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - RESUMO');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $resumo');
    debugPrint('========================================');

    final perfil = await pacienteService.obterPerfil(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - PERFIL');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $perfil');
    debugPrint('========================================');

    final agenda = await pacienteService.obterAgenda(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - AGENDA');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $agenda');
    debugPrint('========================================');

    final plano = await pacienteService.obterPlano(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - PLANO ALIMENTAR');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $plano');
    debugPrint('========================================');

    final exames = await pacienteService.obterExames(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - EXAMES');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $exames');
    debugPrint('========================================');

    final avaliacao = await pacienteService.obterAvaliacao(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - AVALIAÇÃO CORPORAL');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $avaliacao');
    debugPrint('========================================');

    final prescricao = await pacienteService.obterPrescricao(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - PRESCRIÇÃO');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $prescricao');
    debugPrint('========================================');

    final medidas = await pacienteService.obterMedidas(
      token: token,
    );

    debugPrint('========================================');
    debugPrint('TESTE DA API - MEDIDAS');
    debugPrint('STATUS: OK');
    debugPrint('RESPOSTA: $medidas');
    debugPrint('========================================');
  } on ApiException catch (e) {
    debugPrint('========================================');
    debugPrint('ERRO DA API');
    debugPrint('STATUS: ${e.statusCode}');
    debugPrint('MENSAGEM: ${e.message}');
    debugPrint('========================================');
  } catch (e) {
    debugPrint('========================================');
    debugPrint('ERRO DE CONEXÃO');
    debugPrint('$e');
    debugPrint('========================================');
  } finally {
    apiClient.dispose();
  }
}