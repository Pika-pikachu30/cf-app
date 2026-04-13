import 'package:flutter/material.dart';
import 'package:codeforces_tool_app/solved_problems_page.dart';
import '../dashboard/dashboard_page.dart';
import '../topic_analysis_page.dart';
import '../rating_progress_page.dart';
import '../recommendation_page.dart';
import '../ai_mentor_page.dart';
import '../settings/settings_page.dart';
import '../friends_comparison_page.dart';
// import '../chat/chat_page.dart';
// import '../settings/settings_page.dart';

class MainScaffold extends StatefulWidget {
  final String handle;
  final String email;

  const MainScaffold({
    super.key,
    required this.handle,
    required this.email,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(handle: widget.handle),
      TopicAnalysisPage(handle: widget.handle),
      RatingProgressPage(handle: widget.handle),
      RecommendationsPage(handle: widget.handle),
      AiMentorPage(handle: widget.handle),
      SolvedProblemsPage(handle: widget.handle),
      FriendsComparisonPage(handle: widget.handle),
      SettingsPage(email: widget.email)
      // const ChatPage(),
      // const SettingsPage(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D3A),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(4, 4),
            ),
            BoxShadow(
              color: Colors.white10,
              blurRadius: 12,
              offset: Offset(-4, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.dashboard, 0),
            _navItem(Icons.analytics, 1),
            _navItem(Icons.auto_graph, 2),
            _navItem(Icons.recommend, 3),
            _navItem(Icons.smart_toy, 4),
            _navItem(Icons.quiz, 5),
            _navItem(Icons.group, 6),
            _navItem(Icons.settings, 7),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int i) {
    return GestureDetector(
      onTap: () => setState(() => _index = i),
      child: Icon(
        icon,
        size: 28,
        color: _index == i ? const Color(0xFF7B61FF) : Colors.white70,
      ),
    );
  }
}
