// lib/features/interview/pages/interview_chat_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/locale/app_strings.dart';
import '../providers/interview_provider.dart';
import '../../../services/tts_service.dart';
import '../../../services/audio_recorder.dart';
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
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart);
        }
      });

  void _speak(String text, String lang) {
    if (!_ttsEnabled || text.isEmpty) return;
    _tts.speak(text, language: lang);
  }

  Future<void> _startRec() async {
    if (_isRecording) return;
    try {
      HapticFeedback.mediumImpact();
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
      await ref.read(interviewSessionProvider.notifier).sendVoiceBytes(
          bytes, _audioFilename,
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
    HapticFeedback.lightImpact();
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
      setState(() => _aiThinking = true);
      await ref.read(interviewSessionProvider.notifier).endInterview();
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  Future<bool?> _dlg(
      {required String title, required String body, required String confirm}) {
    final s = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: dark ? const Color(0xFF1E222C) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
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
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirm)),
              ],
            ));
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
    final chatBg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF7F8FE);

    // ── FIX: Check isCompleted in build — listener alone is not enough ──
    if (session.isCompleted) {
      return InterviewFeedbackPage(session: session);
    }

    // ── Listener for TTS + video + goal refresh ──
    ref.listen(interviewSessionProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollDown();
        if (next.messages.isNotEmpty) {
          final last = next.messages.last;
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
        _tts.stop();
      }
      if (next.error != null && next.error != prev?.error) _snack(next.error!);
    });

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
        backgroundColor: chatBg,
        body: Column(children: [
          // ── Header ──────────────────────────────────────────
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

          // Goal banner
          if (session.goalId != null)
            _GoalBanner(
                goalId: session.goalId!,
                jobRole: session.jobRole,
                isDark: isDark,
                isAr: isAr),

          // Avatar video
          if (_videoUrl != null)
            _AvatarSection(
                videoUrl: _videoUrl!,
                onComplete: () => setState(() => _videoUrl = null)),

          // AI thinking — subtle top progress bar
          if (_aiThinking && _videoUrl == null)
            LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.violet,
                backgroundColor: AppColors.violet.withValues(alpha: 0.10)),

          // ── Messages ────────────────────────────────────────
          Expanded(
              child: session.messages.isEmpty
                  ? _WaitingHint(isDark: isDark, isAr: isAr)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      itemCount:
                          session.messages.length + (session.isTyping ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (session.isTyping && i == session.messages.length) {
                          return _TypingBubble(isDark: isDark);
                        }
                        final msg = session.messages[i];
                        return _UnifiedBubble(
                            msg: msg,
                            isDark: isDark,
                            isAr: isAr,
                            onTapSpeak: () =>
                                _speak(msg.content, session.language));
                      })),

          // ── Input ───────────────────────────────────────────
          _InputBar(
              controller: _ctrl,
              isDark: isDark,
              isAr: isAr,
              isRecording: _isRecording,
              recSecs: _recSecs,
              isTyping: session.isTyping,
              onSend: (session.isTyping || _isRecording) ? null : _send,
              onRecStart: _startRec,
              onRecStop: _stopRec),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════
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
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
        child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 12),
        color: isDark
            ? const Color(0xFF0F1219).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Close
          GestureDetector(
            onTap: () => context.go('/interview'),
            child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.close_rounded,
                    size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : Colors.black.withValues(alpha: 0.55))),
          ),
          const SizedBox(width: 10),
          // AI avatar
          Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.violet, AppColors.violetDk]),
                  shape: BoxShape.circle),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          // Title
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    session.jobRole.isNotEmpty
                        ? session.jobRole
                        : (isAr ? 'المقابِل الذكي' : 'AI Interviewer'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1A1C20)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.emerald, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(
                      '${session.difficulty.toUpperCase()} · '
                      '${session.language == "ar" ? "العربية" : "English"}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.40)
                              : Colors.black.withValues(alpha: 0.38))),
                  if (session.goalId != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.flag_rounded,
                        size: 10, color: AppColors.violet),
                  ],
                ]),
              ])),
          // Q counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${session.userMsgCount}/7',
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 4),
          // TTS toggle
          GestureDetector(
              onTap: onToggleTts,
              child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: ttsEnabled
                          ? AppColors.violet.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                      ttsEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: ttsEnabled
                          ? AppColors.violet
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.30)
                              : Colors.black.withValues(alpha: 0.28)),
                      size: 18))),
          const SizedBox(width: 4),
          // End button
          GestureDetector(
              onTap: onEnd,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.25))),
                  child: Text(isAr ? 'إنهاء' : 'End',
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)))),
        ]),
      ),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════
