import 'package:flutter/material.dart';

abstract final class PersonalStyle {
  static const honey = Color(0xFFF2D56C);
  static const ink = Color(0xFF20241F);

  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      dark(context) ? const Color(0xFF171817) : const Color(0xFFF5F5F2);
  static Color surface(BuildContext context) =>
      dark(context) ? const Color(0xFF242524) : Colors.white;
  static Color text(BuildContext context) =>
      dark(context) ? const Color(0xFFF2F3ED) : ink;
  static Color secondary(BuildContext context) =>
      dark(context) ? const Color(0xFFA5ACA0) : const Color(0xFF747970);
  static Color divider(BuildContext context) =>
      dark(context) ? const Color(0xFF353832) : const Color(0xFFE8EAE3);
}

class PersonalCard extends StatelessWidget {
  const PersonalCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PersonalStyle.surface(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      );
}

class PersonalHeading extends StatelessWidget {
  const PersonalHeading({super.key, required this.title, required this.kicker});
  final String title;
  final String kicker;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker,
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: PersonalStyle.secondary(context))),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    color: PersonalStyle.text(context))),
          ],
        ),
      );
}

class PersonalBottomBar extends StatelessWidget {
  const PersonalBottomBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  Widget _tab(BuildContext context, int value, IconData icon, String label) =>
      Expanded(
        child: Semantics(
          selected: index == value,
          child: TextButton(
            onPressed: () => onSelect(value),
            style: TextButton.styleFrom(
              foregroundColor: index == value
                  ? PersonalStyle.text(context)
                  : PersonalStyle.secondary(context),
              minimumSize: const Size(48, 58),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: PersonalStyle.surface(context),
          border: Border(top: BorderSide(color: PersonalStyle.divider(context))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              _tab(context, 0, Icons.receipt_long_outlined, '明细'),
              _tab(context, 1, Icons.bar_chart_rounded, '统计'),
              Expanded(
                child: Center(
                  child: IconButton.filled(
                    tooltip: '记一笔',
                    onPressed: onAdd,
                    style: IconButton.styleFrom(
                      backgroundColor: PersonalStyle.honey,
                      foregroundColor: PersonalStyle.ink,
                      minimumSize: const Size(50, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 27),
                  ),
                ),
              ),
              _tab(context, 3, Icons.person_outline_rounded, '我的'),
            ]),
          ),
        ),
      );
}

class PersonalOnlyPage extends StatelessWidget {
  const PersonalOnlyPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('个人账本')),
        body: const Center(child: Text('此版本仅支持个人账本')),
      );
}
