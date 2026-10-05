import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/core/validators/app_validators.dart';
import 'package:hamqadam/widgets/app_password_field.dart';

void main() {
  testWidgets('password can be revealed and confirmation tracks changes', (
    WidgetTester tester,
  ) async {
    final TextEditingController password = TextEditingController();
    final TextEditingController confirmation = TextEditingController();
    addTearDown(password.dispose);
    addTearDown(confirmation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: Column(
              children: <Widget>[
                AppPasswordField(label: 'Password', controller: password),
                AppPasswordField(
                  label: 'Confirm password',
                  controller: confirmation,
                  revalidateWhenControllerChanges: password,
                  validator: (String? value) =>
                      AppValidators.confirmPassword(value, password.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField).first).obscureText,
      isTrue,
    );
    expect(find.byTooltip('Show password'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );

    await tester.enterText(find.byType(TextField).first, 'Password1!');
    await tester.enterText(find.byType(TextField).last, 'Password1!');
    await tester.pump();
    expect(find.text('Passwords do not match'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Different1!');
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Password1!');
    await tester.pump();
    expect(find.text('Passwords do not match'), findsNothing);
  });
}
