// lib/features/interview/widgets/avatar_video_player.dart
// AI avatar video fills 100% of its parent container (like a video call background).
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AvatarVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onComplete;
  final bool autoPlay;

  /// Static face image shown while video is loading / between responses
  final String? faceImageUrl;

  const AvatarVideoPlayer({
    super.key,
    required this.videoUrl,
    this.onComplete,
    this.autoPlay = true,
    this.faceImageUrl,
  });

  @override
  State<AvatarVideoPlayer> createState() => _AvatarVideoPlayerState();
}

class _AvatarVideoPlayerState extends State<AvatarVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _ctrl;
  bool _loading = true;
  bool _error = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _ctrl.initialize();
      _ctrl.addListener(_onVideoEvent);
      if (widget.autoPlay) await _ctrl.play();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  void _onVideoEvent() {
    if (!mounted) return;
    if (_ctrl.value.position >= _ctrl.value.duration &&
        _ctrl.value.duration > Duration.zero) {
      widget.onComplete?.call();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ctrl.removeListener(_onVideoEvent);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // ── Layer 1: Static face / fallback background ───────────────
      _buildFaceBackground(),

      // ── Layer 2: Pulsing "generating" ring while loading ─────────
      if (_loading && !_error) _buildThinkingOverlay(),

      // ── Layer 3: Video — fills entire container ──────────────────
      if (!_loading && !_error) _buildVideoLayer(),

      // ── Layer 4: Error state ─────────────────────────────────────
      if (_error) _buildErrorOverlay(),

      // ── Layer 5: Thin progress bar at very bottom ────────────────
      if (!_loading && !_error)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _ctrl,
            allowScrubbing: false,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF8B5CF6),
              bufferedColor: Colors.white24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
    ]);
  }

  // ── Face background ───────────────────────────────────────────────
  Widget _buildFaceBackground() {
    if (widget.faceImageUrl == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Colors.white24, size: 64),
        ),
      );
    }
    return Image.network(
      widget.faceImageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) =>
          prog == null ? child : _facePlaceholder(),
      errorBuilder: (_, __, ___) => _facePlaceholder(),
    );
  }

  Widget _facePlaceholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Colors.white24, size: 64),
        ),
      );

  // ── Video layer — FILLS the full container ────────────────────────
  Widget _buildVideoLayer() {
    if (!_ctrl.value.isInitialized) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _ctrl.value.isInitialized ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      // SizedBox.expand + FittedBox(fill) makes the video cover the entire
      // parent, regardless of the video's natural aspect ratio.
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _ctrl.value.size.width,
            height: _ctrl.value.size.height,
            child: VideoPlayer(_ctrl),
          ),
        ),
      ),
    );
  }

  // ── Pulsing ring while generating ─────────────────────────────────
  Widget _buildThinkingOverlay() => AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80 + _pulseAnim.value * 12,
                height: 80 + _pulseAnim.value * 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: 0.3 + _pulseAnim.value * 0.5),
                    width: 3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Generating response…',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
      );

  // ── Error state ────────────────────────────────────────────────────
  Widget _buildErrorOverlay() => Container(
        color: Colors.black54,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 36),
          const SizedBox(height: 8),
          const Text('Video unavailable',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = false;
              });
              _initVideo();
            },
            child:
                const Text('Retry', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ]),
      );
}
