import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MaxxingApp());
}

class MaxxingApp extends StatelessWidget {
  const MaxxingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAXXING',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B7BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
