import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hd_status/app.dart';

void main() {
  testWidgets('shows Welcome on first launch, then Home after Skip', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HdStatusApp());
    await tester.pumpAndSettle();

    expect(find.text('Prepare clearer Status uploads'), findsOneWidget);
    expect(find.text('Ready for your next Status?'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Ready for your next Status?'), findsOneWidget);
    expect(find.text('Prepare clearer Status uploads'), findsNothing);
  });

  testWidgets('goes straight to Home when Welcome was already seen', (tester) async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});

    await tester.pumpWidget(const HdStatusApp());
    await tester.pumpAndSettle();

    expect(find.text('Ready for your next Status?'), findsOneWidget);
    expect(find.text('Prepare clearer Status uploads'), findsNothing);
  });
}
