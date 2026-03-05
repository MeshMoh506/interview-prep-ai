// lib/features/interview/pages/interview_chat_page.dart
// Text + Voice chat mode — WhatsApp-style voice bubbles with animated waveform
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
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

class InterviewChatPage extends ConsumerStatefulWidget {
  const InterviewChatPage({super.key});
  @override
  ConsumerState<InterviewChatPage> createState() => _ChatState();
}

class _ChatState extends ConsumerState<InterviewChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _tts = TtsService();

  bool _ttsEnabled = true;
  bool _isRecording = false;
  int _recSecs = 0;
  Timer? _recTimer;

  web.MediaRecorder? _mr;
  final List<web.Blob> _chunks = [];

  String? _videoUrl;
  bool _aiThinking = false;

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
    _recTimer?.cancel();
    _stopMR();
    super.dispose();
  }

  // ── Scroll ────────────────────────────────────────────────────────
  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients)
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic);
      });

  // ── TTS ───────────────────────────────────────────────────────────
  void _speak(String text, String lang) {
    if (!_ttsEnabled || text.isEmpty) {
      return;
    }
    _tts.speak(text, language: lang);
  }

  // ── Recording ─────────────────────────────────────────────────────
  Future<void> _startRec() async {
    if (_isRecording) return;
    try {
      _chunks.clear();
      _recSecs = 0;
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      _mr = web.MediaRecorder(stream);
      _mr!.ondataavailable = ((web.BlobEvent e) {
        if (e.data.size > 0) _chunks.add(e.data);
      }).toJS;
      _mr!.onstop = ((web.Event _) => _onStop()).toJS;
      _mr!.start();
      setState(() => _isRecording = true);
      ref.read(interviewSessionProvider.notifier).setRecording(true);
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSecs++);
      });
    } catch (_) {
      _snack('Microphone permission denied');
    }
  }

  void _stopRec() {
    if (!_isRecording) return;
    _recTimer?.cancel();
    setState(() => _isRecording = false);
    ref.read(interviewSessionProvider.notifier).setRecording(false);
    _stopMR();
  }

  void _stopMR() {
    try {
      _mr?.stop();
    } catch (_) {}
    _mr = null;
  }

  void _onStop() {
    final dur = _recSecs;
    scheduleMicrotask(() async {
      if (_chunks.isEmpty) {
        return;
      }
      try {
        final blob =
            web.Blob(_chunks.toJS, web.BlobPropertyBag(type: 'audio/webm'));
        final comp = Completer<List<int>>();
        final reader = web.FileReader();
        reader.onload = ((web.Event _) {
          try {
            comp.complete(
                (reader.result as JSArrayBuffer).toDart.asUint8List());
          } catch (e) {
            comp.completeError(e);
          }
        }).toJS;
        reader.readAsArrayBuffer(blob);
        final bytes = await comp.future;
        if (!mounted) return;
        setState(() => _aiThinking = true);
        await ref.read(interviewSessionProvider.notifier).sendVoiceBytes(
            bytes, 'voice.webm',
            recordedDuration: Duration(seconds: dur));
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        setState(() => _aiThinking = false);
        _scrollDown();
      } catch (e) {
        if (mounted) {
          setState(() => _aiThinking = false);
          _snack('Voice error: $e');
        }
      }
    });
  }

  // ── Text send ─────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _tts.stop();
    setState(() => _aiThinking = true);
    try {
      await ref.read(interviewSessionProvider.notifier).sendMessage(text);
      _scrollDown();
    } catch (e) {
      if (mounted) _snack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  // ── End ───────────────────────────────────────────────────────────
  Future<void> _end() async {
    final ok = await _dlg(
        title: 'End Interview?',
        body: 'Your session will be scored with detailed AI feedback.',
        confirm: 'End & Score');
    if (ok == true) {
      await ref.read(interviewSessionProvider.notifier).endInterview();
    }
  }

  Future<bool?> _dlg(
          {required String title,
          required String body,
          required String confirm}) =>
      showDialog<bool>(
          context: context,
          builder: (ctx) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
                backgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
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
                      child: Text(confirm)),
                ]);
          });

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ── Build ─────────────────────────────────────────────────────────
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
            if (last.videoUrl?.isNotEmpty == true) {
              setState(() => _videoUrl = last.videoUrl);
            } else {
              _speak(last.content, next.language);
            }
          }
        }
      }
      if (next.error != null && next.error != prev?.error) {
        _snack(next.error!);
      }
    });

    if (session.isCompleted) return InterviewFeedbackPage(session: session);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _dlg(
            title: 'Leave Session?',
            body: "Progress is saved but you won't get a score yet.",
            confirm: 'Leave');
        if (leave == true && mounted) {
          _tts.stop();
          ref.read(interviewSessionProvider.notifier).reset();
          context.go('/interview');
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Stack(children: [
          const BackgroundPainter(),
          Column(children: [
            // ── Header ───────────────────────────────────────────
            _ChatHeader(
                isDark: isDark,
                ttsEnabled: _ttsEnabled,
                session: session,
                onToggleTts: () {
                  setState(() => _ttsEnabled = !_ttsEnabled);
                  if (!_ttsEnabled) _tts.stop();
                },
                onEnd: _end),
            // ── Optional inline avatar video ──────────────────────
            if (_videoUrl != null)
              _AvatarSection(
                  videoUrl: _videoUrl!,
                  onComplete: () => setState(() => _videoUrl = null)),
            // ── AI thinking indicator ─────────────────────────────
            if (_aiThinking && _videoUrl == null) _ThinkingBar(isDark: isDark),
            // ── Messages ──────────────────────────────────────────
            Expanded(
                child: session.messages.isEmpty
                    ? _WaitingHint(isDark: isDark)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        itemCount: session.messages.length +
                            (session.isTyping ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (session.isTyping && i == session.messages.length)
                            return _TypingBubble(isDark: isDark);
                          final msg = session.messages[i];
                          if (msg.isVoice)
                            return _VoiceBubble(msg: msg, isDark: isDark);
                          return _TextBubble(
                              msg: msg,
                              isDark: isDark,
                              onTapSpeak: () =>
                                  _speak(msg.content, session.language));
                        })),
            // ── Input bar ─────────────────────────────────────────
            _InputBar(
                controller: _ctrl,
                isDark: isDark,
                isRecording: _isRecording,
                recSecs: _recSecs,
                isTyping: session.isTyping,
                onSend: (session.isTyping || _isRecording) ? null : _send,
                onRecStart: _startRec,
                onRecStop: _stopRec),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════

class _ChatHeader extends StatelessWidget {
  final bool isDark, ttsEnabled;
  final InterviewSessionState session;
  final VoidCallback onToggleTts, onEnd;
  const _ChatHeader(
      {required this.isDark,
      required this.ttsEnabled,
      required this.session,
      required this.onToggleTts,
      required this.onEnd});

  @override
  Widget build(BuildContext context) => ClipRRect(
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                8, MediaQuery.of(context).padding.top + 6, 8, 12),
            decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.88),
                border: Border(
                    bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12))),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => context.go('/interview')),
              // Avatar pill
              Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.violet, AppColors.violetDk]),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        session.jobRole.isNotEmpty
                            ? session.jobRole
                            : 'AI Interviewer',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(
                          '${session.difficulty.toUpperCase()} • ${session.language == "ar" ? "العربية" : "English"}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ])),
              // Progress pill
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${session.userMsgCount}/7',
                      style: const TextStyle(
                          color: AppColors.violet,
                          fontSize: 11,
                          fontWeight: FontWeight.w900))),
              IconButton(
                  icon: Icon(
                      ttsEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: ttsEnabled ? AppColors.violet : Colors.grey,
                      size: 22),
                  onPressed: onToggleTts),
              TextButton(
                  onPressed: onEnd,
                  style: TextButton.styleFrom(
                      backgroundColor: AppColors.rose.withValues(alpha: 0.1),
                      foregroundColor: AppColors.rose,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('End',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12))),
            ]),
          )));
}

