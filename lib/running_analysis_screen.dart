import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// ── Running Metrics Data Model ────────────────────────────────────────────────

class RunningMetrics {
  final double trunkLean;
  final double kneeDriver;
  final double hipDrop;
  final double armSwing;
  final double headPosition;
  final String footStrike;
  final double cadence;
  final double overallScore;

  const RunningMetrics({
    required this.trunkLean,
    required this.kneeDriver,
    required this.hipDrop,
    required this.armSwing,
    required this.headPosition,
    required this.footStrike,
    required this.cadence,
    required this.overallScore,
  });
}

class RunningResult {
  final String label;
  final String value;
  final String status; // 'good', 'fair', 'poor'
  final String feedback;

  const RunningResult({
    required this.label,
    required this.value,
    required this.status,
    required this.feedback,
  });
}

// ── Phase Enum ────────────────────────────────────────────────────────────────

enum _AnalysisPhase { setup, recording, processing, results }

// ── Main Running Analysis Screen ──────────────────────────────────────────────

class RunningAnalysisScreen extends StatefulWidget {
  const RunningAnalysisScreen({super.key});

  @override
  State<RunningAnalysisScreen> createState() => _RunningAnalysisScreenState();
}

class _RunningAnalysisScreenState extends State<RunningAnalysisScreen> {
  late _AnalysisPhase _phase;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  Timer? _captureTimer;
  bool _isBusy = false;
  int _frameCount = 0;

  // Metrics accumulators (lists to average across frames)
  final List<double> _trunkLeans = [];
  final List<double> _kneeDrives = [];
  final List<double> _hipDrops = [];
  final List<double> _armSwings = [];
  final List<double> _headPositions = [];
  final List<String> _footStrikes = [];

  late final PoseDetector _poseDetector;
  RunningMetrics? _results;

