// lib/features/roadmap/models/roadmap_model.dart
class RoadmapTask {
  final int id;
  final int stageId;
  final int order;
  final String title;
  final String? description;
  final bool isCompleted;
  final int? estimatedHours;
  final List<Map<String, dynamic>>? resources;
  final DateTime? completedAt;

  RoadmapTask({
    required this.id,
    required this.stageId,
    required this.order,
    required this.title,
    this.description,
    required this.isCompleted,
    this.estimatedHours,
    this.resources,
    this.completedAt,
  });

  factory RoadmapTask.fromJson(Map<String, dynamic> json) => RoadmapTask(
        id: json['id'],
        stageId: json['stage_id'],
        order: json['order'],
        title: json['title'],
        description: json['description'],
        isCompleted: json['is_completed'] ?? false,
        estimatedHours: json['estimated_hours'],
        resources: json['resources'] != null
            ? List<Map<String, dynamic>>.from(json['resources'])
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
      );
}

class RoadmapStage {
  final int id;
  final int roadmapId;
  final int order;
  final String title;
  final String? description;
  final String color;
  final String? icon;
  final double progress;
  final bool isUnlocked;
  final bool isCompleted;
  final int? estimatedHours;
  final String? difficulty;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<RoadmapTask> tasks;

  RoadmapStage({
    required this.id,
    required this.roadmapId,
    required this.order,
    required this.title,
    this.description,
    required this.color,
    this.icon,
    required this.progress,
    required this.isUnlocked,
    required this.isCompleted,
    this.estimatedHours,
    this.difficulty,
    this.startedAt,
    this.completedAt,
    this.tasks = const [],
  });

  factory RoadmapStage.fromJson(Map<String, dynamic> json) => RoadmapStage(
        id: json['id'],
        roadmapId: json['roadmap_id'],
        order: json['order'],
        title: json['title'],
        description: json['description'],
        color: json['color'] ?? '#8B5CF6',
        icon: json['icon'],
        progress: (json['progress'] ?? 0).toDouble(),
        isUnlocked: json['is_unlocked'] ?? false,
        isCompleted: json['is_completed'] ?? false,
        estimatedHours: json['estimated_hours'],
        difficulty: json['difficulty'],
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'])
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        tasks: json['tasks'] != null
            ? (json['tasks'] as List)
                .map((t) => RoadmapTask.fromJson(t))
                .toList()
            : [],
      );
}

class Roadmap {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final String? targetRole;
  final String? difficulty;
  final int? estimatedWeeks;
  final bool isAiGenerated;
  final bool isPublic;
  final String? category;
  final List<String>? tags;
  final double overallProgress;
  final int? currentStageId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<RoadmapStage> stages;

  Roadmap({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.targetRole,
    this.difficulty,
    this.estimatedWeeks,
    required this.isAiGenerated,
    required this.isPublic,
    this.category,
    this.tags,
    required this.overallProgress,
    this.currentStageId,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.stages = const [],
  });

  factory Roadmap.fromJson(Map<String, dynamic> json) => Roadmap(
        id: json['id'],
        userId: json['user_id'],
        title: json['title'],
        description: json['description'],
        targetRole: json['target_role'],
        difficulty: json['difficulty'],
        estimatedWeeks: json['estimated_weeks'],
        isAiGenerated: json['is_ai_generated'] ?? false,
        isPublic: json['is_public'] ?? false,
        category: json['category'],
        tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
        overallProgress: (json['overall_progress'] ?? 0).toDouble(),
        currentStageId: json['current_stage_id'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        stages: json['stages'] != null
            ? (json['stages'] as List)
                .map((s) => RoadmapStage.fromJson(s))
                .toList()
            : [],
      );
}
