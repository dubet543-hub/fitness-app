import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Explore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
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
            const SizedBox(height: 24),
            const SectionHeader('Categories'),
            const SizedBox(height: 14),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _CategoryChip(icon: Icons.fitness_center_rounded,  label: 'Strength', color: Color(0xFF38BDF8)),
                  _CategoryChip(icon: Icons.directions_run_rounded,   label: 'Cardio',   color: Color(0xFFFB923C)),
                  _CategoryChip(icon: Icons.self_improvement_rounded, label: 'Mobility', color: Color(0xFF34D399)),
                  _CategoryChip(icon: Icons.sports_cricket_rounded,   label: 'Cricket',  color: Color(0xFFC084FC)),
                  _CategoryChip(icon: Icons.sports_soccer_rounded,    label: 'Football', color: Color(0xFFFBBF24)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader('Trending Drills'),
            const SizedBox(height: 14),
            _DrillCard(title: 'Hip Hinge Pattern',   category: 'Mobility',  level: 'Intermediate', color: const Color(0xFF34D399)),
            const SizedBox(height: 10),
            _DrillCard(title: 'Sprint Acceleration', category: 'Cardio',    level: 'Advanced',     color: const Color(0xFFFB923C)),
            const SizedBox(height: 10),
            _DrillCard(title: 'Thoracic Rotation',   category: 'Strength',  level: 'Beginner',     color: const Color(0xFF38BDF8)),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _CategoryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
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
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final String title, category, level;
  final Color  color;
  const _DrillCard({required this.title, required this.category, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.play_arrow_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(category, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                    const Text(' · ', style: TextStyle(fontSize: 11, color: kTextMuted)),
                    Text(level, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextMuted),
        ],
      ),
    );
  }
}
