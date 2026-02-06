import 'package:flutter/material.dart';

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.balanceLabel,
    this.secondaryBalanceLabel,
    required this.leadingIcon,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String balanceLabel;
  final String? secondaryBalanceLabel;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(leadingIcon, color: cs.primary),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.trim().isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            balanceLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (secondaryBalanceLabel != null)
            Text(
              secondaryBalanceLabel!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
