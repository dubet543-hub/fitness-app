import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'services/local_log_store.dart';
import 'core/theme.dart';
import 'widgets/common_widgets.dart';
import 'services/entitlements.dart';
import 'widgets/feature_gate.dart';

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
  bool _isStreaming = false;
  bool _isBusy = false;
  int _frameCount = 0;
  String? _cameraError;
  bool _permissionDenied = false;

  // Camera controls
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  bool _isFlashOn = false;
  Offset? _focusPoint;

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
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
  }

  Future<void> _initializeCamera() async {
    if (!await LocalLogStore.cameraConsent()) {
      if (mounted) {
        setState(() {
          _phase = _AnalysisPhase.setup;
          _cameraError = "Camera-based features are off.\nEnable them in Privacy & Security settings.";
          _permissionDenied = false;
        });
      }
      return;
    }
    try {
      final cameras = await availableCameras();
      final camera = cameras.isNotEmpty
          ? cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            )
          : null;
      if (camera == null) {
        setState(() {
          _phase = _AnalysisPhase.setup;
          _cameraError = "No camera found on this device";
        });
        return;
      }
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      if (mounted) setState(() { _cameraError = null; _permissionDenied = false; });
    } on CameraException catch (e) {
      if (!mounted) return;
      const deniedCodes = {'CameraAccessDenied', 'CameraAccessDeniedWithoutPrompt', 'CameraAccessRestricted'};
      setState(() {
        _permissionDenied = deniedCodes.contains(e.code);
        _cameraError = _permissionDenied
            ? "Camera access is turned off for SolidCore.\nEnable it in your device Settings to continue."
            : "Camera error: ${e.description ?? e.code}";
      });
    } catch (e) {
      if (mounted) setState(() => _cameraError = "Camera error: $e");
    }
  }

  Future<void> _retryCamera() async {
    setState(() { _cameraError = null; _permissionDenied = false; });
    await _initializeCamera();
  }

  Future<void> _switchCamera() async {
    if (_controller == null) return;
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    final currentDir = _controller!.description.lensDirection;
    final next = cameras.firstWhere(
      (c) => c.lensDirection != currentDir,
      orElse: () => cameras.first,
    );
    await _controller!.dispose();
    _controller = CameraController(
      next,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();
    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    if (mounted) setState(() => _currentZoom = 1.0);
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clamped);
    if (mounted) setState(() => _currentZoom = clamped);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = _isFlashOn ? FlashMode.off : FlashMode.torch;
    await _controller!.setFlashMode(next);
    if (mounted) setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _onTapFocus(TapDownDetails details, BoxConstraints box) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final x = (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
    final y = (details.localPosition.dy / box.maxHeight).clamp(0.0, 1.0);
    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
      if (!mounted) return;
      setState(() => _focusPoint = details.localPosition);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _focusPoint = null);
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    _trunkLeans.clear();
    _kneeDrives.clear();
    _hipDrops.clear();
    _armSwings.clear();
    _headPositions.clear();
    _footStrikes.clear();
    _frameCount = 0;
    _isBusy = false;
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _phase = _AnalysisPhase.recording);
    // Silent, fast frame analysis via the camera image stream — no per-frame
    // shutter sound or disk writes (the old takePicture loop caused the clicks).
    await _controller!.startImageStream(_processCameraImage);
    _isStreaming = true;
  }

  Future<void> _stopRecording() async {
    if (_isStreaming) {
      _isStreaming = false;
      try {
        await _controller!.stopImageStream();
      } catch (_) {}
    }
    setState(() => _phase = _AnalysisPhase.processing);
    await Future.delayed(const Duration(milliseconds: 300));
    _analyzeResults();
  }

  void _processCameraImage(CameraImage image) {
    if (_isBusy) return; // drop frames while a pose is being detected
    _isBusy = true;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }
    _poseDetector.processImage(inputImage).then((poses) {
      if (poses.isNotEmpty) {
        _extractMetrics(poses.first);
        if (mounted) setState(() => _frameCount++);
      }
    }).catchError((_) {}).whenComplete(() => _isBusy = false);
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final ctrl = _controller;
    if (ctrl == null) return null;
    final camera = ctrl.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[ctrl.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
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
    final dominantStrike = footStrikeMap.isEmpty
        ? 'unknown'
        : footStrikeMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;

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

    unawaited(LocalLogStore.addRunningEntry({
      'date': DateTime.now().toIso8601String(),
      'trunkLean': trunkLean,
      'kneeDrive': kneeDrive,
      'hipDrop': hipDrop,
      'armSwing': armSwing,
      'headPosition': headPosition,
      'footStrike': dominantStrike,
      'cadence': cadence,
      'overallScore': overallScore,
    }));

    if (mounted) setState(() => _phase = _AnalysisPhase.results);
  }

  void _reset() {
    setState(() => _phase = _AnalysisPhase.setup);
  }

  @override
  void dispose() {
    if (_isStreaming) {
      _isStreaming = false;
      _controller?.stopImageStream().catchError((_) {});
    }
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
        return kSuccess;
      case 'fair':
        return kWarn;
      case 'poor':
        return kDanger;
      default:
        return kTextSecondary;
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
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.running, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
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
    if (_cameraError != null) {
      return CameraErrorView(
        message: _cameraError!,
        showSettingsButton: _permissionDenied,
        onRetry: _retryCamera,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.directions_run, size: 60, color: kSuccess),
          const SizedBox(height: 20),
          const Text(
            "Running Form Analysis",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Record a 10-second running session from the side view",
            style: TextStyle(fontSize: 14, color: kTextSecondary),
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
              backgroundColor: kSuccess,
              foregroundColor: kOnAccent,
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
        color: kTextPrimary.withValues(alpha: 0.05),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kSuccess, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text("• ", style: TextStyle(color: kSuccess)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 12, color: kTextSecondary),
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
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onScaleStart: (_) => _baseZoom = _currentZoom,
        onScaleUpdate: (d) => _setZoom(_baseZoom * d.scale),
        onTapDown: (d) => _onTapFocus(d, constraints),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FullBleedCameraPreview(
              controller: _controller!,
              screenSize: constraints.biggest,
            ),

            // Tap-to-focus ring
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 28,
                top: _focusPoint!.dy - 28,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(color: kWarn, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // ── Top bar ───────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CamIconButton(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: _switchCamera,
                      ),
                      // Recording status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: kCameraScrim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record,
                                color: kDanger, size: 10),
                            const SizedBox(width: 5),
                            Text(
                              "$_frameCount fr  •  ${(_frameCount * 0.2).toStringAsFixed(1)}s",
                              style: TextStyle(
                                  color: kOnCamera, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _CamIconButton(
                        icon: _isFlashOn
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        onTap: _toggleFlash,
                        active: _isFlashOn,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Right-side zoom controls ───────────────────────────────
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ZoomControls(
                  zoom: _currentZoom,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  onZoomIn: () => _setZoom(_currentZoom + 0.1),
                  onZoomOut: () => _setZoom(_currentZoom - 0.1),
                ),
              ),
            ),

            // ── Bottom stop button ────────────────────────────────────
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _stopRecording,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kOnCamera, width: 3),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kDanger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Stop Recording",
                        style:
                            TextStyle(color: kOnCameraSoft, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Processing Phase ──────────────────────────────────────────────────────

  Widget _buildProcessingPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kSuccess),
          const SizedBox(height: 20),
          Text(
            "Analyzing $_frameCount frames...",
            style: TextStyle(fontSize: 14, color: kTextSecondary),
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
                  kSuccess.withValues(alpha: 0.3),
                  kSuccess.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: kSuccess.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  "Overall Form Score",
                  style: TextStyle(fontSize: 14, color: kTextSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  "${_results!.overallScore.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: kSuccess,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getScoreInterpretation(_results!.overallScore),
                  style: TextStyle(fontSize: 12, color: kTextSecondary),
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

          // Consult-specialist advisory
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kSuccess.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.medical_services_outlined, color: kSuccess, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This analysis flags running-form defaults only. Consult a Physiotherapist or SNC coach to address them.',
                  style: TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.35),
                ),
              ),
            ]),
          ),

          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text("Analyze Another Run"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSuccess,
              foregroundColor: kOnAccent,
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

// ── Shared camera control widgets ─────────────────────────────────────────────

class _CamIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _CamIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? kTextPrimary.withValues(alpha: 0.9)
              : kOnAccent.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: active ? kOnAccent : kTextPrimary,
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomControls({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomBtn(icon: Icons.add_rounded, onTap: zoom < maxZoom ? onZoomIn : null),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: kOnAccent.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "${zoom.toStringAsFixed(1)}×",
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _ZoomBtn(icon: Icons.remove_rounded, onTap: zoom > minZoom ? onZoomOut : null),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kOnAccent.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18,
            color: onTap != null ? kTextPrimary : kTextMuted),
      ),
    );
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
        color: statusColor.withValues(alpha: 0.08),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kTextSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
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
            style: TextStyle(fontSize: 11, color: kTextSecondary),
          ),
        ],
      ),
    );
  }
}
