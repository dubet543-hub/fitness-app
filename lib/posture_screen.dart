import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as imglib;

import 'services/local_log_store.dart';
import 'core/theme.dart';
import 'widgets/common_widgets.dart';

enum PostureMode { frontal, sagittal }

// ─────────────────────────────────────────────────────────────────────────────
// PostureGuideScreen — mode selector + instructions
// ─────────────────────────────────────────────────────────────────────────────
class PostureGuideScreen extends StatefulWidget {
  PostureGuideScreen({super.key});

  @override
  State<PostureGuideScreen> createState() => _PostureGuideScreenState();
}

class _PostureGuideScreenState extends State<PostureGuideScreen> {
  PostureMode _mode = PostureMode.frontal;

  static List<_GuideItem> _frontalInstructions = [
    _GuideItem(
      icon: Icons.accessibility_new,
      color: kSuccess,
      title: "Face the Camera",
      subtitle: "Stand directly facing the phone",
    ),
    _GuideItem(
      icon: Icons.straighten,
      color: kSky,
      title: "2–3 Metres Away",
      subtitle: "Full body from head to feet in frame",
    ),
    _GuideItem(
      icon: Icons.crop_free,
      color: kWarn,
      title: "Arms at Sides",
      subtitle: "Relax arms naturally at your sides",
    ),
    _GuideItem(
      icon: Icons.wb_sunny_outlined,
      color: kWarn,
      title: "Good Lighting",
      subtitle: "Bright, even lighting — no shadows",
    ),
    _GuideItem(
      icon: Icons.checkroom,
      color: kViolet,
      title: "Fitted Clothing",
      subtitle: "Shorts and vest/t-shirt recommended",
    ),
    _GuideItem(
      icon: Icons.stay_current_portrait,
      color: Colors.pinkAccent,
      title: "Stable Phone",
      subtitle: "Place on surface at chest height",
    ),
  ];

  static List<_GuideItem> _sagittalInstructions = [
    _GuideItem(
      icon: Icons.switch_left,
      color: kSuccess,
      title: "Stand Sideways",
      subtitle: "LEFT side of body faces camera",
    ),
    _GuideItem(
      icon: Icons.straighten,
      color: kSky,
      title: "2–3 Metres Away",
      subtitle: "Full body from head to feet in frame",
    ),
    _GuideItem(
      icon: Icons.crop_free,
      color: kWarn,
      title: "Look Straight Ahead",
      subtitle: "Eyes level, chin neutral — no looking at phone",
    ),
    _GuideItem(
      icon: Icons.wb_sunny_outlined,
      color: kWarn,
      title: "Good Lighting",
      subtitle: "Bright, even lighting — no shadows",
    ),
    _GuideItem(
      icon: Icons.checkroom,
      color: kViolet,
      title: "Fitted Clothing",
      subtitle: "Shorts and vest/t-shirt for best results",
    ),
    _GuideItem(
      icon: Icons.stay_current_portrait,
      color: Colors.pinkAccent,
      title: "Stable Phone",
      subtitle: "Place on surface at hip height",
    ),
    _GuideItem(
      icon: Icons.front_hand_outlined,
      color: kSuccess,
      title: "Arms at Sides",
      subtitle: "Relax arms — do not swing forward",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final instructions = _mode == PostureMode.frontal
        ? _frontalInstructions
        : _sagittalInstructions;

    return Scaffold(
      appBar: AppBar(title: const Text("Posture Setup Guide")),
      body: Column(
        children: [
          // Mode selector cards
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                _ModeCard(
                  title: "Frontal View",
                  subtitle: "Face camera\nShoulder, pelvis, knee alignment",
                  icon: Icons.accessibility_new,
                  selected: _mode == PostureMode.frontal,
                  onTap: () => setState(() => _mode = PostureMode.frontal),
                ),
                const SizedBox(width: 10),
                _ModeCard(
                  title: "Sagittal View",
                  subtitle: "Stand sideways\nForward head, kyphosis, swayback",
                  icon: Icons.switch_left,
                  selected: _mode == PostureMode.sagittal,
                  onTap: () => setState(() => _mode = PostureMode.sagittal),
                ),
              ],
            ),
          ),

          // Instructions list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              itemCount: instructions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final item = instructions[i];
                return Card(
                  color: kCard,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.color.withValues(alpha: 0.15),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(fontSize: 12, color: kTextSecondary),
                    ),
                  ),
                );
              },
            ),
          ),

          // Start button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostureScreen(mode: _mode),
                  ),
                ),
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _mode == PostureMode.frontal
                      ? "Start Frontal Analysis"
                      : "Start Sagittal Analysis",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mode == PostureMode.frontal
                      ? kSuccess
                      : kSky,
                  foregroundColor: kOnAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? kInfo : kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kSky : kTextMuted,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? kSky : kTextSecondary,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: selected ? kTextPrimary : kTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: kTextSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _GuideItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PostureScreen — camera with mode + front/back toggle
