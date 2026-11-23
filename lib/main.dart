import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bill_calculator.dart';

void main() => runApp(const ElectricityApp());

enum AppLanguage { mongolian, english }

class ElectricityApp extends StatefulWidget {
  const ElectricityApp({super.key});

  @override
  State<ElectricityApp> createState() => _ElectricityAppState();
}

class _ElectricityAppState extends State<ElectricityApp> {
  AppLanguage language = AppLanguage.mongolian;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF15342F);
    const emerald = Color(0xFF0A9B73);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: language == AppLanguage.english ? 'Erchim · Electricity Bill' : 'Эрчим · Цахилгааны төлбөр',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          primary: emerald,
          secondary: const Color(0xFF258BCA),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F8F6),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: navy, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: navy, fontWeight: FontWeight.w800),
          bodyMedium: TextStyle(color: navy),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FBFA),
          labelStyle: const TextStyle(color: Color(0xFF627D78)),
          floatingLabelStyle: const TextStyle(color: emerald),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFD9E9E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFDCE9E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: emerald, width: 1.7),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 17),
        ),
      ),
      home: CalculatorPage(
        language: language,
        onLanguageChanged: (next) => setState(() => language = next),
      ),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with SingleTickerProviderStateMixin {
  String t(String mongolian, String english) =>
      widget.language == AppLanguage.english ? english : mongolian;

  late final AnimationController _feedbackController;
  late final Animation<double> _feedbackScale;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _feedbackScale = Tween<double>(begin: 1.0, end: 1.24).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeOutBack),
    );
    _feedbackController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _feedbackController.reverse();
    });
  }

  static const emerald = Color(0xFF0A9B73);
  static const navy = Color(0xFF15342F);
  static const muted = Color(0xFF738782);
  static const pale = Color(0xFFEAF7F1);
  final formKey = GlobalKey<FormState>();
  final _resultAnchorKey = GlobalKey();
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
    _feedbackController.dispose();
    super.dispose();
  }

  String? validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return t('Заалтаа оруулна уу', 'Please enter a meter reading');
    final number = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < 0) {
      return t('0-ээс их буюу тэнцүү тоо оруулна уу', 'Enter a number greater than or equal to zero');
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
      // Physics-based spring from Lecture 13; settle and reverse once.
      _feedbackController.animateWith(SpringSimulation(
        const SpringDescription(mass: 1.0, stiffness: 180.0, damping: 20.0),
        0.0,
        1.0,
        0.0,
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _resultAnchorKey.currentContext == null) return;
        Scrollable.ensureVisible(
          _resultAnchorKey.currentContext!,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      });
    } on ArgumentError {
      setState(() {
        result = null;
        errorMessage = 'invalid-reading';
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

  double? _periodDifference(MeterPeriod period) {
    final before = double.tryParse(
        previousControllers[period]!.text.trim().replaceAll(',', '.'));
    final after = double.tryParse(
        currentControllers[period]!.text.trim().replaceAll(',', '.'));
    if (before == null || after == null || after < before) return null;
    return after - before;
  }

  double? get _previewUsage {
    if (mode == CalculationMode.educational) {
      return _periodDifference(MeterPeriod.day);
    }
    double sum = 0;
    for (final period in MeterPeriod.values) {
      final diff = _periodDifference(period);
      if (diff == null) return null;
      sum += diff;
    }
    return sum;
  }

  static final Uri sourceCodeUrl = Uri.parse(
    'https://github.com/bilgee80977053-oss/electricity-calculator',
  );

  Future<void> _openSourceCode() async {
    final launched = await launchUrl(
      sourceCodeUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(
          'GitHub холбоосыг нээж чадсангүй.',
          'Could not open the GitHub source code link.',
        ))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: pale,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bolt_rounded, color: emerald, size: 30),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('ЭРЧИМ', 'ERCHIM'),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                          color: navy,
                          fontSize: 17)),
                  Text(t('Цахилгааны ухаалаг тооцоолуур', 'Smart Electricity Calculator'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('source-code-button'),
            onPressed: _openSourceCode,
            tooltip: t('Эх код (GitHub)', 'Source code (GitHub)'),
            icon: const Icon(Icons.code_rounded, color: navy),
          ),
          PopupMenuButton<AppLanguage>(
            key: const Key('language-selector'),
            tooltip: t('Хэл сонгох', 'Choose language'),
            onSelected: widget.onLanguageChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppLanguage.mongolian,
                child: Text('Монгол'),
              ),
              PopupMenuItem(
                value: AppLanguage.english,
                child: Text('English'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.language_rounded, size: 21, color: navy),
                const SizedBox(width: 3),
                Text(widget.language == AppLanguage.english ? 'EN' : 'MN',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: navy)),
                const Icon(Icons.arrow_drop_down, color: navy, size: 18),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton.filledTonal(
              onPressed: showTariffInfo,
              tooltip: t('Тооцох аргын тайлбар', 'Calculation method'),
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              icon: const Icon(Icons.info_outline_rounded, color: navy),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 780;
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 28 : 16, 12, wide ? 28 : 16, 32),
                  children: [
                    _hero(wide),
                    const SizedBox(height: 22),
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
                                Container(key: _resultAnchorKey, child: _animatedResult()),
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
                      Container(key: _resultAnchorKey, child: _animatedResult()),
                      const SizedBox(height: 16),
                      _tariffCard(),
                    ],
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _historyCard(),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined,
                              size: 18, color: Color(0xFF3E8C75)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              mode == CalculationMode.realTariff2026
                                  ? t('Энэ нь урьдчилсан тооцоо. Шатлалыг хугацааны хэрэглээний харьцаагаар хуваарилах арга нь аппын таамаглал; албан нэхэмжлэх биш.', 'This estimate allocates each tier proportionally to day, evening and night use. It is an app assumption, not an official bill.')
                                  : t('Сургалтын жишиг тариф ашиглав. НӨАТ болон суурь төлбөр ороогүй.', 'Educational sample rates are used. VAT and the monthly base charge are excluded.'),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: Color(0xFF53756B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        key: const Key('source-code-footer'),
                        onPressed: _openSourceCode,
                        icon: const Icon(Icons.code_rounded, size: 18),
                        label: Text(t('Эх кодыг GitHub дээр харах',
                            'View source code on GitHub')),
                      ),
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
    final usage = _previewUsage;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF103D35), Color(0xFF126B59), Color(0xFF139A76)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24125B4A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -70,
            child: Container(
              width: 225,
              height: 225,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x22FFFFFF), width: 34),
              ),
            ),
          ),
          Positioned(
            bottom: -75,
            right: 20,
            child: Container(
              height: 170,
              width: 170,
              decoration: const BoxDecoration(
                  color: Color(0x1109FFA4), shape: BoxShape.circle),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeInOutCubic,
            top: result == null ? 34 : 8,
            right: result == null ? 36 : 72,
            child: AnimatedOpacity(
              opacity: result == null ? .13 : .38,
              duration: const Duration(milliseconds: 520),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 55),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 30 : 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.electric_bolt_rounded,
                        size: 18, color: Color(0xFF9BF9D5)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(t('ТАНЫ ЭРЧИМ ХҮЧНИЙ ТОЙМ', 'YOUR ENERGY OVERVIEW'),
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFD0F8E9),
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0x28FFFFFF),
                          borderRadius: BorderRadius.circular(30)),
                      child: Text(t('2026 · ДАРХАН', '2026 · DARKHAN'),
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(t('Хэрэглээгээ мэдэж,\nтөлбөрөө төлөвлө', 'Understand your usage,\nplan your bill'),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.55,
                        height: 1.15,
                        fontSize: wide ? 31 : 25)),
                const SizedBox(height: 9),
                Text(
                  t('Тоолуурын заалтаа оруулаад хэрэглээ, тарифын задаргааг нэг дороос хараарай.', 'Enter your meter readings to see usage and a detailed cost estimate in one place.'),
                  style: TextStyle(
                      color: Color(0xFFDDF9EE),
                      fontSize: 12.5,
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 68,
                  height: 18,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0x35FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeInOutCubic,
                    alignment: result == null
                        ? Alignment.centerLeft : Alignment.centerRight,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 550),
                      width: result == null ? 13 : 25,
                      height: 12,
                      decoration: BoxDecoration(
                        color: result == null ? Colors.white54 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x20FFFFFF),
                    border: Border.all(color: const Color(0x2FFFFFFF)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0x35FFFFFF),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: ScaleTransition(
                          scale: _feedbackScale,
                          child: const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('Оруулсан заалтын зөрүү', 'Consumption from entered readings'),
                                style: TextStyle(
                                    color: Color(0xFFD1F2E6), fontSize: 11)),
                            const SizedBox(height: 3),
                            Text(
                              usage == null
                                  ? t('Заалтаа шалгана уу', 'Check your readings')
                                  : '${number(usage, precision: 1)} ${t('кВт·цаг', 'kWh')}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 21),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.trending_up_rounded,
                          color: Color(0xFFB9FFDC)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5F0EC)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0C275E52),
                blurRadius: 23,
                offset: Offset(0, 8)),
          ],
        ),
        child: child,
      );

  Widget _heading(IconData icon, String title, String subtitle) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: pale, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 23, color: emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: navy,
                        fontSize: 18)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: muted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      );

  Widget _modeSelector() {
    Widget item(CalculationMode target, String title, String caption) {
      final active = mode == target;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() {
            mode = target;
            result = null;
            errorMessage = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              boxShadow: active
                  ? const [BoxShadow(color: Color(0x120B6853), blurRadius: 9)]
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: active ? emerald : const Color(0xFF9AB0A9),
                        size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(title,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 12,
                                color: active ? navy : muted,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(caption,
                    style: TextStyle(
                        color: active ? emerald : muted, fontSize: 10)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F7F4),
          borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          item(CalculationMode.realTariff2026, t('Бодит тариф (2026)', 'Real Tariff (2026)'), t('Бодит тариф', 'Actual rates')),
          item(CalculationMode.educational, t('Сургалтын тариф', 'Educational Tariff'), t('Сургалтын жишээ', 'Practice rates')),
        ],
      ),
    );
  }

  Widget _formCard() => _panel(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(Icons.tune_rounded, t('Тооцоолол хийх', 'Calculate electricity cost'),
                  t('Хэрэглэх тариф болон тоолуурын заалт', 'Choose a rate plan and enter your readings')),
              const SizedBox(height: 19),
              _modeSelector(),
              const SizedBox(height: 19),
              if (mode == CalculationMode.realTariff2026) ...[
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: emerald, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(t('Дархан-Уул · Өрхийн гурван хугацаат тоолуур', 'Darkhan-Uul · Three-period household meter'),
                          style: TextStyle(
                              color: muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final period in MeterPeriod.values) ...[
                  _periodInputs(period),
                  if (period != MeterPeriod.night) const SizedBox(height: 11),
                ],
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAF8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE7F0EC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 22, color: emerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('НӨАТ тооцох (10%)', 'Add VAT (10%)'),
                                style: TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            Text(t('Нийт дүн дээр нэмэх', 'Include in the estimated total'),
                                style: TextStyle(color: muted, fontSize: 11)),
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
                ),
              ] else ...[
                Text(t('Өмнөх болон одоогийн заалтаа оруулна уу.', 'Enter your previous and current readings.'),
                    style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 14),
                _readingField(MeterPeriod.day, false,
                    label: t('Өмнөх сарын заалт', 'Previous month reading'), hint: t('Өмнөх заалт', 'Previous')),
                const SizedBox(height: 13),
                _readingField(MeterPeriod.day, true,
                    label: t('Одоогийн заалт', 'Current'), hint: t('Одоогийн заалт', 'Current')),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(t('Заалтуудаа шалгана уу. Одоогийн заалт өмнөхөөс бага байж болохгүй.', 'Check your readings. Current readings must not be less than previous readings.'),
                    style: const TextStyle(color: Color(0xFFB42318))),
              ],
              const SizedBox(height: 19),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: emerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(t('Төлбөрөө харах', 'Calculate bill'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: TextButton.icon(
                  onPressed: reset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(t('Талбаруудыг цэвэрлэх', 'Clear readings')),
                  style: TextButton.styleFrom(foregroundColor: muted),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _periodInputs(MeterPeriod period) {
    final title = switch (period) {
      MeterPeriod.day => t('Өдөр', 'Day'),
      MeterPeriod.evening => t('Орой', 'Evening'),
      MeterPeriod.night => t('Шөнө', 'Night'),
    };
    final icon = switch (period) {
      MeterPeriod.day => Icons.wb_sunny_outlined,
      MeterPeriod.evening => Icons.wb_twilight_outlined,
      MeterPeriod.night => Icons.nights_stay_outlined,
    };
    final accent = switch (period) {
      MeterPeriod.day => const Color(0xFF14A777),
      MeterPeriod.evening => const Color(0xFFF0A53F),
      MeterPeriod.night => const Color(0xFF4B89D7),
    };
    final diff = _periodDifference(period);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFB),
        border: Border.all(color: const Color(0xFFE7EFEB)),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 8),
              Text('$title ${t('хугацаа', 'period')}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: navy)),
              const Spacer(),
              Text(diff == null ? '—' : '${number(diff, precision: 1)} ${t('кВт·ц', 'kWh')}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: diff == null ? muted : accent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _readingField(period, false,
                    label: t('Өмнөх заалт', 'Previous'), hint: t('Өмнөх заалт', 'Previous')),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _readingField(period, true,
                    label: t('Одоогийн заалт', 'Current'), hint: t('Одоогийн заалт', 'Current')),
              ),
            ],
          ),
        ],
      ),
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
    final compact = MediaQuery.sizeOf(context).width < 530;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        suffixText: compact ? null : t('кВт·ц', 'kWh'),
        contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 14, vertical: 16),
      ),
      style: const TextStyle(
          color: navy, fontWeight: FontWeight.w700, fontSize: 15),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      validator: (raw) {
        final error = validate(raw);
        if (error != null) return error;
        final previousText = previousControllers[period]!.text
            .trim().replaceAll(',', '.');
        final previousValue = double.tryParse(previousText);
        if (current && previousValue != null && previousValue.isFinite &&
            read(currentControllers[period]!) < previousValue) {
          return t('Одоогийн заалт бага байна', 'Current reading is lower than previous');
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {
        result = null;
        errorMessage = null;
      }),
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
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: pale,
                borderRadius: BorderRadius.circular(23),
              ),
              child: const Icon(Icons.analytics_outlined,
                  size: 34, color: emerald),
            ),
            const SizedBox(height: 15),
            Text(t('Тооцооны үр дүн', 'Calculation result'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 7),
            Text(
              t('Заалтаа оруулаад «Төлбөрөө харах» товчийг дарахад энд тооцооны дэлгэрэнгүй гарна.', 'Enter your readings and press “Calculate bill” to see the detailed result here.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.5, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: const Color(0xFFF3F9F6),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: emerald, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(t('Зөвлөгөө: Тоолуурын шинэ заалт хуучнаасаа багагүй байна.', 'Tip: Current readings must not be lower than previous readings.'),
                        style: TextStyle(color: Color(0xFF507469), fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (bill is BillResult) return _educationalResult(bill);
    return _realResult(bill as RealTariffResult);
  }

  Widget _resultHeading(double total, double used) => Hero(
        tag: 'electricity-bill-summary',
        createRectTween: (begin, end) =>
            MaterialRectCenterArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE5F8EF), Color(0xFFF3FBF8)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: emerald, size: 19),
                SizedBox(width: 7),
                Text(t('ТООЦООЛСОН НИЙТ ДҮН', 'ESTIMATED TOTAL'),
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF367A64))),
              ],
            ),
            const SizedBox(height: 12),
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
                        fontSize: 33,
                        letterSpacing: -.5,
                        fontWeight: FontWeight.w900,
                        color: navy)),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: result == null ? 0 : 1,
              child: Text('${number(used, precision: 2)} ${t('кВт·цаг хэрэглэсэн', 'kWh used')}',
                style: const TextStyle(
                    color: Color(0xFF3D7A68), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _educationalResult(BillResult bill) => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(Icons.receipt_long_outlined, t('Төлбөрийн задаргаа', 'Bill breakdown'),
                t('Сургалтын жишиг тарифаар', 'Based on educational sample rates')),
            const SizedBox(height: 16),
            _resultHeading(bill.total, bill.used),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('open-bill-details'),
                onPressed: () => _openBillDetails(bill),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(t('Дэлгэрэнгүй харах', 'View details')),
              ),
            ),
            const SizedBox(height: 20),
            Text(t('Хэрэглээний шатлал', 'Consumption tiers'),
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: navy)),
            const SizedBox(height: 10),
            _tierProgress(t('0–150 кВт·ц', '0–150 kWh'), bill.tier1Units, bill.used,
                const Color(0xFF0A9B73)),
            _tierProgress(t('151–300 кВт·ц', '151–300 kWh'), bill.tier2Units, bill.used,
                const Color(0xFF55B8CF)),
            _tierProgress(t('300+ кВт·ц', 'Over 300 kWh'), bill.tier3Units, bill.used,
                const Color(0xFFFFB55B)),
            const Divider(height: 25, color: Color(0xFFE8F0ED)),
            _detailRow(t('Эхний 150 кВт·цаг', 'First 150 kWh'), bill.tier1Units,
                BillCalculator.firstRate, bill.tier1Amount),
            _detailRow(t('151–300 кВт·цаг', '151–300 kWh'), bill.tier2Units,
                BillCalculator.secondRate, bill.tier2Amount),
            _detailRow(t('300-аас дээш', 'Over 300 kWh'), bill.tier3Units,
                BillCalculator.thirdRate, bill.tier3Amount),
            const Divider(height: 24, color: Color(0xFFE8F0ED)),
            Text(
                '${t('Дундаж тариф', 'Average rate')}: ${number(bill.averageRate, precision: 2)} ₮/${t('кВт·цаг', 'kWh')}',
                style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      );

  Widget _tierProgress(String label, double units, double total, Color color) {
    final double portion = total <= 0
        ? 0.0
        : (units / total).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label,
                  style: const TextStyle(color: muted, fontSize: 11.5))),
              Text('${number(units, precision: 2)} ${t('кВт·ц', 'kWh')}',
                  style: const TextStyle(color: navy,
                      fontSize: 11.5, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: portion,
              backgroundColor: const Color(0xFFEEF4F1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _usageOverview(RealTariffResult bill) {
    const colors = [Color(0xFF11A878), Color(0xFFFFC16B), Color(0xFF5B96DB)];
    final values = [bill.day, bill.evening, bill.night];
    final labels = [t('Өдрийн хэрэглээ', 'Daytime usage'), t('Оройн хэрэглээ', 'Evening usage'), t('Шөнийн хэрэглээ', 'Nighttime usage')];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        border: Border.all(color: const Color(0xFFE7F1EC)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(116, 116),
                  painter: _UsageRingPainter(values, colors),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: emerald, size: 20),
                    Text(number(bill.used, precision: 1),
                        style: const TextStyle(
                            color: navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    Text(t('кВт·ц', 'kWh'), style: TextStyle(
                        color: muted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Хэрэглээний бүтэц', 'Usage distribution'),
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(height: 11),
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: colors[i], shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(labels[i],
                            style: const TextStyle(color: muted, fontSize: 11))),
                        Text('${bill.used == 0 ? '0' : number(values[i] * 100 / bill.used, precision: 0)}%',
                            style: const TextStyle(color: navy,
                                fontWeight: FontWeight.w800, fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _realResult(RealTariffResult bill) => _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(Icons.analytics_outlined, t('Төлбөрийн задаргаа', 'Bill breakdown'),
                t('Таны тооцоолсон сарын хэрэглээ', 'Your estimated monthly usage')),
            const SizedBox(height: 16),
            _resultHeading(bill.total, bill.used),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('open-bill-details'),
                onPressed: () => _openBillDetails(bill),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(t('Дэлгэрэнгүй харах', 'View details')),
              ),
            ),
            const SizedBox(height: 15),
            _usageOverview(bill),
            const SizedBox(height: 17),
            Text(t('Тоолуурын хэрэглээ', 'Meter consumption'),
                style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 8),
            _simpleRow(t('Өдөр', 'Day'), bill.day),
            _simpleRow(t('Орой', 'Evening'), bill.evening),
            _simpleRow(t('Шөнө', 'Night'), bill.night),
            const Divider(height: 26, color: Color(0xFFE8F0ED)),
            Text(t('Сарын хэрэглээний шатлал', 'Monthly consumption tiers'),
                style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 9),
            for (var index = 0; index < bill.tiers.length; index++)
              _tierResultRow(index, bill.tiers[index]),
            const Divider(height: 25, color: Color(0xFFE8F0ED)),
            _amountRow(t('Цахилгаан', 'Electricity usage'), bill.energyCharge),
            _amountRow(t('Сарын суурь төлбөр', 'Monthly base charge'), bill.baseCharge),
            if (includeVat) _amountRow(t('НӨАТ (10%)', 'VAT (10%)'), bill.vatAmount),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E9),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF9C6D23), size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    t('Урьдчилсан тооцоо. Албан нэхэмжлэхтэй заавал ижил байхгүй.', 'This is an estimate and may differ from the official invoice.'),
                    style: TextStyle(color: Color(0xFF805F2E),
                        fontSize: 11.5, height: 1.4),
                  )),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _simpleRow(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text('${number(value, precision: 2)} ${t('кВт·цаг', 'kWh')}',
                style: const TextStyle(
                    color: Color(0xFF627E7D), fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tierResultRow(int index, TariffTierResult tier) {
    final labels = [t('0–150 кВт·цаг', '0–150 kWh'), t('151–300 кВт·цаг', '151–300 kWh'), t('300-аас дээш', 'Over 300 kWh')];
    final allocated = '${t('Өдөр', 'Day')} ${number(tier.dayUnits, precision: 2)} · '
        '${t('Орой', 'Evening')} ${number(tier.eveningUnits, precision: 2)} · '
        '${t('Шөнө', 'Night')} ${number(tier.nightUnits, precision: 2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${labels[index]} · ${number(tier.units, precision: 2)} ${t('кВт·ц', 'kWh')}',
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
                  Expanded(
                      child: Text(t('Тарифын мэдээлэл', 'Rate information'),
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
          _rate('01', t('0–150 кВт·цаг', '0–150 kWh'), '175 ₮'),
          _rate('02', t('151–300 кВт·цаг', '151–300 kWh'), '256 ₮'),
          _rate('03', t('300-аас дээш', 'Over 300 kWh'), '285 ₮'),
          const SizedBox(height: 8),
          Text(t('Энэ тариф нь сургалтын жишээ.', 'These are educational sample rates.'),
              style: TextStyle(fontSize: 12, color: Color(0xFF788C8E))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(t('Дархан-Уул · Өрхийн · НӨАТ-гүй тариф (₮/кВт·ц)', 'Darkhan-Uul · Residential rates before VAT (₮/kWh)'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        _realRateRow(t('0–150 кВт·ц', '0–150 kWh'), '179 / 294 / 119'),
        _realRateRow(t('151–300 кВт·ц', '151–300 kWh'), '200 / 305 / 119'),
        _realRateRow(t('300-аас дээш', 'Over 300 kWh'), '231 / 315 / 119'),
        const SizedBox(height: 8),
        Text(t('Дараалал: өдөр / орой / шөнө. Суурь төлбөр: 3,360 ₮.', 'Values: day / evening / night. Base charge: 3,360 ₮.'),
            style: TextStyle(fontSize: 12, color: Color(0xFF627E7D))),
        const SizedBox(height: 10),
        Text(
          t('Эх сурвалжийн мэдээлэл: ЭХЗХ-ны 2026.05.29-ний №350 тогтоол, Хавсралт 2 (даалгаварт өгсөн мэдээлэл). Тогтоолын эхийг албан сайтаас баталгаажуулж чадсангүй.', 'Rate figures were supplied with the assignment, referring to ERC Resolution No. 350 of 29 May 2026, Annex 2. The original decision has not been independently verified.'),
          style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF788C8E)),
        ),
        const SizedBox(height: 8),
        Text(
          t('Сарын шатлалыг гурван хугацаанд хэрэглээний харьцаагаар хуваарилах нь энэ аппын таамаглал; албан тооцооллын арга гэж баталгаажаагүй.', 'Allocating monthly tiers proportionally across three time periods is an app assumption, not a verified official billing method.'),
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
            _heading(Icons.history_rounded, t('Сүүлийн тооцооллууд', 'Recent calculations'),
                t('Энэ удаагийн сүүлийн 5 үр дүн', 'Last 5 results from this session')),
            const SizedBox(height: 11),
            for (var i = 0; i < history.length; i++) ...[
              if (i > 0) const Divider(
                  height: 1, color: Color(0xFFEDF3F0)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: pale,
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.receipt_outlined,
                          color: emerald, size: 19),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${number(history[i].used, precision: 2)} ${t('кВт·цаг', 'kWh')}',
                              style: const TextStyle(
                                  color: navy, fontWeight: FontWeight.w700)),
                          Text(history[i].mode == CalculationMode.realTariff2026
                              ? t('Бодит тариф · 2026', 'Actual rates · 2026') : t('Сургалтын тариф', 'Educational rates'),
                              style: const TextStyle(
                                  color: muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('${number(history[i].total, precision: 2)} ₮',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: emerald,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  void _openBillDetails(Object bill) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _BillDetailsPage(
        bill: bill,
        isEnglish: widget.language == AppLanguage.english,
      ),
    ));
  }

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
                Text(t('Тооцох арга ба анхааруулга', 'Calculation method and notices'),
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 21)),
                const SizedBox(height: 12),
                if (mode == CalculationMode.realTariff2026) ...[
                  Text(
                      t('Өдөр, орой, шөнийн хэрэглээг тус бүрийн одоогийн заалтаас өмнөх заалтыг хасаж олно. Сарын хэрэглээг 0–150, 151–300, 300-аас дээш шатлалд хуваана.', 'For day, evening and night, subtract the previous reading from the current reading. Monthly total usage is divided into 0–150, 151–300 and over 300 kWh tiers.')),
                  const SizedBox(height: 8),
                  Text(
                      t('Энэ тооцоолуур шатлал тус бүрийн кВт·цагийг өдөр/орой/шөнийн хэрэглээний харьцаагаар хуваарилна. Энэ нь зөвхөн ил тод зарласан implementation assumption; ЭХЗХ эсвэл хангагчийн албан ёсны алгоритм гэж баталгаажаагүй.', 'The calculator allocates each tier across day, evening and night according to the share of overall usage. This implementation assumption is not a verified ERC or provider billing algorithm.')),
                  const SizedBox(height: 8),
                  Text(
                      t('Тарифыг хэрэглэгчийн өгсөн №350 тогтоолын мэдээллээр оруулсан. Тогтоолын эх болон уг хуваарилалтын аргыг албан эх сурвалжаар баталгаажуулж чадсангүй. Үр дүн нь тооцоолол бөгөөд албан нэхэмжлэхтэй адил байна гэж мэдэгдэхгүй.', 'The tariff inputs reflect the supplied information about Resolution No. 350. Neither the original regulation nor the allocation method has been independently verified. The result is an estimate, not an official invoice.')),
                  const SizedBox(height: 8),
                  Text(
                      t('НӨАТ сонгосон бол цахилгааны төлбөр ба суурь төлбөрийн нийлбэрт 10% тооцно; төлбөрийн бодит НӨАТ-ын хэрэгжилтээр баталгаажаагүй таамаглал.', 'When VAT is enabled, 10% is added to the energy and base charge subtotal. This treatment has not been verified against official VAT billing rules.')),
                ] else ...[
                  Text(t('Хэрэглээ = одоогийн заалт − өмнөх заалт.', 'Usage = current meter reading − previous meter reading.')),
                  const SizedBox(height: 8),
                  Text(
                      '${t('Эхний 150 кВт·цаг × 175 ₮; дараагийн 150 × 256 ₮; ', 'First 150 kWh × 175 ₮; next 150 × 256 ₮; ')}'
                      '${t('300-аас давсан хэсэг × 285 ₮.', 'usage over 300 kWh × 285 ₮.')}'),
                  const SizedBox(height: 12),
                  Text(
                      t('НӨАТ, суурь төлбөр, шөнийн тариф ороогүй сургалтын хувилбар.', 'Educational example excluding VAT, base charges and night tariffs.'),
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


/// A separate bill-detail route demonstrates Flutter Hero animation using
/// the same immutable bill result as the calculator (no recalculation).
class _BillDetailsPage extends StatelessWidget {
  const _BillDetailsPage({
    required this.bill,
    required this.isEnglish,
  });

  final Object bill;
  final bool isEnglish;

  String t(String mn, String en) => isEnglish ? en : mn;

  String format(double value, {int precision = 2}) {
    final parts = value.toStringAsFixed(precision).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final total = bill is BillResult
        ? (bill as BillResult).total
        : (bill as RealTariffResult).total;
    final used = bill is BillResult
        ? (bill as BillResult).used
        : (bill as RealTariffResult).used;
    final rows = <MapEntry<String, String>>[];
    if (bill is BillResult) {
      final data = bill as BillResult;
      rows.addAll([
        MapEntry(t('Эхний 150 кВт·цаг', 'First 150 kWh'),
            '${format(data.tier1Amount)} ₮'),
        MapEntry(t('151–300 кВт·цаг', '151–300 kWh'),
            '${format(data.tier2Amount)} ₮'),
        MapEntry(t('300-аас дээш', 'Over 300 kWh'),
            '${format(data.tier3Amount)} ₮'),
      ]);
    } else {
      final data = bill as RealTariffResult;
      rows.addAll([
        MapEntry(t('Өдөр', 'Day'), '${format(data.day)} ${t('кВт·цаг', 'kWh')}'),
        MapEntry(t('Орой', 'Evening'), '${format(data.evening)} ${t('кВт·цаг', 'kWh')}'),
        MapEntry(t('Шөнө', 'Night'), '${format(data.night)} ${t('кВт·цаг', 'kWh')}'),
        for (var index = 0; index < data.tiers.length; index++)
          MapEntry(
            [t('0–150 кВт·цаг', '0–150 kWh'),
             t('151–300 кВт·цаг', '151–300 kWh'),
             t('300-аас дээш', 'Over 300 kWh')][index],
            '${format(data.tiers[index].amount)} ₮',
          ),
        MapEntry(t('Цахилгаан', 'Energy charge'),
            '${format(data.energyCharge)} ₮'),
        MapEntry(t('Сарын суурь төлбөр', 'Monthly base charge'),
            '${format(data.baseCharge)} ₮'),
        if (data.vatAmount > 0)
          MapEntry(t('НӨАТ (10%)', 'VAT (10%)'), '${format(data.vatAmount)} ₮'),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Төлбөрийн дэлгэрэнгүй', 'Bill details')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Hero(
                  tag: 'electricity-bill-summary',
                  createRectTween: (begin, end) =>
                      MaterialRectCenterArcTween(begin: begin, end: end),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        gradient: const LinearGradient(colors: [
                          Color(0xFFE5F8EF), Color(0xFFF3FBF8)
                        ]),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) => FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('ТООЦООЛСОН НИЙТ ДҮН', 'ESTIMATED TOTAL'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF367A64),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  '${format(total)} ₮',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    color: Color(0xFF15342F),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${format(used)} ${t('кВт·цаг хэрэглэсэн', 'kWh used')}',
                                  style: const TextStyle(
                                    color: Color(0xFF3D7A68),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(t('Тооцооны задаргаа', 'Calculation breakdown'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(row.key),
                          trailing: Text(row.value,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          dense: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(t(
                    'Энэ тооцоо нь зөвхөн урьдчилсан дүн. Тарифын шатлалыг цагийн хэрэглээнд хуваарилах арга нь албан эх сурвалжаар баталгаажаагүй.',
                    'This is an estimate only. The method for allocating usage tiers between time periods has not been verified as an official billing method.'),
                    style: const TextStyle(color: Color(0xFF627D78))),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(t('Тооцоолуур руу буцах', 'Back to calculator')),
                ),
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

/// Minimal, dependency-free visual breakdown of day/evening/night usage.
class _UsageRingPainter extends CustomPainter {
  const _UsageRingPainter(this.values, this.colors);

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    const stroke = 12.0;
    final track = Paint()
      ..color = const Color(0xFFE4F0E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = values.fold<double>(0, (sum, n) => sum + n);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / total) * math.pi * 2;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start + 0.025, math.max(0.0, sweep - 0.05),
          false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _UsageRingPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
