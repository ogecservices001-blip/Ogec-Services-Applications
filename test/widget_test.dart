import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ogec_services_app/core/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen affiche le formulaire de connexion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('OGEC SERVICES'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('SE CONNECTER'), findsOneWidget);
  });
}
