import 'package:flutter/material.dart';
import '../core/theme.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text(
          'EXPLORE',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: const TextField(
                style: TextStyle(color: kTextPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search exercises, drills...',
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: kTextSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Categories ──────────────────────────────────────
            const _SectionLabel('CATEGORIES'),
            const SizedBox(height: 14),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _CategoryChip(icon: Icons.fitness_center_rounded,  label: 'Strength', color: Color(0xFF38BDF8)),
                  _CategoryChip(icon: Icons.directions_run_rounded,   label: 'Cardio',   color: Color(0xFFFF6B35)),
                  _CategoryChip(icon: Icons.self_improvement_rounded, label: 'Mobility', color: kAccent),
                  _CategoryChip(icon: Icons.sports_cricket_rounded,   label: 'Cricket',  color: Color(0xFFA78BFA)),
                  _CategoryChip(icon: Icons.sports_soccer_rounded,    label: 'Football', color: Color(0xFFF59E0B)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Trending Drills ──────────────────────────────────
            const _SectionLabel('TRENDING DRILLS'),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [
                  _DrillRow(title: 'Hip Hinge Pattern',   category: 'Mobility',  level: 'Intermediate', color: kAccent),
                  const Divider(height: 1, indent: 58, color: kBorder),
                  _DrillRow(title: 'Sprint Acceleration', category: 'Cardio',    level: 'Advanced',     color: const Color(0xFFFF6B35)),
                  const Divider(height: 1, indent: 58, color: kBorder),
                  _DrillRow(title: 'Thoracic Rotation',   category: 'Strength',  level: 'Beginner',     color: const Color(0xFF38BDF8)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
  );
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _CategoryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10.5, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DrillRow extends StatelessWidget {
  final String title, category, level;
  final Color  color;
  const _DrillRow({required this.title, required this.category, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.play_arrow_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(category, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                    const Text(' · ', style: TextStyle(fontSize: 11, color: kTextMuted)),
                    Text(level, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
        ],
      ),
    );
  }
}
