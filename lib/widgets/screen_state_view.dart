import 'package:flutter/material.dart';

class ScreenStateView extends StatelessWidget {
  const ScreenStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  const ScreenStateView.loading({super.key, required this.title, this.message})
    : icon = Icons.hourglass_top_rounded,
      action = null;

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      children: <Widget>[
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 72,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message?.isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ],
    );
  }
}
