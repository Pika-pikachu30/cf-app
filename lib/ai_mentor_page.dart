import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'api_service.dart';

class AiMentorPage extends StatefulWidget {
  final String handle;
  const AiMentorPage({super.key, required this.handle});

  @override
  State<AiMentorPage> createState() => _AiMentorPageState();
}

class _AiMentorPageState extends State<AiMentorPage> {
  // Chat state
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> messages = [];
  bool loading = false;

  // Predictor state
  final TextEditingController _userRatingController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _contestIdController = TextEditingController();
  String _selectedDivision = "Div. 2";
  final List<String> _divisions = [
    "Div. 1",
    "Div. 2",
    "Div. 3",
    "Div. 4",
    "Edu / Mixed"
  ];
  bool _useContestStandings = false;
  bool _predicting = false;
  bool _predictorExpanded = true;

  // Prediction results
  int? _deltaResult;
  int? _perfResult;
  int? _newRatingResult;
  String? _predictionError;

  int? userRating;

  @override
  void initState() {
    super.initState();
    _loadUserRating();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _userRatingController.dispose();
    _rankController.dispose();
    _contestIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRating() async {
    userRating = await ApiService.getUserRating(widget.handle);
    if (userRating != null && mounted) {
      _userRatingController.text = userRating.toString();
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Rating color / rank helpers (matches CF rank thresholds)
  // ---------------------------------------------------------------------------

  Color _ratingColor(int rating) {
    if (rating >= 3000) return const Color(0xFFFF0000);
    if (rating >= 2400) return const Color(0xFFFF0000);
    if (rating >= 2100) return const Color(0xFFFF8C00);
    if (rating >= 1900) return const Color(0xFFAA00AA);
    if (rating >= 1600) return const Color(0xFF0000FF);
    if (rating >= 1400) return const Color(0xFF03A89E);
    if (rating >= 1200) return const Color(0xFF008000);
    return const Color(0xFF808080);
  }

  String _rankName(int rating) {
    if (rating >= 3000) return "LGM";
    if (rating >= 2600) return "IGM";
    if (rating >= 2400) return "GM";
    if (rating >= 2300) return "IM";
    if (rating >= 2100) return "Master";
    if (rating >= 1900) return "CM";
    if (rating >= 1600) return "Expert";
    if (rating >= 1400) return "Specialist";
    if (rating >= 1200) return "Pupil";
    return "Newbie";
  }

  // ---------------------------------------------------------------------------
  // Prediction logic
  // ---------------------------------------------------------------------------

  Future<void> _predict() async {
    final rating = int.tryParse(_userRatingController.text);
    final rank = int.tryParse(_rankController.text);
    final contestId = int.tryParse(_contestIdController.text);

    if (rating == null || rank == null || rank <= 0) {
      setState(() {
        _predictionError = "Enter valid rating and rank";
        _deltaResult = null;
      });
      return;
    }

    setState(() {
      _predicting = true;
      _predictionError = null;
      _deltaResult = null;
    });

    try {
      Map<String, dynamic> result;
      if (_useContestStandings && contestId != null) {
        result = await ApiService.predictRatingChangeFromContest(
          contestId: contestId,
          currentRating: rating,
          rank: rank,
        );
      } else {
        result = await ApiService.predictRatingChange(
          currentRating: rating,
          rank: rank,
          division: _selectedDivision,
        );
      }

      if (!mounted) return;
      setState(() {
        _deltaResult = result['delta'] as int;
        _perfResult = result['performance'] as int;
        _newRatingResult = result['newRating'] as int;
        _predictionError = result['error'] as String?;
        _predicting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _predictionError = "Prediction failed: $e";
        _predicting = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Chat logic
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      loading = true;
      _controller.clear();
    });

    _scrollToBottom();

    final reply = await ApiService.chatWithAiMentor(
      handle: widget.handle,
      userMessage: text,
      previousChats: messages
          .map((m) =>
              "${m['role'] == 'user' ? 'Student' : 'Coach'}: ${m['text']}")
          .toList(),
    );

    if (!mounted) return;

    setState(() {
      messages.add({"role": "ai", "text": reply});
      loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // UI Helpers
  // ---------------------------------------------------------------------------

  Widget _buildInputField(TextEditingController ctrl, String label,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: enabled
                ? const Color(0xFF0F1023)
                : const Color(0xFF0F1023).withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: const Text("AI Mentor"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ===================================================================
          // PREDICTOR CARD (collapsible)
          // ===================================================================
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B1D3A), Color(0xFF15172E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF7B61FF).withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  // Header row with toggle
                  InkWell(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    onTap: () => setState(
                        () => _predictorExpanded = !_predictorExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_graph,
                              color: Color(0xFF7B61FF), size: 20),
                          const SizedBox(width: 8),
                          const Text("Rating Predictor",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const Spacer(),
                          // Contest toggle chip
                          if (_predictorExpanded) ...[
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _useContestStandings = !_useContestStandings),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _useContestStandings
                                      ? const Color(0xFF7B61FF)
                                          .withOpacity(0.25)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _useContestStandings
                                        ? const Color(0xFF7B61FF)
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  _useContestStandings
                                      ? "Contest Mode"
                                      : "Quick Mode",
                                  style: TextStyle(
                                    color: _useContestStandings
                                        ? const Color(0xFF7B61FF)
                                        : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            _predictorExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expandable body
                  if (_predictorExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 12),

                          // Row 1: Division / Contest ID
                          Row(
                            children: [
                              // Division dropdown
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Division",
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 44,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: _useContestStandings
                                            ? const Color(0xFF0F1023)
                                                .withOpacity(0.4)
                                            : const Color(0xFF0F1023),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedDivision,
                                          dropdownColor:
                                              const Color(0xFF1B1D3A),
                                          isExpanded: true,
                                          style: TextStyle(
                                            color: _useContestStandings
                                                ? Colors.white38
                                                : Colors.white,
                                            fontSize: 14,
                                          ),
                                          items: _divisions
                                              .map((d) => DropdownMenuItem(
                                                  value: d, child: Text(d)))
                                              .toList(),
                                          onChanged: _useContestStandings
                                              ? null
                                              : (val) {
                                                  if (val != null) {
                                                    setState(() =>
                                                        _selectedDivision =
                                                            val);
                                                  }
                                                },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Contest ID
                              Expanded(
                                child: _buildInputField(
                                  _contestIdController,
                                  "Contest ID",
                                  enabled: _useContestStandings,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Row 2: Rank / Rating / Button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildInputField(
                                    _rankController, "Your Rank"),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildInputField(
                                    _userRatingController, "Current Rating"),
                              ),
                              const SizedBox(width: 10),
                              // Predict button
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B61FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  onPressed: _predicting ? null : _predict,
                                  child: _predicting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.bolt,
                                          color: Colors.white, size: 22),
                                ),
                              ),
                            ],
                          ),

                          // Results
                          if (_predictionError != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_predictionError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12)),
                            ),
                          ],

                          if (_deltaResult != null) ...[
                            const SizedBox(height: 12),
                            _buildResultCard(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ===================================================================
          // CHAT MESSAGES
          // ===================================================================
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology_outlined,
                            size: 48, color: Colors.white.withOpacity(0.15)),
                        const SizedBox(height: 8),
                        Text("Ask your AI mentor anything...",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF7B61FF)
                                : const Color(0xFF1B1D3A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: MarkdownBody(
                            data: msg['text']!,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              strong: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : const Color(0xFF7B61FF),
                                  fontWeight: FontWeight.bold),
                              code: const TextStyle(
                                  color: Colors.white,
                                  backgroundColor: Colors.white10,
                                  fontFamily: 'monospace'),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Loading indicator
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7B61FF)),
              ),
            ),

          // ===================================================================
          // CHAT INPUT
          // ===================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1023),
              border:
                  Border(top: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => loading ? null : _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Ask your mentor...",
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: const Color(0xFF1B1D3A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: loading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rich result card
  // ---------------------------------------------------------------------------

  Widget _buildResultCard() {
    final delta = _deltaResult! + 8;
    final perf = _perfResult ?? 0;
    final oldRating = int.tryParse(_userRatingController.text) ?? 0;
    final newRating = oldRating + delta;
    final isPositive = delta >= 0;

    final mode = (_useContestStandings && _contestIdController.text.isNotEmpty)
        ? "Contest ${_contestIdController.text}"
        : _selectedDivision;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [
                  const Color(0xFF0D2818),
                  const Color(0xFF0F1023),
                ]
              : [
                  const Color(0xFF2D0E0E),
                  const Color(0xFF0F1023),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPositive
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Delta (big number)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isPositive ? Colors.greenAccent : Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 4),
              Text(
                "${isPositive ? '+' : ''}$delta ± 10",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Rating transition
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$oldRating",
                style: TextStyle(
                    color: _ratingColor(oldRating),
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
              ),
              Text(
                "$newRating",
                style: TextStyle(
                    color: _ratingColor(newRating),
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _ratingColor(newRating).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _rankName(newRating),
                  style: TextStyle(
                      color: _ratingColor(newRating),
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Performance + mode
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Performance: ",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
              Text(
                "$perf",
                style: TextStyle(
                    color: _ratingColor(perf),
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              Text(
                " (${_rankName(perf)})",
                style: TextStyle(
                    color: _ratingColor(perf).withOpacity(0.7), fontSize: 11),
              ),
              const SizedBox(width: 10),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                mode,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
