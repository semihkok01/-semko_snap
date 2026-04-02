import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/error_card.dart';
import 'archive_screen.dart';
import 'category_favorites_screen.dart';
import 'category_management_screen.dart';
import 'expense_detail_screen.dart';
import 'expense_list_screen.dart';
import 'login_screen.dart';
import 'manual_expense_screen.dart';
import 'scan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final CategoryService _categoryService = CategoryService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const {};
  List<Expense> _recentExpenses = const [];

  int get _currentMonth => DateTime.now().month;
  int get _currentYear => DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      try {
        await _categoryService.fetchCategories(forceRefresh: true);
      } catch (_) {
        // Statistik und Verlauf bleiben auch ohne aktuelle Kategorien nutzbar.
      }

      final stats = await _expenseService.getStats(
        month: _currentMonth,
        year: _currentYear,
      );
      final expenses = await _expenseService.getExpenses(
        month: _currentMonth,
        year: _currentYear,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stats = stats;
        _recentExpenses = expenses.take(5).toList();
      });
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = exception.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAndRefresh(Widget screen) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => screen));

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final categories = (_stats['categories'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    final currencyTotals = AppFormat.currencyTotalsFromJson(
      _stats['currency_totals'],
    );
    final mixedCurrencies =
        _stats['mixed_currencies'] == true || currencyTotals.length > 1;
    final totalDisplay = AppFormat.currencyTotalsSummary(currencyTotals);
    final expenseCount = (_stats['expense_count'] as num?)?.toInt() ?? 0;
    final dailyAverageDisplay = AppFormat.currencyMetricSummary(
      currencyTotals,
      (entry) => entry.dailyAverage,
      emptyValue: AppFormat.currency(0),
    );
    final dailyAverageEntries = currencyTotals
        .where((entry) => entry.dailyAverage != null)
        .map(
          (entry) => CurrencyTotalEntry(
            currencyCode: entry.currencyCode,
            total: entry.dailyAverage ?? 0,
            expenseCount: entry.expenseCount,
            dailyAverage: entry.dailyAverage,
          ),
        )
        .toList();
    final categoryGroups = _groupCategoriesByCurrency(categories);

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle('Übersicht'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final navigator = Navigator.of(context);
              await authProvider.logout();
              if (!mounted) {
                return;
              }
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Willkommen zurück',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              auth.email ?? 'Semko Scan Nutzer',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthName(_currentMonth)} $_currentYear',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (mixedCurrencies)
                      _CurrencySummaryWrap(
                        entries: currencyTotals,
                        foreground: const Color(0xFF0F172A),
                      )
                    else
                      Text(
                        totalDisplay,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricChip(label: 'Ausgaben', value: '$expenseCount'),
                        mixedCurrencies
                            ? _CurrencyMetricChip(
                                label: 'Tagesdurchschnitt',
                                entries: dailyAverageEntries,
                                background: const Color(0xFFFFF7ED),
                                foreground: const Color(0xFFF59E0B),
                              )
                            : _MetricChip(
                                label: 'Tagesdurchschnitt',
                                value: dailyAverageDisplay,
                                background: const Color(0xFFFFF7ED),
                                foreground: const Color(0xFFF59E0B),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickActionCard(
                  title: 'Beleg scannen',
                  icon: Icons.document_scanner_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => _openAndRefresh(const ScanScreen()),
                ),
                _QuickActionCard(
                  title: 'Manuell',
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openAndRefresh(const ManualExpenseScreen()),
                ),
                _QuickActionCard(
                  title: 'Ausgaben',
                  icon: Icons.list_alt_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => _openAndRefresh(
                    ExpenseListScreen(month: _currentMonth, year: _currentYear),
                  ),
                ),
                _QuickActionCard(
                  title: 'Archiv',
                  icon: Icons.archive_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () => _openAndRefresh(const ArchiveScreen()),
                ),
                _QuickActionCard(
                  title: 'Kategorien',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF0EA5A4),
                  onTap: () => _openAndRefresh(
                    const CategoryManagementScreen(),
                  ),
                ),
                _QuickActionCard(
                  title: 'Favoriten',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openAndRefresh(
                    const CategoryFavoritesScreen(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ErrorCard(
                message: _error!,
                onRetry: _loadDashboard,
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategorien',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (categoryGroups.isEmpty)
                        _buildEmptyState(
                            'Für diesen Monat gibt es noch keine Ausgaben.')
                      else
                        _buildCategoryCharts(categoryGroups, mixedCurrencies),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Letzte Ausgaben',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_recentExpenses.isEmpty)
                        _buildEmptyState(
                            'Noch keine letzten Ausgaben vorhanden.')
                      else
                        ..._recentExpenses.map(
                          (expense) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _RecentExpenseTile(
                              expense: expense,
                              onTap: () => _openAndRefresh(
                                ExpenseDetailScreen(expense: expense),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupCategoriesByCurrency(
    List<Map<String, dynamic>> categories,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final category in categories) {
      final total = (category['total'] as num?)?.toDouble() ?? 0;
      if (total <= 0) {
        continue;
      }

      final currencyCode = AppFormat.normalizeCurrencyCode(
        category['currency'] as String?,
      );
      groups.putIfAbsent(currencyCode, () => <Map<String, dynamic>>[]).add(category);
    }

    return groups;
  }

  Widget _buildCategoryCharts(
    Map<String, List<Map<String, dynamic>>> categoryGroups,
    bool mixedCurrencies,
  ) {
    final entries = categoryGroups.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mixedCurrencies) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Mehrere Währungen werden getrennt dargestellt.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 18),
        ],
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;
          final currencyCode = entry.value.key;
          final categories = entry.value.value;
          final total = categories.fold<double>(
            0,
            (sum, category) => sum + ((category['total'] as num?)?.toDouble() ?? 0),
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == entries.length - 1 ? 0 : 26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mixedCurrencies) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppFormat.currencyLabel(currencyCode),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        AppFormat.currency(total, currencyCode: currencyCode),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 54,
                      sections: categories.map((category) {
                        final totalValue =
                            (category['total'] as num?)?.toDouble() ?? 0;
                        final title = totalValue >= 100
                            ? totalValue.toStringAsFixed(0)
                            : AppFormat.amount(totalValue);

                        return PieChartSectionData(
                          color: _resolveCategoryColor(category),
                          value: totalValue,
                          title: title,
                          radius: 52,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ...categories.map(
                  (category) => _buildCategoryLegendRow(
                    category,
                    currencyCode: currencyCode,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryLegendRow(
    Map<String, dynamic> category, {
    required String currencyCode,
  }) {
    final label = _categoryLabel(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _resolveCategoryColor(category),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            AppFormat.currency(
              (category['total'] as num?)?.toDouble() ?? 0,
              currencyCode: currencyCode,
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Color _resolveCategoryColor(Map<String, dynamic> category) {
    final resolved = Category.byName(category['name'] as String?);
    return (category['color'] as String?) != null
        ? Category.colorFromHex(category['color'] as String?)
        : (resolved?.color ?? const Color(0xFF2563EB));
  }

  String _categoryLabel(Map<String, dynamic> category) {
    final resolved = Category.byName(category['name'] as String?);
    return resolved?.localizedName ?? category['name'] as String? ?? 'Unbekannt';
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return months[month - 1];
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.background = const Color(0xFFEFF6FF),
    this.foreground = const Color(0xFF2563EB),
  });

  final String label;
  final String value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: foreground.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CurrencySummaryWrap extends StatelessWidget {
  const _CurrencySummaryWrap({
    required this.entries,
    required this.foreground,
  });

  final List<CurrencyTotalEntry> entries;
  final Color foreground;

  static const Map<String, Color> _accents = {
    'EUR': Color(0xFF2563EB),
    'TRY': Color(0xFFE76F51),
    'USD': Color(0xFF2A9D8F),
    'GBP': Color(0xFF7C3AED),
    'CHF': Color(0xFF264653),
    'AED': Color(0xFFF59E0B),
    'SAR': Color(0xFF16A34A),
  };

  Color _accentFor(String currencyCode) {
    final predefined = _accents[currencyCode];
    if (predefined != null) {
      return predefined;
    }

    final hue = currencyCode.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.68, 0.52).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries.map((entry) {
        final accent = _accentFor(entry.currencyCode);
        return Container(
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppFormat.currencyLabel(entry.currencyCode),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppFormat.currency(entry.total, currencyCode: entry.currencyCode),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CurrencyMetricChip extends StatelessWidget {
  const _CurrencyMetricChip({
    required this.label,
    required this.entries,
    required this.background,
    required this.foreground,
  });

  final String label;
  final List<CurrencyTotalEntry> entries;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: foreground.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  AppFormat.currency(entry.total, currencyCode: entry.currencyCode),
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 600
          ? 170
          : (MediaQuery.of(context).size.width - 52) / 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentExpenseTile extends StatelessWidget {
  const _RecentExpenseTile({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallbackCategory = Category.byId(expense.categoryId);
    final category = Category.byName(expense.categoryName) ?? fallbackCategory;
    final categoryColor = expense.categoryColor != null
        ? Category.colorFromHex(expense.categoryColor)
        : category.color;
    final categoryIcon = Category.iconForName(
      expense.categoryIcon ?? category.iconName,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: categoryColor.withValues(alpha: 0.15),
              foregroundColor: categoryColor,
              child: Icon(categoryIcon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.shopName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormat.displayDate(expense.date),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              AppFormat.currency(expense.amount, currencyCode: expense.currencyCode),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}








