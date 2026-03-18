import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/error_card.dart';
import 'expense_list_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final ExpenseService _expenseService = ExpenseService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _archive = const [];
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final archive = await _expenseService.getArchive();

      if (!mounted) {
        return;
      }
      setState(() {
        _archive = archive;
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

  void _closeWithResult() {
    Navigator.of(context).pop(_didChange);
  }

  Future<void> _openArchiveMonth(int month, int year) async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseListScreen(month: month, year: year),
      ),
    );

    if (!mounted || didChange != true) {
      return;
    }

    setState(() {
      _didChange = true;
    });

    await _loadArchive();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<Map<String, dynamic>>>{};

    for (final item in _archive) {
      final year = (item['year'] as num?)?.toInt() ?? 0;
      grouped.putIfAbsent(year, () => <Map<String, dynamic>>[]).add(item);
    }

    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeWithResult();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _closeWithResult,
          ),
          title: const BrandAppBarTitle('Archiv'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadArchive,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                ErrorCard(
                  message: _error!,
                  onRetry: _loadArchive,
                )
              else if (_archive.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Noch keine archivierten Monate vorhanden.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                )
              else
                ...years.map(
                  (year) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$year',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...grouped[year]!.map((item) {
                              final month = (item['month'] as num?)?.toInt() ?? 1;
                              final count =
                                  (item['expense_count'] as num?)?.toInt() ?? 0;
                              final currencyTotals = AppFormat.currencyTotalsFromJson(
                                item['currency_totals'],
                              );

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_monthName(month)),
                                subtitle: Text('$count Ausgaben'),
                                trailing: Text(
                                  AppFormat.currencyTotalsSummary(currencyTotals),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onTap: () => _openArchiveMonth(month, year),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
