import 'dart:ui' show Locale;

import 'package:beecount/config/personal_startup.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh install seeds Chinese CNY flat categories without welcome', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await initializePersonalStartup(db, prefs);
    expect(prefs.getString('selected_language'), 'zh');
    expect(prefs.getString('selected_currency'), 'CNY');
    expect(prefs.getString('baseCurrency'), 'CNY');
    expect(prefs.getString('category_mode'), 'flat');
    expect(prefs.getBool('reminder_enabled'), isFalse);
    expect(prefs.getBool('welcome_shown'), isTrue);
    final ledgers = await db.select(db.ledgers).get();
    final categories = await db.select(db.categories).get();
    expect(ledgers, hasLength(1));
    expect(ledgers.single.currency, 'CNY');
    expect(categories, isNotEmpty);
    expect(categories.every((c) => c.level == 1 && c.parentId == null), isTrue);
    expect(categories.any((c) => c.name == '餐饮'), isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(welcomeCheckProvider.future), isFalse);
    expect(container.read(shouldShowWelcomeProvider), isFalse);

    // Reopening must neither duplicate seed data nor undo later preferences.
    await prefs.setString('selected_language', 'en');
    await prefs.setString('baseCurrency', 'USD');
    await prefs.setBool('reminder_enabled', true);
    await initializePersonalStartup(db, prefs);
    expect(await db.select(db.ledgers).get(), hasLength(1));
    expect(await db.select(db.categories).get(), hasLength(categories.length));
    expect(prefs.getString('selected_language'), 'en');
    expect(prefs.getString('baseCurrency'), 'USD');
    expect(prefs.getBool('reminder_enabled'), isTrue);
  });

  test('upgrade preserves existing ledger, currency and hierarchical categories', () async {
    SharedPreferences.setMockInitialValues({
      'welcome_shown': true,
      'selected_currency': 'USD',
      'baseCurrency': 'USD',
      'category_mode': 'hierarchical',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.ensureSeed(
      l10n: lookupAppLocalizations(const Locale('en')),
      currency: 'USD',
      useHierarchicalCategories: true,
    );
    final before = await db.select(db.categories).get();
    final ledger = (await db.select(db.ledgers).get()).single;
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      ledgerId: ledger.id,
      type: 'expense',
      amount: 12.5,
      happenedAt: Value(DateTime(2026, 10, 19)),
    ));
    await initializePersonalStartup(db, prefs);
    expect(prefs.getString('selected_language'), 'zh');
    expect(prefs.getString('baseCurrency'), 'USD');
    expect(prefs.getString('category_mode'), 'hierarchical');
    expect((await db.select(db.ledgers).get()).single.currency, 'USD');
    final after = await db.select(db.categories).get();
    expect(after.map((c) => c.toJson()), before.map((c) => c.toJson()));
    expect((await db.select(db.transactions).get()).single.amount, 12.5);
  });
}
