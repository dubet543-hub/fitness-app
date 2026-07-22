import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';

class AvatarWidget extends StatelessWidget {
  final String  name;
  final String? photoUrl;
  final double  radius;

  const AvatarWidget({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final url      = (photoUrl ?? '').trim();
    final hasPhoto = url.isNotEmpty;
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: kCard,
        backgroundImage: hasPhoto ? NetworkImage(url) : null,
        child: !hasPhoto
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.65,
                ),
              )
            : null,
      ),
    );
  }
}

/// Shown in place of the camera preview when it couldn't start — most
/// commonly because camera access was denied. When [showSettingsButton] is
/// true (permission permanently denied, so the OS won't show its prompt
/// again) an "Open Settings" button deep-links straight to the app's system
/// settings page; [onRetry] re-attempts camera init, e.g. after the user
/// grants access and returns to the app.
class CameraErrorView extends StatelessWidget {
  final String message;
  final bool showSettingsButton;
  final VoidCallback onRetry;

  const CameraErrorView({
    super.key,
    required this.message,
    required this.showSettingsButton,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_rounded, size: 48, color: kTextMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (showSettingsButton)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: kOnAccent),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: kTextPrimary, side: BorderSide(color: kBorder)),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a camera preview that fills [screenSize] edge-to-edge, cropping
/// the overflow rather than stretching (which distorts anyone in frame — the
/// naive `SizedBox.expand`-style fix) or leaving it letterboxed (the default
/// if you just center [CameraPreview] with no scaling) — matching how most
/// camera apps display their live preview.
///
/// [CameraPreview] already sizes itself to the camera's true aspect ratio
/// internally (correctly inverted for portrait vs landscape) — the only job
/// here is to scale that correctly-proportioned box up until it covers
/// [screenSize], then clip the overflow. [child], if provided, is passed
/// through to [CameraPreview]'s own overlay slot so it scales identically
/// with the feed (e.g. a pose/plumb-line overlay that must stay aligned).
class FullBleedCameraPreview extends StatelessWidget {
  final CameraController controller;
  final Size screenSize;
  final Widget? child;

  const FullBleedCameraPreview({
    super.key,
    required this.controller,
    required this.screenSize,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    var scale = screenSize.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: CameraPreview(controller, child: child),
        ),
      ),
    );
  }
}

/// The SolidCore mark with a transparent background.
class BrandLogo extends StatelessWidget {
  final double width;
  const BrandLogo({super.key, required this.width});

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/solidcore_logo.png', width: width);
}

class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: kHeadlineFont,
      fontStyle: FontStyle.italic,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: kTextSecondary,
      letterSpacing: 1.4,
    ),
  );
}
