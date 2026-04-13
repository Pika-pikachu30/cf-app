import 'package:flutter/material.dart';
import '../api_service.dart';
import 'contest_analysis_page.dart'; // ✅ ADD

class RatingProgressPage extends StatefulWidget {
  final String handle;
  const RatingProgressPage({super.key, required this.handle});

  @override
  State<RatingProgressPage> createState() => _RatingProgressPageState();
}

class RatingLinePainter extends CustomPainter {
  final List<dynamic> history;
  final int min, max;

  RatingLinePainter(this.history, this.min, this.max);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF7B61FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double dx = size.width / (history.length - 1);
    double range = (max - min).toDouble();
    if (range == 0) range = 1;

    for (int i = 0; i < history.length; i++) {
      double x = i * dx;
      double y =
          size.height - ((history[i]['newRating'] - min) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _RatingProgressPageState extends State<RatingProgressPage> {
  bool loading = true;
  List<dynamic> history = [];
  Map<int, List<Map<String, dynamic>>> contestPerformance = {};
  int maxRating = 0;
  int minRating = 5000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchRatingHistory(widget.handle),
        ApiService.fetchSubmissions(widget.handle),
      ]);

      final ratingData = results[0] as List<dynamic>;
      final submissions = results[1] as List<dynamic>;

      if (ratingData.isNotEmpty) {
        for (var c in ratingData) {
          if (c['newRating'] > maxRating) maxRating = c['newRating'];
          if (c['newRating'] < minRating) minRating = c['newRating'];
        }
      }

      Map<int, List<Map<String, dynamic>>> performanceMap = {};

      for (var s in submissions) {
        if (s['verdict'] == 'OK' &&
            s['relativeTimeSeconds'] > 0 &&
            s['relativeTimeSeconds'] < 18000) {
          int cId = s['contestId'];
          performanceMap.putIfAbsent(cId, () => []);
          performanceMap[cId]!.add({
            'index': s['problem']['index'],
            'minutes': (s['relativeTimeSeconds'] / 60).round(),
          });
        }
      }

      performanceMap.forEach((key, value) {
        value.sort((a, b) => a['index'].compareTo(b['index']));
      });

      setState(() {
        history = ratingData;
        contestPerformance = performanceMap;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(title: const Text("Contest Timeline")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rating Journey",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildRatingGraph(),
            const SizedBox(height: 35),
            const Text("Contest History & Solve Times",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text(
              "Time shown is minutes into the contest when solved",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 15),
            ...history.reversed
                .map((c) => _buildDetailedContestCard(c))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedContestCard(dynamic c) {
    int diff = c['newRating'] - c['oldRating'];
    int contestId = c['contestId'];
    List<Map<String, dynamic>> solvedThisRound =
        contestPerformance[contestId] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c['contestName'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${diff >= 0 ? '+' : ''}$diff",
                style: TextStyle(
                  color: diff >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          if (solvedThisRound.isEmpty)
            const Text(
              "No problems solved during live duration.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: solvedThisRound.map((p) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1023),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF7B61FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p['index'],
                        style: const TextStyle(
                            color: Color(0xFF7B61FF),
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.timer_outlined,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text("${p['minutes']}m",
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Rank: ${c['rank']}  •  New Rating: ${c['newRating']}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),

              // ✅ VIEW ANALYSIS BUTTON
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContestAnalysisPage(
                        contestId: contestId,
                        handle: widget.handle,
                        contestName: c['contestName'],
                      ),
                    ),
                  );
                },
                child: const Text(
                  "View Analysis →",
                  style: TextStyle(
                    color: Color(0xFF7B61FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingGraph() {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomPaint(
        painter: RatingLinePainter(history, minRating, maxRating),
      ),
    );
  }
}
