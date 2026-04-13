import 'package:flutter/material.dart';

class RatingChart extends StatelessWidget {
  final Map<int, int> data;
  const RatingChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList()..sort();

    // 1. Find the maximum value to normalize bar heights
    final maxSolved =
        data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

    const baseColor = Color(0xFF212436);
    const chartHeight = 180.0; // Fixed height for the chart area

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Problem Rating Distribution",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // Use a fixed height container to prevent overflow
        SizedBox(
          height: chartHeight + 40, // Extra space for labels
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: keys.map((k) {
              final v = data[k]!;

              // 2. Calculate proportional height (normalized)
              // This ensures the tallest bar is exactly 'chartHeight' pixels
              double normalizedHeight = (v / maxSolved) * chartHeight;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "$v",
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF7B61FF)),
                    ),
                    const SizedBox(height: 4),

                    // The Bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: normalizedHeight, // Safe, proportional height
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF7B61FF), Color(0xFFA78BFA)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$k",
                      style:
                          const TextStyle(fontSize: 9, color: Colors.white54),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
