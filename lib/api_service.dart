import 'dart:convert';
import 'dart:async'; // Required for Timeout
import 'dart:isolate'; // Required for Isolate.run
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'rating_calculator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class CPStatsAggregator {
  static const String baseUrl = "https://codeforces.com/api";

  // 1. Fetch Every Submission Ever Made
  static Future<List<dynamic>> fetchAllSubmissions(String handle) async {
    // Omitting 'count' fetches the entire history
    final url = Uri.parse("$baseUrl/user.status?handle=$handle&from=1");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return data['result'];
      }
    }
    return [];
  }

  // 2. Aggregate Data into a Mentor-Friendly Summary
  static Map<String, dynamic> analyzeLifetimePerformance(
      List<dynamic> allSubs) {
    Map<String, int> tagSuccess = {};
    Map<String, int> tagFailure = {};
    Map<int, int> difficultyAC = {};
    int totalAC = 0;

    for (var sub in allSubs) {
      final problem = sub['problem'];
      final List tags = problem['tags'] ?? [];
      final int? rating = problem['rating'];
      final bool isAC = sub['verdict'] == 'OK';

      if (isAC) {
        totalAC++;
        if (rating != null)
          difficultyAC[rating] = (difficultyAC[rating] ?? 0) + 1;
      }

      for (var tag in tags) {
        if (isAC) {
          tagSuccess[tag] = (tagSuccess[tag] ?? 0) + 1;
        } else {
          tagFailure[tag] = (tagFailure[tag] ?? 0) + 1;
        }
      }
    }

    // Find "Kryptonite" Tags (High failure, low success)
    List<String> weakTags = tagFailure.keys.toList()
      ..sort((a, b) => (tagFailure[b]! - (tagSuccess[b] ?? 0))
          .compareTo(tagFailure[a]! - (tagSuccess[a] ?? 0)));

    return {
      'total_submissions': allSubs.length,
      'total_solved': totalAC,
      'accuracy': (totalAC / allSubs.length * 100).toStringAsFixed(1),
      'hardest_solved': difficultyAC.keys.isNotEmpty
          ? difficultyAC.keys.reduce((a, b) => a > b ? a : b)
          : 0,
      'top_weak_tags': weakTags.take(5).toList(),
    };
  }
}

class CodeforcesService {
  static const String baseUrl = "https://codeforces.com/api";

