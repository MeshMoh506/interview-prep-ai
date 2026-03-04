// lib/features/interview/models/interview_model.dart
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
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';
  int? get durationMinutes => 
      durationSeconds != null ? (durationSeconds! / 60).round() : null;

  factory Interview.fromJson(Map<String, dynamic> json) {
    return Interview(
      id: json['id'],
      jobRole: json['job_role'] ?? '',
      difficulty: json['difficulty'] ?? 'medium',
      interviewType: json['interview_type'] ?? 'mixed',
      language: json['language'] ?? 'en',
      status: json['status'] ?? 'in_progress',
      score: json['score']?.toDouble(),
      feedback: json['feedback'] as Map<String, dynamic>?,
      messageCount: json['message_count'] ?? 0,
      userMsgCount: json['user_msg_count'] ?? 0,
      voiceUsed: json['voice_used'] ?? false,
      ttsUsed: json['tts_used'] ?? false,
      durationSeconds: json['duration_seconds'],
      createdAt: DateTime.parse(json['created_at']),
      startedAt: json['started_at'] != null 
          ? DateTime.parse(json['started_at']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
    );
  }
}

class InterviewQuestion {
  final int id;
  final String question;
  final String category;
  final String difficulty;
  final String jobRole;
  final List<String> followUps;
  final String? tips;
  final String? sampleAnswer;
  final bool isCommunity;
  final int upvotes;
  final int downvotes;
  final List<String> tags;

  InterviewQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.difficulty,
    required this.jobRole,
    required this.followUps,
    this.tips,
    this.sampleAnswer,
    required this.isCommunity,
    required this.upvotes,
    required this.downvotes,
    required this.tags,
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) {
    return InterviewQuestion(
      id: json['id'],
      question: json['question'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? '',
      jobRole: json['job_role'] ?? '',
      followUps: List<String>.from(json['follow_ups'] ?? []),
      tips: json['tips'],
      sampleAnswer: json['sample_answer'],
      isCommunity: json['is_community'] ?? false,
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}
