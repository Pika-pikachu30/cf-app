import 'package:flutter/material.dart';
import 'api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  void handleRegister() async {
    setState(() => loading = true);
    final success = await ApiService.register(
      emailController.text,
      passwordController.text,
    );
    setState(() => loading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration successful"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration failed"),
          backgroundColor: Colors.redAccent,
        ),
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
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Join the community today",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 40),

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

              NeuButton(
                onTap: loading ? null : handleRegister,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        "REGISTER",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
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

// Reuse the Neumorphic Widgets to ensure they work if files are separate
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
