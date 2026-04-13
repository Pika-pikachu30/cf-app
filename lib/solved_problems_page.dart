import 'package:flutter/material.dart';
import '../api_service.dart';

class SolvedProblemsPage extends StatefulWidget {
  final String handle;
  const SolvedProblemsPage({super.key, required this.handle});

  @override
  State<SolvedProblemsPage> createState() => _SolvedProblemsPageState();
}

class _SolvedProblemsPageState extends State<SolvedProblemsPage> {
  bool loading = true;

  List<dynamic> solved = [];
  List<dynamic> filtered = [];

  int? selectedDifficulty;
  String? selectedTag;

  @override
  void initState() {
    super.initState();
    loadSolved();
  }

  Future<void> loadSolved() async {
    final submissions = await ApiService.fetchSubmissions(widget.handle);

    final seen = <String>{};
    final List<dynamic> result = [];

    for (var s in submissions) {
      if (s['verdict'] == 'OK') {
        final p = s['problem'];
        final key = "${p['contestId']}-${p['index']}";
        if (seen.add(key)) {
          result.add({
            "name": p['name'],
            "rating": p['rating'],
            "tags": p['tags'],
            "time": DateTime.fromMillisecondsSinceEpoch(
                s['creationTimeSeconds'] * 1000),
          });
        }
      }
    }

    result.sort((a, b) => b['time'].compareTo(a['time']));

    setState(() {
      solved = result;
      filtered = result;
      loading = false;
    });
  }

  void applyFilter() {
    filtered = solved.where((p) {
      if (selectedDifficulty != null && p['rating'] != selectedDifficulty)
        return false;
      if (selectedTag != null && !(p['tags'] as List).contains(selectedTag))
        return false;
      return true;
    }).toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1023),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: const Text("Solved Problems"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _problemCard(filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        children: [
          DropdownButton<int>(
            hint: const Text("Difficulty"),
            value: selectedDifficulty,
            items: [800, 1000, 1200, 1400, 1600, 1800]
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text("$d"),
                    ))
                .toList(),
            onChanged: (v) {
              selectedDifficulty = v;
              applyFilter();
            },
          ),
          DropdownButton<String>(
            hint: const Text("Tag"),
            value: selectedTag,
            items: const ["dp", "greedy", "graphs", "math", "implementation"]
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t),
                    ))
                .toList(),
            onChanged: (v) {
              selectedTag = v;
              applyFilter();
            },
          ),
        ],
      ),
    );
  }

  Widget _problemCard(dynamic p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            "Rating: ${p['rating'] ?? '—'}  •  ${p['time'].toString().split(' ')[0]}",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: (p['tags'] as List)
                .map<Widget>((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 10)),
                      backgroundColor: const Color(0xFF0F1023),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