// ═══════════════════════════════════════════════════════════════════
// TEXT BUBBLE
// ═══════════════════════════════════════════════════════════════════

class _TextBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark;
  final VoidCallback onTapSpeak;
  const _TextBubble(
      {required this.msg, required this.isDark, required this.onTapSpeak});

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[_AvatarDot(), const SizedBox(width: 6)],
              Flexible(
                  child: GestureDetector(
                      onTap: isUser ? null : onTapSpeak,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.violet
                                : (isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white),
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isUser ? 18 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 18)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.content,
                                  style: TextStyle(
                                      color: isUser
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                      fontSize: 14,
                                      height: 1.45)),
                              const SizedBox(height: 4),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(_fmt(msg.timestamp),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isUser
                                            ? Colors.white54
                                            : Colors.grey.shade500)),
                                if (!isUser) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.volume_up_rounded,
                                      size: 10, color: Colors.grey.shade400)
                                ],
                              ]),
                            ]),
                      ))),
            ]));
  }
}

// ═══════════════════════════════════════════════════════════════════
// VOICE BUBBLE  ← WhatsApp style
// ═══════════════════════════════════════════════════════════════════

class _VoiceBubble extends StatefulWidget {
  final ChatMessage msg;
  final bool isDark;
  const _VoiceBubble({required this.msg, required this.isDark});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _fmtD(Duration? d) => d == null
      ? '0:00'
      : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  String _fmtT(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = widget.msg.isUser;
    final wf = widget.msg.waveformBars ?? List.filled(30, 0.3);
    final hasTx = widget.msg.content.isNotEmpty;

    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[_AvatarDot(), const SizedBox(width: 6)],
              Flexible(
                  child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.violet
                        : (widget.isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white),
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Waveform row ────────────────────────────────────
                      Row(children: [
                        // Mic / play button
                        GestureDetector(
                            onTap: () => setState(() => _playing = !_playing),
                            child: AnimatedBuilder(
                                animation: _pulse,
                                builder: (_, __) => Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: isUser
                                            ? Colors.white.withValues(
                                                alpha: _playing ? 0.30 : 0.18)
                                            : AppColors.violet
                                                .withValues(alpha: 0.15),
                                        shape: BoxShape.circle),
                                    child: Icon(
                                        _playing
                                            ? Icons.pause_rounded
                                            : Icons.mic_rounded,
                                        color: isUser
                                            ? Colors.white
                                            : AppColors.violet,
                                        size: 18)))),
                        const SizedBox(width: 10),
                        // Animated bars
                        Expanded(
                            child: _WaveformBars(
                                bars: wf,
                                color: isUser ? Colors.white : AppColors.violet,
                                isPlaying: _playing,
                                anim: _pulse)),
                        const SizedBox(width: 8),
                        Text(_fmtD(widget.msg.audioDuration),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isUser
                                    ? Colors.white70
                                    : Colors.grey.shade600)),
                      ]),

                      // ── Transcript ──────────────────────────────────────
                      if (hasTx) ...[
                        const SizedBox(height: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.text_fields_rounded,
                                      size: 11,
                                      color: isUser
                                          ? Colors.white54
                                          : Colors.grey),
                                  const SizedBox(width: 5),
                                  Expanded(
                                      child: Text(widget.msg.content,
                                          style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              fontStyle: FontStyle.italic,
                                              color: isUser
                                                  ? Colors.white70
                                                  : Colors.grey.shade600))),
                                ])),
                      ] else ...[
                        // Still transcribing
                        const SizedBox(height: 6),
                        Row(children: [
                          SizedBox(
                              width: 60,
                              child: LinearProgressIndicator(
                                  color: isUser
                                      ? Colors.white54
                                      : AppColors.violet,
                                  backgroundColor: Colors.transparent,
                                  minHeight: 2)),
                          const SizedBox(width: 6),
                          Text('Transcribing…',
                              style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      isUser ? Colors.white54 : Colors.grey)),
                        ]),
                      ],

                      const SizedBox(height: 4),
                      Text(_fmtT(widget.msg.timestamp),
                          style: TextStyle(
                              fontSize: 10,
                              color: isUser
                                  ? Colors.white54
                                  : Colors.grey.shade500)),
                    ]),
              )),
            ]));
  }
}

