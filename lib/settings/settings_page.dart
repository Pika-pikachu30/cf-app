import 'package:flutter/material.dart';
import '../api_service.dart';
import '../login_page.dart';
import '../codeforces_page.dart';

class SettingsPage extends StatelessWidget {
  final String email;

  const SettingsPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            Icons.person,
            "Change Codeforces Handle",
            () async {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => CodeforcesPage(email: email),
                ),
              );
            },
          ),
          _tile(
            Icons.sync,
            "Re-sync Data",
            () async {
              await ApiService.resyncAllData();
              _snack(context, "Data re-synced successfully");
            },
          ),
          _tile(
            Icons.delete_outline,
            "Clear Cache",
            () async {
              await ApiService.clearCache();
              _snack(context, "Cache cleared");
            },
          ),
          const Divider(color: Colors.white10),
          _tile(
            Icons.logout,
            "Logout",
            () async {
              await ApiService.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            danger: true,
          ),
        ],
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.redAccent : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: danger ? Colors.redAccent : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
      onTap: onTap,
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF7B61FF),
      ),
    );
  }
}
