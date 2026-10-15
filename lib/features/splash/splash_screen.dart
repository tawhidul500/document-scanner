import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Artwork loops independently; only actual startup work advances the bar.
/// StartupScreen removes this widget immediately when initialization completes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF2468DC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2468DC), Color(0xFF1C59C1), Color(0xFF0C3585)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 375,
                height: 812,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: Lottie.asset(
                          'assets/splash/splash_animation.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: !MediaQuery.of(context).disableAnimations,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Text(
                                  'Document Scanner',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    // Matches the supplied loader: x=112..263, center y=706.
                    Positioned(
                      left: 112,
                      top: 704,
                      width: 151,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          key: const ValueKey('startup-progress'),
                          value: progress?.clamp(0.0, 1.0).toDouble(),
                          minHeight: 4,
                          color: const Color(0xF2FFFFFF),
                          backgroundColor: const Color(0x38FFFFFF),
                          semanticsLabel: 'Loading saved documents',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
