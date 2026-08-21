import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP central do Clínica App.
///
/// Responsável pela comunicação entre o aplicativo
/// Flutter e a API Flask do Clínica Web.
class ApiClient {
  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Endereço da API Flask quando o aplicativo
  /// está sendo executado no Android Emulator.
  ///
  /// O endereço aponta para o computador Windows
  /// que está executando a API Flask.
  static const String baseUrl = 'http://10.20.30.25:5000';

  // ==========================================================
  // GET JSON
  // ==========================================================

  /// Executa uma requisição GET autenticada.
  ///
  /// O token é enviado no padrão:
  ///
  /// Authorization: Bearer `token`
  Future<Map<String, dynamic>> get(
      String path, {
        required String token,
      }) async {
    final uri = Uri.parse('$baseUrl$path');

    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return _processResponse(response);
  }

  // ==========================================================
  // GET PDF / BYTES
  // ==========================================================

  /// Executa uma requisição GET autenticada para endpoints
  /// que retornam arquivos binários, como PDF.
  ///
  /// O token é enviado no padrão:
  ///
  /// Authorization: Bearer `token`
  ///
  /// Retorna somente os bytes do arquivo.
  Future<List<int>> getBytes(
      String path, {
        required String token,
      }) async {
    final uri = Uri.parse('$baseUrl$path');

    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/pdf',
        'Authorization': 'Bearer $token',
      },
    );

    // ========================================================
    // SUCESSO
    // ========================================================

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) {
        throw ApiException(
          'A API retornou um arquivo vazio.',
          statusCode: response.statusCode,
        );
      }

      return response.bodyBytes;
    }

    // ========================================================
    // ERRO
    // ========================================================

    dynamic body;

    if (response.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(
          utf8.decode(
            response.bodyBytes,
          ),
        );
      } catch (_) {
        body = null;
      }
    }

    String message =
        'Erro ao carregar o arquivo da API.';

    if (body is Map<String, dynamic>) {
      final apiMessage =
          body['message'] ??
              body['mensagem'] ??
              body['erro'];

      if (apiMessage != null) {
        final texto =
        apiMessage.toString().trim();

        if (texto.isNotEmpty) {
          message = texto;
        }
      }
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
      data: body is Map<String, dynamic>
          ? body
          : null,
    );
  }

  // ==========================================================
  // POST
  // ==========================================================

  /// Executa uma requisição POST.
  ///
  /// O corpo da requisição é enviado como JSON.
  ///
  /// Pode ser utilizado tanto para endpoints públicos,
  /// como o login, quanto para endpoints autenticados.
  Future<Map<String, dynamic>> post(
      String path, {
        Map<String, dynamic>? body,
        String? token,
      }) async {
    final uri = Uri.parse('$baseUrl$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client.post(
      uri,
      headers: headers,
      body: body == null
          ? null
          : jsonEncode(body),
    );

    return _processResponse(response);
  }

  // ==========================================================
  // PROCESSAMENTO JSON
  // ==========================================================

  /// Processa a resposta da API.
  ///
  /// Respostas HTTP 2xx são devolvidas normalmente.
  ///
  /// Respostas de erro geram [ApiException], preservando:
  ///
  /// - mensagem;
  /// - código HTTP;
  /// - corpo JSON retornado pela API.
  ///
  /// Isso é importante principalmente para o fluxo da Agenda,
  /// onde o backend pode retornar HTTP 409 juntamente com
  /// informações como:
  ///
  /// - CONSULTA_FUTURA_EXISTENTE;
  /// - HORARIO_INDISPONIVEL;
  /// - dados do agendamento existente.
  Map<String, dynamic> _processResponse(
      http.Response response,
      ) {
    dynamic body;

    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(
          response.body,
        );
      } catch (_) {
        throw ApiException(
          'A API retornou uma resposta inválida.',
          statusCode: response.statusCode,
        );
      }
    }

    // ========================================================
    // SUCESSO
    // ========================================================

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      }

      throw ApiException(
        'A API retornou um formato inesperado.',
        statusCode: response.statusCode,
      );
    }

    // ========================================================
    // ERRO
    // ========================================================

    String message =
        'Erro na comunicação com a API.';

    if (body is Map<String, dynamic>) {
      final apiMessage =
          body['message'] ??
              body['mensagem'] ??
              body['erro'];

      if (apiMessage != null) {
        final texto =
        apiMessage.toString().trim();

        if (texto.isNotEmpty) {
          message = texto;
        }
      }
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
      data: body is Map<String, dynamic>
          ? body
          : null,
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  void dispose() {
    _client.close();
  }
}

/// Exceção específica para erros de comunicação
/// com a API do Clínica Web.
class ApiException implements Exception {
  ApiException(
      this.message, {
        this.statusCode,
        this.data,
      });

  final String message;
  final int? statusCode;

  /// Corpo JSON original retornado pela API.
  ///
  /// Exemplo para a Agenda:
  ///
  /// {
  ///   "ok": false,
  ///   "codigo": "CONSULTA_FUTURA_EXISTENTE",
  ///   "erro": "Você já possui uma consulta agendada.",
  ///   "agendamento": {...}
  /// }
  final Map<String, dynamic>? data;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message (HTTP $statusCode)';
  }
}