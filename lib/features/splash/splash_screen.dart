import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../l10n/app_localizations.dart';

/// Uses the supplied six-second animation, including its animated loader.
/// Real startup completion controls navigation, independently of the loop.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.progress});
  final double? progress;

  static const animationAsset = 'assets/splash/opening_animation.json';
  static const topColor = Color(0xFF2468DC);
  static const middleColor = Color(0xFF1C59C1);
  static const bottomColor = Color(0xFF0C3585);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: bottomColor,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: topColor,
      body: Semantics(
        key: const ValueKey('startup-progress'),
        label: context.tr('Loading saved documents'),
        value: progress == null ? null
            : '${(progress!.clamp(0.0, 1.0) * 100).round()}%',
        child: LayoutBuilder(builder: (context, box) {
          final scale = math.min(box.maxWidth / 375, box.maxHeight / 812);
          final top = (box.maxHeight - 812 * scale) / 2;
          // Extend the animation's own background without stretching artwork,
          // cropping its footer, or showing a frame on other aspect ratios.
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [topColor, topColor, middleColor, bottomColor, bottomColor],
                stops: [0, top / box.maxHeight,
                  (top + 812 * scale * .55) / box.maxHeight,
                  (top + 812 * scale) / box.maxHeight, 1],
              ),
            ),
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  key: const ValueKey('opening-artboard'),
                  width: 375,
                  height: 812,
                  child: Stack(children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: Lottie.asset(
                          animationAsset,
                          key: const ValueKey('opening-animation'),
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: !MediaQuery.of(context).disableAnimations,
                          delegates: context.englishLayout ? null : LottieDelegates(
                            values: [
                              for (final layer in ['Title', 'Tagline', 'Loading text'])
                                ValueDelegate.opacity([layer], value: 0),
                            ],
                          ),
                          errorBuilder: (_, error, stack) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: AppText('Document Scanner',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 28)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // English lettering in the upload consists of vector paths.
                    // Localize only these labels; keep all animation in every locale.
                    if (!context.englishLayout) ...[
                      caption('Document Scanner', top: 484, height: 56,
                          size: 28, weight: FontWeight.w600),
                      caption('Scan faster, work smarter', top: 538, height: 40,
                          size: 13),
                      caption('Loading saved documents', top: 716, height: 40,
                          size: 12),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );

  Widget caption(String text, {required double top, required double height,
      required double size, FontWeight weight = FontWeight.w400}) => Positioned(
    left: 24, right: 24, top: top, height: height,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: 327, child: AppText(text,
        textAlign: TextAlign.center, maxLines: 2,
        style: TextStyle(color: Colors.white, fontSize: size, fontWeight: weight))),
    ),
  );
}
