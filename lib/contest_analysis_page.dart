import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // <--- ADD IMPORT
import 'package:fl_chart/fl_chart.dart';
import 'api_service.dart';

class ContestAnalysisPage extends StatefulWidget {
  final String handle;
  final int contestId;
  final String contestName;

  const ContestAnalysisPage({
    super.key,
    required this.handle,
    required this.contestId,
    required this.contestName,
  });

  @override
  State<ContestAnalysisPage> createState() => _ContestAnalysisPageState();
}

class _ContestAnalysisPageState extends State<ContestAnalysisPage> {
  bool loading = true;
  List<Map<String, dynamic>> analysisSections = [];
  String? aiStrategy;

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  Color _getVerdictColor(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'WRONG_ANSWER':
        return Colors.red;
      case 'TIME_LIMIT_EXCEEDED':
        return Colors.orange;
      case 'MEMORY_LIMIT_EXCEEDED':
        return Colors.yellow;
      case 'RUNTIME_ERROR':
        return Colors.purple;
      case 'COMPILATION_ERROR':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Future<void> loadAnalysis() async {
    final data = await ApiService.generateComprehensiveAnalysis(
        handle: widget.handle, contestId: widget.contestId);

    final strategy = await ApiService.generateAiContestStrategy(
        widget.handle, widget.contestId);

    if (!mounted) return;

    setState(() {
      analysisSections = data;
      aiStrategy = strategy;
      loading = false;
    });
  }

  Widget section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _renderSectionContent(String type, dynamic data) {
    if (data == null || (data is Iterable && data.isEmpty)) {
      if (data is Map && data.isEmpty) {
        return const Text("No specific data found for this category.",
            style: TextStyle(color: Colors.white38, fontSize: 13));
      }
    }

    switch (type) {
      case 'stat_grid': // NEW
        return _buildStatGrid(data as Map<String, String>);

      case 'detailed_problem_list': // NEW
        return _buildDetailedProblemList(data as List);

      case 'list':
        return Column(
          children: (data as List)
              .map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 20),
                    title: Text(e['problem'] ?? "Unknown",
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(e['contest'] ?? "",
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ))
              .toList(),
        );

      case 'chips':
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: (data as Map)
              .entries
              .map((e) => Chip(
                    label: Text("${e.key}: ${e.value}",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: const Color(0xFF1B1D3A),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ))
              .toList(),
        );

      case 'mistakes':
        return Column(
          children: (data as Map)
              .entries
              .map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key,
                        style: const TextStyle(color: Colors.white70)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("${e.value}x",
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ),
                  ))
              .toList(),
        );

      case 'pie_chart':
        final Map<String, int> mistakes = Map<String, int>.from(data as Map);
        if (mistakes.isEmpty) {
          return const Text("No errors in this contest!",
              style: TextStyle(color: Colors.greenAccent));
        }
        return SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: mistakes.entries.map((e) {
                final color = _getVerdictColor(e.key);
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  title: '${e.key}\n${e.value}',
                  color: color,
                  radius: 50,
                  titleStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        );

      case 'summary':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: (data as Map)
                .entries
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key,
                              style: const TextStyle(color: Colors.white54)),
                          Text(e.value.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        );

      default:
        return Text(data.toString(),
            style: const TextStyle(color: Colors.white70));
    }
  }

  // --- Helpers ---

  Widget _buildStatGrid(Map<String, String> data) {
    return LayoutBuilder(builder: (context, constraints) {
      double itemWidth = (constraints.maxWidth - 12) / 2; // 2 cols
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: data.entries.map((e) {
          // Determine color for Delta/Rank
          Color valColor = Colors.white;
          if (e.key == "Delta") {
            if (e.value.startsWith("+"))
              valColor = Colors.greenAccent;
            else if (e.value.startsWith("-")) valColor = Colors.redAccent;
          }
          if (e.key == "Rank") valColor = const Color(0xFF7B61FF);

          return Container(
            width: itemWidth,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D3A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Text(e.value,
                    style: TextStyle(
                        color: valColor,
                        fontSize: 22, // Bigger
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildDetailedProblemList(List data) {
    if (data.isEmpty) return const Text("No problems attempted.");

    return Column(
      children: data.map((item) {
        final idx = item['index'] ?? "?";
        final name = item['name'] ?? "Unknown";
        final solved = item['solved'] == true;
        final tries = item['tryCount'] ?? 0;
        final lastVerdict = item['lastVerdict'];

        String statusText;
        if (solved)
          statusText = "Solved";
        else if (lastVerdict != null)
          statusText = lastVerdict;
        else
          statusText = "Tried";

        Color statusColor = solved ? Colors.greenAccent : Colors.redAccent;
        if (!solved && lastVerdict == null) statusColor = Colors.orangeAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(idx,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                          solved
                              ? Icons.check_circle_outline
                              : Icons.highlight_off,
                          color: statusColor,
                          size: 14),
                      const SizedBox(width: 4),
                      Text("$statusText • $tries shot${tries == 1 ? '' : 's'}",
                          style: TextStyle(
                              color: statusColor.withOpacity(0.8),
                              fontSize: 13)),
                    ],
                  )
                ],
              )),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1023),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF7B61FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: Text(widget.contestName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...analysisSections.map((item) {
              return section(
                item['title'] ?? "Analysis",
                _renderSectionContent(item['type'] ?? "text", item['data']),
              );
            }).toList(),

            // --- AI STRATEGY SECTION (UPDATED) ---
            section(
              "AI Mentor Strategy",
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B61FF).withValues(alpha: 0.2),
                      const Color(0xFF1B1D3A)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.3)),
                ),
                // CHANGED: Using MarkdownBody here
                child: MarkdownBody(
                  data: aiStrategy ?? "Developing your tactical plan...",
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        color: Colors.white70, fontSize: 15, height: 1.6),
                    strong: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    listBullet: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