// ═══════════════════════════════════════════════════════════════════
// WAVEFORM BARS  — 30 animated bars driven by a single AnimationController
// ═══════════════════════════════════════════════════════════════════

class _WaveformBars extends StatelessWidget {
  final List<double> bars;
  final Color color;
  final bool isPlaying;
  final Animation<double> anim;
  const _WaveformBars(
      {required this.bars,
      required this.color,
      required this.isPlaying,
      required this.anim});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: anim,
      builder: (_, __) => SizedBox(
          height: 30,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(math.min(bars.length, 30), (i) {
                final amp = bars[i];
                final wave = isPlaying
                    ? math.sin(anim.value * math.pi * 2 + i * 0.42) * 0.20
                    : 0.0;
                final h = math.max(3.0, (amp + wave).clamp(0.0, 1.0) * 27.0);
                return Container(
                    width: 2.5,
                    height: h,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.45 + amp * 0.55),
                        borderRadius: BorderRadius.circular(2)));
              }))));
}

// ═══════════════════════════════════════════════════════════════════
// INPUT BAR
// ═══════════════════════════════════════════════════════════════════

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark, isRecording, isTyping;
  final int recSecs;
  final VoidCallback? onSend;
  final VoidCallback onRecStart, onRecStop;
  const _InputBar(
      {required this.controller,
      required this.isDark,
      required this.isRecording,
      required this.recSecs,
      required this.isTyping,
      required this.onSend,
      required this.onRecStart,
      required this.onRecStop});

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
              top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200))),
      child: isRecording
          ? _RecBar(isDark: isDark, secs: recSecs, onStop: onRecStop)
          : Row(children: [
              // Hold-to-record mic
              GestureDetector(
                  onLongPressStart: (_) => onRecStart(),
                  onLongPressEnd: (_) => onRecStop(),
                  onTap: onRecStart,
                  child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.mic_rounded,
                          color: AppColors.violet, size: 22))),
              const SizedBox(width: 10),
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                          controller: controller,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14),
                          decoration: InputDecoration(
                              hintText: 'Type your answer…',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.grey,
                                  fontSize: 14)),
                          onSubmitted: (_) => onSend?.call(),
                          maxLines: null,
                          keyboardType: TextInputType.multiline))),
              const SizedBox(width: 10),
              GestureDetector(
                  onTap: onSend,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: (onSend == null || isTyping)
                              ? Colors.grey.shade400
                              : AppColors.violet,
                          shape: BoxShape.circle,
                          boxShadow: onSend != null
                              ? [
                                  BoxShadow(
                                      color: AppColors.violet
                                          .withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4))
                                ]
                              : null),
                      child: isTyping
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20))),
            ]));
}

