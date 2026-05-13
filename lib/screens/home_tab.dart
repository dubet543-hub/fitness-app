import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import '../posture_screen.dart';
import '../training_load_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import 'workload_monitor_screen.dart';
import 'wellness_log_screen.dart';

class HomeTab extends StatelessWidget {
  final String  name;
  final String  email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const HomeTab({
    super.key,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onLogout,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName => name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            backgroundColor: kSurface,
            elevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Image.asset('assets/images/solidcore_logo.png', height: 28),
                const SizedBox(width: 10),
                const Text(
                  'SolidCore',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: kTextPrimary, letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 20, color: kTextSecondary),
                      onPressed: () {},
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: kBorder),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              _firstName,
                              style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w800,
                                color: kTextPrimary, letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AvatarWidget(name: name, photoUrl: photoUrl, radius: 24),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kAccent.withValues(alpha: 0.15), kAccent.withValues(alpha: 0.05)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: kAccent, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Weekly Streak', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                              Text('5 days active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                          child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Features',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3),
                      ),
                      Text('See all', style: TextStyle(fontSize: 13, color: kAccent, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Posture\nAnalysis',
                  subtitle: 'Check body alignment',
                  accentColor: const Color(0xFF38BDF8),
                  gradientColors: const [Color(0xFF0C2A4A), Color(0xFF071829)],
                  onTap: () => Navigator.push(context, _route(const PostureGuideScreen())),
                ),
                _FeatureCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Training\nLoad',
                  subtitle: 'Monitor workload',
                  accentColor: const Color(0xFF34D399),
                  gradientColors: const [Color(0xFF063A20), Color(0xFF032513)],
                  onTap: () => Navigator.push(context, _route(const TrainingLoadScreen())),
                ),
                _FeatureCard(
                  icon: Icons.directions_run_rounded,
                  title: 'Running\nAnalysis',
                  subtitle: 'Improve running form',
                  accentColor: const Color(0xFFFB923C),
                  gradientColors: const [Color(0xFF4A1500), Color(0xFF2E0D00)],
                  onTap: () => Navigator.push(context, _route(const RunningAnalysisScreen())),
                ),
                _FeatureCard(
                  icon: Icons.sports_cricket_rounded,
                  title: 'Bowling\nAnalysis',
                  subtitle: 'Perfect technique',
                  accentColor: const Color(0xFFC084FC),
                  gradientColors: const [Color(0xFF2D0A52), Color(0xFF1C0635)],
                  onTap: () => Navigator.push(context, _route(const BowlingAnalysisScreen())),
                ),
                _FeatureCard(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Workload\nMonitor',
                  subtitle: 'Training · Skill · Total load',
                  accentColor: const Color(0xFFFF6B35),
                  gradientColors: const [Color(0xFF3A1200), Color(0xFF210A00)],
                  onTap: () => Navigator.push(context, _route(const WorkloadMonitorScreen())),
                ),
                _FeatureCard(
                  icon: Icons.health_and_safety_rounded,
                  title: 'Wellness\nLog',
                  subtitle: 'Sleep · Mood · Fatigue',
                  accentColor: const Color(0xFF818CF8),
                  gradientColors: const [Color(0xFF1E1B4B), Color(0xFF0F0D2E)],
                  onTap: () => Navigator.push(context, _route(const WellnessLogScreen())),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),

            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Sessions',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3),
                  ),
                  Text('All', style: TextStyle(fontSize: 13, color: kAccent, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _RecentSessionCard(
                  icon: Icons.directions_run_rounded,
                  color: const Color(0xFFFB923C),
                  title: 'Running Analysis',
                  subtitle: 'Stride length · Cadence · Ground contact',
                  time: '2h ago',
                  score: '87',
                ),
                const SizedBox(height: 10),
                _RecentSessionCard(
                  icon: Icons.accessibility_new_rounded,
                  color: const Color(0xFF38BDF8),
                  title: 'Posture Check',
                  subtitle: 'Shoulder · Spine · Hip alignment',
                  time: 'Yesterday',
                  score: '92',
                ),
                const SizedBox(height: 10),
                _RecentSessionCard(
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFF34D399),
                  title: 'Training Load',
                  subtitle: 'Volume · Intensity · Recovery',
                  time: '2d ago',
                  score: '78',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Route _route(Widget screen) => MaterialPageRoute(builder: (_) => screen);
}

class _FeatureCard extends StatelessWidget {
  final IconData    icon;
  final String      title;
  final String      subtitle;
  final Color       accentColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w800,
                fontSize: 15, height: 1.2, letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Open', style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 11, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  final String   time;
  final String   score;

  const _RecentSessionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(score, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