// ─────────────────────────────────────────────────────────────────────────────
class PostureScreen extends StatefulWidget {
  final PostureMode mode;

  const PostureScreen({super.key, required this.mode});

  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  CameraController? controller;
  Future<void>? _initializeControllerFuture;
  String? errorMessage;
  bool _permissionDenied = false;
  bool _isCapturing = false;

  // Camera controls
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  bool _isFlashOn = false;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _startWithConsent();
  }

  Future<void> _startWithConsent() async {
    if (!await LocalLogStore.cameraConsent()) {
      if (mounted) {
        setState(() => errorMessage =
            "Camera-based features are turned off.\nEnable them in Settings ▸ Privacy & Security ▸ Camera-based features.");
      }
      return;
    }
    await _initCamera();
  }

  Future<void> _initCamera({CameraDescription? camera}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => errorMessage = "No camera found on this device");
        return;
      }
      final desc = camera ??
          cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
      await controller?.dispose();
      final newController = CameraController(
        desc,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = newController.initialize();
      await _initializeControllerFuture;
      _minZoom = await newController.getMinZoomLevel();
      _maxZoom = await newController.getMaxZoomLevel();
      if (mounted) setState(() { controller = newController; _currentZoom = 1.0; });
    } on CameraException catch (e) {
      if (!mounted) return;
      const deniedCodes = {'CameraAccessDenied', 'CameraAccessDeniedWithoutPrompt', 'CameraAccessRestricted'};
      setState(() {
        _permissionDenied = deniedCodes.contains(e.code);
        errorMessage = _permissionDenied
            ? "Camera access is turned off for SolidCore.\nEnable it in your device Settings to continue."
            : "Camera error: ${e.description ?? e.code}";
      });
    } catch (e) {
      if (mounted) setState(() => errorMessage = "Camera error: $e");
    }
  }

  Future<void> _retryCamera() async {
    setState(() { errorMessage = null; _permissionDenied = false; });
    await _startWithConsent();
  }

  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2 || controller == null) return;
    final currentDir = controller!.description.lensDirection;
    final next = cameras.firstWhere(
      (c) => c.lensDirection != currentDir,
      orElse: () => cameras.first,
    );
    await _initCamera(camera: next);
  }

  Future<void> _setZoom(double zoom) async {
    if (controller == null || !controller!.value.isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await controller!.setZoomLevel(clamped);
    if (mounted) setState(() => _currentZoom = clamped);
  }

  Future<void> _toggleFlash() async {
    if (controller == null) return;
    final next = _isFlashOn ? FlashMode.off : FlashMode.torch;
    await controller!.setFlashMode(next);
    if (mounted) setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _onTapFocus(TapDownDetails details, BoxConstraints box) async {
    if (controller == null || !controller!.value.isInitialized) return;
    final x = (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
    final y = (details.localPosition.dy / box.maxHeight).clamp(0.0, 1.0);
    try {
      await controller!.setFocusPoint(Offset(x, y));
      await controller!.setExposurePoint(Offset(x, y));
      if (!mounted) return;
      setState(() => _focusPoint = details.localPosition);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _focusPoint = null);
    } catch (_) {}
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      await _initializeControllerFuture;
      final image = await controller!.takePicture();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PoseResultScreen(
            imagePath: image.path,
            mode: widget.mode,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Capture failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Posture Analysis")),
        body: CameraErrorView(
          message: errorMessage!,
          showSettingsButton: _permissionDenied,
          onRetry: _retryCamera,
        ),
      );
    }

    final hintText = widget.mode == PostureMode.frontal
        ? "Face the camera — full body head to feet"
        : "Left side toward camera — look straight ahead";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == PostureMode.frontal
            ? "Frontal Analysis"
            : "Sagittal Analysis"),
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
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
                          controller: controller!,
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
                                border: Border.all(
                                    color: kWarn, width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),

                        // ── Top bar ──────────────────────────────────
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _CamIconButton(
                                    icon: Icons.flip_camera_ios_rounded,
                                    onTap: _switchCamera,
                                  ),
                                  // Hint pill
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: kCameraScrim,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        hintText,
                                        style: TextStyle(
                                            color: kOnCamera,
                                            fontSize: 12),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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

                        // ── Right-side zoom controls ──────────────────
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

                        // ── Bottom capture button ─────────────────────
                        Positioned(
                          bottom: 36,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: _isCapturing ? null : _captureImage,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: kOnCamera, width: 3),
                                ),
                                padding: const EdgeInsets.all(5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isCapturing
                                        ? kOnCameraSoft
                                        : kOnCamera,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isCapturing
                                      ? Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(
                                              color: kOnAccent,
                                              strokeWidth: 2.5),
                                        )
                                      : Icon(Icons.camera_alt,
                                          color: kOnAccent, size: 26),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                });
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PostureResult — data model
// ─────────────────────────────────────────────────────────────────────────────
class PostureResult {
  final String label;
  final String value;
  final String detail;
  final Color color;

