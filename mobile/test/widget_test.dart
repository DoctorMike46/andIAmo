import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:andiamo/main.dart';

void main() {
  testWidgets('App boots and shows splash', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AndiamoApp()));
    await tester.pump();
    expect(find.text('andIAmo'), findsOneWidget);
  });
}
