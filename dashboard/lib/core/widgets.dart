import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shop_core/shop_core.dart';

String formatDate(DateTime? d) =>
    d == null ? '' : DateFormat('d MMM yyyy, HH:mm').format(d.toLocal());

Color statusColor(OrderStatus s) => switch (s) {
      OrderStatus.pending => Colors.orange.shade800,
      OrderStatus.confirmed => Colors.blue.shade700,
      OrderStatus.shipped => Colors.indigo.shade600,
      OrderStatus.delivered => Colors.green.shade700,
      OrderStatus.cancelled => Colors.red.shade700,
    };

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(status.label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.failure, {super.key, required this.onRetry});
  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(failure is NetworkFailure || failure is ServiceUnavailableFailure ? Icons.cloud_off : Icons.error_outline,
              size: 48),
          const SizedBox(height: 12),
          Text(failure.message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
        ]),
      );
}

/// Red box for a failure shown inside forms and dialogs.
class FailureBox extends StatelessWidget {
  const FailureBox(this.failure, {super.key});
  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    var text = failure.message;
    final f = failure;
    if (f is RateLimitedFailure && f.retryAfter != null) text += ' (try again in ${f.retryAfter!.inSeconds} s)';
    if (f is ServiceUnavailableFailure) text += ' Nothing was saved.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: s.onErrorContainer)),
    );
  }
}

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
