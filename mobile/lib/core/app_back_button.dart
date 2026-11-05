import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button for pushed screens. Pops when there is a screen to return to;
/// otherwise (deep link, or reached via `context.go`) falls back to [fallback]
/// so the user is never stranded without a way back.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/'});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      },
    );
  }
}
