// lib/features/interview/providers/interview_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/interview_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum InterviewMode { textVoice, video }

enum MessageKind { text, voice }

// ─────────────────────────────────────────────────────────────────────────────
// CHAT MESSAGE
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  final String role;
  final String content;
  final bool isTyping;
  final MessageKind kind;
  final Duration? audioDuration;
  final List<double>? waveformBars;
  final String? videoUrl;
  final String? talkId;
  final bool shouldSpeak;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.isTyping = false,
    this.kind = MessageKind.text,
    this.audioDuration,
    this.waveformBars,
    this.videoUrl,
    this.talkId,
    this.shouldSpeak = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isVoice => kind == MessageKind.voice;
  bool get isUser => role == 'user';

  ChatMessage copyWith({
    String? role,
    String? content,
    bool? isTyping,
    MessageKind? kind,
    Duration? audioDuration,
    List<double>? waveformBars,
    String? videoUrl,
    String? talkId,
    bool? shouldSpeak,
  }) =>
      ChatMessage(
        role: role ?? this.role,
        content: content ?? this.content,
        isTyping: isTyping ?? this.isTyping,
        kind: kind ?? this.kind,
        audioDuration: audioDuration ?? this.audioDuration,
        waveformBars: waveformBars ?? this.waveformBars,
        videoUrl: videoUrl ?? this.videoUrl,
        talkId: talkId ?? this.talkId,
        shouldSpeak: shouldSpeak ?? this.shouldSpeak,
        timestamp: timestamp,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION STATE
// ─────────────────────────────────────────────────────────────────────────────

class InterviewSessionState {
  final int? sessionId;
  final String status;
  final List<ChatMessage> messages;
  final bool isTyping;
  final bool isRecording;
  final String? error;
  final double? finalScore;
  final Map<String, dynamic>? finalFeedback;
  final String language;
  final InterviewMode mode;
  final String avatarId;
  final String avatarSourceUrl;
  final String avatarIdleVideoUrl; // ← D-ID idle.mp4
  final String jobRole;
  final String difficulty;
  final int userMsgCount;
  final String? latestVideoUrl;
  final bool isGeneratingVideo;

  const InterviewSessionState({
    this.sessionId,
    this.status = 'idle',
    this.messages = const [],
    this.isTyping = false,
    this.isRecording = false,
    this.error,
    this.finalScore,
    this.finalFeedback,
    this.language = 'en',
    this.mode = InterviewMode.textVoice,
    this.avatarId = 'professional_female',
    this.avatarSourceUrl = '',
    this.avatarIdleVideoUrl = '', // ← default empty
    this.jobRole = '',
    this.difficulty = 'medium',
    this.userMsgCount = 0,
    this.latestVideoUrl,
    this.isGeneratingVideo = false,
  });

  bool get isVideoMode => mode == InterviewMode.video;
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get useAvatar => isVideoMode;

  InterviewSessionState copyWith({
    int? sessionId,
    String? status,
    List<ChatMessage>? messages,
    bool? isTyping,
    bool? isRecording,
    String? error,
    double? finalScore,
    Map<String, dynamic>? finalFeedback,
    String? language,
    InterviewMode? mode,
    String? avatarId,
    String? avatarSourceUrl,
    String? avatarIdleVideoUrl,
    String? jobRole,
    String? difficulty,
    int? userMsgCount,
    String? latestVideoUrl,
    bool? isGeneratingVideo,
    bool clearError = false,
    bool clearVideo = false,
  }) =>
      InterviewSessionState(
        sessionId: sessionId ?? this.sessionId,
        status: status ?? this.status,
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        isRecording: isRecording ?? this.isRecording,
        error: clearError ? null : (error ?? this.error),
        finalScore: finalScore ?? this.finalScore,
        finalFeedback: finalFeedback ?? this.finalFeedback,
        language: language ?? this.language,
        mode: mode ?? this.mode,
        avatarId: avatarId ?? this.avatarId,
        avatarSourceUrl: avatarSourceUrl ?? this.avatarSourceUrl,
        avatarIdleVideoUrl: avatarIdleVideoUrl ?? this.avatarIdleVideoUrl,
        jobRole: jobRole ?? this.jobRole,
        difficulty: difficulty ?? this.difficulty,
        userMsgCount: userMsgCount ?? this.userMsgCount,
        latestVideoUrl:
            clearVideo ? null : (latestVideoUrl ?? this.latestVideoUrl),
        isGeneratingVideo: isGeneratingVideo ?? this.isGeneratingVideo,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class InterviewSessionNotifier extends StateNotifier<InterviewSessionState> {
  final _service = InterviewService();
  bool _lastInputWasVoice = false;

  InterviewSessionNotifier() : super(const InterviewSessionState());

  // ── Start ──────────────────────────────────────────────────────────────────
  Future<bool> startInterview({
    required String jobRole,
    required String difficulty,
    required String interviewType,
    required String language,
    int? resumeId,
    bool useAvatar = false,
    String avatarId = 'professional_female',
    String avatarSourceUrl = '',
    String avatarIdleVideoUrl = '', // ← NEW
    InterviewMode mode = InterviewMode.textVoice,
  }) async {
    final resolvedMode = useAvatar ? InterviewMode.video : mode;

    state = state.copyWith(
      status: 'starting',
      language: language,
      mode: resolvedMode,
      avatarId: avatarId,
      avatarSourceUrl: avatarSourceUrl,
      avatarIdleVideoUrl: avatarIdleVideoUrl, // ← store it
      jobRole: jobRole,
      difficulty: difficulty,
      clearError: true,
    );

    final result = await _service.startInterview(
      jobRole: jobRole,
      difficulty: difficulty,
      interviewType: interviewType,
      language: language,
      resumeId: resumeId,
    );

    if (!mounted) return false;

    if (result['success'] == true) {
      final firstQuestion = result['first_question']?.toString() ??
          (language == 'ar'
              ? 'مرحباً! أنا مستعد لبدء المقابلة.'
              : 'Hello! Ready to begin your interview?');

      state = state.copyWith(
        sessionId: result['session_id'] as int?,
        status: 'active',
        messages: [
          ChatMessage(
            role: 'assistant',
            content: firstQuestion,
            shouldSpeak: true,
          )
        ],
      );
      return true;
    } else {
      state = state.copyWith(
        status: 'idle',
        error: result['message']?.toString() ?? 'Failed to start interview',
      );
      return false;
    }
  }

  // ── Text message ───────────────────────────────────────────────────────────
  Future<void> sendMessage(String userMessage) async {
    if (state.sessionId == null) return;
    _lastInputWasVoice = false;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: 'user', content: userMessage, kind: MessageKind.text),
      ],
      isTyping: true,
      userMsgCount: state.userMsgCount + 1,
      clearError: true,
    );

    final result = await _service.sendMessage(
      state.sessionId!,
      userMessage,
      useAvatar: state.isVideoMode,
      avatarId: state.avatarId,
      sourceUrl: state.avatarSourceUrl,
      language: state.language,
    );

    if (!mounted) return;
    _handleAiResponse(result);
  }

  // ── Voice message ──────────────────────────────────────────────────────────
  Future<void> sendVoiceBytes(
    List<int> bytes,
    String filename, {
    Duration? recordedDuration,
    List<double>? waveform,
  }) async {
    if (state.sessionId == null) return;
    _lastInputWasVoice = true;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          role: 'user',
          content: '',
          kind: MessageKind.voice,
          audioDuration: recordedDuration,
          waveformBars: waveform ?? _fakeWaveform(),
        ),
      ],
      isTyping: true,
      userMsgCount: state.userMsgCount + 1,
      clearError: true,
    );

    final result = await _service.sendVoice(
      state.sessionId!,
      bytes,
      filename,
      useAvatar: state.isVideoMode,
      avatarId: state.avatarId,
      sourceUrl: state.avatarSourceUrl,
      language: state.language,
    );

    if (!mounted) return;

    // Fill in the transcript for the voice bubble
    final transcript = result['transcription']?.toString() ?? '';
    final msgs = List<ChatMessage>.from(state.messages);
    final idx =
        msgs.lastIndexWhere((m) => m.isVoice && m.isUser && m.content.isEmpty);
    if (idx != -1) {
      msgs[idx] = msgs[idx].copyWith(content: transcript);
      state = state.copyWith(messages: msgs);
    }

    _handleAiResponse(result);
  }

  // ── Shared AI response handler ─────────────────────────────────────────────
  void _handleAiResponse(Map<String, dynamic> result) {
    if (result['success'] == true) {
      final raw = result['response'];
      final responseText = (raw is Map)
          ? (raw['text'] ?? raw['content'] ?? '').toString()
          : raw?.toString() ?? '';
      final videoUrl = (raw is Map) ? raw['video_url']?.toString() : null;
      final talkId = (raw is Map) ? raw['talk_id']?.toString() : null;

      final isEnded = result['interview_status']?.toString() == 'completed';
      final aiKind = _lastInputWasVoice ? MessageKind.voice : MessageKind.text;
      final wordCount = responseText.split(' ').length;
      final estSeconds = ((wordCount / 130) * 60).round().clamp(1, 120);

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: 'assistant',
            content: responseText,
            kind: aiKind,
            shouldSpeak: _lastInputWasVoice,
            waveformBars: aiKind == MessageKind.voice ? _fakeWaveform() : null,
            audioDuration: aiKind == MessageKind.voice
                ? Duration(seconds: estSeconds)
                : null,
            videoUrl: videoUrl,
            talkId: talkId,
          ),
        ],
        isTyping: false,
        isGeneratingVideo: false,
        latestVideoUrl: videoUrl,
        status: isEnded ? 'completed' : null,
        finalScore: isEnded ? (result['score'] as num?)?.toDouble() : null,
        finalFeedback:
            isEnded ? result['feedback'] as Map<String, dynamic>? : null,
      );
    } else {
      state = state.copyWith(
        isTyping: false,
        isGeneratingVideo: false,
        error: result['message']?.toString() ?? 'Something went wrong',
      );
    }
  }

  // ── End interview ──────────────────────────────────────────────────────────
  Future<void> endInterview() async {
    if (state.sessionId == null) return;
    state = state.copyWith(isTyping: true);
    final result = await _service.endInterview(state.sessionId!);
    if (!mounted) return;
    if (result['success'] == true) {
      state = state.copyWith(
        status: 'completed',
        isTyping: false,
        finalScore: (result['score'] as num?)?.toDouble(),
        finalFeedback: result['feedback'] as Map<String, dynamic>?,
      );
    } else {
      state = state.copyWith(isTyping: false);
    }
  }

  void setRecording(bool v) => state = state.copyWith(isRecording: v);
  void clearLatestVideo() => state = state.copyWith(clearVideo: true);
  void reset() => state = const InterviewSessionState();

  static List<double> _fakeWaveform() => const [
        0.20,
        0.45,
        0.65,
        0.90,
        0.55,
        0.80,
        0.40,
        0.70,
        0.50,
        0.85,
        0.60,
        0.30,
        0.75,
        0.50,
        0.70,
        0.95,
        0.40,
        0.60,
        0.80,
        0.50,
        0.35,
        0.70,
        0.90,
        0.55,
        0.40,
        0.65,
        0.80,
        0.30,
        0.50,
        0.20,
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final interviewSessionProvider =
    StateNotifierProvider<InterviewSessionNotifier, InterviewSessionState>(
  (ref) => InterviewSessionNotifier(),
);

final interviewHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return InterviewService().getInterviewHistory();
});
