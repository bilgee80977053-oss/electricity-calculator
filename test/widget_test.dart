import 'package:electricity_bill_lab/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCalculator(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ElectricityApp());
  }

  testWidgets('calculates the 2026 three-period estimate', (tester) async {
    await pumpCalculator(tester);

    expect(find.text('Real Tariff (2026)'), findsOneWidget);
    await tester.tap(find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('44,210.00 ₮'), findsAtLeastNWidgets(1));
    expect(find.text('Өдөр'), findsOneWidget);
    expect(find.text('Сарын суурь төлбөр'), findsOneWidget);
  });

  testWidgets('optional VAT updates the calculated total', (tester) async {
    await pumpCalculator(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('48,631.00 ₮'), findsAtLeastNWidgets(1));
    expect(find.text('НӨАТ (10%)'), findsOneWidget);
  });

  testWidgets('educational tariff mode keeps the laboratory calculation',
      (tester) async {
    await pumpCalculator(tester);

    await tester.tap(find.text('Educational Tariff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('44,170.00 ₮'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Тарифын мэдээлэл'));
    await tester.pumpAndSettle();
    expect(find.text('175 ₮'), findsOneWidget);
    expect(find.text('256 ₮'), findsOneWidget);
    expect(find.text('285 ₮'), findsOneWidget);
  });

  testWidgets('shows validation error for a decreasing meter reading',
      (tester) async {
    await pumpCalculator(tester);

    final previous = find.widgetWithText(TextFormField, 'Өмнөх заалт');
    final current = find.widgetWithText(TextFormField, 'Одоогийн заалт');
    await tester.enterText(previous.first, '15');
    await tester.enterText(current.first, '12');
    await tester.tap(find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('Одоогийн заалт бага байна'), findsOneWidget);
  });
}