  // 1. Get last 4 contests
  static Future<List<Map<String, dynamic>>> getRecentContests(
      String handle) async {
    final response =
        await http.get(Uri.parse("$baseUrl/user.rating?handle=$handle"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List results = data['result'];
      // Return last 4 contest objects
      return results.reversed
          .take(4)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  // 2. Get last 20 submissions
  static Future<List<Map<String, dynamic>>> getRecentSubmissions(
      String handle) async {
    final response = await http
        .get(Uri.parse("$baseUrl/user.status?handle=$handle&from=1&count=20"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['result'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    return [];
  }
}

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000"; // backend URL

  static const String _geminiApiKey =
      "YOUR_GEMINI_API_KEY_HERE"; // Replace with your Gemini API key
  static Future<String> getProblemSummary(
      String name, int contestId, String index) async {
    try {
      final model = GenerativeModel(
          model: 'gemini-3-flash-preview', apiKey: _geminiApiKey);
      final prompt = """
      Explain the Codeforces problem '$name' ($contestId$index).
      Provide a concise 5 to 10 sentence summary:
      1. What is the core task?
      2. What is the key constraint or difficulty?
      3. What is the input/output goal?
      4. Use **bolding** for key terms.
      5. Use bullet points if needed.
      6. IMPORTANT: Do NOT use LaTeX. Use plain text for math (e.g., N <= 10^5, sum of a[i]).
      Keep it technical and skip the flavor text.
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Could not generate summary.";
    } catch (e) {
      return "Error loading summary. Please read the full statement on Codeforces.";
    }
  }

  static Future<int?> getUserRating(String handle) async {
    try {
      final response = await http.get(
          Uri.parse("https://codeforces.com/api/user.info?handles=$handle"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'].isNotEmpty) {
          return data['result'][0]['rating'];
        }
      }
    } catch (e) {
      print("Error fetching user rating: $e");
    }
    return null;
  }

  // ===========================================================================
  // 🔮 RATING PREDICTION — Exact Carrot/CF Algorithm (FFT-based)
  // Ported from https://github.com/nicklashansen/carrot → predict.js + conv.js
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Core helpers (all O(1) per call after FFT pre-computation)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Public API: Synthetic predictor (no network � instant)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> predictRatingChange({
    required int currentRating,
    required int rank,
    required String division,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/predict-rating"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "currentRating": currentRating,
          "rank": rank,
          "division": division,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Predict rating server error: ${response.body}");
        return _predictionError("Server returned ${response.statusCode}");
      }
    } catch (e) {
      print("Predict rating error: $e");
      return _predictionError("Failed to connect to server");
    }
  }

  // ---------------------------------------------------------------------------
  // Public API: Contest-based predictor (exact Carrot algorithm)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> predictRatingChangeFromContest({
    required int contestId,
    required int currentRating,
    required int rank,
  }) async {
    try {
      // 1. Fetch standings
      final rows = await _fetchContestRows(contestId);
      if (rows.isEmpty) {
        return _predictionError('Could not fetch standings');
      }

      // 2. Fetch ratings (prefer ratingChanges for accurate old ratings)
      Map<String, int> ratingByHandle =
          await _fetchOldRatingsIfAvailable(contestId);

      final handles = <String>[];
      for (final row in rows) {
        final h = (row['party']?['members']?[0]?['handle'] ?? '') as String;
        if (h.isNotEmpty) handles.add(h);
      }
      if (ratingByHandle.isEmpty) {
        ratingByHandle = await _fetchRatingsForHandles(handles);
      }

      // 3. Build participant data
      final previousRatings = <String, int>{};
      final standingsRows = <StandingsRow>[];

      for (final row in rows) {
        final h = (row['party']?['members']?[0]?['handle'] ?? '') as String;
        if (h.isEmpty) continue;

        int r = ratingByHandle[h] ?? CodeforcesRatingCalculator.initialRating;
        if (r <= 0) r = CodeforcesRatingCalculator.initialRating;

        final rk = (row['rank'] as num?)?.toInt() ?? 0;
        if (rk <= 0) continue;

        final pts = (row['points'] as num?)?.toDouble() ?? 0.0;
        final party = Party(members: h);

        previousRatings[party.members!] = r;
        standingsRows.add(StandingsRow(party, rk, pts));
      }

      if (standingsRows.isEmpty) {
        return _predictionError('No rated participants found');
      }

      // 4. Add user at their stated rank
      final er = (currentRating <= 0)
          ? CodeforcesRatingCalculator.initialRating
          : currentRating;
      final userParty = Party(members: '_CURRENT_USER_');
      previousRatings[userParty.members!] = er;

      // Determine points for the specified rank to preserve ordering
      double userPoints = 0.0;
      for (var row in standingsRows) {
        if (row.rank == rank) {
          userPoints = row.points;
          break;
        }
      }
      if (userPoints == 0.0 && standingsRows.isNotEmpty) {
        var closestRow = standingsRows.reduce(
            (a, b) => (a.rank - rank).abs() < (b.rank - rank).abs() ? a : b);
        userPoints = closestRow.points;
      }

      standingsRows.add(StandingsRow(userParty, rank, userPoints));

      Map<String, dynamic> logic() {
        // 5. Compute all deltas
        final calc = CodeforcesRatingCalculator();

        // Use loop-unrolled exact calculation inside isolation / async
        final ratingChanges =
            calc.calculateRatingChangesSync(previousRatings, standingsRows);

        // 6. Extract result
        int userDelta = ratingChanges['_CURRENT_USER_'] ?? 0;

        return {
          'delta': userDelta,
          'performance': er + userDelta, // Approximated
          'newRating': currentRating + userDelta,
        };
      }

      if (kIsWeb) {
        return logic();
      } else {
        return await Isolate.run(logic);
      }
    } catch (e) {
      print('predictRatingChangeFromContest error: $e');
      return _predictionError(e.toString());
    }
  }

  static Map<String, dynamic> _predictionError(String msg) => {
        'delta': 0,
        'performance': 0,
        'newRating': 0,
        'error': msg,
      };

  static Future<List<dynamic>> _fetchContestRows(int contestId) async {
    try {
      final res = await http.get(Uri.parse(
          'https://codeforces.com/api/contest.standings?contestId=$contestId&from=1&count=100000&showUnofficial=false'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          return (data['result']['rows'] as List<dynamic>);
        }
      }
    } catch (e) {
      print('fetchContestRows error: $e');
    }
    return [];
  }

  static Future<Map<String, int>> _fetchOldRatingsIfAvailable(
      int contestId) async {
    try {
      final res = await http.get(Uri.parse(
          'https://codeforces.com/api/contest.ratingChanges?contestId=$contestId'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final changes = (data['result'] as List).cast<Map<String, dynamic>>();
          final map = <String, int>{};
          for (final c in changes) {
            final handle = c['handle'] as String;
            final oldRating = (c['oldRating'] as num).toInt();
            map[handle] = oldRating == 0 ? 1400 : oldRating;
          }
          return map;
        }
      }
    } catch (e) {
      print('fetchOldRatings error: $e');
    }
    return {};
  }

  static Future<Map<String, int>> _fetchRatingsForHandles(
      List<String> handles) async {
    final map = <String, int>{};
    const batchSize = 300;
    for (int i = 0; i < handles.length; i += batchSize) {
      final batch = handles.sublist(
          i, i + batchSize > handles.length ? handles.length : i + batchSize);
      try {
        final res = await http.get(Uri.parse(
            'https://codeforces.com/api/user.info?handles=${batch.join(';')}'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'OK') {
            for (final u in (data['result'] as List)) {
              final h = u['handle'] as String;
              final r = (u['rating'] ?? 1400) as int;
              map[h] = r;
            }
          }
        }
      } catch (e) {
        print('batch ratings error: $e');
      }
    }
    return map;
  }

  // ===========================================================================
  // 🚀 OPTIMIZED PROBLEM SET FETCHING (Cache + New Contest Logic)
  // ===========================================================================
  static Future<Map<String, dynamic>> fetchProblemSet() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_problem_set');
    final lastFetchTimestamp = prefs.getInt('last_problem_fetch_time') ?? 0;
    final lastSavedContestId = prefs.getInt('last_saved_contest_id') ?? 0;

    final now = DateTime.now();
    final lastFetchDate =
        DateTime.fromMillisecondsSinceEpoch(lastFetchTimestamp);

    bool isDifferentDay = now.year != lastFetchDate.year ||
        now.month != lastFetchDate.month ||
        now.day != lastFetchDate.day;

    int latestContestId = lastSavedContestId;
    try {
      final contestRes = await http
          .get(Uri.parse("https://codeforces.com/api/contest.list?gym=false"))
          .timeout(const Duration(seconds: 5));

      if (contestRes.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(contestRes.body);
        final List contests = data['result'];
        final finished = contests.where((c) => c['phase'] == 'FINISHED');
        if (finished.isNotEmpty) latestContestId = finished.first['id'];
      }
    } catch (e) {
      print("Contest check failed: $e");
    }

    bool needsRefresh = isDifferentDay ||
        (latestContestId > lastSavedContestId) ||
        cachedData == null;

    if (!needsRefresh && cachedData != null) {
      // FIX: Explicitly cast the decoded JSON
      return Map<String, dynamic>.from(jsonDecode(cachedData));
    }

    try {
      print("🌍 Downloading & Filtering (Last 5 Years)...");
      final response = await http
          .get(Uri.parse("https://codeforces.com/api/problemset.problems"))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> fullData = jsonDecode(response.body);
        final List problems = fullData['result']['problems'];
        final List stats = fullData['result']['problemStatistics'];

        // Filter for Contest ID > 1300 (roughly last 5 years)
        final filteredProbs =
            problems.where((p) => (p['contestId'] ?? 0) > 1300).toList();

        final filteredResult = {
          "status": "OK",
          "result": {
            "problems": filteredProbs,
            "problemStatistics": stats
                .where((s) => filteredProbs.any((p) =>
                    p['contestId'] == s['contestId'] &&
                    p['index'] == s['index']))
                .toList(),
          }
        };

        await prefs.setString('cached_problem_set', jsonEncode(filteredResult));
        await prefs.setInt(
            'last_problem_fetch_time', now.millisecondsSinceEpoch);
        await prefs.setInt('last_saved_contest_id', latestContestId);

        return filteredResult;
      }
    } catch (e) {
      print("Sync failed: $e");
    }

    return cachedData != null
        ? Map<String, dynamic>.from(jsonDecode(cachedData))
        : {};
  }

  static GenerativeModel _getModel(String systemInstructions) {
    return GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: _geminiApiKey,
      systemInstruction: Content.system(systemInstructions),
    );
  }

  // ===========================================================================
  // 🤖 FIXED AI RECOMMENDATIONS
  // ===========================================================================
  static Future<List<Map<String, dynamic>>> getAiRecommendations(
      List<dynamic> candidates,
      List<String> weakTags,
      int currentRating) async {
    try {
      final model =
          _getModel("You are a Codeforces coach. You only output valid JSON.");

      String candidateString = candidates.asMap().entries.map((e) {
        return "[${e.key}] ${e.value['name']} (Rating: ${e.value['rating']}, Tags: ${e.value['tags']})";
      }).join("\n");

      final prompt = """
        TASK: Select 5 problems from the list.
        CRITICAL RULES:
        1. Rating MUST be > $currentRating.
        2. Focus on: ${weakTags.join(', ')}.
        3. Return ONLY a JSON list of objects: [{"index": int, "reason": "string"}]
        
        LIST:
        $candidateString
      """;

      final response = await model.generateContent([Content.text(prompt)]);

      // Improved JSON Parsing
      String? text =
          response.text?.replaceAll(RegExp(r'```json|```'), '').trim();
      if (text == null || text.isEmpty) return [];

      List<dynamic> parsed = jsonDecode(text);
      return parsed.map((item) {
        int idx = item['index'];
        return {
          ...Map<String, dynamic>.from(candidates[idx]),
          'aiReason': item['reason'],
        };
      }).toList();
    } catch (e) {
      print("AI Recommendation Error: $e");
      return [];
    }
  }

  // ===========================================================================
  // 💡 FIXED AI HINT (Chat History)
  // ===========================================================================
  // 1. Fixed Scraper Call (Added contestId and index to the URL)
// 1. Fixed Scraper Call
  static Future<String?> getScrapedTutorial(int contestId, String index) async {
    try {
      print("Fetching tutorial for $contestId$index..."); // Debug log
      final res = await http
          .get(Uri.parse(
              "$baseUrl/get_tutorial?contestId=$contestId&index=$index"))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // SAFETY CHECK: Ensure the key exists and is not empty
        if (data.containsKey('tutorial') &&
            data['tutorial'] != null &&
            data['tutorial'].toString().isNotEmpty) {
          print("Tutorial found!"); // Debug log
          return data['tutorial'];
        } else {
          print(
              "Backend returned 200 but no tutorial content: ${data['error']}");
        }
      } else {
        print("Backend error: ${res.statusCode}");
      }
    } catch (e) {
      print("Backend Tutorial Scraper Error: $e");
    }
    return null;
  }

// 2. Fixed AI Hint (Now accepts tutorial context)
  static Future<String> getRealAiHint({
    required String problemName,
    required int contestId, // Added
    required String index, // Added
    required List<dynamic> tags,
    required int rating,
    required String userQuery,
    required List<String> previousChatHistory,
    String? tutorialContext, // Added optional tutorial data
  }) async {
    try {
      // Construct the System Prompt with Tutorial Knowledge
// Inside ApiService.getRealAiHint
      String socraticPrompt =
          "You are a Socratic Competitive Programming Coach for '$problemName' ($rating). ";

      if (tutorialContext != null && tutorialContext.isNotEmpty) {
        socraticPrompt += """
    \n\nOFFICIAL TUTORIAL CONTEXT PROVIDED:
    $tutorialContext
    
    INSTRUCTIONS:
    1. Use this tutorial to guide the student.
    2. Start your very first hint with the tag '[Source: Editorial]'.
    3. If you are ever unsure and falling back to general knowledge, use '[Source: Internal Knowledge]'.
    4. Use bold for key terms. For mathematical variables or formulas, wrap them in backticks like `x = a + b` to make them stand out as code. If you must use complex formulas, use standard text representation (e.g., 'sum of n terms' instead of complex sigma notation) to ensure readability
  """;
      } else {
        socraticPrompt +=
            "\n\nNo tutorial found. Use your internal knowledge and tag your response with '[Source: Internal Knowledge]'.";
      }
      final model = _getModel(socraticPrompt);

      // Convert history strings to proper Content objects
      final List<Content> history = previousChatHistory.map((msg) {
        if (msg.startsWith('Student:')) {
          return Content.text(msg.replaceFirst('Student:', '').trim());
        } else {
          // Fallback: treat coach messages as plain text in history
          return Content.text(msg.replaceFirst('Coach:', '').trim());
        }
      }).toList();

      final chat = model.startChat(history: history);
      final response = await chat.sendMessage(Content.text(userQuery));

      return response.text ??
          "Try breaking the problem into smaller sub-tasks.";
    } catch (e) {
      print("AI Hint Error: $e");
      return "Connection error. Please check your API key or internet.";
    }
  }
  // ===========================================================================
  // 🔐 AUTH & USER DATA METHODS
  // ===========================================================================

  static Future<Map<String, dynamic>?> login(
      String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": email,
          "password": password,
        }),
      );

      if (res.statusCode != 200) return null;
      return json.decode(res.body);
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> saveHandle(String email, String handle) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save_handle"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "handle": handle}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 📊 CODEFORCES API METHODS
  // ===========================================================================

  static Future<Map<String, dynamic>?> fetchCodeforcesUser(
      String handle) async {
    try {
      final url = "https://codeforces.com/api/user.info?handles=$handle";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return data['result'][0]; // returns the first user
        }
      }
    } catch (e) {
      print("User Fetch Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchSubmissions(String handle) async {
    try {
      final res = await http.get(
        Uri.parse("https://codeforces.com/api/user.status?handle=$handle"),
      );
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body);
      if (data['status'] != 'OK') return [];

      return data['result'];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchLastContest(String handle) async {
    try {
      final url = "https://codeforces.com/api/user.rating?handle=$handle";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['result'] as List;
        if (results.isNotEmpty) {
          return results.last;
        }
      }
    } catch (e) {
      print("Fetch Last Contest Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchRatingHistory(String handle) async {
    try {
      final url = "https://codeforces.com/api/user.rating?handle=$handle";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'] ?? [];
      }
    } catch (e) {
      print("Fetch Rating History Error: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchContestList() async {
    try {
      final url = "https://codeforces.com/api/contest.list?gym=false";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'] ?? [];
      }
    } catch (e) {
      print("Fetch Contest List Error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchProblemMetadata(
      int contestId, String index) async {
    try {
      final response = await http.get(Uri.parse(
          'https://codeforces.com/api/contest.standings?contestId=$contestId&from=1&count=1'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List problems = data['result']['problems'];
          // Find the problem that matches the index (e.g., "A")
          final problem = problems.firstWhere(
            (p) => p['index'].toString().toUpperCase() == index.toUpperCase(),
            orElse: () => null,
          );
          return problem;
        }
      }
    } catch (e) {
      print("Metadata Fetch Error: $e");
    }
    return null;
  }

  static Map<String, dynamic> analyzeLifetimePerformance(
      List<dynamic> allSubs) {
    Map<String, int> tagSuccess = {};
    Map<String, int> tagFailure = {};
    Map<int, int> difficultyAC = {};
    int totalAC = 0;
    final solvedIds = <String>{};

    for (var sub in allSubs) {
      final problem = sub['problem'];
      final List tags = problem['tags'] ?? [];
      final int? rating = problem['rating'];
      final bool isAC = sub['verdict'] == 'OK';
      final pId = "${problem['contestId']}-${problem['index']}";

      if (isAC) {
        if (!solvedIds.contains(pId)) {
          solvedIds.add(pId);
          if (rating != null) {
            difficultyAC[rating] = (difficultyAC[rating] ?? 0) + 1;
          }
        }
      }

      for (var tag in tags) {
        if (isAC) {
          tagSuccess[tag] = (tagSuccess[tag] ?? 0) + 1;
        } else {
          tagFailure[tag] = (tagFailure[tag] ?? 0) + 1;
        }
      }
    }
    totalAC = solvedIds.length;

    List<String> weakTags = tagFailure.keys.toList()
      ..sort((a, b) => (tagFailure[b]! - (tagSuccess[b] ?? 0))
          .compareTo(tagFailure[a]! - (tagSuccess[a] ?? 0)));

    return {
      'total_submissions': allSubs.length,
      'total_solved': totalAC,
      'accuracy': allSubs.isEmpty
          ? '0.0'
          : (totalAC / allSubs.length * 100).toStringAsFixed(1),
      'hardest_solved': difficultyAC.keys.isNotEmpty
          ? difficultyAC.keys.reduce((a, b) => a > b ? a : b)
          : 0,
      'top_weak_tags': weakTags.take(5).toList(),
    };
  }

  static Future<List<Map<String, dynamic>>> generateComprehensiveAnalysis({
    required String handle,
    required int contestId,
  }) async {
    final submissions = await fetchSubmissions(handle);
    final history = await fetchRatingHistory(handle);

    // --- 1. Contest Specific Rating Changes ---
    Map<String, dynamic>? ratingData;
    try {
      ratingData = history.firstWhere((h) => h['contestId'] == contestId,
          orElse: () => null);
    } catch (e) {
      print("Rating history error: $e");
    }

    // --- 2. Contest Submissions ---
    final contestSubs =
        submissions.where((s) => s['contestId'] == contestId).toList();

    // --- 3. Problem Analysis ---
    Map<String, Map<String, dynamic>> problems = {};
    for (var s in contestSubs) {
      String idx = s['problem']['index'] ?? "?";
      String name = s['problem']['name'] ?? "Unknown";

      if (!problems.containsKey(idx)) {
        problems[idx] = {
          "index": idx,
          "name": name,
          "solved": false,
          "tryCount": 0,
          "lastVerdict": null,
        };
      }

      problems[idx]!["tryCount"] = (problems[idx]!["tryCount"] as int) + 1;

      if (s['verdict'] == 'OK') {
        problems[idx]!["solved"] = true;
        problems[idx]!["lastVerdict"] = "OK";
      } else {
        // Only update lastVerdict if not already solved (or keep latest attempt)
        if (problems[idx]!["solved"] != true) {
          problems[idx]!["lastVerdict"] = s['verdict'];
        }
      }
    }

    // Convert to list & Sort
    List<Map<String, dynamic>> problemList = problems.values.toList();
    problemList
        .sort((a, b) => (a['index'] as String).compareTo(b['index'] as String));

    // --- 4. Verdict Distribution ---
    Map<String, int> contestMistakes = {};
    for (var s in contestSubs.where((s) => s['verdict'] != 'OK')) {
      contestMistakes[s['verdict']] = (contestMistakes[s['verdict']] ?? 0) + 1;
    }

    // --- 5. Summary Info ---
    Map<String, String> summaryData = {};
    if (ratingData != null) {
      summaryData["Rank"] = "${ratingData['rank']}";
      summaryData["Old Rating"] = "${ratingData['oldRating']}";
      summaryData["New Rating"] = "${ratingData['newRating']}";
      int delta =
          (ratingData['newRating'] as int) - (ratingData['oldRating'] as int);
      summaryData["Delta"] = delta >= 0 ? "+$delta" : "$delta";
    } else {
      summaryData["Rank"] = "N/A";
      summaryData["Old Rating"] = "-";
      summaryData["New Rating"] = "-";
      summaryData["Delta"] = "-";
    }
    summaryData["Solved"] =
        "${problemList.where((p) => p['solved'] == true).length}";
    summaryData["Total Submissions"] = "${contestSubs.length}";

    // --- Result ---
    return [
      {
        "title": "Performance Summary",
        "type": "stat_grid",
        "data": summaryData,
      },
      {
        "title": "Problem Analysis",
        "type": "detailed_problem_list",
        "data": problemList,
      },
      {
        "title": "Verdict Distribution",
        "type": "pie_chart",
        "data": contestMistakes,
      },
    ];
  }

// ===========================================================================
// 📊 CONTEST ANALYSIS (CLIENT-SIDE RAG)
// ===========================================================================
  static Future<Map<String, dynamic>> generateContestAnalysis(
    String handle,
    int contestId,
  ) async {
    final submissions = await fetchSubmissions(handle);
    final ratingHistory = await fetchRatingHistory(handle);

    // Filter submissions of THIS contest only
    final contestSubs =
        submissions.where((s) => s['contestId'] == contestId).toList();

    // ---- Solved First ----
    contestSubs.sort(
        (a, b) => a['creationTimeSeconds'].compareTo(b['creationTimeSeconds']));

    Map<String, dynamic>? solvedFirst;
    for (var s in contestSubs) {
      if (s['verdict'] == 'OK') {
        solvedFirst = {
          "problem": s['problem']['index'],
          "name": s['problem']['name'],
          "minutes": (s['relativeTimeSeconds'] / 60).round(),
        };
        break;
      }
    }

    // ---- Failed difficulty buckets ----
    final Map<int, int> failedDifficulty = {};
    final Map<String, int> mistakes = {};

    for (var s in contestSubs) {
      if (s['verdict'] != 'OK') {
        final rating = s['problem']['rating'];
        if (rating != null) {
          failedDifficulty[rating] = (failedDifficulty[rating] ?? 0) + 1;
        }

        final verdict = s['verdict'];
        mistakes[verdict] = (mistakes[verdict] ?? 0) + 1;
      }
    }

    // ---- Contest rating change ----
    final contestRating = ratingHistory.firstWhere(
      (c) => c['contestId'] == contestId,
      orElse: () => null,
    );

    Map<String, dynamic>? contestInfo;
    if (contestRating != null) {
      contestInfo = {
        "rank": contestRating['rank'],
        "rating_change":
            contestRating['newRating'] - contestRating['oldRating'],
        "new_rating": contestRating['newRating'],
      };
    }

    return {
      "contest_id": contestId,
      "solved_first": solvedFirst,
      "failed_difficulties": failedDifficulty,
      "mistakes": mistakes,
      "contest_info": contestInfo,
    };
  }

// ===========================================================================
// 🤖 AI CONTEST STRATEGY (GEMINI)
// ===========================================================================
  static Future<String> generateAiContestStrategy(
      String handle, int contestID) async {
    final analysis = await generateContestAnalysis(handle, contestID);

    final model = _getModel("""
You are a world-class Competitive Programming coach.
You analyze contest performance and give actionable advice.
Be concise, sharp, and practical.
""");

    final prompt = """
USER ANALYSIS:
Solved first problems:
${analysis['solved_first']}

Failed difficulty counts:
${analysis['failed_difficulties']}

Common mistakes:
${analysis['mistakes']}

Last contest:
${analysis['last_contest']}

TASK:
Give a short strategy with:
- What problems to start with
- What to avoid early
- What to practice before next contest
Use bullet points.
""";

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text ?? "No strategy generated.";
  }

// Helper to aggregate "All-Time" statistics from the full submission list
  Map<String, dynamic> aggregateLifetimeStats(
      List<Map<String, dynamic>> allSubs) {
    Map<String, int> tagFailures = {};
    int totalAC = 0;

    for (var sub in allSubs) {
      if (sub['verdict'] == 'OK') {
        totalAC++;
      } else {
        // Track which topics (tags) cause the most failures
        List tags = sub['problem']['tags'] ?? [];
        for (var tag in tags) {
          tagFailures[tag] = (tagFailures[tag] ?? 0) + 1;
        }
      }
    }

    // Sort tags by most failures
    var sortedTags = tagFailures.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total_solved': totalAC,
      'problematic_tags': sortedTags.take(5).map((e) => e.key).toList(),
      'accuracy_rate': (totalAC / allSubs.length * 100).toStringAsFixed(1),
    };
  }

// ===========================================================================
// 🧠 AI MENTOR CHAT (CONTEXT-AWARE)
// ===========================================================================
  static Future<String> chatWithAiMentor({
    required String handle,
    required String userMessage,
    List<String> previousChats = const [],
  }) async {
    // Fetch real-time data
    final recentContests = await CodeforcesService.getRecentContests(handle);
    final recentSubs = await CodeforcesService.getRecentSubmissions(handle);
    final allSubmissions = await CPStatsAggregator.fetchAllSubmissions(handle);
    final lifetimeStats =
        CPStatsAggregator.analyzeLifetimePerformance(allSubmissions);
    // Format Contest History for Gemini
    final contestSummary = recentContests
        .map((c) =>
            "- ${c['contestName']}: Rank ${c['rank']}, Rating Change: ${c['newRating'] - c['oldRating']}")
        .join("\n");

    // Format Submission History (last 20)
    final subSummary = recentSubs
        .map((s) =>
            "- Problem ${s['problem']['name']} (${s['problem']['rating'] ?? 'Unrated'}): ${s['verdict']}")
        .join("\n");

    final mentorContext = """
STUDENT PROFILE FOR $handle:

RECENT CONTEST PERFORMANCE (Last 4):
$contestSummary

RECENT SUBMISSION ACTIVITY (Last 20):
$subSummary

STUDENT LIFETIME DATABASE:
- Total Solved: ${lifetimeStats['total_solved']}
- Lifetime Accuracy: ${lifetimeStats['accuracy']}%
- Peak Problem Difficulty Solved: ${lifetimeStats['hardest_solved']}
- Historical Weak Points (Tags): ${lifetimeStats['top_weak_tags'].join(', ')}
CRITICAL RULES (DO NOT BREAK):
1. Greetings ("hi", "hello"):
   - ONE friendly sentence
   - ONE clarifying question
   - STOP

2. Normal questions:
   - 3–6 concise bullet points
   - No paragraphs

3. Long explanation ONLY if user explicitly asks

INSTRUCTIONS:
1. Analyze if the student is currently 'peaking' or 'slumping' based on the rating changes.
2. Look for patterns in the last 20 submissions (e.g., frequent Wrong Answers on high-rated problems).
3. Identify if the student is struggling with a specific difficulty tier right now.
4. Provide tailored advice based on only recent trends.
5. If they ask for a problem recommendation, suggest a problem having slightly more rating in one of their 'Weak Points' tags.
""";

    // ... rest of your model logic
    final model = _getModel(mentorContext);
    final List<Content> history = [
      Content.text(mentorContext),
      ...previousChats.map((c) => Content.text(c)),
    ];

    final chat = model.startChat(history: history);
    final response = await chat.sendMessage(Content.text(userMessage));

    return response.text ?? "Let's improve step by step.";
  }

  static Future<void> resyncAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear only cached CF-related data
    await prefs.remove('cached_problem_set');
    await prefs.remove('last_problem_fetch_time');
    await prefs.remove('last_saved_contest_id');

    // You can add more keys later if needed
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();

    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.contains('cached') ||
          k.contains('problem') ||
          k.contains('contest')) {
        await prefs.remove(k);
      }
    }
  }

  static Future<void> changeHandle(String email, String newHandle) async {
    // Save new handle to backend
    await saveHandle(email, newHandle);

    // Clear cached data related to old handle
    await resyncAllData();
  }
}

// =============================================================================
// FFT Convolution — ported from Carrot's conv.js (Cooley-Tukey, O(n log n))
// =============================================================================

class _FFTConv {
  final int n;
  late final List<double> _wr;
  late final List<double> _wi;
  late final List<int> _rev;

  _FFTConv(int minSize) : n = _nextPow2(minSize) {
    final n2 = n >> 1;
    _wr = List<double>.filled(n2, 0);
    _wi = List<double>.filled(n2, 0);
    final ang = 2 * math.pi / n;
    for (int i = 0; i < n2; i++) {
      _wr[i] = math.cos(i * ang);
      _wi[i] = math.sin(i * ang);
    }
    int k = 0;
    int tmp = 1;
    while (tmp < n) {
      tmp <<= 1;
      k++;
    }
    _rev = List<int>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      _rev[i] = (_rev[i >> 1] >> 1) | ((i & 1) << (k - 1));
    }
  }

  static int _nextPow2(int v) {
    int k = 1;
    while (k < v) k <<= 1;
    return k;
  }

  void _reverse(List<double> a) {
    for (int i = 1; i < n; i++) {
      if (i < _rev[i]) {
        final tmp = a[i];
        a[i] = a[_rev[i]];
        a[_rev[i]] = tmp;
      }
    }
  }

  void _transform(List<double> ar, List<double> ai) {
    _reverse(ar);
    _reverse(ai);
    for (int len = 2; len <= n; len <<= 1) {
      final half = len >> 1;
      final diff = n ~/ len;
      for (int i = 0; i < n; i += len) {
        int pw = 0;
        for (int j = i; j < i + half; j++) {
          final k = j + half;
          final vr = ar[k] * _wr[pw] - ai[k] * _wi[pw];
          final vi = ar[k] * _wi[pw] + ai[k] * _wr[pw];
          ar[k] = ar[j] - vr;
          ai[k] = ai[j] - vi;
          ar[j] += vr;
          ai[j] += vi;
          pw += diff;
        }
      }
    }
  }

  List<double> convolve(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return [];
    final resLen = a.length + b.length - 1;
    final cr = List<double>.filled(n, 0);
    final ci = List<double>.filled(n, 0);
    for (int i = 0; i < a.length; i++) cr[i] = a[i];
    for (int i = 0; i < b.length; i++) ci[i] = b[i];
    _transform(cr, ci);
    cr[0] = 4 * cr[0] * ci[0];
    ci[0] = 0;
    for (int i = 1, j = n - 1; i <= j; i++, j--) {
      final ar = cr[i] + cr[j];
      final ai = ci[i] - ci[j];
      final br = ci[j] + ci[i];
      final bi = cr[j] - cr[i];
      cr[i] = ar * br - ai * bi;
      ci[i] = ar * bi + ai * br;
      cr[j] = cr[i];
      ci[j] = -ci[i];
    }
    _transform(cr, ci);
    final res = List<double>.filled(resLen, 0);
    res[0] = cr[0] / (4 * n);
    for (int i = 1, j = n - 1; i <= j; i++, j--) {
      if (i < resLen) res[i] = cr[j] / (4 * n);
      if (j < resLen) res[j] = cr[i] / (4 * n);
    }
    return res;
  }
}
