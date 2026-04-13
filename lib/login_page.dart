import 'package:flutter/material.dart';
import 'api_service.dart';
import 'register_page.dart';
import 'codeforces_page.dart';
import './navigation/bottom_nav.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  void handleLogin() async {
    setState(() => loading = true);

    final user = await ApiService.login(
      emailController.text,
      passwordController.text,
    );

    setState(() => loading = false);

    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed")),
      );
      return;
    }

    // --- DEBUGGING: Print what the server actually returns ---
    print("SERVER RESPONSE: $user");
    // Check your console. Does it say "handle": "Tourist" or "codeforces_handle": "Tourist"?
    // ---------------------------------------------------------

    // 1. Save Basic Session Data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("loggedIn", true);
    await prefs.setString("email", emailController.text);

    // 2. RETRIEVE HANDLE (Corrected Key)
    // Most databases/APIs will return the column name, which is likely just "handle"
    final String? handle = user["handle"] ?? user["codeforces_handle"];

    // 3. CHECK & SAVE HANDLE LOCALLY
    if (handle != null && handle.isNotEmpty) {
      await prefs.setString(
          "handle", handle); // Save for splash screen checks later

      // ✅ Handle exists: Go to Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => MainScaffold(
                  handle: handle,
                  email: emailController.text,
                )),
      );
    } else {
      // ❌ No handle found in response: Go to Link page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CodeforcesPage(email: emailController.text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF212436);

    return Scaffold(
      backgroundColor: baseColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 60,
                color: Color(0xFF7B61FF),
              ),
              const SizedBox(height: 20),
              Text(
                "Welcome",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Sign in to continue",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 40),

              // Neumorphic Inputs
              NeuTextField(
                controller: emailController,
                hintText: "Email Address",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),
              NeuTextField(
                controller: passwordController,
                hintText: "Password",
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 40),

              // Neumorphic Button
              NeuButton(
                onTap: loading ? null : handleLogin,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
              const SizedBox(height: 25),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(),
                    ),
                  );
                },
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: "Register",
                        style: TextStyle(
                          color: Color(0xFF7B61FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== NEUMORPHIC WIDGETS ====================

class NeuTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;

  const NeuTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF212436),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

class NeuButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const NeuButton({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? const LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF5E43F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: onTap == null ? Colors.grey.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(15),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B61FF).withOpacity(0.4),
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: child,
      ),
    );
  }
}
