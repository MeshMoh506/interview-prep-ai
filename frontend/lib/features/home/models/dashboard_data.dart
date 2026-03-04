class DashboardData {
  // Counts
  final int resumeCount;
  final int resumeAnalyzed;
  final int interviewCount;
  final int interviewsCompleted;
  final int roadmapCount;

  // Scores
  final double? avgScore;
  final double? bestScore;
  final int bestStreak;

  // Today
  final int goalsToday;
  final int goalsDone;

  // Charts
  final List<ScoreTrend> scoreTrend;
  final List<RoleBreakdown> roleBreakdown;

  // Latest
  final List<RecentInterview> recentInterviews;
  final ActiveRoadmap? activeRoadmap;
  final String? latestResumeTitle;

  // Skills
  final List<String> skillGaps;
  final List<String> knownSkills;

  // Feed & tip
  final List<ActivityItem> activityFeed;
  final MotivationalTip tip;

  DashboardData({
    required this.resumeCount,
    required this.resumeAnalyzed,
    required this.interviewCount,
    required this.interviewsCompleted,
    required this.roadmapCount,
    this.avgScore,
    this.bestScore,
    required this.bestStreak,
    required this.goalsToday,
    required this.goalsDone,
    required this.scoreTrend,
    required this.roleBreakdown,
    required this.recentInterviews,
    this.activeRoadmap,
    this.latestResumeTitle,
    required this.skillGaps,
    required this.knownSkills,
    required this.activityFeed,
    required this.tip,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      resumeCount: json['resume_count'] ?? 0,
      resumeAnalyzed: json['resume_analyzed'] ?? 0,
      interviewCount: json['interview_count'] ?? 0,
      interviewsCompleted: json['interviews_completed'] ?? 0,
      roadmapCount: json['roadmap_count'] ?? 0,
      avgScore: json['avg_score']?.toDouble(),
      bestScore: json['best_score']?.toDouble(),
      bestStreak: json['best_streak'] ?? 0,
      goalsToday: json['goals_today'] ?? 0,
      goalsDone: json['goals_done'] ?? 0,
      scoreTrend: (json['score_trend'] as List?)
          ?.map((e) => ScoreTrend.fromJson(e))
          .toList() ?? [],
      roleBreakdown: (json['role_breakdown'] as List?)
          ?.map((e) => RoleBreakdown.fromJson(e))
          .toList() ?? [],
      recentInterviews: (json['recent_interviews'] as List?)
          ?.map((e) => RecentInterview.fromJson(e))
          .toList() ?? [],
      activeRoadmap: json['active_roadmap'] != null
          ? ActiveRoadmap.fromJson(json['active_roadmap'])
          : null,
      latestResumeTitle: json['latest_resume_title'],
      skillGaps: List<String>.from(json['skill_gaps'] ?? []),
      knownSkills: List<String>.from(json['known_skills'] ?? []),
      activityFeed: (json['activity_feed'] as List?)
          ?.map((e) => ActivityItem.fromJson(e))
          .toList() ?? [],
      tip: MotivationalTip.fromJson(json['tip'] ?? {}),
    );
  }
}

class ScoreTrend {
  final String label;
  final double score;

  ScoreTrend({required this.label, required this.score});

  factory ScoreTrend.fromJson(Map<String, dynamic> json) {
    return ScoreTrend(
      label: json['label'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
    );
  }
}

class RoleBreakdown {
  final String role;
  final int count;

  RoleBreakdown({required this.role, required this.count});

  factory RoleBreakdown.fromJson(Map<String, dynamic> json) {
    return RoleBreakdown(
      role: json['role'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class RecentInterview {
  final int id;
  final String jobRole;
  final String difficulty;
  final String status;
  final double? score;
  final String createdAt;
  final String? completedAt;
  final int? durationMinutes;

  RecentInterview({
    required this.id,
    required this.jobRole,
    required this.difficulty,
    required this.status,
    this.score,
    required this.createdAt,
    this.completedAt,
    this.durationMinutes,
  });

  factory RecentInterview.fromJson(Map<String, dynamic> json) {
    return RecentInterview(
      id: json['id'] ?? 0,
      jobRole: json['job_role'] ?? '',
      difficulty: json['difficulty'] ?? '',
      status: json['status'] ?? '',
      score: json['score']?.toDouble(),
      createdAt: json['created_at'] ?? '',
      completedAt: json['completed_at'],
      durationMinutes: json['duration_minutes'],
    );
  }
}

class ActiveRoadmap {
  final int id;
  final String title;
  final String targetRole;
  final double overallProgress;
  final int streakDays;
  final String status;
  final int milestonesDone;
  final int milestonesTotal;
  final String? activeMilestone;
  final String? lastActivity;

  ActiveRoadmap({
    required this.id,
    required this.title,
    required this.targetRole,
    required this.overallProgress,
    required this.streakDays,
    required this.status,
    required this.milestonesDone,
    required this.milestonesTotal,
    this.activeMilestone,
    this.lastActivity,
  });

  factory ActiveRoadmap.fromJson(Map<String, dynamic> json) {
    return ActiveRoadmap(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      targetRole: json['target_role'] ?? '',
      overallProgress: (json['overall_progress'] ?? 0).toDouble(),
      streakDays: json['streak_days'] ?? 0,
      status: json['status'] ?? '',
      milestonesDone: json['milestones_done'] ?? 0,
      milestonesTotal: json['milestones_total'] ?? 0,
      activeMilestone: json['active_milestone'],
      lastActivity: json['last_activity'],
    );
  }
}

class ActivityItem {
  final String type;
  final String icon;
  final String title;
  final String subtitle;
  final String time;
  final String color;

  ActivityItem({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: json['type'] ?? '',
      icon: json['icon'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      time: json['time'] ?? '',
      color: json['color'] ?? '',
    );
  }
}

class MotivationalTip {
  final String emoji;
  final String title;
  final String body;

  MotivationalTip({
    required this.emoji,
    required this.title,
    required this.body,
  });

  factory MotivationalTip.fromJson(Map<String, dynamic> json) {
    return MotivationalTip(
      emoji: json['emoji'] ?? '💪',
      title: json['title'] ?? 'Keep Going!',
      body: json['body'] ?? 'You\'re doing great!',
    );
  }
}
