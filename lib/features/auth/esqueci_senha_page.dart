import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

/// Tela de recuperação de senha do paciente do Nexo APP.
///
/// Fluxo:
///
/// 1. Paciente informa CPF ou telefone;
/// 2. APP solicita código à API;
/// 3. API gera e envia o código para o e-mail cadastrado;
/// 4. Paciente informa o código recebido;
/// 5. Paciente informa a nova senha;
/// 6. APP envia os dados para a API;
/// 7. API valida o código e grava a nova senha.
class EsqueciSenhaPage extends StatefulWidget {
  const EsqueciSenhaPage({
    super.key,
    this.loginInicial = '',
  });

  /// CPF ou telefone informado anteriormente
  /// na tela de login.
  final String loginInicial;

  @override
  State<EsqueciSenhaPage> createState() =>
      _EsqueciSenhaPageState();
}

class _EsqueciSenhaPageState
    extends State<EsqueciSenhaPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _loginController;

  final TextEditingController _codigoController =
  TextEditingController();

  final TextEditingController _senhaController =
  TextEditingController();

  final TextEditingController
  _confirmarSenhaController =
  TextEditingController();

  late final ApiClient _apiClient;

  bool _etapaCodigo = false;
  bool _carregando = false;

  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;

  String? _erro;
  String? _mensagem;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();

    _loginController = TextEditingController(
      text: widget.loginInicial,
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _codigoController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();

    _apiClient.dispose();

    super.dispose();
  }

  // ==========================================================
  // SOLICITAR CÓDIGO
  // ==========================================================

  Future<void> _solicitarCodigo() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
      _mensagem = null;
    });

    try {
      final login =
      _loginController.text.trim();

      // ======================================================
      // API
      // ======================================================
      //
      // POST
      // /api/app/auth/paciente/esqueci-senha
      //
      // {
      //   "login": "CPF ou telefone"
      // }
      //
      final resposta = await _apiClient.post(
        '/api/app/auth/paciente/esqueci-senha',
        body: {
          'login': login,
        },
      );

      if (!mounted) {
        return;
      }

      final ok = resposta['ok'];

      if (ok == false) {
        setState(() {
          _erro = _mensagemDaResposta(
            resposta,
            fallback:
            'Não foi possível solicitar o código.',
          );
        });

        return;
      }

      setState(() {
        _etapaCodigo = true;

        _mensagem =
        'Se os dados estiverem corretos, '
            'um código foi enviado para o '
            'e-mail cadastrado.';
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro =
        'Não foi possível solicitar o '
            'código de recuperação.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // ==========================================================
  // REDEFINIR SENHA
  // ==========================================================

  Future<void> _redefinirSenha() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final senha =
        _senhaController.text;

    final confirmar =
        _confirmarSenhaController.text;

    if (senha != confirmar) {
      setState(() {
        _erro =
        'As senhas não conferem.';
      });

      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
      _mensagem = null;
    });

    try {
      final login =
      _loginController.text.trim();

      final codigo =
      _codigoController.text.trim();

      // ======================================================
      // API
      // ======================================================
      //
      // POST
      // /api/app/auth/paciente/redefinir-senha
      //
      // {
      //   "login": "CPF ou telefone",
      //   "codigo": "123456",
      //   "senha": "nova senha"
      // }
      //
      final resposta = await _apiClient.post(
        '/api/app/auth/paciente/redefinir-senha',
        body: {
          'login': login,
          'codigo': codigo,
          'senha': senha,
        },
      );

      if (!mounted) {
        return;
      }

      final ok = resposta['ok'];

      if (ok == false) {
        setState(() {
          _erro = _mensagemDaResposta(
            resposta,
            fallback:
            'Não foi possível redefinir a senha.',
          );
        });

        return;
      }

      // ======================================================
      // SUCESSO
      // ======================================================

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Senha redefinida com sucesso.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro =
        'Não foi possível redefinir a senha.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // ==========================================================
  // MENSAGEM DA API
  // ==========================================================

  String _mensagemDaResposta(
      Map<String, dynamic> resposta, {
        required String fallback,
      }) {
    final erro =
        resposta['erro'] ??
            resposta['mensagem'] ??
            resposta['message'];

    if (erro != null) {
      final texto =
      erro.toString().trim();

      if (texto.isNotEmpty) {
        return texto;
      }
    }

    return fallback;
  }

  // ==========================================================
  // VOLTAR
  // ==========================================================

  void _voltar() {
    if (_carregando) {
      return;
    }

    if (_etapaCodigo) {
      setState(() {
        _etapaCodigo = false;
        _erro = null;
        _mensagem = null;

        _codigoController.clear();
        _senhaController.clear();
        _confirmarSenhaController.clear();
      });

      return;
    }

    Navigator.of(context).pop();
  }

  // ==========================================================
  // INTERFACE
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
      colorScheme.surface,
      appBar: AppBar(
        backgroundColor:
        colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed:
          _carregando
              ? null
              : _voltar,
          icon: const Icon(
            Icons.arrow_back,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.fromLTRB(
              24,
              8,
              24,
              32,
            ),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // LOGO
                    // ==================================================

                    Center(
                      child: Image.asset(
                        'assets/images/nexo_saude.png',
                        width: 170,
                        height: 130,
                        fit: BoxFit.contain,
                        errorBuilder: (
                            context,
                            error,
                            stackTrace,
                            ) {
                          return Icon(
                            Icons
                                .lock_reset_outlined,
                            size: 72,
                            color:
                            colorScheme
                                .primary,
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      'Esqueci minha senha',
                      textAlign:
                      TextAlign.center,
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      _etapaCodigo
                          ? 'Digite o código recebido '
                          'e cadastre uma nova senha.'
                          : 'Informe seu CPF ou telefone '
                          'para recuperar seu acesso.',
                      textAlign:
                      TextAlign.center,
                      style: theme
                          .textTheme
                          .bodyLarge,
                    ),

                    const SizedBox(
                      height: 32,
                    ),

                    // ==================================================
                    // CPF / TELEFONE
                    // ==================================================

                    TextFormField(
                      controller:
                      _loginController,
                      keyboardType:
                      TextInputType.text,
                      textInputAction:
                      _etapaCodigo
                          ? TextInputAction.next
                          : TextInputAction.done,
                      enabled:
                      !_carregando &&
                          !_etapaCodigo,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'CPF ou telefone',
                        hintText:
                        'Digite seu CPF ou telefone',
                        prefixIcon:
                        Icon(
                          Icons
                              .person_outline,
                        ),
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final texto =
                            value?.trim() ??
                                '';

                        if (texto.isEmpty) {
                          return
                            'Informe seu CPF ou telefone.';
                        }

                        return null;
                      },
                    ),

                    // ==================================================
                    // ETAPA 2
                    // ==================================================

                    if (_etapaCodigo) ...[
                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // CÓDIGO
                      // ------------------------------------------------

                      TextFormField(
                        controller:
                        _codigoController,
                        keyboardType:
                        TextInputType.number,
                        textInputAction:
                        TextInputAction.next,
                        enabled:
                        !_carregando,
                        maxLength: 6,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Código de recuperação',
                          hintText:
                          'Digite o código recebido',
                          prefixIcon:
                          Icon(
                            Icons
                                .pin_outlined,
                          ),
                          border:
                          OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: (value) {
                          final texto =
                              value?.trim() ??
                                  '';

                          if (texto.isEmpty) {
                            return
                              'Informe o código recebido.';
                          }

                          if (texto.length != 6) {
                            return
                              'O código deve possuir 6 dígitos.';
                          }

                          if (!RegExp(
                            r'^\d{6}$',
                          ).hasMatch(texto)) {
                            return
                              'Informe um código válido.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // NOVA SENHA
                      // ------------------------------------------------

                      TextFormField(
                        controller:
                        _senhaController,
                        obscureText:
                        _ocultarSenha,
                        textInputAction:
                        TextInputAction.next,
                        enabled:
                        !_carregando,
                        decoration:
                        InputDecoration(
                          labelText:
                          'Nova senha',
                          hintText:
                          'Digite sua nova senha',
                          prefixIcon:
                          const Icon(
                            Icons
                                .lock_outline,
                          ),
                          suffixIcon:
                          IconButton(
                            tooltip:
                            _ocultarSenha
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed:
                            _carregando
                                ? null
                                : () {
                              setState(() {
                                _ocultarSenha =
                                !_ocultarSenha;
                              });
                            },
                            icon:
                            Icon(
                              _ocultarSenha
                                  ? Icons
                                  .visibility_outlined
                                  : Icons
                                  .visibility_off_outlined,
                            ),
                          ),
                          border:
                          const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final texto =
                              value ?? '';

                          if (texto.isEmpty) {
                            return
                              'Informe a nova senha.';
                          }

                          if (texto.length < 6) {
                            return
                              'A senha deve possuir pelo menos 6 caracteres.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // CONFIRMAR SENHA
                      // ------------------------------------------------

                      TextFormField(
                        controller:
                        _confirmarSenhaController,
                        obscureText:
                        _ocultarConfirmacao,
                        textInputAction:
                        TextInputAction.done,
                        enabled:
                        !_carregando,
                        onFieldSubmitted:
                            (_) {
                          _redefinirSenha();
                        },
                        decoration:
                        InputDecoration(
                          labelText:
                          'Confirmar senha',
                          hintText:
                          'Digite novamente a senha',
                          prefixIcon:
                          const Icon(
                            Icons
                                .lock_reset_outlined,
                          ),
                          suffixIcon:
                          IconButton(
                            tooltip:
                            _ocultarConfirmacao
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed:
                            _carregando
                                ? null
                                : () {
                              setState(() {
                                _ocultarConfirmacao =
                                !_ocultarConfirmacao;
                              });
                            },
                            icon:
                            Icon(
                              _ocultarConfirmacao
                                  ? Icons
                                  .visibility_outlined
                                  : Icons
                                  .visibility_off_outlined,
                            ),
                          ),
                          border:
                          const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return
                              'Confirme sua senha.';
                          }

                          return null;
                        },
                      ),
                    ],

                    const SizedBox(
                      height: 16,
                    ),

                    // ==================================================
                    // MENSAGEM
                    // ==================================================

                    if (_mensagem != null) ...[
                      Container(
                        padding:
                        const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .primaryContainer,
                          borderRadius:
                          BorderRadius.circular(
                            8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme
                                  .onPrimaryContainer,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                _mensagem!,
                                style:
                                TextStyle(
                                  color: colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                    ],

                    // ==================================================
                    // ERRO
                    // ==================================================

                    if (_erro != null) ...[
                      Container(
                        padding:
                        const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .errorContainer,
                          borderRadius:
                          BorderRadius.circular(
                            8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                _erro!,
                                style:
                                TextStyle(
                                  color: colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                    ],

                    // ==================================================
                    // BOTÃO PRINCIPAL
                    // ==================================================

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                        _carregando
                            ? null
                            : _etapaCodigo
                            ? _redefinirSenha
                            : _solicitarCodigo,
                        child: _carregando
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          _etapaCodigo
                              ? 'Redefinir senha'
                              : 'Enviar código',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // VOLTAR PARA LOGIN
                    // ==================================================

                    TextButton(
                      onPressed:
                      _carregando
                          ? null
                          : () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
                      child: const Text(
                        'Voltar para o login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}