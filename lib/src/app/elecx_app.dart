import 'package:flutter/material.dart';

import '../features/auth/pin_unlock_screen.dart';

class ElecXApp extends StatelessWidget {
  const ElecXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElecX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF244A7C),
      ),
      home: const PinUnlockScreen(),
    );
  }
}
