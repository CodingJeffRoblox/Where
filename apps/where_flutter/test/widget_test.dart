// Replaces the default test that `flutter create` would generate (it refers
// to a MyApp class that does not exist here and would break the build checks).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:where_flutter/main.dart';
import 'package:where_flutter/src/boot_screen.dart';

void main() {
  testWidgets('shows a clear message when the core cannot load', (tester) async {
    await tester.pumpWidget(const WhereApp(startupError: 'where_ffi.dll not found'));
    expect(find.textContaining('Where could not start'), findsOneWidget);
    expect(find.textContaining('where_ffi.dll not found'), findsOneWidget);
  });

  testWidgets('loading screen shows the current startup step', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BootScreen(step: 'Starting the search engine…', progress: 0.4),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Where'), findsOneWidget);
    expect(find.text('Starting the search engine…'), findsOneWidget);
  });
}