// Recording state bar
class _RecBar extends StatefulWidget {
  final bool isDark;
  final int secs;
  final VoidCallback onStop;
  const _RecBar(
      {required this.isDark, required this.secs, required this.onStop});
  @override
  State<_RecBar> createState() => _RecBarState();
}

class _RecBarState extends State<_RecBar> with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  String get _fmt =>
      '${(widget.secs ~/ 60).toString().padLeft(2, '0')}:${(widget.secs % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Row(children: [
        // Delete
        GestureDetector(
            onTap: widget.onStop,
            child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.rose, size: 22))),
        const SizedBox(width: 12),
        AnimatedBuilder(
            animation: _blink,
            builder: (_, __) => Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: _blink.value),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_fmt,
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ])),
        const Spacer(),
        const Text('Tap ■ to send',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const Spacer(),
        GestureDetector(
            onTap: widget.onStop,
            child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                    color: AppColors.rose, shape: BoxShape.circle),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white, size: 22))),
      ]);
}

// ═══════════════════════════════════════════════════════════════════
// FEEDBACK PAGE  (public so video page can reuse it)
// ═══════════════════════════════════════════════════════════════════

class InterviewFeedbackPage extends ConsumerWidget {
  final InterviewSessionState session;
  const InterviewFeedbackPage({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = session.finalScore ?? 0;
    final fb = session.finalFeedback ?? {};
    final sc = score >= 70
        ? AppColors.emerald
        : (score >= 40 ? AppColors.amber : AppColors.rose);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(children: [
        const BackgroundPainter(),
        SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(children: [
            const SizedBox(height: 20),
            // Score ring
            Stack(alignment: Alignment.center, children: [
              SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      color: sc,
                      backgroundColor: sc.withValues(alpha: 0.1))),
              Column(children: [
                Text('${score.toInt()}',
                    style: TextStyle(
                        fontSize: 44, fontWeight: FontWeight.w900, color: sc)),
                Text('/100',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold)),
              ]),
            ]),
            const SizedBox(height: 20),
            Text('Interview Complete! 🎉',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text(session.jobRole.isNotEmpty ? session.jobRole : 'Great effort!',
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 28),
            if (fb['summary'] != null)
              _FbCard(
                  title: 'Summary',
                  icon: Icons.summarize_rounded,
                  color: AppColors.violet,
                  isDark: isDark,
                  child: Text(fb['summary'].toString(),
                      style: const TextStyle(height: 1.6, color: Colors.grey))),
            if ((fb['strengths'] as List?)?.isNotEmpty == true)
              _FbCard(
                  title: 'Strengths',
                  icon: Icons.star_rounded,
                  color: AppColors.emerald,
                  isDark: isDark,
                  child: Column(
                      children: (fb['strengths'] as List)
                          .map((s) => _bullet(s.toString(), AppColors.emerald))
                          .toList())),
            if ((fb['areas_for_improvement'] as List?)?.isNotEmpty == true)
              _FbCard(
                  title: 'Areas to Improve',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.amber,
                  isDark: isDark,
                  child: Column(
                      children: (fb['areas_for_improvement'] as List)
                          .map((s) => _bullet(s.toString(), AppColors.amber))
                          .toList())),
            if (fb['communication_score'] != null)
              _FbCard(
                  title: 'Score Breakdown',
                  icon: Icons.analytics_rounded,
                  color: AppColors.cyan,
                  isDark: isDark,
                  child: Column(children: [
                    _sBar('Communication',
                        (fb['communication_score'] as num).toDouble()),
                    _sBar('Technical',
                        (fb['technical_score'] as num?)?.toDouble() ?? 0),
                    _sBar('Confidence',
                        (fb['confidence_score'] as num?)?.toDouble() ?? 0),
                  ])),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        ref.read(interviewSessionProvider.notifier).reset();
                        context.go('/interview');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.violet,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                      child: const Text('Back',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        ref.read(interviewSessionProvider.notifier).reset();
                        context.go('/interview/setup');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.emerald.withValues(alpha: 0.12),
                          foregroundColor: AppColors.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                      child: const Text('Try Again',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
            ]),
          ]),
        ))
      ]),
    );
  }

  Widget _bullet(String t, Color c) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        Expanded(
            child: Text(t,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13, height: 1.4))),
      ]));

  Widget _sBar(String label, double v) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12))),
          Text('${v.toInt()}%',
              style: const TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: v / 100,
                color: AppColors.cyan,
                backgroundColor: AppColors.cyan.withValues(alpha: 0.1),
                minHeight: 5)),
      ]));
}

