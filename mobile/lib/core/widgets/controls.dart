import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dota/rank.dart';
import '../theme/app_typography.dart';
import '../theme/theme_context.dart';

/// Перемикач з кількох рівноправних варіантів: обраний залитий манго.
/// Сортування мети, період у профілі.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({super.key, required this.values, required this.selected, required this.label, required this.onChanged});

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(m.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(m.radiusSm + 1),
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: m.motionFast,
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: value == selected ? colors.mango : Colors.transparent,
                      borderRadius: BorderRadius.circular(m.radiusSm + 1),
                    ),
                    child: Text(
                      label(value),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: context.text.labelMedium?.copyWith(
                        color: value == selected ? colors.ink : colors.textMuted,
                        fontWeight: value == selected ? FontWeight.w600 : FontWeight.w500,
                        fontVariations: wght(value == selected ? FontWeight.w600 : FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Чип рангу в шапці: показує обраний ранг і відкриває список.
class RankChip extends ConsumerWidget {
  const RankChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(rankProvider);
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Ранг: ${rank.label}. Змінити',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showRankPicker(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: colors.mangoSoft, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.military_tech_rounded, size: 16, color: colors.mango),
              const SizedBox(width: 4),
              Text(rank.short, style: context.text.labelMedium?.copyWith(color: colors.mango)),
              Icon(Icons.expand_more_rounded, size: 16, color: colors.mango),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showRankPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final selected = ref.watch(rankProvider);
        final m = context.metrics;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: m.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space1),
                  child: Text('Ранг', style: context.text.titleMedium),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(m.space4, 0, m.space4, m.space2),
                  child: Text(
                    'Вінрейт, пікрейт і тіри рахуються за матчами цього рангу. AI-білд один для всіх рангів.',
                    style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                  ),
                ),
                RadioGroup<Rank>(
                  groupValue: selected,
                  onChanged: (rank) {
                    if (rank != null) ref.read(rankProvider.notifier).select(rank);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Column(
                    children: [
                      for (final rank in Rank.values)
                        RadioListTile<Rank>(
                          value: rank,
                          dense: true,
                          activeColor: context.colors.mango,
                          title: Text(rank.label, style: context.text.bodyLarge),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
