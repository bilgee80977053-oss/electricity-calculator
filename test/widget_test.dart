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

  // The calculator's form is taller than a 1000px test viewport.
  // Scroll the target into the visible area before tapping it.
  Future<void> tapWhenVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('GitHub source code button is visible', (tester) async {
    await pumpCalculator(tester);
    expect(find.byKey(const Key('source-code-button')), findsOneWidget);
  });

  testWidgets('calculates the 2026 three-period estimate', (tester) async {
    await pumpCalculator(tester);

    expect(find.text('Бодит тариф (2026)'), findsOneWidget);
    await tapWhenVisible(tester, find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('44,210.00 ₮'), findsAtLeastNWidgets(1));
    expect(find.text('Өдөр'), findsOneWidget);
    expect(find.text('Сарын суурь төлбөр'), findsOneWidget);
  });

  testWidgets('optional VAT updates the calculated total', (tester) async {
    await pumpCalculator(tester);

    await tapWhenVisible(tester, find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tapWhenVisible(tester, find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('48,631.00 ₮'), findsAtLeastNWidgets(1));
    expect(find.text('НӨАТ (10%)'), findsOneWidget);
  });

  testWidgets('educational tariff mode keeps the laboratory calculation',
      (tester) async {
    await pumpCalculator(tester);

    await tapWhenVisible(tester, find.text('Сургалтын тариф'));
    await tester.pumpAndSettle();
    await tapWhenVisible(tester, find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('44,170.00 ₮'), findsAtLeastNWidgets(1));
    await tapWhenVisible(tester, find.text('Тарифын мэдээлэл'));
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
    await tapWhenVisible(tester, find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.text('Одоогийн заалт бага байна'), findsOneWidget);
  });

  testWidgets('switches between Mongolian and English without losing inputs',
      (tester) async {
    await pumpCalculator(tester);

    await tapWhenVisible(tester, find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tapWhenVisible(tester, find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Smart Electricity Calculator'), findsOneWidget);
    expect(find.text('Calculate bill'), findsOneWidget);
    expect(find.text('Monthly base charge'), findsNothing);

    await tapWhenVisible(tester, find.text('Calculate bill'));
    await tester.pumpAndSettle();
    expect(find.text('44,210.00 ₮'), findsAtLeastNWidgets(1));
    expect(find.text('Monthly base charge'), findsOneWidget);

    await tapWhenVisible(tester, find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tapWhenVisible(tester, find.text('Монгол').last);
    await tester.pumpAndSettle();
    expect(find.text('Төлбөрөө харах'), findsOneWidget);
    expect(find.text('44,210.00 ₮'), findsAtLeastNWidgets(1));
  });

  testWidgets('Hero opens the bill detail route and returns',
      (tester) async {
    await pumpCalculator(tester);
    await tapWhenVisible(tester, find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();

    expect(find.byType(Hero), findsAtLeastNWidgets(1));
    await tapWhenVisible(tester, find.byKey(const Key('open-bill-details')));
    await tester.pumpAndSettle();
    expect(find.text('Төлбөрийн дэлгэрэнгүй'), findsOneWidget);
    expect(find.text('44,210.00 ₮'), findsAtLeastNWidgets(1));

    await tapWhenVisible(tester, find.text('Тооцоолуур руу буцах'));
    await tester.pumpAndSettle();
    expect(find.text('Төлбөрөө харах'), findsOneWidget);
  });

  testWidgets('Lecture 13 animation widgets are integrated with calculator',
      (tester) async {
    await pumpCalculator(tester);
    expect(find.byType(AnimatedPositioned), findsAtLeastNWidgets(1));
    expect(find.byType(AnimatedAlign), findsAtLeastNWidgets(1));
    expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
    expect(find.byType(AnimatedOpacity), findsAtLeastNWidgets(1));
    await tapWhenVisible(tester, find.text('Төлбөрөө харах'));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsAtLeastNWidgets(1));
    expect(find.byType(ScaleTransition), findsAtLeastNWidgets(1));
  });

}
