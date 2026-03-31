// lib/features/interview/pages/interview_chat_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/background_painter.dart';
import '../providers/interview_provider.dart';
import '../../../services/tts_service.dart';
import '../../../services/audio_recorder.dart'; // ← CORRECT PATH: lib/services/
import '../widgets/avatar_video_player.dart';
import '../../goals/providers/goal_provider.dart';
import 'interview_feedback_page.dart';

class InterviewChatPage extends ConsumerStatefulWidget {
  const InterviewChatPage({super.key});
  @override
  ConsumerState<InterviewChatPage> createState() => _ChatState();
}

class _ChatState extends ConsumerState<InterviewChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _tts = TtsService();
  final _recorder = AudioRecorder();

  bool _ttsEnabled = true;
  bool _isRecording = false;
  int _recSecs = 0;
  Timer? _recTimer;
  String? _videoUrl;
  bool _aiThinking = false;

  // ── audio filename is platform-aware ─────────────────────────────
  String get _audioFilename => kIsWeb ? 'voice.webm' : 'voice.m4a';

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
    _recorder.dispose();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic);
        }
      });

  void _speak(String text, String lang) {
    if (!_ttsEnabled || text.isEmpty) return;
    _tts.speak(text, language: lang);
  }

  Future<void> _startRec() async {
    if (_isRecording) return;
    try {
      await _recorder.start();
      _recSecs = 0;
      setState(() => _isRecording = true);
      ref.read(interviewSessionProvider.notifier).setRecording(true);
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSecs++);
      });
    } catch (e) {
      _snack('Mic error: $e');
    }
  }

  Future<void> _stopRec() async {
    if (!_isRecording) return;
    _recTimer?.cancel();
    setState(() => _isRecording = false);
    ref.read(interviewSessionProvider.notifier).setRecording(false);

    final dur = _recSecs;
    try {
      final bytes = await _recorder.stop();
      if (bytes.isEmpty || !mounted) return;
      setState(() => _aiThinking = true);
      await ref.read(interviewSessionProvider.notifier).sendVoiceBytes(bytes,
          _audioFilename, // ← FIXED: 'voice.m4a' on mobile, 'voice.webm' on web
          recordedDuration: Duration(seconds: dur));
      _scrollDown();
      if (mounted) setState(() => _aiThinking = false);
    } catch (e) {
      if (mounted) {
        setState(() => _aiThinking = false);
        _snack('Voice error: $e');
      }
    }
  }

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

  Future<void> _end() async {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final ok = await _dlg(
        title: isAr ? 'إنهاء المقابلة؟' : 'End Interview?',
        body: isAr
            ? 'سيتم تقييم جلستك مع تغذية راجعة مفصّلة.'
            : 'Your session will be scored with detailed AI feedback.',
        confirm: isAr ? 'إنهاء وتقييم' : 'End & Score');
    if (ok == true) {
      await ref.read(interviewSessionProvider.notifier).endInterview();
    }
  }

  Future<bool?> _dlg(
      {required String title, required String body, required String confirm}) {
    final s = AppStrings.of(context);
    return showDialog<bool>(
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
                    child: Text(s.cancel)),
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
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(interviewSessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    ref.listen(interviewSessionProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollDown();
        if (next.messages.isNotEmpty) {
          final last = next.messages.last;
          // Speak AI reply — always speak if TTS enabled
          if (last.role == 'assistant' &&
              !last.isTyping &&
              last.content.isNotEmpty) {
            if (last.videoUrl?.isNotEmpty == true) {
              setState(() => _videoUrl = last.videoUrl);
            } else {
              _speak(last.content, next.language);
            }
          }
        }
      }
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        final goalId = next.goalId;
        if (goalId != null) {
          ref.read(goalProvider.notifier).loadGoalProgress(goalId);
        }
      }
      if (next.error != null && next.error != prev?.error) _snack(next.error!);
    });

    if (session.isCompleted) return InterviewFeedbackPage(session: session);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _dlg(
            title: isAr ? 'مغادرة الجلسة؟' : 'Leave Session?',
            body: isAr
                ? 'سيتم حفظ تقدمك لكن لن تحصل على تقييم.'
                : "Progress is saved but you won't get a score yet.",
            confirm: isAr ? 'مغادرة' : 'Leave');
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
            _ChatHeader(
                isDark: isDark,
                ttsEnabled: _ttsEnabled,
                session: session,
                isAr: isAr,
                onToggleTts: () {
                  setState(() => _ttsEnabled = !_ttsEnabled);
                  if (!_ttsEnabled) _tts.stop();
                },
                onEnd: _end),
            if (session.goalId != null)
              _GoalSessionBanner(
                  goalId: session.goalId!,
                  jobRole: session.jobRole,
                  isDark: isDark,
                  isAr: isAr),
            if (_videoUrl != null)
              _AvatarSection(
                  videoUrl: _videoUrl!,
                  onComplete: () => setState(() => _videoUrl = null)),
            if (_aiThinking && _videoUrl == null)
              _ThinkingBar(isDark: isDark, isAr: isAr),
            Expanded(
                child: session.messages.isEmpty
                    ? _WaitingHint(isDark: isDark, isAr: isAr)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        itemCount: session.messages.length +
                            (session.isTyping ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (session.isTyping &&
                              i == session.messages.length) {
                            return _TypingBubble(isDark: isDark);
                          }
                          final msg = session.messages[i];
                          if (msg.isVoice) {
                            return _VoiceBubble(
                                msg: msg, isDark: isDark, isAr: isAr);
                          }
                          return _TextBubble(
                              msg: msg,
                              isDark: isDark,
                              onTapSpeak: () =>
                                  _speak(msg.content, session.language));
                        })),
            _InputBar(
                controller: _ctrl,
                isDark: isDark,
                isRecording: _isRecording,
                recSecs: _recSecs,
                isTyping: session.isTyping,
                isAr: isAr,
                onSend: (session.isTyping || _isRecording) ? null : _send,
                onRecStart: _startRec,
                onRecStop: _stopRec),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDGETS (unchanged from original)