// GOAL BANNER — uses ConsumerWidget to read real goal data
// ══════════════════════════════════════════════════════════════════
class _GoalBanner extends ConsumerWidget {
  final int goalId;
  final String jobRole;
  final bool isDark, isAr;
  const _GoalBanner(
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
                  fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// UNIFIED BUBBLE — handles both text and voice
// ══════════════════════════════════════════════════════════════════
class _UnifiedBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isDark, isAr;
  final VoidCallback onTapSpeak;
  const _UnifiedBubble(
      {required this.msg,
      required this.isDark,
      required this.isAr,
      required this.onTapSpeak});

  String get _time => '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
      '${msg.timestamp.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[_AvatarCircle(), const SizedBox(width: 8)],
              Flexible(
                  child: GestureDetector(
                onTap: isUser ? null : onTapSpeak,
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.violet
                        : (isDark ? const Color(0xFF1E222C) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isUser ? 22 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 22),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: isUser
                              ? AppColors.violet.withValues(alpha: 0.22)
                              : Colors.black
                                  .withValues(alpha: isDark ? 0.18 : 0.06),
                          blurRadius: isUser ? 12 : 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: msg.isVoice
                      ? _VoiceContent(msg: msg, isUser: isUser, isAr: isAr)
                      : Text(msg.content,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: isUser
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.88)
                                      : const Color(0xFF1A1C20)))),
                ),
              )),
              if (isUser) ...[const SizedBox(width: 8), _UserCircle()],
            ],
          ),
          // Timestamp outside bubble
          Padding(
            padding: EdgeInsets.only(
                top: 5, left: isUser ? 0 : 46, right: isUser ? 46 : 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_time,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.black.withValues(alpha: 0.28))),
              if (!isUser) ...[
                const SizedBox(width: 4),
                Icon(Icons.volume_up_rounded,
                    size: 10,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.20)),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Voice content inside bubble ──────────────────────────────────
class _VoiceContent extends StatelessWidget {
  final ChatMessage msg;
  final bool isUser, isAr;
  const _VoiceContent(
      {required this.msg, required this.isUser, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final dur = msg.audioDuration;
    final durStr = dur == null
        ? '0:00'
        : '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.mic_rounded,
          color: isUser ? Colors.white : AppColors.violet, size: 22),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StaticWave(
            color: isUser
                ? Colors.white.withValues(alpha: 0.70)
                : AppColors.violet.withValues(alpha: 0.50)),
        const SizedBox(height: 4),
        if (msg.content.isNotEmpty)
          Text(msg.content,
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.75)
                      : Colors.grey.shade600))
        else
          Text(isAr ? 'جاري التحويل…' : 'Transcribing…',
              style: TextStyle(
                  fontSize: 10,
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.grey)),
      ]),
      const SizedBox(width: 10),
      Text(durStr,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  isUser ? Colors.white.withValues(alpha: 0.70) : Colors.grey)),
    ]);
  }
}

// Static waveform — fixed bars, no Random() in build
class _StaticWave extends StatelessWidget {
  final Color color;
  const _StaticWave({required this.color});
  static const _bars = [
    0.4,
    0.7,
    0.5,
    0.9,
    0.6,
    0.8,
    0.4,
    0.7,
    0.5,
    0.8,
    0.6,
    0.4
  ];

  @override
  Widget build(BuildContext context) => Row(
        children: _bars
            .map((h) => Container(
                  width: 2.5,
                  height: h * 20,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ))
            .toList(),
      );
}

