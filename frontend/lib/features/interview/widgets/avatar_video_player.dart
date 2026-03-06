// lib/features/interview/widgets/avatar_video_player.dart
//
// Three-state avatar player:
//
//  IDLE     → loops idle.mp4 from D-ID (avatar breathes / blinks naturally)
//  LOADING  → pulsing ring overlay while response clip is being generated
//  SPEAKING → plays the one-shot response clip, then snaps back to IDLE
//
// How to use:
//
//   AvatarVideoPlayer(
//     idleVideoUrl: session.avatarIdleVideoUrl,   // loop
//     videoUrl:     _currentVideoUrl ?? '',       // '' = show idle
//     faceImageUrl: session.avatarSourceUrl,      // static fallback
//     isLoading:    _isVideoLoading,              // show pulse ring
//     onComplete:   () => setState(() => _currentVideoUrl = null),
//   )

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
enum _AvatarState { idle, loading, speaking }

// ─────────────────────────────────────────────────────────────────────────────
class AvatarVideoPlayer extends StatefulWidget {
  /// Looping idle clip from D-ID (e.g. idle.mp4).
  /// If empty/null the static [faceImageUrl] is shown instead.
  final String? idleVideoUrl;

  /// One-shot response clip. Pass empty string to return to idle.
  final String videoUrl;

  /// Static face thumbnail — shown as background at all times.
  final String? faceImageUrl;

  /// When true, overlays a pulsing "Generating…" ring.
  final bool isLoading;

  /// Called when the speaking clip finishes.
  final VoidCallback? onComplete;

  const AvatarVideoPlayer({
    super.key,
    this.idleVideoUrl,
    required this.videoUrl,
    this.faceImageUrl,
    this.isLoading = false,
    this.onComplete,
  });

  @override
  State<AvatarVideoPlayer> createState() => _AvatarVideoPlayerState();
}

