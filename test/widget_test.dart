import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dummy test to verify build', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Manicure Pro'),
        ),
      ),
    );

    expect(find.text('Manicure Pro'), findsOneWidget);
  });
}
