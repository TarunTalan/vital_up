import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  testWidgets('shows the error under the field', (tester) async {
    await tester.pumpWidget(_host(AppTextField(
      controller: TextEditingController(),
      label: 'Protein',
      error: 'Enter grams of protein',
    )));
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Enter grams of protein'), findsOneWidget);
  });

  testWidgets('validator message appears after Form.validate()', (tester) async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController();
    await tester.pumpWidget(_host(Form(
      key: form,
      child: AppTextField(
        controller: controller,
        validator: (v) => v.isEmpty ? 'Required' : null,
      ),
    )));
    expect(find.text('Required'), findsNothing);

    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);

    controller.text = 'ok';
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('integer field rejects non-digits', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_host(AppTextField.integer(controller: controller)));
    await tester.enterText(find.byType(TextField), '12a');
    expect(controller.text, isEmpty);
    await tester.enterText(find.byType(TextField), '120');
    expect(controller.text, '120');
  });

  testWidgets('disabled field is dimmed', (tester) async {
    await tester.pumpWidget(_host(AppTextField(
      controller: TextEditingController(text: 'Locked'),
      enabled: false,
    )));
    await tester.pumpAndSettle();
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, AppDimens.disabledOpacity);
  });
}