// ─────────────────────────────────────────────────────────────────────────────
class _AvatarVideoPlayerState extends State<AvatarVideoPlayer>
    with SingleTickerProviderStateMixin {
  // ── Idle (looping) ──────────────────────────────────────────────
  VideoPlayerController? _idleCtrl;
  bool _idleReady = false;
  String _loadedIdleUrl = '';

  // ── Speaking (one-shot) ─────────────────────────────────────────
  VideoPlayerController? _speakCtrl;
  bool _speakReady = false;
  String _loadedSpeakUrl = '';

  // ── Pulse animation for LOADING state ──────────────────────────
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final Animation<double> _pulseAnim =
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initIdle(widget.idleVideoUrl);
    if (widget.videoUrl.isNotEmpty) _initSpeak(widget.videoUrl);
  }

  @override
  void didUpdateWidget(AvatarVideoPlayer old) {
    super.didUpdateWidget(old);

    // Idle URL changed
    if (widget.idleVideoUrl != old.idleVideoUrl) {
      _disposeIdle();
      _initIdle(widget.idleVideoUrl);
    }

    // Speaking URL changed
    if (widget.videoUrl != old.videoUrl) {
      _disposeSpeak();
      if (widget.videoUrl.isNotEmpty) {
        _initSpeak(widget.videoUrl);
      } else {
        // Empty → back to idle
        setState(() {});
        _idleCtrl?.play();
      }
    }
  }

  // ── Idle init ──────────────────────────────────────────────────
  Future<void> _initIdle(String? url) async {
    if (url == null || url.isEmpty) return;
    if (url == _loadedIdleUrl) return;
    _loadedIdleUrl = url;

    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0); // idle is always muted
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _idleCtrl = ctrl;
      _idleReady = true;
      // Only auto-play idle if not currently speaking
      if (widget.videoUrl.isEmpty && !widget.isLoading) await ctrl.play();
      setState(() {});
    } catch (e) {
      debugPrint('[AvatarPlayer] idle init failed: $e');
    }
  }

  // ── Speak init ─────────────────────────────────────────────────
  Future<void> _initSpeak(String url) async {
    if (url == _loadedSpeakUrl) return;
    _loadedSpeakUrl = url;

    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(false);
      ctrl.addListener(_onSpeakTick);

      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _speakCtrl = ctrl;
      _speakReady = true;

      // Pause idle while speaking
      _idleCtrl?.pause();

      await ctrl.play();
      setState(() {});
    } catch (e) {
      debugPrint('[AvatarPlayer] speak init failed: $e');
      // Fall back to idle gracefully
      if (mounted) {
        _speakReady = false;
        _idleCtrl?.play();
        widget.onComplete?.call();
        setState(() {});
      }
    }
  }

  void _onSpeakTick() {
    if (!mounted || _speakCtrl == null) return;
    final v = _speakCtrl!.value;
    if (v.position >= v.duration && v.duration > Duration.zero) {
      // Clip finished → notify parent, tear down speak ctrl, resume idle
      widget.onComplete?.call();
      _disposeSpeak();
      _idleCtrl?.play();
      if (mounted) setState(() {});
    } else {
      if (mounted) setState(() {});
    }
  }

  // ── Dispose helpers ─────────────────────────────────────────────
  void _disposeIdle() {
    _idleCtrl?.dispose();
    _idleCtrl = null;
    _idleReady = false;
    _loadedIdleUrl = '';
  }

  void _disposeSpeak() {
    _speakCtrl?.removeListener(_onSpeakTick);
    _speakCtrl?.dispose();
    _speakCtrl = null;
    _speakReady = false;
    _loadedSpeakUrl = '';
  }

  @override
  void dispose() {
    _pulse.dispose();
    _disposeIdle();
    _disposeSpeak();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  _AvatarState get _state {
    if (_speakReady && widget.videoUrl.isNotEmpty) return _AvatarState.speaking;
    if (widget.isLoading) return _AvatarState.loading;
    return _AvatarState.idle;
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Layer 1 — static face (always present as background)
      _buildFace(),

      // Layer 2 — idle looping video
      if (_idleReady && _state == _AvatarState.idle) _videoFill(_idleCtrl!),

      // Layer 3 — loading pulse ring
      if (_state == _AvatarState.loading) _buildLoadingOverlay(),

      // Layer 4 — speaking clip (fades in)
      if (_speakReady && _state == _AvatarState.speaking)
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: _videoFill(_speakCtrl!),
        ),

      // Layer 5 — progress bar while speaking
      if (_speakReady && _state == _AvatarState.speaking)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _speakCtrl!,
            allowScrubbing: false,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF8B5CF6),
              bufferedColor: Colors.white24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),

      // Layer 6 — status badge
      Positioned(
        bottom: 8,
        left: 10,
        child: _StateBadge(state: _state),
      ),
    ]);
  }

  // ── Helpers ────────────────────────────────────────────────────

  Widget _videoFill(VideoPlayerController ctrl) {
    if (!ctrl.value.isInitialized) return const SizedBox.shrink();
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  Widget _buildFace() {
    final url = widget.faceImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
            child: Icon(Icons.person_rounded, color: Colors.white24, size: 64)),
      );
    }
    return Image.network(url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) => p == null ? child : _faceBg(),
        errorBuilder: (_, __, ___) => _faceBg());
  }

  Widget _faceBg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
            child: Icon(Icons.person_rounded, color: Colors.white24, size: 64)),
      );

  Widget _buildLoadingOverlay() => AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          color: Colors.black.withValues(alpha: 0.30),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72 + _pulseAnim.value * 14,
                height: 72 + _pulseAnim.value * 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: 0.3 + _pulseAnim.value * 0.5),
                    width: 3,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Generating response…',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Small status badge
// ─────────────────────────────────────────────────────────────────────────────
class _StateBadge extends StatelessWidget {
  final _AvatarState state;
  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _AvatarState.idle => ('● IDLE', const Color(0xFF10B981)),
      _AvatarState.loading => ('● THINKING', const Color(0xFFF59E0B)),
      _AvatarState.speaking => ('● SPEAKING', const Color(0xFF8B5CF6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}
