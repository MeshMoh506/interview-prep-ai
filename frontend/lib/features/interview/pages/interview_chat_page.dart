// lib/features/interview/pages/interview_chat_page.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async' show Completer, scheduleMicrotask;
import 'dart:js_interop';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/background_painter.dart';
import '../providers/interview_provider.dart';
import '../../../services/tts_service.dart';
import '../widgets/avatar_video_player.dart';
import '../../auth/screens/login_screen.dart'; // GlassCard, PrimaryButton

class InterviewChatPage extends ConsumerStatefulWidget {
  const InterviewChatPage({super.key});

  @override
  ConsumerState<InterviewChatPage> createState() => _ChatState();
}

class _ChatState extends ConsumerState<InterviewChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _ttsEnabled = true;
  bool _isRecording = false;
  final _tts = TtsService();
  web.MediaRecorder? _mediaRecorder;
  final List<web.Blob> _chunks = [];

  String? _currentVideoUrl;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _tts.preload();
  }

  @override
  void dispose() {
    _tts.stop();
    _ctrl.dispose();
    _scroll.dispose();
    _stopMediaRecorder();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

  void _speak(String text, String lang) {
    if (!_ttsEnabled || text.isEmpty) return;
    _tts.speak(text, language: lang);
  }

  void _stopSpeaking() => _tts.stop();

  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      _chunks.clear();
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      _mediaRecorder = web.MediaRecorder(stream);
      _mediaRecorder!.ondataavailable = ((web.BlobEvent e) {
        if (e.data.size > 0) _chunks.add(e.data);
      }).toJS;
      _mediaRecorder!.onstop = ((web.Event _) => _onRecordingStop()).toJS;
      _mediaRecorder!.start();
      setState(() => _isRecording = true);
      ref.read(interviewSessionProvider.notifier).setRecording(true);
    } catch (_) {
      _snack('Microphone access denied');
    }
  }

  void _onRecordingStop() {
    scheduleMicrotask(() async {
      if (_chunks.isEmpty) return;
      try {
        final blob =
            web.Blob(_chunks.toJS, web.BlobPropertyBag(type: 'audio/webm'));
        final completer = Completer<List<int>>();
        final reader = web.FileReader();
        reader.onload = ((web.Event e) {
          try {
            final buf = (reader.result as JSArrayBuffer).toDart;
            completer.complete(buf.asUint8List());
          } catch (err) {
            completer.completeError(err);
          }
        }).toJS;
        reader.readAsArrayBuffer(blob);
        final bytes = await completer.future;
        if (!mounted) return;
        setState(() => _isVideoLoading = true);
        await ref
            .read(interviewSessionProvider.notifier)
            .sendVoiceBytes(bytes, 'voice.webm');
        _scrollDown();
        // Reset loading if no video url came back
        if (mounted) setState(() => _isVideoLoading = false);
      } catch (e) {
        if (mounted) {
          setState(() => _isVideoLoading = false);
          _snack('Voice error: $e');
        }
      }
    });
  }

  void _stopMediaRecorder() {
    try {
      _mediaRecorder?.stop();
    } catch (_) {}
    _mediaRecorder = null;
  }

  void _stopRecording() {
    if (!_isRecording) return;
    setState(() => _isRecording = false);
    ref.read(interviewSessionProvider.notifier).setRecording(false);
    _stopMediaRecorder();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _stopSpeaking();
    setState(() => _isVideoLoading = true);
    try {
      await ref.read(interviewSessionProvider.notifier).sendMessage(text);
      _scrollDown();
    } catch (e) {
      if (mounted) {
        setState(() => _isVideoLoading = false);
        _snack('Send failed: $e');
      }
    }
  }

  Future<void> _end() async {
    final confirm = await _confirmDialog(
      title: 'End Interview?',
      body: 'Get your final score and detailed AI feedback now.',
      confirmLabel: 'End & Score',
    );
    if (confirm == true) {
      await ref.read(interviewSessionProvider.notifier).endInterview();
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.rose : AppColors.emerald,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(interviewSessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(interviewSessionProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollDown();
        if (next.messages.isNotEmpty) {
          final last = next.messages.last;
          if (last.role == 'assistant' && !last.isTyping) {
            if (last.videoUrl != null && last.videoUrl!.isNotEmpty) {
              setState(() {
                _currentVideoUrl = last.videoUrl;
                _isVideoLoading = false;
              });
            } else {
              setState(() => _isVideoLoading = false);
              _speak(last.content, next.language);
            }
          }
        }
      }
      if (next.error != null && next.error != prev?.error) {
        setState(() => _isVideoLoading = false);
        _snack(next.error!);
      }
    });

    if (session.status == 'completed') {
      return _FeedbackPage(session: session);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDialog(
            title: 'Leave Session?',
            body: "Your progress is saved, but you won't get a score yet.",
            confirmLabel: 'Leave');
        // FIX: check mounted BEFORE using context after await
        if (leave == true && mounted) {
          _stopSpeaking();
          ref.read(interviewSessionProvider.notifier).reset();
          context.go('/interview');
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            const BackgroundPainter(),
            Column(
              children: [
                _PremiumChatHeader(
                    isDark: isDark,
                    ttsEnabled: _ttsEnabled,
                    onToggleTts: () {
                      setState(() => _ttsEnabled = !_ttsEnabled);
                      if (!_ttsEnabled) _stopSpeaking();
                    },
                    onEnd: _end),
                if (_currentVideoUrl != null)
                  _AvatarSection(
                      videoUrl: _currentVideoUrl!,
                      onComplete: () =>
                          setState(() => _currentVideoUrl = null)),
                if (_isVideoLoading && _currentVideoUrl == null)
                  _AvatarLoading(isDark: isDark),
                Expanded(
                  child: session.messages.isEmpty && !session.isTyping
                      ? _WaitingState(isDark: isDark)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          itemCount: session.messages.length +
                              (session.isTyping ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (session.isTyping &&
                                i == session.messages.length) {
                              return _TypingBubble(isDark: isDark);
                            }
                            return _MessageBubble(
                                msg: session.messages[i],
                                isDark: isDark,
                                onTapSpeak: () => _speak(
                                    session.messages[i].content,
                                    session.language));
                          },
                        ),
                ),
                _ModernInputBar(
                    controller: _ctrl,
                    isDark: isDark,
                    isRecording: _isRecording,
                    isTyping: session.isTyping,
                    onSend: (session.isTyping || _isRecording) ? null : _send,
                    onRecordStart: _startRecording,
                    onRecordStop: _stopRecording),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumChatHeader extends StatelessWidget {
  final bool isDark, ttsEnabled;
  final VoidCallback onToggleTts, onEnd;
  const _PremiumChatHeader({
    required this.isDark,
    required this.ttsEnabled,
    required this.onToggleTts,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              10, MediaQuery.of(context).padding.top + 5, 10, 10),
          color: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                // FIX: use context.go not Navigator.maybePop
                onPressed: () => context.go('/interview'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Interviewer',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Live Session',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
              ),
              IconButton(
                  icon: Icon(
                      ttsEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: ttsEnabled ? AppColors.violet : Colors.grey),
                  onPressed: onToggleTts),
              TextButton(
                  onPressed: onEnd,
                  style: TextButton.styleFrom(
                      backgroundColor: AppColors.rose.withValues(alpha: 0.1),
                      foregroundColor: AppColors.rose,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('End',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark;
  final VoidCallback onTapSpeak;
  const _MessageBubble(
      {required this.msg, required this.isDark, required this.onTapSpeak});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: isUser ? null : onTapSpeak,
        child: Container(
          margin: EdgeInsets.only(
              bottom: 12, left: isUser ? 50 : 0, right: isUser ? 0 : 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.violet
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Text(msg.content,
              style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 14,
                  height: 1.5)),
        ),
      ),
    );
  }
}

class _ModernInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark, isRecording, isTyping;
  final VoidCallback? onSend;
  final VoidCallback onRecordStart, onRecordStop;
  const _ModernInputBar({
    required this.controller,
    required this.isDark,
    required this.isRecording,
    required this.isTyping,
    required this.onSend,
    required this.onRecordStart,
    required this.onRecordStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTapDown: (_) => onRecordStart(),
            onTapUp: (_) => onRecordStop(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: isRecording
                      ? AppColors.rose
                      : AppColors.violet.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: isRecording ? Colors.white : AppColors.violet),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: controller,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                    hintText: isRecording ? 'Listening...' : 'Type answer...',
                    border: InputBorder.none,
                    hintStyle: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onSend,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: onSend == null ? Colors.grey : AppColors.violet,
                  shape: BoxShape.circle),
              child: isTyping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEEDBACK PAGE
// ─────────────────────────────────────────────────────────────────────────────
class _FeedbackPage extends ConsumerWidget {
  final InterviewSessionState session;
  const _FeedbackPage({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = session.finalScore ?? 0;
    final feedback = session.finalFeedback ?? {};

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          const BackgroundPainter(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: GlassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        const Text('Session Feedback',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 24),
                        _ScoreHero(score: score),
                        const SizedBox(height: 32),
                        if (feedback['overall_feedback'] != null)
                          Text(feedback['overall_feedback'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  height: 1.6, color: Colors.grey)),
                        const SizedBox(height: 40),
                        PrimaryButton(
                          label: 'Return to History',
                          isLoading: false,
                          onTap: () {
                            ref.read(interviewSessionProvider.notifier).reset();
                            context.go('/interview');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  final double score;
  const _ScoreHero({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.emerald
        : (score >= 40 ? AppColors.amber : AppColors.rose);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.1))),
        Text('${score.toInt()}',
            style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final String videoUrl;
  final VoidCallback onComplete;
  const _AvatarSection({required this.videoUrl, required this.onComplete});

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.all(16),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withValues(alpha: 0.2), blurRadius: 20)
          ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child:
              AvatarVideoPlayer(videoUrl: videoUrl, onComplete: onComplete)));
}

class _AvatarLoading extends StatelessWidget {
  final bool isDark;
  const _AvatarLoading({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24)),
      child: const Column(children: [
        CircularProgressIndicator(color: AppColors.violet),
        SizedBox(height: 12),
        Text('AI is thinking...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
      ]));
}

class _WaitingState extends StatelessWidget {
  final bool isDark;
  const _WaitingState({required this.isDark});

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.psychology_rounded, size: 60, color: AppColors.violet),
          SizedBox(height: 16),
          Text('Preparing interview...',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
        ]),
      );
}

class _TypingBubble extends StatelessWidget {
  final bool isDark;
  const _TypingBubble({required this.isDark});

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: const SizedBox(
              width: 30,
              child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.violet,
                  backgroundColor: Colors.transparent))));
}
