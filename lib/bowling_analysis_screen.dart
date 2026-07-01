import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'services/local_log_store.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum BowlingType { fast, spin }

enum _Phase { typeSelect, setup, recording, processing, results }

// ── Data ──────────────────────────────────────────────────────────────────────

class _BowlingMetrics {
  final BowlingType type;
  final double trunkLean;
  final double armArc;
  final double frontKnee;
  final double headPosition;
  final double bodyTilt;
  final int framesAnalyzed;

  const _BowlingMetrics({
    required this.type,
    required this.trunkLean,
    required this.armArc,
    required this.frontKnee,
    required this.headPosition,
    required this.bodyTilt,
    required this.framesAnalyzed,
  });
}

class _Info {
  final Color color;
  final String label;
  final String tip;
  const _Info(this.color, this.label, this.tip);
}

class _OverallInfo {
  final Color color;
  final String label;
  const _OverallInfo(this.color, this.label);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class BowlingAnalysisScreen extends StatefulWidget {
  const BowlingAnalysisScreen({super.key});

  @override
  State<BowlingAnalysisScreen> createState() => _BowlingAnalysisScreenState();
}

class _BowlingAnalysisScreenState extends State<BowlingAnalysisScreen> {
  BowlingType _bowlingType = BowlingType.fast;
  _Phase _phase = _Phase.typeSelect;

  CameraController? _ctrl;
  bool _camReady = false;
  bool _isStreaming = false;
  bool _isBusy = false;
  int _frameCount = 0;

  // Camera controls
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  bool _isFlashOn = false;
  Offset? _focusPoint;

  final List<double> _trunkLeans = [];
  final List<double> _armArcs = [];
  final List<double> _frontKnees = [];
  final List<double> _headPositions = [];
  final List<double> _bodyTilts = [];

