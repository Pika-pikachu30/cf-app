import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'problem_details_page.dart';

class RecommendationsPage extends StatefulWidget {
  final String handle;
  const RecommendationsPage({super.key, required this.handle});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  bool loading = true;
  bool usingAi = false;
  bool isSearching = false; // New: track manual search state
  List<Map<String, dynamic>> finalProblems = [];
  List<String> weakTags = [];

  final TextEditingController _contestController = TextEditingController();
  String _selectedIndex = 'A';
  final List<String> _indexOptions = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  @override
  void initState() {
    super.initState();
    _engineStart();
  }

  // ... (Your existing _analyzeWeaknesses and _engineStart functions) ...
  void _analyzeWeaknesses(List<dynamic> submissions) {
    Map<String, int> tagSolved = {};
    Map<String, int> tagTotal = {};
    for (var s in submissions) {
      final tags = s['problem']['tags'] as List? ?? [];
      for (var t in tags) {
        String tag = t.toString();
        tagTotal[tag] = (tagTotal[tag] ?? 0) + 1;
        if (s['verdict'] == 'OK') tagSolved[tag] = (tagSolved[tag] ?? 0) + 1;
      }
    }
    List<String> sortedTags =
        tagTotal.keys.where((t) => tagTotal[t]! >= 3).toList();
    sortedTags.sort((a, b) {
      double rateA = (tagSolved[a] ?? 0) / tagTotal[a]!;
      double rateB = (tagSolved[b] ?? 0) / tagTotal[b]!;
      return rateA.compareTo(rateB);
    });
    if (mounted) {
      setState(() {
        weakTags = sortedTags.take(3).toList();
        if (weakTags.isEmpty) weakTags = ["greedy", "implementation", "math"];
      });
    }
  }

  Future<void> _engineStart() async {
    try {
      final userData = await ApiService.fetchCodeforcesUser(widget.handle);
      final submissions = await ApiService.fetchSubmissions(widget.handle);
      if (userData == null) throw Exception("User not found");
      _analyzeWeaknesses(submissions);
      final problemData = await ApiService.fetchProblemSet();
      if (problemData.isEmpty || problemData['result'] == null)
        throw Exception("Problem set unavailable");
      final Map<String, dynamic> result =
          Map<String, dynamic>.from(problemData['result']);
      final List allProblems = result['problems'];
      int currentRating = userData['rating'] ?? 1000;
      final solvedIds = submissions
          .where((s) => s['verdict'] == 'OK')
          .map((s) => "${s['problem']['contestId']}${s['problem']['index']}")
          .toSet();
      final candidates = allProblems
          .where((p) {
            int pRating = p['rating'] ?? 0;
            bool ratingMatch = pRating >= (currentRating - 100) &&
                pRating <= (currentRating + 200);
            bool notSolved =
                !solvedIds.contains("${p['contestId']}${p['index']}");
            return ratingMatch && notSolved;
          })
          .take(30)
          .toList();
      if (mounted) setState(() => usingAi = true);
      final aiSelection = await ApiService.getAiRecommendations(
          candidates, weakTags, currentRating);
      if (mounted) {
        setState(() {
          if (aiSelection.isNotEmpty) {
            finalProblems = List<Map<String, dynamic>>.from(aiSelection);
          } else {
            finalProblems = candidates.take(5).map((p) {
              return Map<String, dynamic>.from(p)
                ..['aiReason'] = 'Recommended based on your rating.';
            }).toList();
          }
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
          title: const Text("Problems"),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF7B61FF)),
                  const SizedBox(height: 20),
                  Text(
                      usingAi
                          ? "AI is curating your list..."
                          : "Analyzing profile...",
                      style: const TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _engineStart,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildManualSearch(),
                  const SizedBox(height: 25),
                  if (weakTags.isNotEmpty) _buildWeaknessHeader(),
                  const Text("Recommended for You",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 15),
                  ...finalProblems.map((p) => _buildAiProblemCard(p)),
                ],
              ),
            ),
    );
  }

  Widget _buildManualSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _contestController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "Contest ID",
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _selectedIndex,
                  dropdownColor: const Color(0xFF1B1D3A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Index",
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: _indexOptions
                      .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedIndex = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSearching ? null : _handleManualSearch,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF)),
              child: isSearching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("View Problem",
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManualSearch() async {
    if (_contestController.text.isEmpty) return;

    setState(() => isSearching = true);

    int cid = int.parse(_contestController.text);
    String idx = _selectedIndex.toUpperCase();

    // Fetch correct metadata from Codeforces before navigating
    final metadata = await ApiService.fetchProblemMetadata(cid, idx);

    setState(() => isSearching = false);

    if (metadata != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProblemDetailsPage(problem: metadata),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Problem not found. Check Contest ID/Index.")),
      );
    }
  }

  Widget _buildWeaknessHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Identified Weaknesses",
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)),
                Text(weakTags.join(", ").toUpperCase(),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAiProblemCard(Map<String, dynamic> p) {
    // Extract tags properly
    List tags = p['tags'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Name and Rating ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${p['index']}. ${p['name']}",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              Chip(
                label: Text("${p['rating'] ?? '?'}",
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: const Color(0xFF7B61FF).withOpacity(0.2),
              )
            ],
          ),

          // --- Tags ---
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: tags
                .take(3)
                .map((tag) => Text(
                      "#$tag",
                      style: const TextStyle(
                          color: Color(0xFF7B61FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ))
                .toList(),
          ),

          const SizedBox(height: 12),

          // --- AI Reason Box ---
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7B61FF).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFF7B61FF).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: Color(0xFF7B61FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p['aiReason'] ??
                        "Recommended based on your recent activity.",
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // --- Action Button ---
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProblemDetailsPage(problem: p))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("View & Solve",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
