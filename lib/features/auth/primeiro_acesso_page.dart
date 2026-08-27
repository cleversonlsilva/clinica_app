import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';

/// ============================================================
/// FORMATADOR CPF / TELEFONE
/// ============================================================
///
/// Aceita:
///
/// CPF:
/// 12345678901
/// → 123.456.789-01
///
/// Telefone:
/// 4499998493
/// → (44) 9999-8493
///
/// Telefone:
/// 44999998493
/// → (44) 99999-8493
///
/// O valor continua sendo enviado ao backend normalmente.
/// O backend já possui normalização própria.
class CpfTelefoneInputFormatter
    extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final numeros = newValue.text.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (numeros.isEmpty) {
      return const TextEditingValue();
    }

    final valorFormatado = _formatar(numeros);

    return TextEditingValue(
      text: valorFormatado,
      selection: TextSelection.collapsed(
        offset: valorFormatado.length,
      ),
    );
  }

  String _formatar(String numeros) {
    // ========================================================
    // CPF
    // ========================================================
    //
    // CPF possui 11 dígitos.
    //
    if (numeros.length == 11) {
      return '${numeros.substring(0, 3)}.'
          '${numeros.substring(3, 6)}.'
          '${numeros.substring(6, 9)}-'
          '${numeros.substring(9, 11)}';
    }

    // ========================================================
    // TELEFONE COM DDD
    // ========================================================
    //
    // 10 dígitos:
    // (44) 9999-8493
    //
    if (numeros.length <= 10) {
      if (numeros.length <= 2) {
        return '($numeros';
      }

      if (numeros.length <= 6) {
        return '(${numeros.substring(0, 2)}) '
            '${numeros.substring(2)}';
      }

      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    }

    // ========================================================
    // SEGURANÇA
    // ========================================================
    //
    // Caso ultrapasse 11 dígitos, limita ao máximo esperado.
    //
    final limitado = numeros.substring(0, 11);

    return '${limitado.substring(0, 3)}.'
        '${limitado.substring(3, 6)}.'
        '${limitado.substring(6, 9)}-'
        '${limitado.substring(9, 11)}';
  }
}

/// Tela responsável pelo primeiro acesso do paciente.
///
/// O paciente informa CPF ou telefone e cria sua primeira senha.
///
/// Quando o CPF ou telefone já foi informado na tela de login,
/// ele é recebido através de [loginInicial] e apresentado
/// automaticamente nesta tela.
///
/// Após o cadastro realizado com sucesso, o backend retorna
/// automaticamente um token de autenticação. O resultado é
/// comunicado ao AuthGate através de onPrimeiroAcessoSuccess.
class PrimeiroAcessoPage extends StatefulWidget {
  const PrimeiroAcessoPage({
    super.key,
    this.loginInicial,
    required this.onPrimeiroAcessoSuccess,
    required this.onVoltarLogin,
  });

  /// CPF ou telefone informado anteriormente na tela de login.
  ///
  /// Quando informado, o campo de identificação já será
  /// preenchido ao abrir a tela de Primeiro Acesso.
  final String? loginInicial;

  final VoidCallback onPrimeiroAcessoSuccess;
  final VoidCallback onVoltarLogin;

  @override
  State<PrimeiroAcessoPage> createState() =>
      _PrimeiroAcessoPageState();
}

class _PrimeiroAcessoPageState
    extends State<PrimeiroAcessoPage> {
  final _formKey = GlobalKey<FormState>();

  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmacaoSenhaController =
  TextEditingController();

  late final AuthService _authService;

  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;

  String? _erro;

  @override
  void initState() {
    super.initState();

    _authService = AuthServiceFactory.create();

    // ========================================================
    // LOGIN INICIAL
    // ========================================================
    //
    // Aproveita o CPF ou telefone que o paciente já informou
    // na tela de login.
    //
    final loginInicial =
        widget.loginInicial?.trim() ?? '';

    if (loginInicial.isNotEmpty) {
      _loginController.text = loginInicial;
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _senhaController.dispose();
    _confirmacaoSenhaController.dispose();

    super.dispose();
  }

  // ==========================================================
  // PRIMEIRO ACESSO
  // ==========================================================

  Future<void> _cadastrarAcesso() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final login = _loginController.text.trim();
    final senha = _senhaController.text;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      await _authService.primeiroAcesso(
        login: login,
        senha: senha,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Acesso criado com sucesso.',
          ),
        ),
      );

      widget.onPrimeiroAcessoSuccess();
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
        _erro = 'Erro ao criar o acesso: $e';
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
  // VALIDAÇÃO
  // ==========================================================

  String? _validarLogin(String? value) {
    final texto = value?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Informe seu CPF ou telefone.';
    }

    final numeros = texto.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (numeros.length < 10) {
      return 'Informe um CPF ou telefone válido.';
    }

    return null;
  }

  String? _validarSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe uma senha.';
    }

    if (value.length < 6) {
      return 'A senha deve possuir pelo menos 6 caracteres.';
    }

    return null;
  }

  String? _validarConfirmacao(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha.';
    }

    if (value != _senhaController.text) {
      return 'As senhas não conferem.';
    }

    return null;
  }

  // ==========================================================
  // INTERFACE
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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

                    Image.asset(
                      'assets/images/logo_nexo_saude.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Primeiro acesso',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Crie sua senha para acessar o Nexo APP.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge,
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
                      inputFormatters: [
                        CpfTelefoneInputFormatter(),
                      ],
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
                      validator: _validarLogin,
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // NOVA SENHA
                    // ==================================================

                    TextFormField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      textInputAction:
                      TextInputAction.next,
                      enabled: !_carregando,
                      decoration:
                      InputDecoration(
                        labelText: 'Nova senha',
                        hintText:
                        'Crie uma senha com pelo menos 6 caracteres',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon:
                        IconButton(
                          tooltip: _ocultarSenha
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: _carregando
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
                      validator: _validarSenha,
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // CONFIRMAÇÃO
                    // ==================================================

                    TextFormField(
                      controller:
                      _confirmacaoSenhaController,
                      obscureText:
                      _ocultarConfirmacao,
                      textInputAction:
                      TextInputAction.done,
                      enabled: !_carregando,
                      onFieldSubmitted: (_) {
                        _cadastrarAcesso();
                      },
                      decoration:
                      InputDecoration(
                        labelText:
                        'Confirmar senha',
                        hintText:
                        'Digite a senha novamente',
                        prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                        ),
                        suffixIcon:
                        IconButton(
                          tooltip:
                          _ocultarConfirmacao
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: _carregando
                              ? null
                              : () {
                            setState(() {
                              _ocultarConfirmacao =
                              !_ocultarConfirmacao;
                            });
                          },
                          icon: Icon(
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
                      validator:
                      _validarConfirmacao,
                    ),

                    const SizedBox(height: 16),

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
                          BorderRadius.circular(8),
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
                            const SizedBox(width: 10),
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
                    // CRIAR ACESSO
                    // ==================================================

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                        _carregando
                            ? null
                            : _cadastrarAcesso,
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
                          'Criar acesso',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // VOLTAR
                    // ==================================================

                    TextButton(
                      onPressed: _carregando
                          ? null
                          : widget.onVoltarLogin,
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