  _BowlingMetrics? _results;
  late final PoseDetector _poseDetector;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (!await LocalLogStore.cameraConsent()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Camera-based features are off. Enable them in Privacy & Security settings."),
          duration: Duration(seconds: 4),
        ));
      }
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _ctrl = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _ctrl!.initialize();
    _minZoom = await _ctrl!.getMinZoomLevel();
    _maxZoom = await _ctrl!.getMaxZoomLevel();
    if (mounted) setState(() => _camReady = true);
  }

  Future<void> _switchCamera() async {
    if (_ctrl == null) return;
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    final currentDir = _ctrl!.description.lensDirection;
    final next = cameras.firstWhere(
      (c) => c.lensDirection != currentDir,
      orElse: () => cameras.first,
    );
    await _ctrl!.dispose();
    _ctrl = CameraController(
      next,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _ctrl!.initialize();
    _minZoom = await _ctrl!.getMinZoomLevel();
    _maxZoom = await _ctrl!.getMaxZoomLevel();
    if (mounted) setState(() { _camReady = true; _currentZoom = 1.0; });
  }

  Future<void> _setZoom(double zoom) async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await _ctrl!.setZoomLevel(clamped);
    if (mounted) setState(() => _currentZoom = clamped);
  }

  Future<void> _toggleFlash() async {
    if (_ctrl == null) return;
    final next = _isFlashOn ? FlashMode.off : FlashMode.torch;
    await _ctrl!.setFlashMode(next);
    if (mounted) setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _onTapFocus(TapDownDetails details, BoxConstraints box) async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    final x = (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
    final y = (details.localPosition.dy / box.maxHeight).clamp(0.0, 1.0);
    try {
      await _ctrl!.setFocusPoint(Offset(x, y));
      await _ctrl!.setExposurePoint(Offset(x, y));
      if (!mounted) return;
      setState(() => _focusPoint = details.localPosition);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _focusPoint = null);
    } catch (_) {}
  }

  void _selectType(BowlingType type) {
    setState(() {
      _bowlingType = type;
      _phase = _Phase.setup;
    });
  }

  Future<void> _startRecording() async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    _trunkLeans.clear();
    _armArcs.clear();
    _frontKnees.clear();
    _headPositions.clear();
    _bodyTilts.clear();
    setState(() {
      _phase = _Phase.recording;
      _frameCount = 0;
    });
    // Analyse the live camera stream (~30fps) so the delivery instant is
    // actually captured — takePicture polling was far too slow for this.
    await _ctrl!.startImageStream(_processCameraImage);
    _isStreaming = true;
  }

  Future<void> _stopRecording() async {
    if (_isStreaming) {
      _isStreaming = false;
      try {
        await _ctrl!.stopImageStream();
      } catch (_) {}
    }
    setState(() => _phase = _Phase.processing);
    await Future.delayed(const Duration(milliseconds: 300));
    _computeResults();
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
    final ctrl = _ctrl;
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

  static double _angle3(
      double ax, double ay, double bx, double by, double cx, double cy) {
    final v1x = ax - bx, v1y = ay - by;
    final v2x = cx - bx, v2y = cy - by;
    final dot = v1x * v2x + v1y * v2y;
    final m1 = sqrt(v1x * v1x + v1y * v1y);
    final m2 = sqrt(v2x * v2x + v2y * v2y);
    if (m1 == 0 || m2 == 0) return 90;
    return acos((dot / (m1 * m2)).clamp(-1.0, 1.0)) * 180 / pi;
  }

  void _extractMetrics(Pose pose) {
    final lm = pose.landmarks;
    PoseLandmark? p(PoseLandmarkType t) => lm[t];

    final ls = p(PoseLandmarkType.leftShoulder);
    final rs = p(PoseLandmarkType.rightShoulder);
    final lh = p(PoseLandmarkType.leftHip);
    final rh = p(PoseLandmarkType.rightHip);
    final lKnee = p(PoseLandmarkType.leftKnee);
    final rKnee = p(PoseLandmarkType.rightKnee);
    final lAnkle = p(PoseLandmarkType.leftAnkle);
    final rAnkle = p(PoseLandmarkType.rightAnkle);
    final lWrist = p(PoseLandmarkType.leftWrist);
    final rWrist = p(PoseLandmarkType.rightWrist);
    final lEar = p(PoseLandmarkType.leftEar);
    final rEar = p(PoseLandmarkType.rightEar);

    if (ls == null || rs == null || lh == null || rh == null) return;

    final msx = (ls.x + rs.x) / 2, msy = (ls.y + rs.y) / 2;
    final mhx = (lh.x + rh.x) / 2, mhy = (lh.y + rh.y) / 2;

    // 1. Trunk lean — shoulder-hip line from vertical
    final dy = mhy - msy;
    final dx = (msx - mhx).abs();
    if (dy > 10) _trunkLeans.add(atan2(dx, dy) * 180 / pi);

    // 2. Arm arc — wrist elevation above shoulder line (converted to degrees)
    if (lWrist != null && rWrist != null) {
      final highWristY = min(lWrist.y, rWrist.y);
      final shoulderY = min(ls.y, rs.y);
      final trunkH = (mhy - msy).abs().clamp(1.0, double.infinity);
      final arcRatio = (shoulderY - highWristY) / trunkH;
      _armArcs.add((arcRatio * 90).clamp(-20.0, 90.0));
    }

    // 3. Front knee angle — the lower (planted) leg at delivery
    if (lKnee != null && rKnee != null && lAnkle != null && rAnkle != null) {
      final useLef = lKnee.y > rKnee.y;
      final fHip = useLef ? lh : rh;
      final fKnee = useLef ? lKnee : rKnee;
      final fAnkle = useLef ? lAnkle : rAnkle;
      _frontKnees.add(
          _angle3(fHip.x, fHip.y, fKnee.x, fKnee.y, fAnkle.x, fAnkle.y));
    }

    // 4. Head position — ear offset from shoulder vertical
    if (lEar != null && rEar != null) {
      final earX = (lEar.x + rEar.x) / 2;
      final earY = (lEar.y + rEar.y) / 2;
      final ddx = (earX - msx).abs();
      final ddy = (msy - earY).abs().clamp(5.0, double.infinity);
      _headPositions.add(atan2(ddx, ddy) * 180 / pi);
    }

    // 5. Shoulder tilt — lateral lean
    final sx = (rs.x - ls.x).abs().clamp(1.0, double.infinity);
    final sy = (ls.y - rs.y).abs();
    _bodyTilts.add(atan2(sy, sx) * 180 / pi);
  }

  double _avg(List<double> l) =>
      l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;

  void _computeResults() {
    if (_frameCount == 0) {
      setState(() => _phase = _Phase.setup);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "No pose detected. Try better lighting and full body in frame.")),
      );
      return;
    }
    _results = _BowlingMetrics(
      type: _bowlingType,
      trunkLean: _avg(_trunkLeans),
      armArc: _avg(_armArcs),
      frontKnee: _avg(_frontKnees),
      headPosition: _avg(_headPositions),
      bodyTilt: _avg(_bodyTilts),
      framesAnalyzed: _frameCount,
    );
    setState(() => _phase = _Phase.results);
  }

  @override
  void dispose() {
    if (_isStreaming) {
      _isStreaming = false;
      _ctrl?.stopImageStream().catchError((_) {});
    }
    _ctrl?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bowling Analysis"),
        centerTitle: true,
      ),
      body: switch (_phase) {
        _Phase.typeSelect => _buildTypeSelect(),
        _Phase.setup => _buildSetup(),
        _Phase.recording => _buildRecording(),
        _Phase.processing => _buildProcessing(),
        _Phase.results => _buildResults(),
      },
    );
  }

  // ── Type Select ───────────────────────────────────────────────────────────

  Widget _buildTypeSelect() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.sports_cricket, size: 64, color: Colors.tealAccent),
          const SizedBox(height: 16),
          const Text(
            "Select Bowling Type",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "Choose the type of bowling to analyse",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          _TypeCard(
            title: "Fast Bowling",
            subtitle: "Pace, seam & swing bowlers",
            icon: Icons.flash_on,
            color: Colors.orangeAccent,
            metrics: const [
              "Trunk Lean",
              "Arm Arc",
              "Front Knee",
              "Head Position",
              "Shoulder Tilt"
            ],
            onTap: () => _selectType(BowlingType.fast),
          ),
          const SizedBox(height: 16),
          _TypeCard(
            title: "Spin Bowling",
            subtitle: "Off-spin, leg-spin & left-arm spin",
            icon: Icons.rotate_right,
            color: Colors.purpleAccent,
            metrics: const [
              "Body Rotation",
              "Arm Arc",
              "Pivot Angle",
              "Head Position",
              "Release Tilt"
            ],
            onTap: () => _selectType(BowlingType.spin),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    final isFast = _bowlingType == BowlingType.fast;
    final color = isFast ? Colors.orangeAccent : Colors.purpleAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(isFast ? Icons.flash_on : Icons.rotate_right,
              size: 52, color: color),
          const SizedBox(height: 10),
          Text(
            isFast ? "Fast Bowling Analysis" : "Spin Bowling Analysis",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _InfoCard(
            color: color,
            icon: Icons.videocam,
            title: "Camera Setup",
            items: const [
              "Place phone on a stable surface at hip height",
              "Film from the SIDE — perpendicular to run-up",
              "Full body must be visible in frame",
              "Good, even lighting is essential",
            ],
          ),
          const SizedBox(height: 10),
          _InfoCard(
            color: color,
            icon: isFast ? Icons.flash_on : Icons.rotate_right,
            title: isFast ? "Fast Bowling Tips" : "Spin Bowling Tips",
            items: isFast
                ? const [
                    "Bowl at full pace — natural action",
                    "Complete full delivery + follow-through",
                    "Record 3–5 deliveries for best accuracy",
                    "Wear fitted clothing for better detection",
                  ]
                : const [
                    "Bowl with full spinning action",
                    "Include complete pivot & follow-through",
                    "Record 3–5 deliveries for best accuracy",
                    "Wear fitted clothing for better detection",
                  ],
          ),
          const SizedBox(height: 10),
          _InfoCard(
            color: Colors.lightBlueAccent,
            icon: Icons.analytics_outlined,
            title: "What We Analyse",
            items: isFast
                ? const [
                    "Trunk lean at delivery stride",
                    "Bowling arm arc & elevation",
                    "Front knee angle — braced vs collapsed",
                    "Head position & alignment",
                    "Shoulder line tilt (side-on vs front-on)",
                  ]
                : const [
                    "Body rotation at delivery",
                    "Bowling arm arc & elevation",
                    "Pivot angle & hip drive",
                    "Head position & alignment",
                    "Lateral tilt at release",
                  ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _camReady ? _startRecording : null,
            icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
            label: const Text("Start Recording"),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _phase = _Phase.typeSelect),
            child: const Text("← Change bowling type"),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Widget _buildRecording() {
    if (!_camReady) return const Center(child: CircularProgressIndicator());
    final isFast = _bowlingType == BowlingType.fast;
    final typeColor = isFast ? Colors.orangeAccent : Colors.purpleAccent;

    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onScaleStart: (_) => _baseZoom = _currentZoom,
        onScaleUpdate: (d) => _setZoom(_baseZoom * d.scale),
        onTapDown: (d) => _onTapFocus(d, constraints),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_ctrl!),

            // Tap-to-focus ring
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 28,
                top: _focusPoint!.dy - 28,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellowAccent, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // ── Top bar ─────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CamIconButton(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: _switchCamera,
                      ),
                      // Mode + frame count pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record,
                                color: typeColor, size: 10),
                            const SizedBox(width: 5),
                            Text(
                              "${isFast ? 'FAST' : 'SPIN'}  •  $_frameCount fr",
                              style: TextStyle(
                                  color: typeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
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

            // ── Right-side zoom controls ──────────────────────────────
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
                          border:
                              Border.all(color: Colors.white, width: 3),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Stop & Analyse",
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Processing ────────────────────────────────────────────────────────────

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.tealAccent),
          const SizedBox(height: 20),
          Text(
            "Analysing ${_bowlingType == BowlingType.fast ? 'fast' : 'spin'} bowling action...",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "$_frameCount frames captured",
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final m = _results!;
    final isFast = m.type == BowlingType.fast;
    final color = isFast ? Colors.orangeAccent : Colors.purpleAccent;
    final overall = _overallFeedback(m);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(isFast ? Icons.flash_on : Icons.rotate_right,
                    size: 40, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFast
                            ? "Fast Bowling Results"
                            : "Spin Bowling Results",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(overall.label,
                          style: TextStyle(
                              fontSize: 13, color: overall.color)),
                      Text("${m.framesAnalyzed} frames analysed",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Metric cards
          ...(isFast ? _fastCards(m) : _spinCards(m)),

          const SizedBox(height: 16),
          // Consult-specialist advisory
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.sports_cricket_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'This analysis flags difficulties in your bowling action only. Consult your Bowling Coach to address them.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white, height: 1.35),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _phase = _Phase.typeSelect),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text("Change Type"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _phase = _Phase.setup;
                    _results = null;
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Analyse Again"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Metric card builders ──────────────────────────────────────────────────

  List<Widget> _fastCards(_BowlingMetrics m) => [
        _card(
          title: "Trunk Lean",
          value: "${m.trunkLean.toStringAsFixed(1)}°",
          ideal: "Ideal: 15–25°",
          info: _trunkFast(m.trunkLean),
          icon: Icons.straighten,
        ),
        _card(
          title: "Bowling Arm Arc",
          value: _arcLabel(m.armArc),
          ideal: "Ideal: High arm action (> 45°)",
          info: _armFast(m.armArc),
          icon: Icons.change_history,
        ),
        _card(
          title: "Front Knee Angle",
          value: "${m.frontKnee.toStringAsFixed(1)}°",
          ideal: "Ideal: 150–175° (braced leg)",
          info: _kneeFast(m.frontKnee),
          icon: Icons.accessibility_new,
        ),
        _card(
          title: "Head Position",
          value: "${m.headPosition.toStringAsFixed(1)}°",
          ideal: "Ideal: < 8° forward tilt",
          info: _headInfo(m.headPosition),
          icon: Icons.person,
        ),
        _card(
          title: "Shoulder Tilt",
          value: "${m.bodyTilt.toStringAsFixed(1)}°",
          ideal: "Ideal: 10–25° (side-on action)",
          info: _tiltFast(m.bodyTilt),
          icon: Icons.swap_vert,
        ),
      ];

  List<Widget> _spinCards(_BowlingMetrics m) => [
        _card(
          title: "Body Rotation",
          value: "${m.trunkLean.toStringAsFixed(1)}°",
          ideal: "Ideal: 10–20° at delivery",
          info: _trunkSpin(m.trunkLean),
          icon: Icons.rotate_right,
        ),
        _card(
          title: "Bowling Arm Arc",
          value: _arcLabel(m.armArc),
          ideal: "Ideal: Full arc over shoulder",
          info: _armSpin(m.armArc),
          icon: Icons.change_history,
        ),
        _card(
          title: "Pivot / Hip Drive",
          value: "${m.frontKnee.toStringAsFixed(1)}°",
          ideal: "Ideal: > 140° pivot",
          info: _kneeSpin(m.frontKnee),
          icon: Icons.sync,
        ),
        _card(
          title: "Head Position",
          value: "${m.headPosition.toStringAsFixed(1)}°",
          ideal: "Ideal: < 8° forward tilt",
          info: _headInfo(m.headPosition),
          icon: Icons.person,
        ),
        _card(
          title: "Release Tilt",
          value: "${m.bodyTilt.toStringAsFixed(1)}°",
          ideal: "Ideal: 5–15° lateral tilt",
          info: _tiltSpin(m.bodyTilt),
          icon: Icons.swap_vert,
        ),
      ];

  Widget _card({
    required String title,
    required String value,
    required String ideal,
    required _Info info,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: info.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: info.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: info.color)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(info.label,
                          style: TextStyle(
                              fontSize: 10, color: info.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(info.tip,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text(ideal,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.withValues(alpha: 0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  _Info _trunkFast(double v) {
    if (v < 10) return _Info(Colors.orange, "Too Upright", "Increase forward lean for power");
    if (v <= 25) return _Info(Colors.greenAccent, "Optimal", "Good delivery stride lean");
    return _Info(Colors.redAccent, "Excessive Lean", "Reduce lean — lower back stress risk");
  }

  _Info _trunkSpin(double v) {
    if (v < 5) return _Info(Colors.orange, "Upright", "Add body drive for more revolutions");
    if (v <= 20) return _Info(Colors.greenAccent, "Good Rotation", "Well-balanced body drive");
    return _Info(Colors.orange, "Over-rotated", "Control body tilt through delivery");
  }

  _Info _armFast(double v) {
    if (v >= 45) return _Info(Colors.greenAccent, "High Action", "Excellent arm arc — over the top");
    if (v >= 15) return _Info(Colors.orange, "Medium Action", "Work on higher arm position");
    return _Info(Colors.redAccent, "Low / Round-arm", "High injury risk — raise the arm");
  }

  _Info _armSpin(double v) {
    if (v >= 30) return _Info(Colors.greenAccent, "Full Arc", "Good arm over the shoulder");
    if (v >= 10) return _Info(Colors.orange, "Partial Arc", "Extend arm higher for more revs");
    return _Info(Colors.redAccent, "Flat Arc", "Improve arm elevation for flight & spin");
  }

  _Info _kneeFast(double v) {
    if (v >= 150) return _Info(Colors.greenAccent, "Braced", "Strong front leg brace — good power transfer");
    if (v >= 130) return _Info(Colors.orange, "Soft Knee", "Work on bracing the front leg at delivery");
    return _Info(Colors.redAccent, "Collapsed", "Front knee buckling — high injury risk");
  }

  _Info _kneeSpin(double v) {
    if (v >= 140) return _Info(Colors.greenAccent, "Good Pivot", "Strong hip drive through delivery");
    if (v >= 110) return _Info(Colors.orange, "Partial Pivot", "Improve pivot follow-through");
    return _Info(Colors.redAccent, "Restricted", "Work on hip flexibility & rotation");
  }

  _Info _headInfo(double v) {
    if (v < 5) return _Info(Colors.greenAccent, "Neutral", "Good head & cervical alignment");
    if (v <= 10) return _Info(Colors.orange, "Slight Forward", "Keep chin slightly tucked");
    return _Info(Colors.redAccent, "Forward Head", "Focus on neutral cervical alignment");
  }

  _Info _tiltFast(double v) {
    if (v >= 10 && v <= 25) return _Info(Colors.greenAccent, "Side-on", "Effective side-on delivery action");
    if (v >= 5) return _Info(Colors.orange, "Moderate", "More side-on action recommended");
    return _Info(Colors.orange, "Front-on", "Mixed/front-on action — review chest position");
  }

  _Info _tiltSpin(double v) {
    if (v >= 5 && v <= 15) return _Info(Colors.greenAccent, "Optimal", "Good lateral tilt at release");
    if (v < 5) return _Info(Colors.orange, "Upright", "More side tilt for better loop & flight");
    return _Info(Colors.orange, "Excessive Tilt", "Reduce lateral lean slightly");
  }

  String _arcLabel(double v) {
    if (v >= 45) return "High";
    if (v >= 15) return "Medium";
    return "Low";
  }

  _OverallInfo _overallFeedback(_BowlingMetrics m) {
    int issues = 0;

    _countIssues(_Info info) {
      if (info.color == Colors.redAccent) {
        issues += 2;
      } else if (info.color == Colors.orange) {
        issues += 1;
      }
    }

    if (m.type == BowlingType.fast) {
      _countIssues(_trunkFast(m.trunkLean));
      _countIssues(_armFast(m.armArc));
      _countIssues(_kneeFast(m.frontKnee));
      _countIssues(_headInfo(m.headPosition));
      _countIssues(_tiltFast(m.bodyTilt));
    } else {
      _countIssues(_trunkSpin(m.trunkLean));
      _countIssues(_armSpin(m.armArc));
      _countIssues(_kneeSpin(m.frontKnee));
      _countIssues(_headInfo(m.headPosition));
      _countIssues(_tiltSpin(m.bodyTilt));
    }

    if (issues >= 5) return _OverallInfo(Colors.redAccent, "Significant Issues Detected");
    if (issues >= 3) return _OverallInfo(Colors.orange, "Needs Improvement");
    if (issues >= 1) return _OverallInfo(Colors.yellowAccent, "Minor Adjustments Needed");
    return _OverallInfo(Colors.greenAccent, "Good Bowling Action");
  }
}

// ── Type Card ─────────────────────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> metrics;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: metrics
                        .map((m) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(m,
                                  style: TextStyle(
                                      fontSize: 10, color: color)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> items;

  const _InfoCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ", style: TextStyle(color: color)),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              )),
        ],

      ),
    );
  }
}

// -- Shared camera control widgets ---------------------------------------------

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
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22,
            color: active ? Colors.black : Colors.white),
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
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "${zoom.toStringAsFixed(1)}x",
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18,
            color: onTap != null ? Colors.white : Colors.white30),
      ),
    );
  }
}
