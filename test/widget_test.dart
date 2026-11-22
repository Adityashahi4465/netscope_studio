import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/theme/app_theme.dart';

void main() {
  testWidgets(
    'compact cockpit validates edits, resets, and opens real settings',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(540, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(AppTheme.loadFonts);
      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pumpAndSettle();
      expect(find.text('Benchmark cockpit'), findsOneWidget);
      expect(find.text('Awaiting measurement'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Run settings'));
      await tester.pumpAndSettle();
      final port = find.widgetWithText(TextFormField, 'TCP port');
      await tester.enterText(port, '70000');
      await tester.pump();
      expect(find.textContaining('TCP port must be between'), findsWidgets);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      final start = find.widgetWithText(ElevatedButton, 'Start');
      expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
