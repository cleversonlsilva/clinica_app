import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';

void main() {
  runApp(const MyApp());
}

/// Aplicação principal do Clínica App.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexo APP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}