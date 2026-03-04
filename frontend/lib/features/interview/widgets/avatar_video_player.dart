// lib/features/interview/widgets/avatar_video_player.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AvatarVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onComplete;
  final bool autoPlay;

  const AvatarVideoPlayer({
    super.key,
    required this.videoUrl,
    this.onComplete,
    this.autoPlay = true,
  });

  @override
  State<AvatarVideoPlayer> createState() => _AvatarVideoPlayerState();
}

class _AvatarVideoPlayerState extends State<AvatarVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();

      _controller.addListener(() {
        // Video completed
        if (_controller.value.position >= _controller.value.duration) {
          widget.onComplete?.call();
        }

        // Update UI on state changes
        if (mounted) setState(() {});
      });

      if (widget.autoPlay) {
        await _controller.play();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_hasError) {
      return _buildError();
    }

    return _buildPlayer();
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading AI interviewer...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Could not load video',
            style: TextStyle(
              color: Colors.red[700],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _initializeVideo();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),

          // Play/Pause overlay (shows when paused)
          if (!_controller.value.isPlaying)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: IconButton(
                  icon: const Icon(
                    Icons.play_circle_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                  onPressed: () => _controller.play(),
                ),
              ),
            ),

          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF8B5CF6),
                bufferedColor: Colors.white30,
                backgroundColor: Colors.black26,
              ),
            ),
          ),

          // Controls in bottom right
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                // Volume
                IconButton(
                  icon: Icon(
                    _controller.value.volume > 0
                        ? Icons.volume_up
                        : Icons.volume_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.setVolume(
                        _controller.value.volume > 0 ? 0 : 1,
                      );
                    });
                  },
                ),

                // Time
                Text(
                  '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
