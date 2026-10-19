import '../data/db.dart';

typedef PersonalTransaction = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount,
});

/// Matches the existing ledger statistics: transfers and excluded entries are
/// not income/expense, and foreign-currency entries use their saved conversion.
class PersonalSummary {
  PersonalSummary(Iterable<PersonalTransaction> rows) {
    for (final row in rows) {
      final tx = row.t;
      if (tx.excludeFromStats) continue;
      final amount = tx.nativeAmount ?? tx.amount;
      if (tx.type == 'income') income += amount;
      if (tx.type == 'expense') {
        expense += amount;
        final category = row.category?.name ?? '未分类';
        byCategory.update(category, (value) => value + amount,
            ifAbsent: () => amount);
      }
    }
  }

  double income = 0;
  double expense = 0;
  double get remaining => income - expense;
  final Map<String, double> byCategory = {};
}
