// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:codeforces_tool_app/api_service.dart';

void main() {
  test('Test Prediction', () async {
    try {
      final result = await ApiService.predictRatingChange(
        currentRating: 1350,
        rank: 3500,
        division: "Div. 2",
      );
      print("SUCCESS: \$result");
    } catch (e, st) {
      print("ERROR: \$e\\n\$st");
      rethrow;
    }
  });
}