// ══════════════════════════════════════════════════════════════════

class _GoalSessionBanner extends ConsumerWidget {
  final int goalId;
  final String jobRole;
  final bool isDark, isAr;
  const _GoalSessionBanner(
      {required this.goalId,
      required this.jobRole,
      required this.isDark,
      required this.isAr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalProvider).goals;
    final goal = goals.where((g) => g.id == goalId).firstOrNull;
    final weekDone = goal?.currentWeekCount ?? 0;
    final weekTarget = goal?.weeklyInterviewTarget ?? 3;
    final onTrack = weekDone >= weekTarget;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: isDark ? 0.12 : 0.07),
          border: Border(
              bottom:
                  BorderSide(color: AppColors.violet.withValues(alpha: 0.15)))),
      child: Row(children: [
        const Icon(Icons.flag_rounded, color: AppColors.violet, size: 13),
        const SizedBox(width: 6),
        Expanded(
            child: Text(
                isAr ? 'مقابلة ضمن هدف: $jobRole' : 'Goal interview: $jobRole',
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: (onTrack ? AppColors.emerald : AppColors.violet)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
                '$weekDone/$weekTarget ${isAr ? "هذا الأسبوع" : "this wk"}',
                style: TextStyle(
                    color: onTrack ? AppColors.emerald : AppColors.violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final bool isDark, ttsEnabled, isAr;
  final InterviewSessionState session;
  final VoidCallback onToggleTts, onEnd;
  const _ChatHeader(
      {required this.isDark,
      required this.ttsEnabled,
      required this.session,
      required this.isAr,
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
                            : (isAr ? 'المقابِل الذكي' : 'AI Interviewer'),
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
                          '${session.difficulty.toUpperCase()} • '
                          '${session.language == "ar" ? "العربية" : "English"}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w700)),
                      if (session.goalId != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.flag_rounded,
                            size: 10, color: AppColors.violet),
                      ],
                    ]),
                  ])),
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
                  child: Text(isAr ? 'إنهاء' : 'End',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12))),
            ]),
          )));
}

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
  final bool isDark, isAr;
  const _ThinkingBar({required this.isDark, required this.isAr});
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
        Text(isAr ? 'الذكاء الاصطناعي يفكر…' : 'AI is thinking…',
            style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
}

class _WaitingHint extends StatelessWidget {
  final bool isDark, isAr;
  const _WaitingHint({required this.isDark, required this.isAr});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.psychology_rounded, size: 64, color: AppColors.violet),
        const SizedBox(height: 16),
        Text(isAr ? 'جاري تحضير المقابلة…' : 'Preparing interview…',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(
            isAr
                ? 'اضغط على المايكروفون للكلام  •  أو اكتب أدناه'
                : 'Tap mic to speak  •  or type below',
            style: TextStyle(
                fontSize: 12, color: Colors.grey.withValues(alpha: 0.6))),
      ]));
}

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
                                      size: 10, color: Colors.grey.shade400),
                                ],
                              ]),
                            ]),
                      ))),
            ]));
  }
}

class _VoiceBubble extends StatefulWidget {
  final ChatMessage msg;
  final bool isDark, isAr;
  const _VoiceBubble(
      {required this.msg, required this.isDark, required this.isAr});
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
                      Row(children: [
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
                          Text(widget.isAr ? 'جاري التحويل…' : 'Transcribing…',
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark, isRecording, isTyping, isAr;
  final int recSecs;
  final VoidCallback? onSend;
  final VoidCallback onRecStart;
  final Future<void> Function() onRecStop;
  const _InputBar(
      {required this.controller,
      required this.isDark,
      required this.isRecording,
      required this.recSecs,
      required this.isTyping,
      required this.isAr,
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
          ? _RecBar(
              isDark: isDark, secs: recSecs, onStop: onRecStop, isAr: isAr)
          : Row(children: [
              GestureDetector(
                  // TAP ONCE to start, tap again (via _RecBar stop) to stop
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
                              hintText:
                                  isAr ? 'اكتب إجابتك…' : 'Type your answer…',
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

class _RecBar extends StatefulWidget {
  final bool isDark, isAr;
  final int secs;
  final Future<void> Function() onStop;
  const _RecBar(
      {required this.isDark,
      required this.secs,
      required this.onStop,
      required this.isAr});
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

  String get _fmt => '${(widget.secs ~/ 60).toString().padLeft(2, '0')}:'
      '${(widget.secs % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Row(children: [
        // Trash = cancel (don't send)
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
        Text(widget.isAr ? 'اضغط ■ للإرسال' : 'Tap ■ to send',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const Spacer(),
        // Stop = send
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
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0),
            SizedBox(width: 5),
            _Dot(delay: 180),
            SizedBox(width: 5),
            _Dot(delay: 360),
          ])));
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
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
