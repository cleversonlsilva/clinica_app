import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../home/home_page.dart';
import 'login_page.dart';

/// Controla a entrada do aplicativo de acordo com a sessão atual.
///
/// Se existir uma sessão válida, apresenta a Home do paciente.
///
/// Caso contrário, apresenta a tela de login.
///
/// A atualização da sessão após o login também é controlada
/// por este Gate, evitando que o LoginPage precise realizar
/// navegação diretamente.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;

  bool? _possuiSessao;

  @override
  void initState() {
    super.initState();

    _authService = AuthServiceFactory.create();

    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    final possuiSessao = await _authService.possuiSessao();

    if (!mounted) {
      return;
    }

    setState(() {
      _possuiSessao = possuiSessao;
    });
  }

  /// Atualiza o estado do Gate após um login realizado com sucesso.
  ///
  /// O LoginPage não precisa conhecer a Home nem realizar
  /// navegação diretamente.
  void _loginRealizado() {
    if (!mounted) {
      return;
    }

    setState(() {
      _possuiSessao = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_possuiSessao == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_possuiSessao!) {
      return const HomePage();
    }

    return LoginPage(
      onLoginSuccess: _loginRealizado,
    );
  }
}