import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bill_calculator.dart';

void main() => runApp(const ElectricityApp());

class ElectricityApp extends StatelessWidget {
  const ElectricityApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF33314D);
    const emerald = Color(0xFF6658B8);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Цахилгааны төлбөр',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          primary: emerald,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7FB),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: navy, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: navy, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFBFAFF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  static const emerald = Color(0xFF6658B8);
  static const navy = Color(0xFF33314D);
  final formKey = GlobalKey<FormState>();
  final previousControllers = <MeterPeriod, TextEditingController>{
    MeterPeriod.day: TextEditingController(text: '1200'),
    MeterPeriod.evening: TextEditingController(text: '0'),
    MeterPeriod.night: TextEditingController(text: '0'),
  };
  final currentControllers = <MeterPeriod, TextEditingController>{
    MeterPeriod.day: TextEditingController(text: '1420'),
    MeterPeriod.evening: TextEditingController(text: '0'),
    MeterPeriod.night: TextEditingController(text: '0'),
  };

  CalculationMode mode = CalculationMode.realTariff2026;
  Object? result;
  String? errorMessage;
  final List<_HistoryEntry> history = [];
  bool showRates = false;
  bool includeVat = false;

  @override
  void dispose() {
    for (final controller in [
      ...previousControllers.values,
      ...currentControllers.values
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Заалтаа оруулна уу';
    final number = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < 0) {
      return '0-ээс их буюу тэнцүү тоо оруулна уу';
    }
    return null;
  }

  double read(TextEditingController controller) =>
      double.parse(controller.text.trim().replaceAll(',', '.'));

  MeterReading _reading(MeterPeriod period) => MeterReading(
        previous: read(previousControllers[period]!),
        current: read(currentControllers[period]!),
      );

  void calculate() {
    if (!formKey.currentState!.validate()) return;
    try {
      final next = mode == CalculationMode.educational
          ? BillCalculator.calculate(
              read(previousControllers[MeterPeriod.day]!),
              read(currentControllers[MeterPeriod.day]!),
            )
          : RealTariffCalculator.calculate(
              day: _reading(MeterPeriod.day),
              evening: _reading(MeterPeriod.evening),
              night: _reading(MeterPeriod.night),
              includeVat: includeVat,
            );
      final used =
          next is BillResult ? next.used : (next as RealTariffResult).used;
      final total =
          next is BillResult ? next.total : (next as RealTariffResult).total;
      setState(() {
        result = next;
        errorMessage = null;
        history.insert(0, _HistoryEntry(used: used, total: total, mode: mode));
        if (history.length > 5) history.removeLast();
      });
    } on ArgumentError catch (error) {
      setState(() {
        result = null;
        errorMessage = error.message.toString();
      });
    }
  }

  void reset() {
    for (final controller in [
      ...previousControllers.values,
      ...currentControllers.values
    ]) {
      controller.clear();
    }
    setState(() {
      result = null;
      errorMessage = null;
    });
  }

  String number(double value, {int precision = 0}) {
    final pieces = value.toStringAsFixed(precision).split('.');
    final whole = pieces.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return pieces.length == 1 ? whole : '$whole.${pieces.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FB),
        titleSpacing: 22,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: emerald, size: 28),
            SizedBox(width: 8),
            Text('Энерги тооцоолуур',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: navy, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: showTariffInfo,
            tooltip: 'Тарифын тайлбар',
            icon: const Icon(Icons.info_outline, color: navy),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 750;
                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 28 : 16,
                    vertical: wide ? 22 : 12,
                  ),
                  children: [
                    _hero(wide),
                    const SizedBox(height: 18),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _formCard()),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _animatedResult(),
                                const SizedBox(height: 16),
                                _tariffCard(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _formCard(),
                      const SizedBox(height: 16),
                      _animatedResult(),
                      const SizedBox(height: 16),
                      _tariffCard(),
                    ],
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _historyCard(),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      mode == CalculationMode.realTariff2026
                          ? 'Шатлалыг хугацааны хэрэглээний харьцаагаар хуваарилсан таамаглал · Албан нэхэмжлэх биш'
                          : 'Сургалтын тариф · НӨАТ болон суурь хураамж ороогүй',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF75878D)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(bool wide) {
    return Container(
      padding: EdgeInsets.all(wide ? 30 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF453B83), Color(0xFF8B74CF), Color(0xFFA38ED7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ӨРХИЙН ЦАХИЛГААНЫ ХЭРЭГЛЭЭ',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      color: Color(0xFFECE5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 11),
                Text(
                  'Төлбөрөө хялбар тооцоол',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 28 : 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Тоолуурын заалтаа оруулаад хэрэглээ болон төлбөрийн задаргааг хараарай.',
                  style: TextStyle(color: Color(0xFFF7F2FF), height: 1.5),
                ),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 20),
            const Icon(Icons.electric_meter_outlined,
                color: Color(0xFFECE5FF), size: 104),
          ],
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFEBE8F4)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x114C416F),
                blurRadius: 30,
                offset: Offset(0, 12)),
          ],
        ),
        child: child,
      );

  Widget _formCard() => _panel(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFEFEAFB),
                    foregroundColor: emerald,
                    child: Icon(Icons.speed_outlined),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Тооцооллын тохиргоо',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: navy)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<CalculationMode>(
                segments: const [
                  ButtonSegment(
                    value: CalculationMode.realTariff2026,
                    label: Text('Real Tariff (2026)'),
                  ),
                  ButtonSegment(
                    value: CalculationMode.educational,
                    label: Text('Educational Tariff'),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() {
                  mode = selection.first;
                  result = null;
                  errorMessage = null;
                }),
              ),
              const SizedBox(height: 18),
              if (mode == CalculationMode.realTariff2026) ...[
                const Text(
                  'Дархан-Уул · Өрхийн хэрэглэгч · Гурван хугацаат тоолуур',
                  style: TextStyle(
                      color: Color(0xFF6B7E84),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final period in MeterPeriod.values) ...[
                  _periodInputs(period),
                  if (period != MeterPeriod.night) const SizedBox(height: 13),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('НӨАТ тооцох (10%)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('Тарифын дүн дээр нэмнэ',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: includeVat,
                      activeThumbColor: emerald,
                      onChanged: (value) => setState(() {
                        includeVat = value;
                        result = null;
                      }),
                    ),
                  ],
                ),
              ] else ...[
                const Text('Өмнөх болон одоогийн заалтаа оруулаарай.',
                    style: TextStyle(color: Color(0xFF6B7E84), fontSize: 13)),
                const SizedBox(height: 18),
                _readingField(
                  MeterPeriod.day,
                  false,
                  label: 'Өмнөх сарын заалт',
                  hint: 'Өмнөх заалт',
                ),
                const SizedBox(height: 14),
                _readingField(
                  MeterPeriod.day,
                  true,
                  label: 'Одоогийн заалт',
                  hint: 'Одоогийн заалт',
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(errorMessage!,
                    style: const TextStyle(color: Color(0xFFB42318))),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: emerald,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Төлбөрөө харах',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: reset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Талбаруудыг цэвэрлэх'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _periodInputs(MeterPeriod period) {
    final title = switch (period) {
      MeterPeriod.day => 'Өдөр',
      MeterPeriod.evening => 'Орой',
      MeterPeriod.night => 'Шөнө',
    };
    final icon = switch (period) {
      MeterPeriod.day => Icons.wb_sunny_outlined,
      MeterPeriod.evening => Icons.wb_twilight_outlined,
      MeterPeriod.night => Icons.nights_stay_outlined,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: emerald),
          const SizedBox(width: 7),
          Text('$title хугацаа',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: navy)),
        ]),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _readingField(period, false,
                  label: 'Өмнөх заалт', hint: 'Өмнөх заалт'),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _readingField(period, true,
                  label: 'Одоогийн заалт', hint: 'Одоогийн заалт'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _readingField(
    MeterPeriod period,
    bool current, {
    required String label,
    required String hint,
  }) {
    final controller =
        current ? currentControllers[period]! : previousControllers[period]!;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: 'кВт·ц',
        prefixIcon: Icon(
          current ? Icons.electric_meter_outlined : Icons.history_rounded,
          color: emerald,
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      validator: (raw) {
        final error = validate(raw);
        if (error != null) return error;
        if (current &&
            read(currentControllers[period]!) <
                read(previousControllers[period]!)) {
          return 'Одоогийн заалт бага байна';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => calculate(),
    );
  }

  Widget _animatedResult() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(result == null
              ? 'empty'
              : 'bill-${result.hashCode}-${history.length}'),
          child: _resultCard(),
        ),
      );

  Widget _resultCard() {
    final bill = result;
    if (bill == null) {
      return _panel(
        child: const Column(
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 46, color: Color(0xFF9E90C9)),
            SizedBox(height: 12),
            Text('Таны тооцоолол энд гарна',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: navy)),
            SizedBox(height: 6),
            Text('Заалтаа оруулаад «Төлбөрөө харах» товчийг дараарай.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF74878A))),
          ],
        ),
      );
    }
    if (bill is BillResult) return _educationalResult(bill);
    return _realResult(bill as RealTariffResult);
  }

  Widget _resultHeading(double total, double used) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ТООЦООЛСОН НИЙТ ДҮН',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF63847F))),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            key: ValueKey(total),
            tween: Tween(begin: 0, end: total),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${number(value, precision: 2)} ₮',
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w900, color: navy)),
            ),
          ),
          const SizedBox(height: 8),
          Text('${number(used, precision: 2)} кВт·цаг хэрэглэсэн',
              style: const TextStyle(color: Color(0xFF627E7D))),
        ],
      );

  Widget _educationalResult(BillResult bill) => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeading(bill.total, bill.used),
            const Divider(height: 28),
            _detailRow('Эхний 150 кВт·цаг', bill.tier1Units,
                BillCalculator.firstRate, bill.tier1Amount),
            _detailRow('151–300 кВт·цаг', bill.tier2Units,
                BillCalculator.secondRate, bill.tier2Amount),
            _detailRow('300-аас дээш', bill.tier3Units,
                BillCalculator.thirdRate, bill.tier3Amount),
            const Divider(height: 28),
            Text(
                'Дундаж тариф: ${number(bill.averageRate, precision: 2)} ₮/кВт·цаг',
                style: const TextStyle(fontSize: 12, color: Color(0xFF627E7D))),
          ],
        ),
      );

  Widget _realResult(RealTariffResult bill) => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeading(bill.total, bill.used),
            const Divider(height: 28),
            const Text('Хугацааны хэрэглээ',
                style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 8),
            _simpleRow('Өдөр', bill.day),
            _simpleRow('Орой', bill.evening),
            _simpleRow('Шөнө', bill.night),
            const Divider(height: 24),
            const Text('Сарын хэрэглээний шатлал',
                style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 6),
            for (var index = 0; index < bill.tiers.length; index++)
              _tierResultRow(index, bill.tiers[index]),
            const Divider(height: 24),
            _amountRow('Цахилгаан', bill.energyCharge),
            _amountRow('Сарын суурь төлбөр', bill.baseCharge),
            if (includeVat) _amountRow('НӨАТ (10%)', bill.vatAmount),
            const Divider(height: 16),
            const Text(
              'Тооцоолсон дүн. Албан нэхэмжлэхтэй ижил байна гэж баталгаажуулахгүй.',
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF788C8E)),
            ),
          ],
        ),
      );

  Widget _simpleRow(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text('${number(value, precision: 2)} кВт·цаг',
                style: const TextStyle(
                    color: Color(0xFF627E7D), fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tierResultRow(int index, TariffTierResult tier) {
    const labels = ['0–150 кВт·цаг', '151–300 кВт·цаг', '300-аас дээш'];
    final allocated = 'Өдөр ${number(tier.dayUnits, precision: 2)} · '
        'Орой ${number(tier.eveningUnits, precision: 2)} · '
        'Шөнө ${number(tier.nightUnits, precision: 2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${labels[index]} · ${number(tier.units, precision: 2)} кВт·ц',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
                Text(allocated,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF71868B))),
              ],
            ),
          ),
          Text('${number(tier.amount, precision: 2)} ₮',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: navy, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, double units, double rate, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${number(units, precision: 2)} × ${number(rate)} ₮',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF71868B))),
              ],
            ),
          ),
          Text('${number(amount, precision: 2)} ₮',
              style: const TextStyle(fontWeight: FontWeight.w700, color: navy)),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text('${number(amount, precision: 2)} ₮',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, color: navy)),
          ],
        ),
      );

  Widget _tariffCard() => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => showRates = !showRates),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.layers_outlined, color: emerald),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Тарифын мэдээлэл',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: navy))),
                  AnimatedRotation(
                    turns: showRates ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: navy),
                  ),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: showRates ? _ratesContent() : const SizedBox.shrink(),
            ),
          ],
        ),
      );

  Widget _ratesContent() {
    if (mode == CalculationMode.educational) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          _rate('01', '0–150 кВт·цаг', '175 ₮'),
          _rate('02', '151–300 кВт·цаг', '256 ₮'),
          _rate('03', '300-аас дээш', '285 ₮'),
          const SizedBox(height: 8),
          const Text('Энэ тариф нь сургалтын жишээ.',
              style: TextStyle(fontSize: 12, color: Color(0xFF788C8E))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Дархан-Уул · Өрхийн · НӨАТ-гүй тариф (₮/кВт·ц)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        _realRateRow('0–150 кВт·ц', '179 / 294 / 119'),
        _realRateRow('151–300 кВт·ц', '200 / 305 / 119'),
        _realRateRow('300-аас дээш', '231 / 315 / 119'),
        const SizedBox(height: 8),
        const Text('Дараалал: өдөр / орой / шөнө. Суурь төлбөр: 3,360 ₮.',
            style: TextStyle(fontSize: 12, color: Color(0xFF627E7D))),
        const SizedBox(height: 10),
        const Text(
          'Эх сурвалжийн мэдээлэл: ЭХЗХ-ны 2026.05.29-ний №350 тогтоол, Хавсралт 2 (даалгаварт өгсөн мэдээлэл). Тогтоолын эхийг албан сайтаас баталгаажуулж чадсангүй.',
          style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF788C8E)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Сарын шатлалыг гурван хугацаанд хэрэглээний харьцаагаар хуваарилах нь энэ аппын таамаглал; албан тооцооллын арга гэж баталгаажаагүй.',
          style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF788C8E)),
        ),
      ],
    );
  }

  Widget _realRateRow(String label, String rates) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(rates,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      );

  Widget _rate(String index, String label, String amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEAFB),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(index,
                style: const TextStyle(
                    color: emerald, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(amount,
              style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
        ]),
      );

  Widget _historyCard() => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Сүүлийн тооцооллууд',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: navy)),
            for (final entry in history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_outlined, color: emerald),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                          '${number(entry.used, precision: 2)} кВт·цаг · ${entry.mode == CalculationMode.realTariff2026 ? '2026' : 'сургалтын'}'),
                    ),
                    Text('${number(entry.total, precision: 2)} ₮',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: navy)),
                  ],
                ),
              ),
          ],
        ),
      );

  void showTariffInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Тооцох арга ба анхааруулга',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 21)),
                const SizedBox(height: 12),
                if (mode == CalculationMode.realTariff2026) ...[
                  const Text(
                      'Өдөр, орой, шөнийн хэрэглээг тус бүрийн одоогийн заалтаас өмнөх заалтыг хасаж олно. Сарын хэрэглээг 0–150, 151–300, 300-аас дээш шатлалд хуваана.'),
                  const SizedBox(height: 8),
                  const Text(
                      'Энэ тооцоолуур шатлал тус бүрийн кВт·цагийг өдөр/орой/шөнийн хэрэглээний харьцаагаар хуваарилна. Энэ нь зөвхөн ил тод зарласан implementation assumption; ЭХЗХ эсвэл хангагчийн албан ёсны алгоритм гэж баталгаажаагүй.'),
                  const SizedBox(height: 8),
                  const Text(
                      'Тарифыг хэрэглэгчийн өгсөн №350 тогтоолын мэдээллээр оруулсан. Тогтоолын эх болон уг хуваарилалтын аргыг албан эх сурвалжаар баталгаажуулж чадсангүй. Үр дүн нь тооцоолол бөгөөд албан нэхэмжлэхтэй адил байна гэж мэдэгдэхгүй.'),
                  const SizedBox(height: 8),
                  const Text(
                      'НӨАТ сонгосон бол цахилгааны төлбөр ба суурь төлбөрийн нийлбэрт 10% тооцно; төлбөрийн бодит НӨАТ-ын хэрэгжилтээр баталгаажаагүй таамаглал.'),
                ] else ...[
                  const Text('Хэрэглээ = одоогийн заалт − өмнөх заалт.'),
                  const SizedBox(height: 8),
                  const Text(
                      'Эхний 150 кВт·цаг × 175 ₮; дараагийн 150 × 256 ₮; '
                      '300-аас давсан хэсэг × 285 ₮.'),
                  const SizedBox(height: 12),
                  const Text(
                      'НӨАТ, суурь төлбөр, шөнийн тариф ороогүй сургалтын хувилбар.',
                      style: TextStyle(color: Color(0xFF728385))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.used,
    required this.total,
    required this.mode,
  });

  final double used;
  final double total;
  final CalculationMode mode;
}
