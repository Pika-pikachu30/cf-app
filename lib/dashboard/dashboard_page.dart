import 'package:flutter/material.dart';
import '../api_service.dart';
import 'stats_card.dart';
import 'activity_list.dart';
import 'rating_chart.dart';
import 'rating_predictor_widget.dart';

class DashboardPage extends StatefulWidget {
  final String handle;
  const DashboardPage({super.key, required this.handle});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  int solved = 0;
  List recent = [];
  int? rating;
  Map<int, int> ratingBuckets = {};

  // Analytics variables
  Map<String, double> topicAccuracy = {};
  List<String> strongestTopics = [];
  List<String> weakestTopics = [];
  Map<String, dynamic>? lastContest;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchSubmissions(widget.handle),
        ApiService.fetchCodeforcesUser(widget.handle),
        ApiService.fetchLastContest(widget.handle),
      ]);

      final submissions = results[0] as List<dynamic>;
      final userInfo = results[1] as Map<String, dynamic>?;
      final contestData = results[2] as Map<String, dynamic>?;

      Map<String, int> tagSolved = {};
      Map<String, int> tagTotal = {};
      final solvedSet = <String>{};
      final buckets = <int, int>{};
      final recentList = <Map<String, dynamic>>[];

      for (var s in submissions) {
        final problem = s['problem'];
        final List tags = problem['tags'] ?? [];
        final int? pRating = problem['rating'];
        final String pId = "${problem['contestId']}-${problem['index']}";

        if (recentList.length < 10) {
          recentList.add({
            'name': problem['name'],
            'verdict': s['verdict'],
          });
        }

        if (s['verdict'] == 'OK' && pRating != null) {
          buckets[pRating] = (buckets[pRating] ?? 0) + 1;
        }

        for (var tag in tags) {
          tagTotal[tag] = (tagTotal[tag] ?? 0) + 1;
          if (s['verdict'] == 'OK') {
            tagSolved[tag] = (tagSolved[tag] ?? 0) + 1;
            solvedSet.add(pId);
          }
        }
      }

      // --- MISSING LOGIC START ---
      Map<String, double> accuracyMap = {};
      tagTotal.forEach((tag, total) {
        accuracyMap[tag] = (tagSolved[tag] ?? 0) / total;
      });

      // This defines 'sortedTags'
      var sortedTags = accuracyMap.keys.toList()
        ..sort((a, b) => accuracyMap[a]!.compareTo(accuracyMap[b]!));
      // --- MISSING LOGIC END ---

      setState(() {
        solved = solvedSet.length;
        rating = userInfo?['rating'];
        ratingBuckets = buckets;
        recent = recentList;
        lastContest = contestData;

        // Now 'sortedTags' is defined and can be used here
        weakestTopics = sortedTags.take(3).toList();
        strongestTopics = sortedTags.reversed.take(3).toList();

        topicAccuracy = accuracyMap;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  // Helper function to build Topic Progress Bars
  Widget _buildTopicItem(String tag, double accuracy, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tag,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                height: 6,
                width: MediaQuery.of(context).size.width * 0.8 * accuracy,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B61FF)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Dashboard",
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: StatsCard(
                      title: "Solved",
                      value: solved.toString(),
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatsCard(
                      title: "Rating",
                      value: rating?.toString() ?? "—",
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Add the predictor widget here
              RatingPredictorWidget(handle: widget.handle),

              const SizedBox(height: 30),
              RatingChart(data: ratingBuckets),
              const SizedBox(height: 30),

              // Last Contest Section
              if (lastContest != null) ...[
                const Text("Last Contest Performance",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1D3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lastContest!['contestName'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            Text("Rank: ${lastContest!['rank']}",
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      Text(
                        "${lastContest!['newRating'] - lastContest!['oldRating'] >= 0 ? '+' : ''}${lastContest!['newRating'] - lastContest!['oldRating']}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: (lastContest!['newRating'] -
                                      lastContest!['oldRating']) >=
                                  0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // Topic Analysis
              const Text("Weakest Topics (Improve these!)",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              ...weakestTopics.map((t) =>
                  _buildTopicItem(t, topicAccuracy[t]!, Colors.redAccent)),

              const SizedBox(height: 30),

              const Text("Strongest Topics",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              ...strongestTopics.map((t) =>
                  _buildTopicItem(t, topicAccuracy[t]!, Colors.greenAccent)),

              const SizedBox(height: 30),
              ActivityList(items: recent),
            ],
          ),
        ),
      ),
    );
  }
}
