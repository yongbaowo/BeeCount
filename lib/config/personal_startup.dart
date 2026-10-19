import 'dart:ui' show Locale;

import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../l10n/app_localizations.dart';

/// Complete the personal edition's first-run setup before providers or UI load.
/// The marker is written last so an interrupted setup can safely be retried.
Future<void> initializePersonalStartup(
  BeeDatabase db,
  SharedPreferences prefs,
) async {
  if (prefs.getBool('personal_startup_completed') == true) return;

  final welcomeCompleted = prefs.getBool('welcome_shown') ?? false;
  if (!welcomeCompleted) {
    await prefs.setString('selected_language', 'zh');
    await prefs.remove('selected_language_country');
    await prefs.setString('selected_currency', 'CNY');
    await prefs.setString('baseCurrency', 'CNY');
    await prefs.setString('category_mode', 'flat');
    await prefs.setBool('reminder_enabled', false);

    await db.transaction(() async {
      // A previous launch may have committed the database before preferences
      // were saved. Never seed again over existing or imported data.
      final ledgers = await (db.select(db.ledgers)..limit(1)).get();
      final categories = await (db.select(db.categories)..limit(1)).get();
      if (ledgers.isEmpty && categories.isEmpty) {
        await db.ensureSeed(
          l10n: lookupAppLocalizations(const Locale('zh')),
          currency: 'CNY',
          useHierarchicalCategories: false,
          createDefaultLedger: true,
        );
      }
    });
    await prefs.setBool('welcome_shown', true);
  } else if (prefs.getString('selected_language') == null) {
    // Existing ledgers, currencies and categories are never reseeded on upgrade.
    await prefs.setString('selected_language', 'zh');
    await prefs.remove('selected_language_country');
  }

  await prefs.setBool('personal_startup_completed', true);
}
