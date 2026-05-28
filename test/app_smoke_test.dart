import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleo/src/app/voleo_app.dart';

void main() {
  testWidgets('renders onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoleoApp()));

    expect(find.text('Voleo'), findsOneWidget);
    expect(find.text('WM 2026 Tippspiel'), findsOneWidget);
  });
}
