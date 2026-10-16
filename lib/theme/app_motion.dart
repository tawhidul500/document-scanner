import 'package:flutter/material.dart';

/// Shared timings with support for the device's reduced-motion preference.
abstract final class AppMotion {
  static const curve = Curves.easeInOutCubic;
  static Duration duration(BuildContext context, {int milliseconds = 220}) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: milliseconds);
}

/// Subtle motion for Material routes; Cupertino routes keep native back gestures.
class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final eased = animation.drive(CurveTween(curve: AppMotion.curve));
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .025), end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}
