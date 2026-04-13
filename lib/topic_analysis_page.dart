import 'package:flutter/material.dart';
import '../api_service.dart';

class TopicAnalysisPage extends StatefulWidget {
  final String handle;
  const TopicAnalysisPage({super.key, required this.handle});

  @override
  State<TopicAnalysisPage> createState() => _TopicAnalysisPageState();
}

class _TopicAnalysisPageState extends State<TopicAnalysisPage> {
  bool loading = true;
  Map<String, Map<String, int>> tagStats =
      {}; // { 'tag': {'solved': 5, 'total': 10} }
  Map<String, List<int>> tagDifficulty = {}; // { 'tag': [800, 1200...] }
  Map<DateTime, int> heatmapData = {};
  @override
  void initState() {
    super.initState();
    _processData();
  }
// Add this variable to your State class
// Map<DateTime, int> heatmapData = {};

  void _processData() async {
    final submissions = await ApiService.fetchSubmissions(widget.handle);
    Map<String, Map<String, int>> stats = {};
    Map<String, List<int>> diffs = {};
    Map<DateTime, int> heat = {}; // Temporary map for heatmap

    for (var s in submissions) {
      // Heatmap Logic: Convert timestamp to date-only DateTime
      final date =
          DateTime.fromMillisecondsSinceEpoch(s['creationTimeSeconds'] * 1000);
      final day = DateTime(date.year, date.month, date.day);
      heat[day] = (heat[day] ?? 0) + 1;

      final problem = s['problem'];
      final List tags = problem['tags'] ?? [];
      final int? rating = problem['rating'];

      for (var tag in tags) {
        stats.putIfAbsent(tag, () => {'solved': 0, 'total': 0});
        diffs.putIfAbsent(tag, () => []);
        stats[tag]!['total'] = stats[tag]!['total']! + 1;
        if (s['verdict'] == 'OK') {
          stats[tag]!['solved'] = stats[tag]!['solved']! + 1;
          if (rating != null) diffs[tag]!.add(rating);
        }
      }
    }

    setState(() {
      tagStats = stats;
      tagDifficulty = diffs;
      heatmapData = heat; // Store the processed heatmap data
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final sortedTags = tagStats.keys.toList()
      ..sort(
          (a, b) => tagStats[b]!['total']!.compareTo(tagStats[a]!['total']!));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(title: const Text("Topic Analysis")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeatmap(), // 👈 Heatmap added at the top
          const SizedBox(height: 25),
          const Text("Detailed Topic Stats",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          // Move your existing tag list logic here:
          ...sortedTags.map((tag) {
            final solved = tagStats[tag]!['solved']!;
            final total = tagStats[tag]!['total']!;
            final rate = (solved / total) * 100;
            final list = tagDifficulty[tag]!;
            final avg = list.isEmpty
                ? 0
                : (list.reduce((a, b) => a + b) / list.length).round();
            return _buildTopicCard(tag, solved, total, rate, avg);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
      String tag, int solved, int total, double rate, int avg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tag.toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF7B61FF))),
              Text("${rate.toStringAsFixed(1)}% Success",
                  style:
                      const TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: solved / total,
              backgroundColor: Colors.white10,
              color: const Color(0xFF7B61FF),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Solved", "$solved/$total"),
              _miniStat("Avg Difficulty", avg == 0 ? "N/A" : avg.toString()),
              _miniStat("Mastery", _getMasteryLevel(rate)),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }

  Widget _buildHeatmap() {
    // Generate list of the last 84 days (12 weeks)
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 365));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Activity Heatmap (Last 365 Days)",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 15),
          SizedBox(
            height: 130,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, // 7 days a week
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 365,
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final dayOnly = DateTime(date.year, date.month, date.day);
                final count = heatmapData[dayOnly] ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    color: _getHeatColor(count),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getHeatColor(int count) {
    if (count == 0) return Colors.white.withOpacity(0.05);
    if (count <= 2) return const Color(0xFF4D38B1); // Low activity
    if (count <= 5) return const Color(0xFF7B61FF); // Medium
    return const Color(0xFFA78BFA); // High activity
  }

  String _getMasteryLevel(double rate) {
    if (rate > 80) return "Expert";
    if (rate > 50) return "Intermediate";
    return "Beginner";
  }
}