class _FbCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final Widget child;
  const _FbCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.isDark,
      required this.child});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(title.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2))
        ]),
        const SizedBox(height: 12),
        child,
      ]));
}

// ═══════════════════════════════════════════════════════════════════
// SHARED SMALL HELPERS
// ═══════════════════════════════════════════════════════════════════

class _AvatarDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [AppColors.violet, AppColors.violetDk]),
          shape: BoxShape.circle),
      child:
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 14));
}

class _AvatarSection extends StatelessWidget {
  final String videoUrl;
  final VoidCallback onComplete;
  const _AvatarSection({required this.videoUrl, required this.onComplete});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withValues(alpha: 0.2), blurRadius: 20)
          ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child:
              AvatarVideoPlayer(videoUrl: videoUrl, onComplete: onComplete)));
}

class _ThinkingBar extends StatelessWidget {
  final bool isDark;
  const _ThinkingBar({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: AppColors.violet, strokeWidth: 2)),
        const SizedBox(width: 10),
        const Text('AI is thinking…',
            style: TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
}

class _WaitingHint extends StatelessWidget {
  final bool isDark;
  const _WaitingHint({required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.psychology_rounded, size: 64, color: AppColors.violet),
        const SizedBox(height: 16),
        const Text('Preparing interview…',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 8),
        Text('Hold mic to speak  •  or type below',
            style: TextStyle(
                fontSize: 12, color: Colors.grey.withValues(alpha: 0.6))),
      ]));
}

class _TypingBubble extends StatelessWidget {
  final bool isDark;
  const _TypingBubble({required this.isDark});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const _Dot(delay: 0),
            const SizedBox(width: 5),
            const _Dot(delay: 180),
            const SizedBox(width: 5),
            const _Dot(delay: 360)
          ])));
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({super.key, required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _a = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _a,
      child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              color: AppColors.violet, shape: BoxShape.circle)));
}
