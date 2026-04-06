import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verificarteweb/app.dart';

void main() {
  testWidgets('Initial screen is the Feed screen and handles load error', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VerificarteApp());

    // Wait for the feed to try loading and fail (due to the test environment).
    // The pumpAndSettle will wait for all animations and async tasks to complete.
    await tester.pumpAndSettle();

    // Verify the AppBar title is present, paying attention to the exact case.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('VerificArte'),
      ),
      findsOneWidget,
    );

    // Verify that the error message is shown since network calls fail in tests.
    expect(find.text('No se pudo cargar la feed.'), findsOneWidget);
  });
}
