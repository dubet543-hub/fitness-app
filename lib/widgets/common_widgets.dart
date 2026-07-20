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
