/// Billing calculations kept independent of the Flutter widgets.
enum CalculationMode { realTariff2026, educational }

enum MeterPeriod { day, evening, night }

class MeterReading {
  const MeterReading({required this.previous, required this.current});

  final double previous;
  final double current;

  double get used => current - previous;

  void validate() {
    if (!previous.isFinite ||
        !current.isFinite ||
        previous < 0 ||
        current < 0) {
      throw ArgumentError(
          'Meter readings must be finite, non-negative numbers.');
    }
    if (current < previous) {
      throw ArgumentError(
          'The current reading cannot be less than the previous reading.');
    }
  }
}

class BillCalculator {
  static const double firstRate = 175;
  static const double secondRate = 256;
  static const double thirdRate = 285;

  static BillResult calculate(double previous, double current) {
    final reading = MeterReading(previous: previous, current: current)
      ..validate();
    final tiers = _tierUnits(reading.used);
    final amounts = [
      tiers[0] * firstRate,
      tiers[1] * secondRate,
      tiers[2] * thirdRate,
    ];
    if (amounts.any((amount) => !amount.isFinite) ||
        !amounts.reduce((a, b) => a + b).isFinite) {
      throw ArgumentError(
          'The readings are too large to calculate a finite bill.');
    }

    return BillResult(
      previous: previous,
      current: current,
      used: reading.used,
      tier1Units: tiers[0],
      tier2Units: tiers[1],
      tier3Units: tiers[2],
      tier1Amount: amounts[0],
      tier2Amount: amounts[1],
      tier3Amount: amounts[2],
    );
  }
}

class BillResult {
  const BillResult({
    required this.previous,
    required this.current,
    required this.used,
    required this.tier1Units,
    required this.tier2Units,
    required this.tier3Units,
    required this.tier1Amount,
    required this.tier2Amount,
    required this.tier3Amount,
  });

  final double previous;
  final double current;
  final double used;
  final double tier1Units;
  final double tier2Units;
  final double tier3Units;
  final double tier1Amount;
  final double tier2Amount;
  final double tier3Amount;

  double get total => tier1Amount + tier2Amount + tier3Amount;
  double get averageRate => used == 0 ? 0 : total / used;
}

class TariffTierResult {
  const TariffTierResult({
    required this.units,
    required this.dayUnits,
    required this.eveningUnits,
    required this.nightUnits,
    required this.amount,
  });

  final double units;
  final double dayUnits;
  final double eveningUnits;
  final double nightUnits;
  final double amount;
}

class RealTariffResult {
  const RealTariffResult({
    required this.day,
    required this.evening,
    required this.night,
    required this.tiers,
    required this.energyCharge,
    required this.baseCharge,
    required this.vatAmount,
  });

  final double day;
  final double evening;
  final double night;
  final List<TariffTierResult> tiers;
  final double energyCharge;
  final double baseCharge;
  final double vatAmount;

  double get used => day + evening + night;
  double get subtotal => energyCharge + baseCharge;
  double get total => subtotal + vatAmount;
}

class RealTariffCalculator {
  static const double baseCharge = 3360;
  static const double vatRate = 0.10;
  static const List<List<double>> rates = [
    [179, 294, 119],
    [200, 305, 119],
    [231, 315, 119],
  ];
  static RealTariffResult calculate({
    required MeterReading day,
    required MeterReading evening,
    required MeterReading night,
    required bool includeVat,
  }) {
    day.validate();
    evening.validate();
    night.validate();

    final consumptions = [day.used, evening.used, night.used];
    final total = consumptions.reduce((a, b) => a + b);
    if (!total.isFinite) {
      throw ArgumentError(
          'The combined consumption is too large to calculate.');
    }
    final tierUnits = _tierUnits(total);
    final allocatedTiers = <TariffTierResult>[];

    for (var tier = 0; tier < tierUnits.length; tier++) {
      final units = tierUnits[tier];
      final dayUnits = total == 0 ? 0.0 : units * consumptions[0] / total;
      final eveningUnits = total == 0 ? 0.0 : units * consumptions[1] / total;
      final nightUnits = total == 0 ? 0.0 : units * consumptions[2] / total;
      final amount = dayUnits * rates[tier][0] +
          eveningUnits * rates[tier][1] +
          nightUnits * rates[tier][2];
      allocatedTiers.add(TariffTierResult(
        units: units,
        dayUnits: dayUnits,
        eveningUnits: eveningUnits,
        nightUnits: nightUnits,
        amount: amount,
      ));
    }

    final energyCharge =
        allocatedTiers.fold<double>(0, (sum, tier) => sum + tier.amount);
    final subtotal = energyCharge + baseCharge;
    final vatAmount = includeVat ? subtotal * vatRate : 0.0;
    if (!energyCharge.isFinite || !subtotal.isFinite || !vatAmount.isFinite) {
      throw ArgumentError(
          'The readings are too large to calculate a finite bill.');
    }

    return RealTariffResult(
      day: consumptions[0],
      evening: consumptions[1],
      night: consumptions[2],
      tiers: List.unmodifiable(allocatedTiers),
      energyCharge: energyCharge,
      baseCharge: baseCharge,
      vatAmount: vatAmount,
    );
  }
}

List<double> _tierUnits(double used) {
  final first = used > 150 ? 150.0 : used;
  final afterFirst = used - first;
  final second = afterFirst > 150 ? 150.0 : afterFirst;
  return [first, second, afterFirst - second];
}
