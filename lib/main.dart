import 'package:flutter/material.dart';
import 'splash_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CP Mentor AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF212436), // Deep Neumorphic Base
        primaryColor: const Color(0xFF7B61FF),
        fontFamily: 'Roboto', // Or your preferred font
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}
