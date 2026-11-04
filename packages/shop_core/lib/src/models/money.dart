import 'package:equatable/equatable.dart';

/// Amount of money stored as whole cents. The API sends prices as strings
/// ("12.00"); never use `double` for money.
class Money extends Equatable implements Comparable<Money> {
  const Money(this.cents);

  static const zero = Money(0);

  final int cents;

  /// Parses "12", "12.5" or "12.50".
  factory Money.parse(Object? value) {
    final text = (value ?? '0').toString().trim();
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2})\d*)?$').firstMatch(text);
    if (match == null) return Money.zero;
    final whole = int.parse(match.group(2)!);
    final frac = int.parse((match.group(3) ?? '0').padRight(2, '0'));
    final cents = whole * 100 + frac;
    return Money(match.group(1) == '-' ? -cents : cents);
  }

  Money operator +(Money o) => Money(cents + o.cents);
  Money operator *(int n) => Money(cents * n);

  /// "$12.00"
  @override
  String toString() {
    final abs = cents.abs();
    final s = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    return cents < 0 ? '-\$$s' : '\$$s';
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  List<Object?> get props => [cents];
}