  const PostureResult({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PoseResultScreen — ML Kit detection + mode-specific analysis
// ─────────────────────────────────────────────────────────────────────────────
class PoseResultScreen extends StatefulWidget {
  final String imagePath;
  final PostureMode mode;

  const PoseResultScreen({
    super.key,
    required this.imagePath,
    required this.mode,
  });

  @override
  State<PoseResultScreen> createState() => _PoseResultScreenState();
}

class _PoseResultScreenState extends State<PoseResultScreen> {
  List<Pose> poses = [];
  bool isLoading = true;
  List<PostureResult> results = [];
  ui.Image? decodedImage;
  String? _displayImagePath;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _detectPose();
  }

  Future<void> _detectPose() async {
    try {
      // ML Kit's file-based pose detector doesn't reliably honor the photo's
      // EXIF orientation on every platform, which silently rotates every
      // landmark ~90° from how the photo is actually displayed — e.g. a
      // level shoulder line reads as ~90° "tilt" instead of ~0°. Bake the
      // orientation into the pixel data once, up front, and read display,
      // sizing, and detection all from that same normalized file so they
      // can never disagree.
      String path = widget.imagePath;
      final rawBytes = await File(widget.imagePath).readAsBytes();
      final decodedForBaking = imglib.decodeImage(rawBytes);
      if (decodedForBaking != null) {
        final baked = imglib.bakeOrientation(decodedForBaking);
        final normalizedPath = '${widget.imagePath}_normalized.jpg';
        await imglib.encodeJpgFile(normalizedPath, baked, quality: 92);
        path = normalizedPath;
      }

      final bytes = await File(path).readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single),
      );
      final inputImage = InputImage.fromFilePath(path);
      final detected = await detector.processImage(inputImage);
      await detector.close();

      if (!mounted) return;

      setState(() {
        decodedImage = decoded;
        _displayImagePath = path;
        poses = detected;
        isLoading = false;

        if (detected.isEmpty) {
          results = [
            PostureResult(
              label: "No Body Detected",
              value: "—",
              detail: "Make sure your full body is visible and well-lit",
              color: kWarn,
            ),
          ];
        } else {
          results = widget.mode == PostureMode.frontal
              ? _analyzeFrontal(detected.first)
              : _analyzeSagittal(detected.first);
        }
      });

      // Save the measurements to local history — mirrors how body
      // composition results are persisted immediately after analysis.
      if (detected.isNotEmpty) {
        await LocalLogStore.addPostureEntry({
          'date': DateTime.now().toIso8601String(),
          'mode': widget.mode == PostureMode.frontal ? 'frontal' : 'sagittal',
          'results': results
              .map((r) => {'label': r.label, 'value': r.value, 'detail': r.detail})
              .toList(),
        });
        if (mounted) setState(() => _saved = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        results = [
          PostureResult(
            label: "Detection Error",
            value: "Failed",
            detail: e.toString(),
            color: kDanger,
          ),
        ];
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _angleFromHorizontal(PoseLandmark a, PoseLandmark b) {
    final dx = (b.x - a.x).abs();
    final dy = (b.y - a.y).abs();
    return atan2(dy, dx) * 180 / pi;
  }

  double _angleBetween(PoseLandmark a, PoseLandmark vertex, PoseLandmark b) {
    final v1x = a.x - vertex.x;
    final v1y = a.y - vertex.y;
    final v2x = b.x - vertex.x;
    final v2y = b.y - vertex.y;
    final dot = v1x * v2x + v1y * v2y;
    final mag1 = sqrt(v1x * v1x + v1y * v1y);
    final mag2 = sqrt(v2x * v2x + v2y * v2y);
    if (mag1 == 0 || mag2 == 0) return 0;
    return acos((dot / (mag1 * mag2)).clamp(-1.0, 1.0)) * 180 / pi;
  }

  Color _color(String severity) {
    switch (severity) {
      case 'good':
        return kSuccess;
      case 'mild':
        return kWarn;
      case 'moderate':
        return kWarn;
      case 'severe':
        return kDanger;
      default:
        return kTextPrimary;
    }
  }

  // ── FRONTAL Analysis ─────────────────────────────────────────────────────

  List<PostureResult> _analyzeFrontal(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final lFoot = pose.landmarks[PoseLandmarkType.leftFootIndex];
    final rFoot = pose.landmarks[PoseLandmarkType.rightFootIndex];
    final lHeel = pose.landmarks[PoseLandmarkType.leftHeel];
    final rHeel = pose.landmarks[PoseLandmarkType.rightHeel];

    if (lShoulder == null || rShoulder == null || lHip == null || rHip == null) {
      return [
        PostureResult(
          label: "Visibility",
          value: "—",
          detail: "Shoulders and hips not visible — step further back",
          color: kWarn,
        ),
      ];
    }

    final results = <PostureResult>[];
    final shoulderMidX = (lShoulder.x + rShoulder.x) / 2;
    final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
    final hipMidX = (lHip.x + rHip.x) / 2;
    final hipMidY = (lHip.y + rHip.y) / 2;
    final torsoH = (hipMidY - shoulderMidY).abs();

    // 1. Head Position
    if (nose != null && torsoH > 0) {
      final headOffset = (nose.x - shoulderMidX).abs();
      final ratio = headOffset / torsoH;
      final angleDeg = atan2(headOffset, torsoH) * 180 / pi;
      String severity, detail;
      if (ratio < 0.10) {
        severity = 'good';
        detail = "Head is centred";
      } else if (ratio < 0.20) {
        severity = 'mild';
        detail = "Slight head tilt or lean";
      } else if (ratio < 0.35) {
        severity = 'moderate';
        detail = "Moderate head deviation from midline";
      } else {
        severity = 'severe';
        detail = "Significant head displacement from midline";
      }
      results.add(PostureResult(
        label: "Head Position",
        value: "${angleDeg.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 2. Shoulder Tilt
    final shoulderAngle = _angleFromHorizontal(lShoulder, rShoulder);
    {
      String severity, detail;
      if (shoulderAngle < 3) {
        severity = 'good';
        detail = "Shoulders are level";
      } else if (shoulderAngle < 7) {
        severity = 'mild';
        detail = "Slight shoulder height difference";
      } else if (shoulderAngle < 12) {
        severity = 'moderate';
        detail = "Shoulder hiking/dropping detected";
      } else {
        severity = 'severe';
        detail = "Significant shoulder imbalance";
      }
      results.add(PostureResult(
        label: "Shoulder Tilt",
        value: "${shoulderAngle.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 3. Scoliosis Screening
    final spineAngle =
        atan2((shoulderMidX - hipMidX).abs(), (shoulderMidY - hipMidY).abs()) *
            180 /
            pi;
    {
      String severity, detail;
      if (spineAngle < 3) {
        severity = 'good';
        detail = "Spine appears straight";
      } else if (spineAngle < 8) {
        severity = 'mild';
        detail = "Slight lateral trunk lean";
      } else if (spineAngle < 15) {
        severity = 'moderate';
        detail = "Moderate trunk deviation — scoliosis screening recommended";
      } else {
        severity = 'severe';
        detail = "Significant spinal deviation — clinical assessment advised";
      }
      results.add(PostureResult(
        label: "Scoliosis Screen",
        value: "${spineAngle.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 4. Pelvic Obliquity
    final pelvicAngle = _angleFromHorizontal(lHip, rHip);
    {
      String severity, detail;
      if (pelvicAngle < 3) {
        severity = 'good';
        detail = "Pelvis is level";
      } else if (pelvicAngle < 7) {
        severity = 'mild';
        detail = "Slight pelvic obliquity";
      } else if (pelvicAngle < 12) {
        severity = 'moderate';
        detail = "Moderate pelvic tilt — check leg length";
      } else {
        severity = 'severe';
        detail = "Significant pelvic obliquity";
      }
      results.add(PostureResult(
        label: "Pelvic Obliquity",
        value: "${pelvicAngle.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 5. Knee Alignment
    if (lKnee != null && rKnee != null && lAnkle != null && rAnkle != null) {
      final hipWidth = (lHip.x - rHip.x).abs();
      final kneeWidth = (lKnee.x - rKnee.x).abs();
      final kneeRatio = hipWidth > 0 ? kneeWidth / hipWidth : 1.0;

      String severity, label, detail;
      if (kneeRatio >= 0.75 && kneeRatio <= 1.25) {
        severity = 'good';
        label = "Knee Alignment";
        detail = "Knees are well aligned";
      } else if (kneeRatio < 0.75) {
        severity = kneeRatio < 0.5 ? 'severe' : 'mild';
        label = "Genu Valgum";
        detail = "Knock-knees — knees angle inward";
      } else {
        severity = kneeRatio > 1.5 ? 'severe' : 'mild';
        label = "Genu Varum";
        detail = "Bow-legged — knees angle outward";
      }
      final leftLegAngle = _angleFromHorizontal(lKnee, lAnkle);
      final rightLegAngle = _angleFromHorizontal(rKnee, rAnkle);
      final avgLegAngle = (leftLegAngle + rightLegAngle) / 2;
      results.add(PostureResult(
        label: label,
        value: "${avgLegAngle.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 6. Foot Alignment
    if (lFoot != null && rFoot != null && (lAnkle != null || lHeel != null)) {
      final lRef = lHeel ?? lAnkle;
      final rRef = rHeel ?? rAnkle;
      if (lRef != null && rRef != null) {
        final leftFootDx = lFoot.x - lRef.x;
        final leftFootDy = (lFoot.y - lRef.y).abs();
        final leftAngle =
            leftFootDy > 0 ? atan2(leftFootDx.abs(), leftFootDy) * 180 / pi : 0.0;

        final rightFootDx = rFoot.x - rRef.x;
        final rightFootDy = (rFoot.y - rRef.y).abs();
        final rightAngle =
            rightFootDy > 0 ? atan2(rightFootDx.abs(), rightFootDy) * 180 / pi : 0.0;

        final leftOut = leftFootDx < 0;
        final rightOut = rightFootDx > 0;
        final avgAngle = (leftAngle + rightAngle) / 2;

        String severity, label, detail;
        if (leftOut && rightOut && avgAngle > 20) {
          severity = avgAngle > 35 ? 'severe' : 'moderate';
          label = "Forefoot Abduction";
          detail = "Both feet turn outward (toe-out pattern)";
        } else if (!leftOut && !rightOut && avgAngle > 10) {
          severity = avgAngle > 20 ? 'severe' : 'moderate';
          label = "Forefoot Adduction";
          detail = "Both feet turn inward (pigeon-toed pattern)";
        } else if (avgAngle <= 15) {
          severity = 'good';
          label = "Foot Alignment";
          detail = "Feet are in neutral alignment";
        } else {
          severity = 'mild';
          label = "Foot Alignment";
          detail = "Slight asymmetry in foot position";
        }

        results.add(PostureResult(
          label: label,
          value: "${avgAngle.toStringAsFixed(1)}°",
          detail: detail,
          color: _color(severity),
        ));
      }
    }

    return results;
  }

  // ── SAGITTAL Analysis ────────────────────────────────────────────────────

  List<PostureResult> _analyzeSagittal(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final lEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rEar = pose.landmarks[PoseLandmarkType.rightEar];
    final lHeel = pose.landmarks[PoseLandmarkType.leftHeel];
    final rHeel = pose.landmarks[PoseLandmarkType.rightHeel];
    final lFoot = pose.landmarks[PoseLandmarkType.leftFootIndex];
    final rFoot = pose.landmarks[PoseLandmarkType.rightFootIndex];

    final leftScore = (lShoulder?.likelihood ?? 0) +
        (lHip?.likelihood ?? 0) +
        (lKnee?.likelihood ?? 0) +
        (lAnkle?.likelihood ?? 0);
    final rightScore = (rShoulder?.likelihood ?? 0) +
        (rHip?.likelihood ?? 0) +
        (rKnee?.likelihood ?? 0) +
        (rAnkle?.likelihood ?? 0);

    final useLeft = leftScore >= rightScore;
    final shoulder = useLeft ? lShoulder : rShoulder;
    final hip = useLeft ? lHip : rHip;
    final knee = useLeft ? lKnee : rKnee;
    final ankle = useLeft ? lAnkle : rAnkle;
    final ear = useLeft ? lEar : rEar;
    final heel = useLeft ? lHeel : rHeel;
    final foot = useLeft ? lFoot : rFoot;

    if (shoulder == null || hip == null) {
      return [
        PostureResult(
          label: "Visibility",
          value: "—",
          detail: "Key landmarks not visible — stand sideways with full body in frame",
          color: kWarn,
        ),
      ];
    }

    final results = <PostureResult>[];
    final torsoH = (hip.y - shoulder.y).abs();
    final legH = ankle != null ? (ankle.y - hip.y).abs() : torsoH;

    // 1. Forward Head Posture
    if (ear != null && torsoH > 0) {
      final offset = (ear.x - shoulder.x).abs();
      final ratio = offset / torsoH;
      final angleDeg = atan2(offset, torsoH) * 180 / pi;
      String severity, detail;
      if (ratio < 0.10) {
        severity = 'good';
        detail = "Head aligned with plumb line";
      } else if (ratio < 0.22) {
        severity = 'mild';
        detail = "Mild forward head — cervical strain risk";
      } else if (ratio < 0.40) {
        severity = 'moderate';
        detail = "Moderate forward head posture detected";
      } else {
        severity = 'severe';
        detail = "Significant forward head — Upper Crossed Syndrome possible";
      }
      results.add(PostureResult(
        label: "Forward Head",
        value: "${angleDeg.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 2. Neck Angle
    if (ear != null) {
      final neckAngle = _angleBetween(ear, shoulder, hip);
      final dev = (180 - neckAngle).abs();
      String severity, detail;
      if (dev < 15) {
        severity = 'good';
        detail = "Neck angle is within normal range";
      } else if (dev < 30) {
        severity = 'mild';
        detail = "Mild cervical deviation from neutral";
      } else if (dev < 45) {
        severity = 'moderate';
        detail = "Moderate neck/upper spine deviation";
      } else {
        severity = 'severe';
        detail = "Significant cervical alignment issue";
      }
      results.add(PostureResult(
        label: "Neck Angle",
        value: "${neckAngle.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 3. Thoracic Alignment (Kyphosis proxy)
    if (torsoH > 0) {
      final trunkOffset = (shoulder.x - hip.x).abs();
      final ratio = trunkOffset / torsoH;
      final angleDeg = atan2(trunkOffset, torsoH) * 180 / pi;
      String severity, detail;
      if (ratio < 0.08) {
        severity = 'good';
        detail = "Trunk is upright — thoracic alignment normal";
      } else if (ratio < 0.18) {
        severity = 'mild';
        detail = "Slight thoracic deviation — possible early kyphosis";
      } else if (ratio < 0.32) {
        severity = 'moderate';
        detail = "Moderate thoracic kyphosis or trunk lean";
      } else {
        severity = 'severe';
        detail = "Significant thoracic kyphosis or trunk deviation";
      }
      results.add(PostureResult(
        label: "Thoracic (Kyphosis)",
        value: "${angleDeg.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 4. Plumb Line / Swayback
    if (ankle != null && legH > 0) {
      final hipAnkleOffset = (hip.x - ankle.x).abs();
      final ratio = hipAnkleOffset / legH;
      final angleDeg = atan2(hipAnkleOffset, legH) * 180 / pi;
      String severity, detail;
      if (ratio < 0.06) {
        severity = 'good';
        detail = "Hip is plumb over ankle — good alignment";
      } else if (ratio < 0.15) {
        severity = 'mild';
        detail = "Slight hip displacement from plumb line";
      } else if (ratio < 0.28) {
        severity = 'moderate';
        detail = "Moderate swayback or hip shift";
      } else {
        severity = 'severe';
        detail = "Significant swayback — hip far from plumb line";
      }
      results.add(PostureResult(
        label: "Swayback / Hip Plumb",
        value: "${angleDeg.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 5. Genu Recurvatum
    if (knee != null && ankle != null && legH > 0) {
      final t = (hip.y - knee.y) / (hip.y - ankle.y);
      final expectedKX = hip.x + t * (ankle.x - hip.x);
      final deviation = (knee.x - expectedKX).abs();
      final ratio = deviation / legH;
      final angleDeg = atan2(deviation, legH) * 180 / pi;
      String severity, detail;
      if (ratio < 0.04) {
        severity = 'good';
        detail = "Knee alignment is normal";
      } else if (ratio < 0.10) {
        severity = 'mild';
        detail = "Slight knee deviation from plumb";
      } else if (ratio < 0.20) {
        severity = 'moderate';
        detail = "Moderate genu recurvatum possible";
      } else {
        severity = 'severe';
        detail = "Significant knee hyperextension detected";
      }
      results.add(PostureResult(
        label: "Genu Recurvatum",
        value: "${angleDeg.toStringAsFixed(1)}°",
        detail: detail,
        color: _color(severity),
      ));
    }

    // 6. Foot / Arch Assessment
    if (heel != null && foot != null && ankle != null) {
      final footLen = sqrt(pow(foot.x - heel.x, 2) + pow(foot.y - heel.y, 2));
      final archH = (heel.y - ankle.y).abs();
      final archRatio = footLen > 0 ? archH / footLen : 0;

      String severity, label, detail;
      if (archRatio < 0.20) {
        severity = 'moderate';
        label = "Pes Planus";
        detail = "Low arch (flat foot) — check overpronation";
      } else if (archRatio > 0.55) {
        severity = 'moderate';
        label = "Pes Cavus";
        detail = "High arch — check supination and ankle stability";
      } else {
        severity = 'good';
        label = "Arch Height";
        detail = "Medial arch appears within normal range";
      }
      results.add(PostureResult(
        label: label,
        value: archRatio.toStringAsFixed(2),
        detail: detail,
        color: _color(severity),
      ));
    }

    return results;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == PostureMode.frontal
            ? "Frontal Result"
            : "Sagittal Result"),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: decodedImage == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: decodedImage!.width.toDouble(),
                        height: decodedImage!.height.toDouble(),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                File(_displayImagePath ?? widget.imagePath),
                                fit: BoxFit.fill,
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: PosePainter(
                                  poses: poses,
                                  imageWidth: decodedImage!.width.toDouble(),
                                  imageHeight: decodedImage!.height.toDouble(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text("Analyzing posture..."),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final r = results[i];
                      return Card(
                        color: kSurface,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: r.color,
                            radius: 12,
                          ),
                          title: Row(
                            children: [
                              Text(
                                r.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                r.value,
                                style: TextStyle(
                                    color: r.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            r.detail,
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 11),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_saved)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: kSuccess),
                  const SizedBox(width: 6),
                  Text('Saved to history', style: TextStyle(color: kSuccess, fontSize: 12)),
                ],
              ),
            ),
          if (!isLoading)
            const _ConsultBanner(
              specialist: 'Physiotherapist',
              message:
                  'This is a screening tool, not a diagnosis. Consult a Physiotherapist to address any flagged findings for postural integrity.',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Consult-specialist advisory banner
// ─────────────────────────────────────────────────────────────────────────────
class _ConsultBanner extends StatelessWidget {
  final String specialist;
  final String message;
  const _ConsultBanner({required this.specialist, required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSky.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSky.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.medical_services_outlined, color: kSky, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.35)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PosePainter — plumb-line overlay
// ─────────────────────────────────────────────────────────────────────────────
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final double imageWidth;
  final double imageHeight;

  PosePainter({
    required this.poses,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    final pose = poses.first;

    Offset? pt(PoseLandmarkType t) {
      final lm = pose.landmarks[t];
      if (lm == null) return null;
      return Offset(
        lm.x * size.width / imageWidth,
        lm.y * size.height / imageHeight,
      );
    }

    double? avgX(List<PoseLandmarkType> ts) {
      final xs = ts.map(pt).whereType<Offset>().map((o) => o.dx).toList();
      if (xs.isEmpty) return null;
      return xs.reduce((a, b) => a + b) / xs.length;
    }

    // Plumb line anchor — a true vertical through the base of support.
    //  • Sagittal (side): dropped through the lateral malleolus (ankle), the
    //    classic posture reference that ear, shoulder, hip and knee align over.
    //  • Frontal: the body midline — midpoint between both ankles — used to read
    //    left/right symmetry.
    final plumbX = avgX([PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle]) ??
        avgX([PoseLandmarkType.leftHeel, PoseLandmarkType.rightHeel]) ??
        avgX([PoseLandmarkType.leftHip, PoseLandmarkType.rightHip]);
    if (plumbX == null) return;

    // The plumb line itself: a dashed vertical gravity reference.
    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const dash = 14.0, gap = 9.0;
    for (double y = 0; y < size.height; y += dash + gap) {
      canvas.drawLine(
        Offset(plumbX, y),
        Offset(plumbX, min(y + dash, size.height)),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter old) => old.poses != poses;
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
              ? kTextPrimary.withValues(alpha: 0.9)
              : kOnAccent.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22,
            color: active ? kOnAccent : kTextPrimary),
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
            "${zoom.toStringAsFixed(1)}x",
            style: TextStyle(
                color: kTextPrimary, fontSize: 11, fontWeight: FontWeight.bold),
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
