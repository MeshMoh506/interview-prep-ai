// lib/features/interview/models/interview_model.dart
// Handles both /history and /interviews API response shapes safely.

class Interview {
  final int id;
  final String jobRole;
  final String difficulty;
  final String interviewType;
  final String language;
  final String status;
  final double? score;
  final Map<String, dynamic>? feedback;
  final int messageCount;
  final int userMsgCount;
  final bool voiceUsed;
  final bool ttsUsed;
  final int? durationSeconds;
  final int? goalId;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Interview({
    required this.id,
    required this.jobRole,
    required this.difficulty,
    required this.interviewType,
    required this.language,
    required this.status,
    this.score,
    this.feedback,
    required this.messageCount,
    required this.userMsgCount,
    required this.voiceUsed,
    required this.ttsUsed,
    this.durationSeconds,
    this.goalId,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  int? get durationMinutes {
    // /history returns duration_minutes directly
    // /interviews returns duration_seconds
    return durationSeconds != null ? (durationSeconds! / 60).round() : null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  factory Interview.fromJson(Map<String, dynamic> json) {
    // createdAt: try created_at → started_at → now (never crashes)
    final createdAt = _parseDate(json['created_at']) ??
        _parseDate(json['started_at']) ??
        DateTime.now();

    return Interview(
      id: (json['id'] as num).toInt(),
      jobRole: (json['job_role'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'medium').toString(),
      interviewType: (json['interview_type'] ?? 'mixed').toString(),
      language: (json['language'] ?? 'en').toString(),
      status: (json['status'] ?? 'in_progress').toString(),
      score: (json['score'] as num?)?.toDouble(),
      feedback: json['feedback'] as Map<String, dynamic>?,
      // /history uses message_count; /interviews uses message_count too
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      userMsgCount: (json['user_msg_count'] as num?)?.toInt() ?? 0,
      voiceUsed: json['voice_used'] as bool? ?? false,
      ttsUsed: json['tts_used'] as bool? ?? false,
      // /history returns duration_minutes, /interviews returns duration_seconds
      durationSeconds: json['duration_seconds'] as int? ??
          ((json['duration_minutes'] as num?)?.toInt() != null
              ? ((json['duration_minutes'] as num).toInt() * 60)
              : null),
      goalId: (json['goal_id'] as num?)?.toInt(),
      createdAt: createdAt,
      startedAt: _parseDate(json['started_at']),
      completedAt: _parseDate(json['completed_at']),
    );
  }
}
