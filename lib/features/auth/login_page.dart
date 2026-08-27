import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import 'esqueci_senha_page.dart';
import 'primeiro_acesso_page.dart';

/// Tela de login do paciente do Nexo APP.
///
/// Responsável por:
///
/// - autenticar o paciente;
/// - abrir o fluxo de primeiro acesso;
/// - abrir o fluxo de recuperação de senha;
/// - preservar o CPF/telefone já informado pelo paciente;
/// - aplicar máscara visual para CPF ou telefone.
///
/// A comunicação com a API permanece centralizada
/// nas camadas de autenticação e serviços.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
  });

  final VoidCallback onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();

  late final AuthService _authService;

  bool _carregando = false;
  bool _ocultarSenha = true;
  String? _erro;

  @override
  void initState() {
    super.initState();

    _authService = AuthServiceFactory.create();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _senhaController.dispose();

    super.dispose();
  }

  // ==========================================================
  // NORMALIZAÇÃO
  // ==========================================================

  /// Retorna somente os números digitados.
  ///
  /// Isso garante que a API continue recebendo:
  ///
  /// CPF:
  /// 2222222222
  ///
  /// ou telefone:
  /// 44999999999
  ///
  /// independentemente da máscara exibida na tela.
  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // ==========================================================
  // MÁSCARA CPF / TELEFONE
  // ==========================================================

  String _formatarLogin(String valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.isEmpty) {
      return '';
    }

    // ========================================================
    // CPF
    //
    // Até 11 dígitos, quando a entrada possui estrutura de CPF,
    // utilizamos:
    //
    // 222.222.222-2
    //
    // O banco atual aceita CPF com quantidade variável de
    // dígitos, portanto não exigimos 11 dígitos.
    // ========================================================

    if (numeros.length <= 11) {
      return _formatarCpfOuTelefone(numeros);
    }

    // ========================================================
    // TELEFONE
    //
    // Telefones com 11 dígitos também são suportados.
    //
    // Quando ultrapassar 11 dígitos, limitamos a entrada para
    // evitar números inválidos.
    // ========================================================

    return _formatarTelefone(numeros.substring(0, 11));
  }

  String _formatarCpfOuTelefone(String numeros) {
    // ========================================================
    // 10 DÍGITOS
    //
    // Tratamos como telefone fixo:
    //
    // (44) 9999-9999
    // ========================================================

    if (numeros.length == 10) {
      return _formatarTelefone(numeros);
    }

    // ========================================================
    // 11 DÍGITOS
    //
    // O sistema aceita CPF e telefone.
    //
    // Para manter uma experiência previsível, exibimos CPF
    // quando a entrada possui 11 dígitos.
    //
    // A API recebe somente os números e continua responsável
    // pela identificação real do cadastro.
    // ========================================================

    if (numeros.length == 11) {
      return _formatarCpf(numeros);
    }

    // ========================================================
    // ENTRADA PARCIAL
    // ========================================================

    return _formatarCpfParcial(numeros);
  }

  String _formatarCpf(String numeros) {
    final buffer = StringBuffer();

    for (var i = 0; i < numeros.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      }

      if (i == 9) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    return buffer.toString();
  }

  String _formatarCpfParcial(String numeros) {
    final buffer = StringBuffer();

    for (var i = 0; i < numeros.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      }

      if (i == 9) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    return buffer.toString();
  }

  String _formatarTelefone(String numeros) {
    final buffer = StringBuffer();

    if (numeros.isEmpty) {
      return '';
    }

    // DDD
    if (numeros.isNotEmpty) {
      buffer.write('(');
      buffer.write(numeros.substring(
        0,
        numeros.length >= 2 ? 2 : numeros.length,
      ));
    }

    if (numeros.length >= 2) {
      buffer.write(')');
    }

    if (numeros.length > 2) {
      buffer.write(' ');

      final restante = numeros.substring(2);

      if (numeros.length >= 11) {
        // Celular:
        //
        // (44) 99999-9999

        if (restante.length <= 5) {
          buffer.write(restante);
        } else {
          buffer.write(
            restante.substring(0, 5),
          );

          buffer.write('-');

          buffer.write(
            restante.substring(5),
          );
        }
      } else {
        // Fixo:
        //
        // (44) 9999-9999

        if (restante.length <= 4) {
          buffer.write(restante);
        } else {
          buffer.write(
            restante.substring(0, 4),
          );

          buffer.write('-');

          buffer.write(
            restante.substring(4),
          );
        }
      }
    }

    return buffer.toString();
  }

  void _onLoginChanged(String valor) {
    final formatado = _formatarLogin(valor);

    if (_loginController.text == formatado) {
      return;
    }

    _loginController.value = TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(
        offset: formatado.length,
      ),
    );

    if (_erro != null) {
      setState(() {
        _erro = null;
      });
    }
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      // ------------------------------------------------------
      // IMPORTANTE:
      //
      // A máscara NÃO é enviada para a API.
      // ------------------------------------------------------

      final login = _somenteNumeros(
        _loginController.text.trim(),
      );

      await _authService.login(
        login: login,
        senha: _senhaController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login realizado com sucesso.',
          ),
        ),
      );

      widget.onLoginSuccess();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.message;
      });
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = 'Erro no login: $e';
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
  // PRIMEIRO ACESSO
  // ==========================================================

  void _abrirPrimeiroAcesso() {
    if (_carregando) {
      return;
    }

    FocusScope.of(context).unfocus();

    // Envia somente os números para o próximo fluxo.
    final loginInicial = _somenteNumeros(
      _loginController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return PrimeiroAcessoPage(
            loginInicial: loginInicial,
            onPrimeiroAcessoSuccess: () {
              widget.onLoginSuccess();

              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            onVoltarLogin: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // ESQUECI MINHA SENHA
  // ==========================================================

  void _abrirEsqueciSenha() {
    if (_carregando) {
      return;
    }

    FocusScope.of(context).unfocus();

    // Envia somente os números para o fluxo de recuperação.
    final loginInicial = _somenteNumeros(
      _loginController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return EsqueciSenhaPage(
            loginInicial: loginInicial,
          );
        },
      ),
    );
  }

  // ==========================================================
  // INTERFACE
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==================================================
                    // LOGO NEXO SAÚDE
                    // ==================================================

                    Center(
                      child: Image.asset(
                        'assets/images/nexo_saude.png',
                        width: 190,
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (
                            context,
                            error,
                            stackTrace,
                            ) {
                          return Column(
                            children: [
                              Icon(
                                Icons
                                    .medical_services_outlined,
                                size: 64,
                                color:
                                colorScheme.primary,
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              Text(
                                'Nexo APP',
                                textAlign:
                                TextAlign.center,
                                style: theme
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Acesse sua área do paciente',
                      textAlign: TextAlign.center,
                      style:
                      theme.textTheme.bodyLarge,
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // CPF / TELEFONE
                    // ==================================================

                    TextFormField(
                      controller: _loginController,
                      keyboardType: TextInputType.phone,
                      textInputAction:
                      TextInputAction.next,
                      enabled: !_carregando,
                      onChanged: _onLoginChanged,
                      decoration:
                      const InputDecoration(
                        labelText: 'CPF ou telefone',
                        hintText:
                        'Digite seu CPF ou telefone',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                        border:
                        OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final texto =
                        _somenteNumeros(
                          value?.trim() ?? '',
                        );

                        if (texto.isEmpty) {
                          return 'Informe seu CPF ou telefone.';
                        }

                        if (texto.length < 10) {
                          return 'Informe um CPF ou telefone válido.';
                        }

                        if (texto.length > 11) {
                          return 'CPF ou telefone inválido.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // SENHA
                    // ==================================================

                    TextFormField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      textInputAction:
                      TextInputAction.done,
                      enabled: !_carregando,
                      onFieldSubmitted: (_) {
                        _entrar();
                      },
                      decoration:
                      InputDecoration(
                        labelText: 'Senha',
                        hintText:
                        'Digite sua senha',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon:
                        IconButton(
                          tooltip: _ocultarSenha
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
                          icon: Icon(
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
                        if (value == null ||
                            value.isEmpty) {
                          return 'Informe sua senha.';
                        }

                        return null;
                      },
                    ),

                    // ==================================================
                    // ESQUECI MINHA SENHA
                    // ==================================================

                    Align(
                      alignment:
                      Alignment.centerRight,
                      child: TextButton(
                        onPressed: _carregando
                            ? null
                            : _abrirEsqueciSenha,
                        child: const Text(
                          'Esqueci minha senha',
                        ),
                      ),
                    ),

                    // ==================================================
                    // ERRO
                    // ==================================================

                    if (_erro != null) ...[
                      Container(
                        padding:
                        const EdgeInsets.all(12),
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
                                style: TextStyle(
                                  color: colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ==================================================
                    // ENTRAR
                    // ==================================================

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _carregando
                            ? null
                            : _entrar,
                        child: _carregando
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Entrar',
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // PRIMEIRO ACESSO
                    // ==================================================

                    TextButton(
                      onPressed: _carregando
                          ? null
                          : _abrirPrimeiroAcesso,
                      child: const Text(
                        'Primeiro acesso',
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