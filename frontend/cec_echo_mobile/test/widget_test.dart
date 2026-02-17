import 'package:flutter_test/flutter_test.dart';
import 'package:cec_echo_mobile/main.dart';

void main() {
  testWidgets('app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CECApp());
    expect(find.text('CEC ECHO Login'), findsOneWidget);
  });
}
