import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'ai_hint_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ProblemDetailsPage extends StatefulWidget {
  final Map<String, dynamic> problem;
  const ProblemDetailsPage({super.key, required this.problem});

  @override
  State<ProblemDetailsPage> createState() => _ProblemDetailsPageState();
}

class _ProblemDetailsPageState extends State<ProblemDetailsPage> {
  late Future<String> _summaryFuture;

  @override
  void initState() {
    super.initState();
    // Start fetching the AI summary as soon as the page is initialized
    _summaryFuture = ApiService.getProblemSummary(
      widget.problem['name'] ?? 'Unknown Problem',
      widget.problem['contestId'] ?? 0,
      widget.problem['index'] ?? '',
    );
  }

  Future<void> _launchEditorial() async {
    final contestId = widget.problem['contestId'];
    final url = Uri.parse(
        "https://www.google.com/search?q=codeforces+contest+$contestId+editorial");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch editorial search")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: const Text("Problem Analysis"),
        backgroundColor: const Color(0xFF1B1D3A),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header Section ---
                  _buildHeader(),
                  const SizedBox(height: 30),

                  // --- AI Summary Section ---
                  const Text(
                    "AI EXPLANATION",
                    style: TextStyle(
                      color: Color(0xFF7B61FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryBox(),
                  const SizedBox(height: 30),

                  // --- Tags Section ---
                  const Text(
                    "ALGORITHMIC TAGS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTags(),
                ],
              ),
            ),
          ),

          // --- Bottom Action Buttons ---
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF7B61FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology,
                size: 48, color: Color(0xFF7B61FF)),
          ),
          const SizedBox(height: 16),
          Text(
            widget.problem['name'] ?? 'Loading...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Rating: ${widget.problem['rating'] ?? 'Unrated'}  •  Difficulty: ${widget.problem['index']}",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: FutureBuilder<String>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
              ),
            );
          } else if (snapshot.hasError || !snapshot.hasData) {
            return const Text("Failed to load AI summary.",
                style: TextStyle(color: Colors.white38));
          }

          // --- STABLE RENDERER ---
          return MarkdownBody(
            data: snapshot.data!,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                  color: Colors.white70, fontSize: 15, height: 1.6),
              strong: const TextStyle(
                  color: Color(0xFF7B61FF), fontWeight: FontWeight.bold),
              listBullet: const TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTags() {
    final List<dynamic> tags = widget.problem['tags'] ?? [];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1D3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            tag.toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1D3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _launchEditorial,
              icon: const Icon(Icons.launch, size: 18),
              label: const Text("Read Statement on Codeforces"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _launchEditorial,
              icon: const Icon(Icons.article, size: 18),
              label: const Text("Find Editorial"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiHintPage(problem: widget.problem),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text(
                "Ask AI for Hints",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
