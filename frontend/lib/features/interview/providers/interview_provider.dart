// lib/features/interview/providers/interview_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/interview_service.dart';

class ChatMessage {
  final String role;
  final String content;
  final bool isTyping;
  final String? videoUrl;
  final String? talkId;

  ChatMessage({
    required this.role,
    required this.content,
    this.isTyping = false,
    this.videoUrl,
    this.talkId,
  });

  ChatMessage copyWith(
      {String? role,
      String? content,
      bool? isTyping,
      String? videoUrl,
      String? talkId}) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      isTyping: isTyping ?? this.isTyping,
      videoUrl: videoUrl ?? this.videoUrl,
      talkId: talkId ?? this.talkId,
    );
  }
}

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
  final bool useAvatar;
  final String avatarId;

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
    this.useAvatar = false,
    this.avatarId = 'professional_female',
  });

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
    bool? useAvatar,
    String? avatarId,
  }) {
    return InterviewSessionState(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isRecording: isRecording ?? this.isRecording,
      error: error,
      finalScore: finalScore ?? this.finalScore,
      finalFeedback: finalFeedback ?? this.finalFeedback,
      language: language ?? this.language,
      useAvatar: useAvatar ?? this.useAvatar,
      avatarId: avatarId ?? this.avatarId,
    );
  }
}

class InterviewSessionNotifier extends StateNotifier<InterviewSessionState> {
  final _service = InterviewService();

  InterviewSessionNotifier() : super(const InterviewSessionState());

  Future<bool> startInterview({
    required String jobRole,
    required String difficulty,
    required String interviewType,
    required String language,
    int? resumeId,
    bool useAvatar = false,
    String avatarId = 'professional_female',
  }) async {
    state = state.copyWith(
        status: 'starting',
        language: language,
        useAvatar: useAvatar,
        avatarId: avatarId);

    final result = await _service.startInterview(
      jobRole: jobRole,
      difficulty: difficulty,
      interviewType: interviewType,
      language: language,
      resumeId: resumeId,
    );

    if (result['success']) {
      final sessionId = result['session_id'];
      final firstQuestion =
          result['first_question'] ?? 'Hello! Ready to begin?';

      state = state.copyWith(
        sessionId: sessionId,
        status: 'active',
        messages: [ChatMessage(role: 'assistant', content: firstQuestion)],
      );
      return true;
    } else {
      state = state.copyWith(
          error: result['message'] ?? 'Failed to start interview');
      return false;
    }
  }

  Future<void> sendMessage(String userMessage) async {
    if (state.sessionId == null) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: 'user', content: userMessage)
      ],
      isTyping: true,
      error: null,
    );

    final result = await _service.sendMessage(
      state.sessionId!,
      userMessage,
      useAvatar: state.useAvatar,
      avatarId: state.avatarId,
    );

    if (result['success']) {
      final responseData = result['response'];
      final responseText = responseData is Map
          ? (responseData['text'] ?? responseData['content'] ?? '')
          : responseData.toString();
      final videoUrl = responseData is Map ? responseData['video_url'] : null;
      final talkId = responseData is Map ? responseData['talk_id'] : null;

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
              role: 'assistant',
              content: responseText,
              videoUrl: videoUrl,
              talkId: talkId),
        ],
        isTyping: false,
      );
    } else {
      state = state.copyWith(
          isTyping: false,
          error: result['message'] ?? 'Failed to send message');
    }
  }

  Future<void> sendVoiceBytes(List<int> bytes, String filename) async {
    if (state.sessionId == null) return;

    state = state.copyWith(isTyping: true, error: null);

    final result = await _service.sendVoice(
      state.sessionId!,
      bytes,
      filename,
      useAvatar: state.useAvatar,
      avatarId: state.avatarId,
    );

    if (result['success']) {
      final transcription = result['transcription'] ?? '';
      final responseData = result['response'];
      final responseText = responseData is Map
          ? (responseData['text'] ?? responseData['content'] ?? '')
          : responseData.toString();
      final videoUrl = responseData is Map ? responseData['video_url'] : null;
      final talkId = responseData is Map ? responseData['talk_id'] : null;

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(role: 'user', content: transcription),
          ChatMessage(
              role: 'assistant',
              content: responseText,
              videoUrl: videoUrl,
              talkId: talkId),
        ],
        isTyping: false,
      );
    } else {
      state = state.copyWith(
          isTyping: false,
          error: result['message'] ?? 'Failed to process voice');
    }
  }

  Future<void> endInterview() async {
    if (state.sessionId == null) return;

    final result = await _service.endInterview(state.sessionId!);

    if (result['success']) {
      state = state.copyWith(
        status: 'completed',
        finalScore: (result['score'] as num?)?.toDouble(),
        finalFeedback: result['feedback'] as Map<String, dynamic>?,
      );
    }
  }

  void setRecording(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  void reset() {
    state = const InterviewSessionState();
  }
}

final interviewSessionProvider =
    StateNotifierProvider<InterviewSessionNotifier, InterviewSessionState>(
  (ref) => InterviewSessionNotifier(),
);

final interviewHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = InterviewService();
  return await service.getInterviewHistory();
});
