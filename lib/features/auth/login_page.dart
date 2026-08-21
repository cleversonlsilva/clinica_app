import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';

/// Tela de login do paciente do Clínica App.
///
/// A interface utiliza o AuthService como única camada
/// responsável pelo processo de autenticação.
///
/// Após o login realizado com sucesso, comunica o resultado
/// ao AuthGate através de onLoginSuccess.
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
      await _authService.login(
        login: _loginController.text.trim(),
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = 'Não foi possível realizar o login.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Nexo APP',
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
                      'Acesse sua área do paciente',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _loginController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      enabled: !_carregando,
                      decoration: const InputDecoration(
                        labelText: 'CPF ou telefone',
                        hintText: 'Digite seu CPF ou telefone',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final texto = value?.trim() ?? '';

                        if (texto.isEmpty) {
                          return 'Informe seu CPF ou telefone.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      textInputAction: TextInputAction.done,
                      enabled: !_carregando,
                      onFieldSubmitted: (_) {
                        _entrar();
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        hintText: 'Digite sua senha',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon: IconButton(
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
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe sua senha.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_erro != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _erro!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                        _carregando ? null : _entrar,
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
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () {
                        // O fluxo de primeiro acesso será
                        // conectado posteriormente.
                      },
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