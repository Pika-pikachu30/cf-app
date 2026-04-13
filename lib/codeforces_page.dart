import 'package:flutter/material.dart';
import 'package:codeforces_tool_app/navigation/bottom_nav.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodeforcesPage extends StatefulWidget {
  final String email;
  const CodeforcesPage({super.key, required this.email});

  @override
  State<CodeforcesPage> createState() => _CodeforcesPageState();
}

class _CodeforcesPageState extends State<CodeforcesPage> {
  final handleController = TextEditingController();
  bool loading = false;

  void verifyHandle() async {
    if (handleController.text.isEmpty) return;

    setState(() => loading = true);
    final userData =
        await ApiService.fetchCodeforcesUser(handleController.text);
    setState(() => loading = false);

    if (!mounted) return;

    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Codeforces ID not found"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2B2E4A), // Slightly lighter than bg
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Identity",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Handle:", userData['handle']),
            const SizedBox(height: 10),
            _buildInfoRow("Rating:", "${userData['rating'] ?? 'Unrated'}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ), // In codeforces_page.dart, inside the 'Confirm' button onPressed:

// Inside the onPressed for "Confirm"

            onPressed: () async {
              Navigator.pop(context);

              setState(() => loading = true);

              // 1. Save to Server (You already have this)
              await ApiService.saveHandle(
                widget.email,
                handleController.text,
              );

              // 2. SAVE LOCALLY (Add this!)
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  "handle", handleController.text); // <--- Important

              setState(() => loading = false);

              if (!mounted) return;

              // Navigate to Dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MainScaffold(
                    handle: handleController.text,
                    email: widget.email,
                  ),
                ),
              );
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(width: 10),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF7B61FF),
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF212436);

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Connect Profile",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        offset: const Offset(-5, -5),
                        blurRadius: 10),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(5, 5),
                        blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.link_rounded,
                    size: 50, color: Color(0xFF7B61FF)),
              ),
              const SizedBox(height: 30),

              const Text(
                "Link Codeforces",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter your handle to fetch statistics",
                style: TextStyle(
                    fontSize: 14, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 40),

              // Neumorphic Input
              Container(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        offset: const Offset(-4, -4),
                        blurRadius: 10),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(4, 4),
                        blurRadius: 10),
                  ],
                ),
                child: TextField(
                  controller: handleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_search_outlined,
                        color: Colors.white54),
                    labelText: "Codeforces Handle",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Neumorphic Button
              GestureDetector(
                onTap: loading ? null : verifyHandle,
                child: Container(
                  width: double.infinity,
                  height: 55,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B61FF), Color(0xFF5E43F3)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF7B61FF).withOpacity(0.4),
                          offset: const Offset(-4, -4),
                          blurRadius: 10),
                      BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          offset: const Offset(4, 4),
                          blurRadius: 10),
                    ],
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("VERIFY & SAVE",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
