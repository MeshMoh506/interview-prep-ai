// lib/features/roadmap/models/roadmap_model.dart

class RoadmapTask {
  final int id;
  final int order;
  final String title;
  final String description;
  final double estimatedHours;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<Map<String, dynamic>> resources;

  const RoadmapTask({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    required this.estimatedHours,
    required this.isCompleted,
    this.completedAt,
    required this.resources,
  });

  factory RoadmapTask.fromJson(Map<String, dynamic> json) {
    // Filter out internal _time_log entries from resources
    final rawResources = (json['resources'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .where((r) => r['type'] != '_time_log')
            .toList() ??
        [];

    return RoadmapTask(
      id: json['id'] as int,
      order: json['order'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      resources: rawResources,
    );
  }

  RoadmapTask copyWith({bool? isCompleted}) => RoadmapTask(
        id: id,
        order: order,
        title: title,
        description: description,
        estimatedHours: estimatedHours,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: completedAt,
        resources: resources,
      );
}

class RoadmapStage {
  final int id;
  final int order;
  final String title;
  final String description;
  final String? color;
  final String? icon;
  final double estimatedHours;
  final String? difficulty;
  final bool isUnlocked;
  final bool isCompleted;
  final double progress;
  final List<RoadmapTask> tasks;

  const RoadmapStage({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    this.color,
    this.icon,
    required this.estimatedHours,
    this.difficulty,
    required this.isUnlocked,
    required this.isCompleted,
    required this.progress,
    required this.tasks,
  });

  factory RoadmapStage.fromJson(Map<String, dynamic> json) => RoadmapStage(
        id: json['id'] as int,
        order: json['order'] as int? ?? 0,
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        color: json['color']?.toString(),
        icon: json['icon']?.toString(),
        estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0,
        difficulty: json['difficulty']?.toString(),
        isUnlocked: json['is_unlocked'] as bool? ?? false,
        isCompleted: json['is_completed'] as bool? ?? false,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        tasks: (json['tasks'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(RoadmapTask.fromJson)
                .toList() ??
            [],
      );

  int get completedTaskCount => tasks.where((t) => t.isCompleted).length;
  int get totalTaskCount => tasks.length;
}

class Roadmap {
  final int id;
  final String title;
  final String description;
  final String? targetRole;
  final String? difficulty;
  final int? estimatedWeeks;
  final double overallProgress;
  final bool isAiGenerated;
  final String? category;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<RoadmapStage> stages;

  const Roadmap({
    required this.id,
    required this.title,
    required this.description,
    this.targetRole,
    this.difficulty,
    this.estimatedWeeks,
    required this.overallProgress,
    required this.isAiGenerated,
    this.category,
    required this.tags,
    this.createdAt,
    this.completedAt,
    required this.stages,
  });

  factory Roadmap.fromJson(Map<String, dynamic> json) => Roadmap(
        id: json['id'] as int,
        title: json['title']?.toString() ?? 'Untitled Roadmap',
        description: json['description']?.toString() ?? '',
        targetRole: json['target_role']?.toString(),
        difficulty: json['difficulty']?.toString(),
        estimatedWeeks: json['estimated_weeks'] as int?,
        overallProgress: (json['overall_progress'] as num?)?.toDouble() ?? 0,
        isAiGenerated: json['is_ai_generated'] as bool? ?? false,
        category: json['category']?.toString(),
        tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'].toString())
            : null,
        stages: (json['stages'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(RoadmapStage.fromJson)
                .toList() ??
            [],
      );

  bool get isCompleted => overallProgress >= 100;
  int get completedStages => stages.where((s) => s.isCompleted).length;
  int get totalTasks => stages.fold(0, (sum, s) => sum + s.totalTaskCount);
  int get completedTasks =>
      stages.fold(0, (sum, s) => sum + s.completedTaskCount);
}
