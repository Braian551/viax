// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:viax/main.dart';
import 'package:viax/src/providers/database_provider.dart';
import 'package:viax/src/theme/theme_provider.dart';

void main() {
  testWidgets('App smoke test builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => DatabaseProvider()),
        ],
        child: const MyApp(enableDatabaseInit: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Dispose tree to avoid pending timers from startup flows.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
