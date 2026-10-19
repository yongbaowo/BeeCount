import 'package:beecount/config/personal_edition.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/models/personal_summary.dart';
import 'package:beecount/pages/personal/personal_pages.dart';
import 'package:beecount/pages/personal/personal_style.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/shared_ledger_providers.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PersonalTransaction row(String type, double amount,
        {bool excluded = false, double? nativeAmount}) =>
    (
      t: Transaction(
        id: 1,
        ledgerId: 1,
        type: type,
        amount: amount,
        happenedAt: DateTime(2026, 10, 19),
        excludeFromStats: excluded,
        excludeFromBudget: false,
        nativeAmount: nativeAmount,
      ),
      category: null,
      account: null,
      toAccount: null,
    );

void main() {
  test('ledger totals omit transfers and flags, use saved currency conversion', () {
    final summary = PersonalSummary([
      row('income', 5000),
      row('expense', 100),
      row('expense', 1000, nativeAmount: 48.5),
      row('expense', 900, excluded: true),
      row('income', 900, excluded: true),
      row('transfer', 3000),
    ]);
    expect(summary.income, 5000);
    expect(summary.expense, 148.5);
    expect(summary.remaining, 4851.5);
    expect(summary.byCategory, {'未分类': 148.5});
    expect(PersonalSummary([]).expense, 0);
  });

  test('personal sharing queries never initialize the cloud connection', () async {
    expect(personalEdition, isTrue);
    expect(sharedLedgersEnabled, isFalse);
    expect(requireSharedLedgers, throwsUnsupportedError);
    final container = ProviderContainer(overrides: [
      beecountCloudProviderInstance.overrideWith((ref) async {
        fail('Personal sharing must not access a cloud connection');
      }),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(ledgerMembersProvider('ledger').future), isEmpty);
    expect(await container.read(ledgerInvitesProvider('ledger').future), isEmpty);
    expect(await container.read(memberStatsProvider(const MemberStatsKey(ledgerId: 'ledger')).future), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('personal navigation fits $width / $brightness and responds', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = -1;
        var added = false;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: const SizedBox.expand(
              key: ValueKey('page-body'),
              child: Center(child: Text('页面内容')),
            ),
            bottomNavigationBar: PersonalBottomBar(
              index: 0,
              onSelect: (value) => selected = value,
              onAdd: () => added = true,
            ),
          ),
        ));
        final bodyRect = tester.getRect(find.byKey(const ValueKey('page-body')));
        final barRect = tester.getRect(find.byType(PersonalBottomBar));
        // Regression: the unconstrained Center formerly grew to the viewport,
        // consuming the entire Scaffold and hiding all page content.
        expect(bodyRect.height, greaterThan(600));
        expect(barRect.height, lessThan(120));
        expect(barRect.top, greaterThan(700));
        expect(find.text('页面内容').hitTestable(), findsOneWidget);
        await tester.tap(find.text('统计'));
        expect(selected, 1);
        await tester.tap(find.byTooltip('记一笔'));
        expect(added, isTrue);
        await tester.tap(find.text('我的'));
        expect(selected, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('home displays live values and month controls', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        personalTransactionsProvider.overrideWith((ref) => Stream.value([
          row('income', 5000), row('expense', 32),
        ])),
        currentLedgerProvider.overrideWith((ref) => Stream.value(null)),
        personalBudgetProvider.overrideWith((ref) async => null),
        personalSelectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
      ],
      child: MaterialApp(home: Scaffold(
        body: const PersonalOverviewPage(),
        bottomNavigationBar: PersonalBottomBar(
          index: 0, onSelect: (_) {}, onAdd: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('¥ 32.00'), findsOneWidget);
    expect(find.text('¥ 32.00').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byType(PersonalOverviewPage)).height,
        greaterThan(600));
    expect(find.text('¥ 4,968.00'), findsOneWidget);
    expect(find.text('2026 年 10 月'), findsOneWidget);
    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 9 月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
