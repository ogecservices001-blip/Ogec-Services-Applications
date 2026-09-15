import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_gate.dart';
import 'core/widgets/web_update_banner.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OGEC Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      builder: (context, child) => WebUpdateBanner(child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}
