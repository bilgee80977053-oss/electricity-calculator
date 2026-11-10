import 'package:flutter_test/flutter_test.dart';
import 'package:electricity_bill_lab/bill_calculator.dart';

void main() {
  group('BillCalculator — шаталсан төлбөр', () {
    test('0 кВт·цаг', () {
      final bill = BillCalculator.calculate(100, 100);
      expect(bill.used, 0);
      expect(bill.total, 0);
    });

    test('эхний 150 кВт·цаг', () {
      final bill = BillCalculator.calculate(0, 150);
      expect(bill.tier1Amount, 26250);
      expect(bill.total, 26250);
    });

    test('220 кВт·цаг', () {
      final bill = BillCalculator.calculate(1200, 1420);
      expect(bill.tier1Units, 150);
      expect(bill.tier2Units, 70);
      expect(bill.tier3Units, 0);
      expect(bill.total, 44170);
    });

    test('350 кВт·цаг', () {
      final bill = BillCalculator.calculate(0, 350);
      expect(bill.tier3Units, 50);
      expect(bill.total, 78900);
    });

    test('одоо заалт өмнөхөөс бага бол алдаа', () {
      expect(() => BillCalculator.calculate(1420, 1200), throwsArgumentError);
    });

    test('сөрөг болон хязгааргүй оролтыг хориглоно', () {
      expect(() => BillCalculator.calculate(-1, 5), throwsArgumentError);
      expect(() => BillCalculator.calculate(0, double.infinity),
          throwsArgumentError);
    });
  });

  group('RealTariffCalculator — 2026 estimate', () {
    test('calculates the three-period tiers and monthly base charge', () {
      final bill = RealTariffCalculator.calculate(
        day: const MeterReading(previous: 0, current: 100),
        evening: const MeterReading(previous: 0, current: 100),
        night: const MeterReading(previous: 0, current: 100),
        includeVat: false,
      );

      expect(bill.used, 300);
      expect(bill.tiers[0].units, 150);
      expect(bill.tiers[0].dayUnits, 50);
      expect(bill.tiers[1].units, 150);
      expect(bill.energyCharge, 60800);
      expect(bill.baseCharge, 3360);
      expect(bill.vatAmount, 0);
      expect(bill.total, 64160);
    });

    test('charges consumption above 300 kWh at the third-tier day rate', () {
      final bill = RealTariffCalculator.calculate(
        day: const MeterReading(previous: 0, current: 400),
        evening: const MeterReading(previous: 0, current: 0),
        night: const MeterReading(previous: 0, current: 0),
        includeVat: false,
      );

      expect(bill.tiers.map((tier) => tier.units), [150, 150, 100]);
      expect(bill.energyCharge, 79950);
      expect(bill.total, 83310);
    });

    test('adds optional 10 percent VAT to the subtotal', () {
      final bill = RealTariffCalculator.calculate(
        day: const MeterReading(previous: 10, current: 10),
        evening: const MeterReading(previous: 20, current: 20),
        night: const MeterReading(previous: 30, current: 30),
        includeVat: true,
      );

      expect(bill.energyCharge, 0);
      expect(bill.subtotal, 3360);
      expect(bill.vatAmount, 336);
      expect(bill.total, 3696);
    });

    test('validates each period reading', () {
      expect(
        () => RealTariffCalculator.calculate(
          day: const MeterReading(previous: 4, current: 3),
          evening: const MeterReading(previous: 0, current: 0),
          night: const MeterReading(previous: 0, current: 0),
          includeVat: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => RealTariffCalculator.calculate(
          day: const MeterReading(previous: -1, current: 0),
          evening: const MeterReading(previous: 0, current: 0),
          night: const MeterReading(previous: 0, current: 0),
          includeVat: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects finite readings that would overflow the calculated bill', () {
      expect(
        () => RealTariffCalculator.calculate(
          day: const MeterReading(previous: 0, current: 1e308),
          evening: const MeterReading(previous: 0, current: 0),
          night: const MeterReading(previous: 0, current: 0),
          includeVat: false,
        ),
        throwsArgumentError,
      );
    });
  });
}
