import 'package:flutter/material.dart';

/// A page route that slides up from the bottom of the screen instead of
/// the platform default (right-to-left push).
///
/// Used for the chat screen so opening a conversation feels like it
/// rises up from the chat list, rather than sliding in from the side.
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  SlideUpPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
                  reverseCurve: const Interval(0.6, 1.0, curve: Curves.easeIn),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Convenience helper — pushes [screen] using [SlideUpPageRoute].
Future<T?> pushSlideUp<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    SlideUpPageRoute<T>(builder: (_) => screen),
  );
}
