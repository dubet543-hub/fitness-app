import 'package:flutter/material.dart';
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

/// The SolidCore mark: chrome ribbon with a teal highlight, drawn for display
/// on a dark surface (same treatment as the app icon). On the light palette's
/// near-white backgrounds the pale highlights wash out to almost nothing, so
/// this always seats the artwork on a fixed dark plate rather than the
/// theme's (possibly light) page background.
class BrandLogo extends StatelessWidget {
  final double width;
  const BrandLogo({super.key, required this.width});

  static const _plate = Color(0xFF0D1117);

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: width * 0.08),
    decoration: BoxDecoration(
      color: _plate,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Image.asset('assets/images/solidcore_logo.png', width: width),
  );
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
