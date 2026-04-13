import 'package:flutter/material.dart';
import '../api_service.dart';

class RatingPredictorWidget extends StatefulWidget {
  final String handle;

  const RatingPredictorWidget({super.key, required this.handle});

  @override
  State<RatingPredictorWidget> createState() => _RatingPredictorWidgetState();
}

class _RatingPredictorWidgetState extends State<RatingPredictorWidget> {
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

  int? _deltaResult;
  int? _perfResult;
  int? _newRatingResult;
  String? _predictionError;

  @override
  void initState() {
    super.initState();
    _loadUserRating();
  }

  @override
  void dispose() {
    _userRatingController.dispose();
    _rankController.dispose();
    _contestIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRating() async {
    int? userRating = await ApiService.getUserRating(widget.handle);
    if (userRating != null && mounted) {
      _userRatingController.text = userRating.toString();
    }
    if (mounted) setState(() {});
  }

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

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B1D3A), Color(0xFF15172E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.25)),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              onTap: () =>
                  setState(() => _predictorExpanded = !_predictorExpanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    if (_predictorExpanded) ...[
                      GestureDetector(
                        onTap: () => setState(
                            () => _useContestStandings = !_useContestStandings),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _useContestStandings
                                ? const Color(0xFF7B61FF).withOpacity(0.25)
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
            if (_predictorExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                DropdownButtonHideUnderline == null
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.start,
                            children: [
                              const Text("Division",
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Container(
                                height: 44,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _useContestStandings
                                      ? const Color(0xFF0F1023).withOpacity(0.4)
                                      : const Color(0xFF0F1023),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedDivision,
                                    dropdownColor: const Color(0xFF1B1D3A),
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
                                                  _selectedDivision = val);
                                            }
                                          },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            _userRatingController,
                            "Current Rating",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInputField(
                            _rankController,
                            "Expected Rank",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _predicting ? null : _predict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _predicting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text("Predict Delta",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    if (_predictionError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _predictionError!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_deltaResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildResultRow(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow() {
    final oldRating = int.tryParse(_userRatingController.text) ?? 0;
    final delta = _deltaResult!;
    final newRating = oldRating + delta;
    final isPositive = delta >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1023),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Predicted Change",
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${isPositive ? '+' : ''}$delta ± 10",
                    style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("New Rating (Approx)",
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ratingColor(newRating).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$newRating - ${_rankName(newRating)}",
                  style: TextStyle(
                    color: _ratingColor(newRating),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
