import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/budget_repository.dart';
import '../../models/personal_summary.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../utils/currencies.dart';
import '../../utils/month_range.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../widgets/category_icon.dart';
import '../account/accounts_page.dart';
import '../budget/budget_page.dart';
import '../cloud/cloud_service_page.dart';
import '../main/ledgers_page_new.dart';
import '../settings/about_page.dart';
import '../settings/app_lock_settings_page.dart';
import '../settings/data_management_page.dart';
import '../settings/smart_billing_page.dart';
import 'personal_style.dart';

final personalSelectedMonthProvider = StateProvider<DateTime>((ref) =>
    labelForDate(DateTime.now(), ref.watch(currentMonthStartDayProvider)));

final personalTransactionsProvider =
    StreamProvider.autoDispose<List<PersonalTransaction>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final month = ref.watch(personalSelectedMonthProvider);
  // Re-subscribe if the ledger's custom monthly boundary changes.
  ref.watch(currentMonthStartDayProvider);
  return repo.watchTransactionsWithCategoryInMonth(
      ledgerId: ledgerId, month: month);
});

final personalBudgetProvider = FutureProvider.autoDispose<BudgetUsage?>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final month = ref.watch(personalSelectedMonthProvider);
  final startDay = ref.watch(currentMonthStartDayProvider);
  ref.watch(budgetRefreshProvider);
  ref.watch(statsRefreshProvider);
  ref.watch(personalTransactionsProvider);
  final budget = await repo.getTotalBudget(ledgerId);
  if (budget == null || !budget.enabled) return null;
  // getBudgetUsage expects a date inside the budget period, not a month label.
  return repo.getBudgetUsage(
      budget.id, DateTime(month.year, month.month, startDay));
});

String _money(double value) => NumberFormat('#,##0.00', 'en_US').format(value);

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class PersonalMonthPicker extends ConsumerWidget {
  const PersonalMonthPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(personalSelectedMonthProvider);
    void move(int offset) {
      ref.read(personalSelectedMonthProvider.notifier).state =
          DateTime(month.year, month.month + offset, 1);
    }

    return Row(children: [
      IconButton(
        tooltip: '上个月',
        onPressed: () => move(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text('${month.year} 年 ${month.month} 月',
            textAlign: TextAlign.center,
            style: TextStyle(color: PersonalStyle.secondary(context))),
      ),
      IconButton(
        tooltip: '下个月',
        onPressed: () => move(1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ]);
  }
}

/// Home and statistics share the same live month stream and accounting rules.
class PersonalOverviewPage extends ConsumerWidget {
  const PersonalOverviewPage({super.key, this.statistics = false});
  final bool statistics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(personalTransactionsProvider);
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final symbol = getCurrencySymbol(ledger?.currency ?? 'CNY');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: PersonalStyle.dark(context)
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('账本暂时未能加载'),
              TextButton(
                  onPressed: () => ref.invalidate(personalTransactionsProvider),
                  child: const Text('重试')),
            ]),
          ),
          data: (items) {
            final summary = PersonalSummary(items);
            final sorted = [...items]
              ..sort((a, b) => b.t.happenedAt.compareTo(a.t.happenedAt));
            return CustomScrollView(
              key: PageStorageKey(statistics ? 'personal-stats' : 'personal-home'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.list(children: [
                    PersonalHeading(
                      kicker: statistics ? 'OVERVIEW' : 'BEECOUNT',
                      title: statistics ? '每一笔，都有数。' : '把日子，记清楚。',
                    ),
                    if (!statistics)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _open(context, const LedgersPageNew()),
                          icon: const Icon(Icons.book_outlined, size: 16),
                          label: Text(ledger?.name ?? '我的生活账本',
                              overflow: TextOverflow.ellipsis),
                          style: TextButton.styleFrom(
                              foregroundColor: PersonalStyle.secondary(context)),
                        ),
                      ),
                    const PersonalMonthPicker(),
                    const SizedBox(height: 12),
                    _TotalsCard(summary: summary, symbol: symbol),
                    const SizedBox(height: 20),
                    _BudgetStrip(symbol: symbol),
                    const SizedBox(height: 24),
                    Text(statistics ? '支出分布' : '本月明细',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: PersonalStyle.text(context))),
                    const SizedBox(height: 12),
                    if (statistics)
                      _CategoryBreakdown(summary: summary, symbol: symbol),
                    if (!statistics && sorted.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('还没有记录，点下方 ＋ 记下第一笔。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: PersonalStyle.secondary(context))),
                      ),
                  ]),
                ),
                if (!statistics)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final row = sorted[index];
                        final previous = index == 0 ? null : sorted[index - 1];
                        final day = DateUtils.dateOnly(row.t.happenedAt);
                        final newDay = previous == null ||
                            day != DateUtils.dateOnly(previous.t.happenedAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (newDay)
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 4),
                                child: Text(DateFormat('M 月 d 日').format(day),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: PersonalStyle.secondary(context))),
                              ),
                            _PersonalTransactionRow(row: row),
                          ],
                        );
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.summary, required this.symbol});
  final PersonalSummary summary;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    Widget small(String title, double value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13, color: PersonalStyle.secondary(context))),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$symbol ${_money(value)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            ),
          ]),
        );
    return PersonalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('本月支出', style: TextStyle(color: PersonalStyle.secondary(context), fontSize: 13)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('$symbol ${_money(summary.expense)}',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w500, letterSpacing: -1.5)),
        ),
        const SizedBox(height: 24),
        Row(children: [small('收入', summary.income), const SizedBox(width: 14), small('结余', summary.remaining)]),
      ]),
    );
  }
}