  @override
  void initState() {
    super.initState();
    _phase = _AnalysisPhase.setup;
    _initializeCamera();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.isNotEmpty ? cameras.first : null;
      if (camera == null) {
        setState(() => _phase = _AnalysisPhase.setup);
        return;
      }

      _controller = CameraController(camera, ResolutionPreset.high);
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Camera error: $e")),
        );
      }
    }
  }

  void _startRecording() {
    _trunkLeans.clear();
    _kneeDrives.clear();
    _hipDrops.clear();
    _armSwings.clear();
    _headPositions.clear();
    _footStrikes.clear();
    _frameCount = 0;
    _isBusy = false;

    setState(() => _phase = _AnalysisPhase.recording);

    _captureTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (_isBusy || _controller == null) return;
      _isBusy = true;

      try {
        final image = await _controller!.takePicture();
        await _processFrame(image.path);
        await File(image.path).delete();
        _frameCount++;
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Frame capture error: $e");
      } finally {
        _isBusy = false;
      }
    });
  }

  void _stopRecording() {
    _captureTimer?.cancel();
    setState(() => _phase = _AnalysisPhase.processing);
    _analyzeResults();
  }

  Future<void> _processFrame(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _extractMetrics(pose);
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
    }
  }

  void _extractMetrics(Pose pose) {
    // Extract key landmarks
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final lEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rEar = pose.landmarks[PoseLandmarkType.rightEar];
    final lHeel = pose.landmarks[PoseLandmarkType.leftHeel];
    final rHeel = pose.landmarks[PoseLandmarkType.rightHeel];

    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null) {
      return;
    }

    // Calculate trunk lean (shoulder-hip angle from vertical)
    final shoulderMid = Offset((lShoulder.x + rShoulder.x) / 2,
        (lShoulder.y + rShoulder.y) / 2);
    final hipMid =
        Offset((lHip.x + rHip.x) / 2, (lHip.y + rHip.y) / 2);
    final trunkVector = Offset(shoulderMid.dx - hipMid.dx, shoulderMid.dy - hipMid.dy);
    final verticalRef = Offset(0, -1); // Vertical upward in image coords
    final trunkAngle = _angleBetweenVectors(trunkVector, verticalRef);
    _trunkLeans.add(trunkAngle);

    // Calculate knee drive (max knee height relative to hip)
    if (lKnee != null && rKnee != null) {
      final hipY = hipMid.dy;
      final lKneeHeight = (hipY - lKnee.y) / ((lHip.y - (lAnkle?.y ?? lHip.y)).abs() + 1);
      final rKneeHeight = (hipY - rKnee.y) / ((rHip.y - (rAnkle?.y ?? rHip.y)).abs() + 1);
      final avgKneeDrive = max(lKneeHeight, rKneeHeight) * 100;
      _kneeDrives.add(avgKneeDrive.clamp(0, 200));
    }

    // Calculate hip drop (vertical asymmetry)
    if (lHip != null && rHip != null) {
      final hipDiff = (lHip.y - rHip.y).abs();
      final bodyHeight = (hipMid.dy - (lShoulder.y + rShoulder.y) / 2).abs() + 1;
      final hipDropPercent = (hipDiff / bodyHeight) * 100;
      _hipDrops.add(hipDropPercent);
    }

    // Calculate arm swing (elbow angle)
    if (lElbow != null && lShoulder != null && lWrist != null) {
      final lElbowAngle =
          _angleBetweenThreePoints(lShoulder, lElbow, lWrist);
      _armSwings.add(lElbowAngle);
    }

    // Calculate head position relative to shoulder line
    if (lEar != null && rEar != null) {
      final earMid = Offset((lEar.x + rEar.x) / 2, (lEar.y + rEar.y) / 2);
      final headOffset = (earMid.dx - shoulderMid.dx).abs();
      final torsoHeight = (shoulderMid.dy - hipMid.dy).abs() + 1;
      final headDeviation = atan2(headOffset, torsoHeight) * 180 / pi;
      _headPositions.add(headDeviation);
    }

    // Determine foot strike pattern (heel vs midfoot vs forefoot)
    if (lHeel != null && lAnkle != null) {
      final heelY = lHeel.y;
      final ankleY = lAnkle.y;
      final diff = (heelY - ankleY).abs();
      if (diff > 15) {
        _footStrikes.add('heel');
      } else if (diff > 5) {
        _footStrikes.add('midfoot');
      } else {
        _footStrikes.add('forefoot');
      }
    }
  }

  void _analyzeResults() {
    final trunkLean = (_trunkLeans.isNotEmpty
        ? _trunkLeans.reduce((a, b) => a + b) / _trunkLeans.length
        : 0.0) as double;
    final kneeDrive = (_kneeDrives.isNotEmpty
        ? _kneeDrives.reduce((a, b) => a + b) / _kneeDrives.length
        : 0.0) as double;
    final hipDrop = (_hipDrops.isNotEmpty
        ? _hipDrops.reduce((a, b) => a + b) / _hipDrops.length
        : 0.0) as double;
    final armSwing = (_armSwings.isNotEmpty
        ? _armSwings.reduce((a, b) => a + b) / _armSwings.length
        : 0.0) as double;
    final headPosition = (_headPositions.isNotEmpty
        ? _headPositions.reduce((a, b) => a + b) / _headPositions.length
        : 0.0) as double;

    final footStrikeMap = <String, int>{};
    for (final strike in _footStrikes) {
      footStrikeMap[strike] = (footStrikeMap[strike] ?? 0) + 1;
    }
    final dominantStrike = footStrikeMap.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key ??
        'unknown';

    final cadence = (_frameCount > 0 ? (_frameCount / 10) * 60 : 0.0) as double;

    // Calculate overall score (0-100)
    int issueCount = 0;
    if (trunkLean > 10) issueCount += 2;
    if (trunkLean > 15) issueCount += 2;
    if (kneeDrive < 60) issueCount += 2;
    if (hipDrop > 8) issueCount += 2;
    if (armSwing.abs() - 90 > 20) issueCount += 1;
    if (headPosition > 8) issueCount += 1;

    final overallScore = max(0, 100 - (issueCount * 10)).toDouble();

    _results = RunningMetrics(
      trunkLean: trunkLean,
      kneeDriver: kneeDrive,
      hipDrop: hipDrop,
      armSwing: armSwing,
      headPosition: headPosition,
      footStrike: dominantStrike,
      cadence: cadence,
      overallScore: overallScore,
    );

    if (mounted) setState(() => _phase = _AnalysisPhase.results);
  }

  void _reset() {
    setState(() => _phase = _AnalysisPhase.setup);
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _angleBetweenVectors(Offset v1, Offset v2) {
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
    final mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy);
    if (mag1 == 0 || mag2 == 0) return 0;
    return acos((dot / (mag1 * mag2)).clamp(-1.0, 1.0)) * 180 / pi;
  }

  double _angleBetweenThreePoints(
      PoseLandmark a, PoseLandmark vertex, PoseLandmark b) {
    final v1 = Offset(a.x - vertex.x, a.y - vertex.y);
    final v2 = Offset(b.x - vertex.x, b.y - vertex.y);
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
    final mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy);
    if (mag1 == 0 || mag2 == 0) return 0;
    return acos((dot / (mag1 * mag2)).clamp(-1.0, 1.0)) * 180 / pi;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'good':
        return Colors.greenAccent;
      case 'fair':
        return Colors.yellowAccent;
      case 'poor':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getMetricStatus(String metric, double value) {
    switch (metric) {
      case 'trunk_lean':
        if (value < 5) return 'fair';
        if (value <= 10) return 'good';
        return 'poor';
      case 'knee_drive':
        if (value >= 80) return 'good';
        if (value >= 60) return 'fair';
        return 'poor';
      case 'hip_drop':
        if (value < 5) return 'good';
        if (value < 8) return 'fair';
        return 'poor';
      case 'arm_swing':
        final diff = (value - 90).abs();
        if (diff < 15) return 'good';
        if (diff < 25) return 'fair';
        return 'poor';
      case 'head_position':
        if (value < 5) return 'good';
        if (value < 10) return 'fair';
        return 'poor';
      default:
        return 'fair';
    }
  }

  String _getMetricFeedback(String metric, double value) {
    switch (metric) {
      case 'trunk_lean':
        if (value < 5) {
          return "Increase forward lean slightly for efficiency";
        } else if (value <= 10) {
          return "Excellent trunk angle—optimal for distance running";
        } else if (value <= 15) {
          return "Moderate forward lean—watch for excessive flexion";
        } else {
          return "Reduce forward lean to prevent lower back stress";
        }
      case 'knee_drive':
        if (value >= 80) {
          return "Strong knee drive—good power generation";
        } else if (value >= 60) {
          return "Adequate knee height—focus on hip flexor strength";
        } else {
          return "Low knee drive—increase hip flexor activation";
        }
      case 'hip_drop':
        if (value < 5) {
          return "Excellent pelvic stability—strong glutes";
        } else if (value < 8) {
          return "Minor hip drop—core strengthening recommended";
        } else {
          return "Significant hip drop—prioritize glute med training";
        }
      case 'arm_swing':
        if ((value - 90).abs() < 15) {
          return "Good elbow angle—efficient arm mechanics";
        } else if ((value - 90).abs() < 25) {
          return "Slightly tense arms—relax shoulder tension";
        } else {
          return "Excessive arm angle—focus on relaxed running";
        }
      case 'head_position':
        if (value < 5) {
          return "Neutral head position—good spinal alignment";
        } else if (value < 10) {
          return "Mild forward head—maintain neutral cervical spine";
        } else {
          return "Excessive forward head—look straight ahead";
        }
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Running Analysis"),
        centerTitle: true,
      ),
      body: _phase == _AnalysisPhase.setup
          ? _buildSetupPhase()
          : _phase == _AnalysisPhase.recording
              ? _buildRecordingPhase()
              : _phase == _AnalysisPhase.processing
                  ? _buildProcessingPhase()
                  : _buildResultsPhase(),
    );
  }

  // ── Setup Phase ───────────────────────────────────────────────────────────

  Widget _buildSetupPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.directions_run, size: 60, color: Colors.tealAccent),
          const SizedBox(height: 20),
          const Text(
            "Running Form Analysis",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            "Record a 10-second running session from the side view",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildInstructionCard(
            icon: Icons.videocam,
            title: "Camera Setup",
            items: [
              "Position phone at hip height",
              "Film from the side (perpendicular to running path)",
              "Ensure full body is visible",
              "Good lighting is essential",
            ],
          ),
          const SizedBox(height: 14),
          _buildInstructionCard(
            icon: Icons.directions_run,
            title: "Running Tips",
            items: [
              "Run at steady, comfortable pace",
              "Maintain natural running form",
              "Record 8-10 strides for analysis",
              "Clear background works best",
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _controller == null ? null : _startRecording,
            icon: const Icon(Icons.camera_alt),
            label: const Text("Start Recording"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.tealAccent, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Text("• ", style: TextStyle(color: Colors.tealAccent)),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Recording Phase ───────────────────────────────────────────────────────

  Widget _buildRecordingPhase() {
    return _controller == null
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Recording Running Form",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.fiber_manual_record,
                                  color: Colors.redAccent, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                "Frames: $_frameCount",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.timer, color: Colors.tealAccent, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                "${(_frameCount * 0.2).toStringAsFixed(1)}s",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    children: [
                      FloatingActionButton(
                        onPressed: _stopRecording,
                        backgroundColor: Colors.redAccent,
                        child: const Icon(Icons.stop),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Tap to stop",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }

  // ── Processing Phase ──────────────────────────────────────────────────────

  Widget _buildProcessingPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.tealAccent),
          const SizedBox(height: 20),
          Text(
            "Analyzing $_frameCount frames...",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Results Phase ─────────────────────────────────────────────────────────

  Widget _buildResultsPhase() {
    if (_results == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final metrics = [
      ('trunk_lean', 'Trunk Lean', "${_results!.trunkLean.toStringAsFixed(1)}°"),
      ('knee_drive', 'Knee Drive', "${_results!.kneeDriver.toStringAsFixed(0)}%"),
      ('hip_drop', 'Hip Drop', "${_results!.hipDrop.toStringAsFixed(1)}%"),
      ('arm_swing', 'Arm Swing', "${_results!.armSwing.toStringAsFixed(1)}°"),
      ('head_position', 'Head Position', "${_results!.headPosition.toStringAsFixed(1)}°"),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall Score Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.tealAccent.withOpacity(0.3),
                  Colors.tealAccent.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text(
                  "Overall Form Score",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  "${_results!.overallScore.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getScoreInterpretation(_results!.overallScore),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Metrics Grid
          ...metrics.map((m) {
            final status = _getMetricStatus(m.$1, double.parse(m.$3.replaceAll(RegExp(r'[^0-9.]'), '')));
            final feedback = _getMetricFeedback(m.$1, double.parse(m.$3.replaceAll(RegExp(r'[^0-9.]'), '')));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MetricCard(
                label: m.$2,
                value: m.$3,
                status: status,
                feedback: feedback,
                statusColor: _statusColor(status),
              ),
            );
          }),

          // Foot Strike Card
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MetricCard(
              label: "Foot Strike",
              value: _results!.footStrike.toUpperCase(),
              status: _results!.footStrike == 'midfoot' ? 'good' : 'fair',
              feedback: _getFootStrikeFeedback(_results!.footStrike),
              statusColor: _statusColor(
                _results!.footStrike == 'midfoot' ? 'good' : 'fair',
              ),
            ),
          ),

          // Cadence Card
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _MetricCard(
              label: "Estimated Cadence",
              value: "${_results!.cadence.toStringAsFixed(0)} steps/min",
              status: _results!.cadence >= 160 && _results!.cadence <= 180
                  ? 'good'
                  : 'fair',
              feedback: _getStrikeFeedback(_results!.cadence),
              statusColor: _statusColor(
                _results!.cadence >= 160 && _results!.cadence <= 180
                    ? 'good'
                    : 'fair',
              ),
            ),
          ),

          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text("Analyze Another Run"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getScoreInterpretation(double score) {
    if (score >= 85) return "Excellent form—great running mechanics!";
    if (score >= 70) return "Good form—minor adjustments recommended";
    if (score >= 55) return "Fair form—focus on key improvements";
    return "Significant form issues—consult a running coach";
  }

  String _getFootStrikeFeedback(String strike) {
    switch (strike) {
      case 'heel':
        return "Heel striking—consider transitioning to midfoot for efficiency";
      case 'midfoot':
        return "Optimal midfoot strike—excellent efficiency and power transfer";
      case 'forefoot':
        return "Forefoot striking—suitable for sprinting, high cadence running";
      default:
        return "Foot strike pattern detected";
    }
  }

  String _getStrikeFeedback(double cadence) {
    if (cadence >= 160 && cadence <= 180) {
      return "Optimal cadence—good stride turnover";
    } else if (cadence < 160) {
      return "Low cadence—increase step rate to reduce impact";
    } else {
      return "High cadence—may indicate short strides, focus on power";
    }
  }
}

// ── Metric Card Widget ────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final String feedback;
  final Color statusColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.status,
    required this.feedback,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            feedback,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
