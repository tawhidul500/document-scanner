import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../l10n/app_localizations.dart';

/// Uses the supplied six-second animation, including its animated loader.
/// Plays one complete cycle at 1.5x before startup can navigate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.progress, this.onAnimationComplete});
  final double? progress;
  final VoidCallback? onAnimationComplete;

  static const animationAsset = 'assets/splash/opening_animation.json';
  static const topColor = Color(0xFF2468DC);
  static const middleColor = Color(0xFF1C59C1);
  static const bottomColor = Color(0xFF0C3585);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool completionReported = false;
  static const topColor = SplashScreen.topColor;
  static const middleColor = SplashScreen.middleColor;
  static const bottomColor = SplashScreen.bottomColor;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) finishAnimation();
      });
  }

  void finishAnimation() {
    if (completionReported) return;
    completionReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAnimationComplete?.call();
    });
  }

  void updatePlayback() {
    if (MediaQuery.of(context).disableAnimations) {
      controller.stop();
      controller.value = 1;
      finishAnimation();
    } else if (controller.duration != null && !completionReported && !controller.isAnimating) {
      controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updatePlayback();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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
        value: widget.progress == null ? null
            : '${(widget.progress!.clamp(0.0, 1.0) * 100).round()}%',
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
                          SplashScreen.animationAsset,
                          key: const ValueKey('opening-animation'),
                          fit: BoxFit.contain,
                          controller: controller,
                          repeat: false,
                          onLoaded: (composition) {
                            controller.duration = Duration(
                              microseconds: (composition.duration.inMicroseconds / 1.5).round(),
                            );
                            updatePlayback();
                          },
                          animate: !MediaQuery.of(context).disableAnimations,
                          delegates: context.englishLayout ? null : LottieDelegates(
                            values: [
                              for (final layer in ['Title', 'Tagline', 'Loading text'])
                                ValueDelegate.opacity([layer], value: 0),
                            ],
                          ),
                          errorBuilder: (_, error, stack) {
                            // A missing/corrupt animation must not block startup.
                            finishAnimation();
                            return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: AppText('Document Scanner',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 28)),
                            ),
                          );
                          },
                        ),
                      ),
                    ),
                    // English lettering in the upload consists of vector paths.
                    // Localize only these labels; keep all animation in every locale.
                    if (!context.englishLayout) ...[
                      caption('Document Scanner', top: 484, height: 56,
                          size: 28, weight: FontWeight.w700),
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