class _BudgetStrip extends ConsumerWidget {
  const _BudgetStrip({required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(personalBudgetProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BudgetPage()));
        ref.invalidate(personalBudgetProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: budget.when(
          loading: () => const Text('预算加载中…'),
          error: (_, __) => const Text('预算暂不可用，点此查看'),
          data: (usage) => Column(children: [
            Row(children: [
              Expanded(child: Text('月度预算', style: TextStyle(color: PersonalStyle.secondary(context), fontSize: 13))),
              Flexible(
                child: Text(
                  usage == null ? '设置预算 ›' : '${usage.remaining < 0 ? '超出' : '剩余'} $symbol ${_money(usage.remaining.abs())}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: PersonalStyle.secondary(context), fontSize: 13),
                ),
              ),
            ]),
            if (usage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: usage.rate.clamp(0.0, 1.0).toDouble(),
                  minHeight: 5,
                  color: PersonalStyle.honey,
                  backgroundColor: PersonalStyle.divider(context),
                  semanticsLabel: '预算已使用',
                  semanticsValue: '${(usage.rate * 100).round()}%',
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PersonalTransactionRow extends ConsumerWidget {
  const _PersonalTransactionRow({required this.row});
  final PersonalTransaction row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = row.t;
    final title = tx.note?.trim();
    final category = tx.type == 'transfer' ? '转账' : row.category?.name ?? '未分类';
    final currency = tx.currencyCode ?? row.account?.currency ??
        ref.watch(currentLedgerProvider).valueOrNull?.currency ?? 'CNY';
    final sign = tx.type == 'expense' ? '−' : tx.type == 'income' ? '+' : '';
    return InkWell(
      onTap: () => TransactionEditUtils.editTransaction(context, ref, tx, row.category),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PersonalStyle.divider(context)))),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: PersonalStyle.surface(context), borderRadius: BorderRadius.circular(13)),
            child: Center(child: tx.type == 'transfer'
                ? const Icon(Icons.swap_horiz_rounded, size: 20)
                : CategoryIconWidget(category: row.category, size: 20, color: PersonalStyle.text(context))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title == null || title.isEmpty ? category : title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text([category, if (row.account != null) row.account!.name, if (tx.excludeFromStats) '不计收支'].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: PersonalStyle.secondary(context))),
          ])),
          const SizedBox(width: 8),
          Flexible(child: Text('$sign${getCurrencySymbol(currency)} ${_money(tx.amount)}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary, required this.symbol});
  final PersonalSummary summary;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final groups = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (groups.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('这个月还没有计入统计的支出。'));
    return PersonalCard(child: Column(children: [
      for (var i = 0; i < groups.length; i++) ...[
        if (i > 0) const SizedBox(height: 22),
        Row(children: [Expanded(child: Text(groups[i].key)), const SizedBox(width: 8), Text('$symbol ${_money(groups[i].value)}')]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: summary.expense > 0 ? (groups[i].value / summary.expense).clamp(0.0, 1.0).toDouble() : 0,
          minHeight: 5, color: PersonalStyle.honey, backgroundColor: PersonalStyle.divider(context),
          semanticsLabel: groups[i].key,
          semanticsValue: '${_money(groups[i].value)}，占支出 ${summary.expense > 0 ? (groups[i].value / summary.expense * 100).round() : 0}%',
        ),
      ],
    ]));
  }
}

class PersonalMinePage extends ConsumerWidget {
  const PersonalMinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget link(IconData icon, String label, Widget destination) => ListTile(
          leading: Icon(icon, color: PersonalStyle.text(context), size: 21),
          title: Text(label),
          trailing: Icon(Icons.chevron_right_rounded, color: PersonalStyle.secondary(context), size: 20),
          onTap: () => _open(context, destination),
          contentPadding: EdgeInsets.zero,
        );
    final mode = ref.watch(themeModeProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const PersonalHeading(title: '我的小账本。', kicker: 'PERSONAL'),
          PersonalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded),
            const SizedBox(height: 12),
            const Text('一个人的生活，也值得认真记录。', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 7),
            Text('个人简约版', style: TextStyle(color: PersonalStyle.secondary(context), fontSize: 13)),
          ])),
          const SizedBox(height: 18),
          PersonalCard(child: Column(children: [
            link(Icons.account_balance_wallet_outlined, '账户管理', const AccountsPage()),
            link(Icons.book_outlined, '我的账本', const LedgersPageNew()),
            link(Icons.pie_chart_outline_rounded, '预算管理', const BudgetPage()),
            link(Icons.folder_outlined, '数据与备份', const DataManagementPage()),
            link(Icons.cloud_outlined, '同步设置', const CloudServicePage()),
          ])),
          const SizedBox(height: 18),
          PersonalCard(child: Column(children: [
            link(Icons.auto_awesome_outlined, '智能记账', const SmartBillingPage()),
            link(Icons.fingerprint_rounded, '隐私与应用锁', const AppLockSettingsPage()),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.contrast_rounded, color: PersonalStyle.text(context)),
              title: const Text('外观'),
              trailing: DropdownButton<ThemeMode>(
                value: mode, underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                ],
                onChanged: (value) { if (value != null) ref.read(themeModeProvider.notifier).state = value; },
              ),
            ),
            link(Icons.info_outline_rounded, '关于 BeeCount', const AboutPage()),
          ])),
          const SizedBox(height: 24),
          Text('基于 BeeCount · TNT-Likely / sunxiao\n个人定制，保留原项目版权与许可。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: PersonalStyle.secondary(context))),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
