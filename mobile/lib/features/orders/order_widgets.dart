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
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// pending -> confirmed -> shipped -> delivered, or a cancelled banner.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline(this.status, {super.key, this.stockReturnPending = false});
  final OrderStatus status;

  /// Cancelled while the stock service was down: items are not back in stock yet.
  final bool stockReturnPending;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.shipped,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel, color: statusColor(status)),
          const SizedBox(width: 8),
          Text(
            stockReturnPending
                ? 'This order was cancelled. Reserved items will be returned to stock shortly.'
                : 'This order was cancelled. Reserved items were returned to stock.',
            style: TextStyle(color: statusColor(status)),
          ),
        ].map((w) => w is Text ? Expanded(child: w) : w).toList(),
      );
    }
    final current = _steps.indexOf(status);
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            children: [
              Icon(
                i <= current
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: i <= current ? statusColor(_steps[i]) : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                _steps[i].label,
                style: TextStyle(
                  fontWeight: i == current
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: i <= current ? null : Colors.grey,
                ),
              ),
            ],
          ).withPadding(const EdgeInsets.symmetric(vertical: 6)),
      ],
    );
  }
}

extension on Widget {
  Widget withPadding(EdgeInsets p) => Padding(padding: p, child: this);
}