// ══════════════════════════════════════════════════════════════════
// INPUT BAR — floating pill style from doc 20
// ══════════════════════════════════════════════════════════════════
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
      required this.isAr,
      required this.isRecording,
      required this.recSecs,
      required this.isTyping,
      required this.onSend,
      required this.onRecStart,
      required this.onRecStop});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final barColor = isDark ? const Color(0xFF1E222C) : Colors.white;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 14),
      color: Colors.transparent,
      child: isRecording
          ? _RecordingPanel(secs: recSecs, onStop: onRecStop, isAr: isAr)
          : Row(children: [
              // Text pill
              Expanded(
                  child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.30 : 0.07),
                        blurRadius: 14,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(children: [
                  const SizedBox(width: 18),
                  Expanded(
                      child: TextField(
                    controller: controller,
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1A1C20)),
                    decoration: InputDecoration(
                      hintText: isAr ? 'اكتب هنا...' : 'Type your answer...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: true,
                      fillColor: barColor,
                      hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: 0.30)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onSubmitted: (_) => onSend?.call(),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  )),
                  // Mic inside pill
                  GestureDetector(
                      onTap: onRecStart,
                      child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                              color: AppColors.violet.withValues(alpha: 0.08),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.mic_none_rounded,
                              color: AppColors.violet, size: 20))),
                ]),
              )),
              const SizedBox(width: 10),
              // Send circle
              GestureDetector(
                onTap: onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: (onSend == null || isTyping)
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.grey.shade300)
                        : AppColors.violet,
                    shape: BoxShape.circle,
                    boxShadow: (onSend != null && !isTyping)
                        ? [
                            BoxShadow(
                                color: AppColors.violet.withValues(alpha: 0.40),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: isTyping
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.40)
                                  : Colors.grey.shade400,
                              strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// RECORDING PANEL
// ══════════════════════════════════════════════════════════════════
class _RecordingPanel extends StatelessWidget {
  final int secs;
  final VoidCallback onStop;
  final bool isAr;
  const _RecordingPanel(
      {required this.secs, required this.onStop, required this.isAr});

  String get _fmt =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
            color: AppColors.rose.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.25))),
        child: Row(children: [
          _PulsingDot(),
          const SizedBox(width: 10),
          Text(_fmt,
              style: const TextStyle(
                  color: AppColors.rose,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          const Spacer(),
          Text(isAr ? 'جاري التسجيل...' : 'Recording...',
              style: const TextStyle(
                  color: AppColors.rose,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
              onTap: onStop,
              child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: AppColors.rose, shape: BoxShape.circle),
                  child: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 22))),
        ]),
      );
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _c,
      child: const Icon(Icons.circle, color: AppColors.rose, size: 10));
}

// ══════════════════════════════════════════════════════════════════
// AVATAR CIRCLES
// ══════════════════════════════════════════════════════════════════
class _AvatarCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [AppColors.violet, AppColors.violetDk]),
          shape: BoxShape.circle),
      child:
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 17));
}

class _UserCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: 0.12),
          shape: BoxShape.circle),
      child:
          const Icon(Icons.person_rounded, color: AppColors.violet, size: 17));
}

// ══════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ══════════════════════════════════════════════════════════════════
class _AvatarSection extends StatelessWidget {
  final String videoUrl;
  final VoidCallback onComplete;
  const _AvatarSection({required this.videoUrl, required this.onComplete});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 200,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.violet.withValues(alpha: 0.20), blurRadius: 20)
          ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child:
              AvatarVideoPlayer(videoUrl: videoUrl, onComplete: onComplete)));
}

class _WaitingHint extends StatelessWidget {
  final bool isDark, isAr;
  const _WaitingHint({required this.isDark, required this.isAr});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.psychology_rounded,
                color: AppColors.violet, size: 42)),
        const SizedBox(height: 16),
        Text(isAr ? 'جاري تحضير المقابلة…' : 'Preparing interview…',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.50)
                    : Colors.grey)),
        const SizedBox(height: 8),
        Text(isAr ? 'اكتب أو اضغط على المايكروفون' : 'Type or tap the mic',
            style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.28))),
      ]));
}

class _TypingBubble extends StatelessWidget {
  final bool isDark;
  const _TypingBubble({required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _AvatarCircle(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222C) : Colors.white,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                    bottomLeft: Radius.circular(4)),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(delay: 0),
              SizedBox(width: 5),
              _Dot(delay: 180),
              SizedBox(width: 5),
              _Dot(delay: 360),
            ]),
          ),
        ]),
      );
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _a = Tween(begin: 0.3, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  @override
  void initState() {
    super.initState();
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
