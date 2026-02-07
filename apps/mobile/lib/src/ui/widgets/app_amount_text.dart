import 'package:flutter/material.dart';

class AppAmountText extends StatelessWidget {
  const AppAmountText(
    this.text, {
    super.key,
    required this.cents,
    this.style,
    this.align = TextAlign.right,
  });

  final String text;
  final int cents;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = cents < 0;

    // Outflows are negative (red). Inflows should read as distinctly "green".
    final color = isNegative ? theme.colorScheme.error : Colors.green.shade700;

    return Text(
      text,
      textAlign: align,
      style: (style ?? theme.textTheme.titleSmall)?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
