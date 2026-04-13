import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Ensure these imports match your file structure
import 'login_page.dart';
import 'codeforces_page.dart';
import 'api_service.dart';
import './navigation/bottom_nav.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _progressValue = 0.0;
  String _loadingText = "Initializing...";

  @override
  void initState() {
    super.initState();

    // 1. Setup Breathing Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // 2. Start Logic
    _startLoadingProcess();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startLoadingProcess() async {
    if (mounted) setState(() => _progressValue = 0.2);
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _progressValue = 0.5;
        _loadingText = "Verifying Session...";
      });
    }

    try {
      final problemFetchTask = ApiService.fetchProblemSet();

      await Future.wait([
        Future.delayed(const Duration(milliseconds: 800)),
        problemFetchTask.catchError((e) {
          debugPrint("Splash API fetch error: $e");
          return <String, dynamic>{};
        }),
      ]);
    } catch (e) {
      debugPrint("Critical splash error: $e");
    }

    if (mounted) {
      setState(() {
        _progressValue = 1.0;
        _loadingText = "Ready!";
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool("loggedIn") ?? false;
    final email = prefs.getString("email");
    final handle = prefs.getString("handle");

    if (!mounted) return;

    if (loggedIn && email != null) {
      if (handle != null && handle.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => MainScaffold(handle: handle, email: email)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CodeforcesPage(email: email)),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF212436);
    const accentColor = Color(0xFF7B61FF);

    return Scaffold(
      backgroundColor: baseColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- 1. Custom Constructed "C" Logo ---
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final double animValue = _animation.value;
                final double blur = 10 + (10 * animValue);
                final double offsetDelta = 5 + (5 * animValue);

                return Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius:
                        BorderRadius.circular(45), // Soft square shape
                    boxShadow: [
                      // Glowing Effect
                      BoxShadow(
                        color: accentColor.withOpacity(0.3 + (0.3 * animValue)),
                        offset: Offset.zero,
                        blurRadius: 20 + (10 * animValue),
                        spreadRadius: 1 + (3 * animValue),
                      ),
                      // Neumorphic Light Shadow
                      BoxShadow(
                        color: Colors.white.withOpacity(0.08),
                        offset: Offset(-offsetDelta, -offsetDelta),
                        blurRadius: blur,
                      ),
                      // Neumorphic Dark Shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        offset: Offset(offsetDelta, offsetDelta),
                        blurRadius: blur,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20.0), // Spacing from outer box
                    child: Container(
                      decoration: BoxDecoration(
                        // The Purple Outer Ring (Gradient for depth)
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF7B61FF), // accentColor
                            Color(0xFF5E43D8), // darker shade
                          ],
                        ),
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                            6.0), // Thickness of purple ring
                        child: Container(
                          decoration: BoxDecoration(
                              // The Inner White Oval
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 0,
                                )
                              ]),
                          child: const Center(
                            child: Text(
                              "C",
                              style: TextStyle(
                                fontSize: 65,
                                height:
                                    1.0, // Tightens line height to center vertically
                                fontWeight: FontWeight.w900, // Extra Bold
                                color: accentColor,
                                letterSpacing:
                                    -2.0, // Tighter kerning for logo look
                                fontFamily:
                                    'Roboto', // Ensures clean sans-serif
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 60),

            // --- 2. Title ---
            Text(
              "CP Mentor AI",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- 3. Custom Progress Bar ---
            SizedBox(
              width: 220,
              child: Column(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E2F),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(2, 2),
                          blurRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.05),
                          offset: const Offset(-1, -1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: 220 * _progressValue,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFFA78BFA)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 0),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _loadingText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
