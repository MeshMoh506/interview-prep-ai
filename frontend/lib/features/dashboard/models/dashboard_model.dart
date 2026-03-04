// lib/features/dashboard/models/dashboard_model.dart

class ScoreTrend {
  final String date;
  final double score;
  ScoreTrend({required this.date, required this.score});
  factory ScoreTrend.fromJson(Map<String, dynamic> j) => ScoreTrend(
        date: j['date'] ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0.0,
      );
}

class RoleBreakdown {
  final String role;
  final int count;
  final double avgScore;
  RoleBreakdown(
      {required this.role, required this.count, required this.avgScore});
  factory RoleBreakdown.fromJson(Map<String, dynamic> j) => RoleBreakdown(
        role: j['role'] ?? '',
        count: j['count'] ?? 0,
        avgScore: (j['avg_score'] as num?)?.toDouble() ?? 0.0,
      );
}

class RecentInterview {
  final int id;
  final String jobRole;
  final String difficulty;
  final String status;
  final double? score;
  final DateTime createdAt;

  RecentInterview({
    required this.id,
    required this.jobRole,
    required this.difficulty,
    required this.status,
    this.score,
    required this.createdAt,
  });

  factory RecentInterview.fromJson(Map<String, dynamic> j) => RecentInterview(
        id: j['id'] ?? 0,
        jobRole: j['job_role'] ?? '',
        difficulty: j['difficulty'] ?? '',
        status: j['status'] ?? '',
        score: (j['score'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

class ActiveRoadmapSummary {
  final int id;
  final String title;
  final String targetRole;
  final double overallProgress;
  final int streakDays;
  final int milestonesDone;
  final int milestonesTotal;
  final String? activeMilestone;

  ActiveRoadmapSummary({
    required this.id,
    required this.title,
    required this.targetRole,
    required this.overallProgress,
    required this.streakDays,
    required this.milestonesDone,
    required this.milestonesTotal,
    this.activeMilestone,
  });

  factory ActiveRoadmapSummary.fromJson(Map<String, dynamic> j) =>
      ActiveRoadmapSummary(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        targetRole: j['target_role'] ?? '',
        overallProgress: (j['overall_progress'] as num?)?.toDouble() ?? 0.0,
        streakDays: j['streak_days'] ?? 0,
        milestonesDone: j['milestones_done'] ?? 0,
        milestonesTotal: j['milestones_total'] ?? 0,
        activeMilestone: j['active_milestone'],
      );
}

class ActivityItem {
  final String type;
  final String icon;
  final String title;
  final String subtitle;
  final DateTime time;
  final String color;

  ActivityItem({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
        type: j['type'] ?? '',
        icon: j['icon'] ?? '⚡',
        title: j['title'] ?? '',
        subtitle: j['subtitle'] ?? '',
        time: DateTime.tryParse(j['time'] ?? '') ?? DateTime.now(),
        color: j['color'] ?? '#8B5CF6',
      );
}

class DashboardTip {
  final String emoji;
  final String title;
  final String body;

  DashboardTip({required this.emoji, required this.title, required this.body});

  factory DashboardTip.fromJson(Map<String, dynamic> j) => DashboardTip(
        emoji: j['emoji'] ?? '💪',
        title: j['title'] ?? 'Keep going!',
        body: j['body'] ?? 'You got this!',
      );
}

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

  // Recent
  final List<RecentInterview> recentInterviews;
  final ActiveRoadmapSummary? activeRoadmap;
  final String? latestResumeTitle;

  // Skills
  final List<String> skillGaps;
  final List<String> knownSkills;

  // Feed
  final List<ActivityItem> activityFeed;
  final DashboardTip tip;

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

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        resumeCount: j['resume_count'] ?? 0,
        resumeAnalyzed: j['resume_analyzed'] ?? 0,
        interviewCount: j['interview_count'] ?? 0,
        interviewsCompleted: j['interviews_completed'] ?? 0,
        roadmapCount: j['roadmap_count'] ?? 0,
        avgScore: (j['avg_score'] as num?)?.toDouble(),
        bestScore: (j['best_score'] as num?)?.toDouble(),
        bestStreak: j['best_streak'] ?? 0,
        goalsToday: j['goals_today'] ?? 0,
        goalsDone: j['goals_done'] ?? 0,
        scoreTrend: (j['score_trend'] as List? ?? [])
            .map((e) => ScoreTrend.fromJson(e))
            .toList(),
        roleBreakdown: (j['role_breakdown'] as List? ?? [])
            .map((e) => RoleBreakdown.fromJson(e))
            .toList(),
        recentInterviews: (j['recent_interviews'] as List? ?? [])
            .map((e) => RecentInterview.fromJson(e))
            .toList(),
        activeRoadmap: j['active_roadmap'] != null
            ? ActiveRoadmapSummary.fromJson(j['active_roadmap'])
            : null,
        latestResumeTitle: j['latest_resume_title'],
        skillGaps: List<String>.from(j['skill_gaps'] ?? []),
        knownSkills: List<String>.from(j['known_skills'] ?? []),
        activityFeed: (j['activity_feed'] as List? ?? [])
            .map((e) => ActivityItem.fromJson(e))
            .toList(),
        tip: DashboardTip.fromJson(j['tip'] ??
            {'emoji': '💪', 'title': 'Keep going!', 'body': 'You got this!'}),
      );

  /// Empty state used before API loads
  factory DashboardData.empty() => DashboardData(
        resumeCount: 0,
        resumeAnalyzed: 0,
        interviewCount: 0,
        interviewsCompleted: 0,
        roadmapCount: 0,
        bestStreak: 0,
        goalsToday: 0,
        goalsDone: 0,
        scoreTrend: [],
        roleBreakdown: [],
        recentInterviews: [],
        activityFeed: [],
        skillGaps: [],
        knownSkills: [],
        tip: DashboardTip(
            emoji: '💪', title: 'Welcome!', body: 'Start your journey.'),
      );
}
