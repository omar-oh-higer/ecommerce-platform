import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';

/// Red box with the failure message (wrong password, rate limit, etc).
class FailureBanner extends StatelessWidget {
  const FailureBanner(this.failure, {super.key});
  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    var text = failure.message;
    final f = failure;
    if (f is RateLimitedFailure && f.retryAfter != null) {
      text = '$text (try again in ${f.retryAfter!.inSeconds} s)';
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}

/// Shown after the token expired and could not be refreshed.
class SessionExpiredBanner extends StatelessWidget {
  const SessionExpiredBanner({super.key});
  @override
  Widget build(BuildContext context) => const FailureBanner(
    UnauthenticatedFailure('Your session has expired. Please sign in again.'),
  );
}
