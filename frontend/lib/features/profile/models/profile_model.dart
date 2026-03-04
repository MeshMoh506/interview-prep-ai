// lib/features/profile/models/profile_model.dart

class UserProfile {
  final int id;
  final String email;
  final String? fullName;
  final String? bio;
  final String? location;
  final String? phone;
  final String? linkedinUrl;
  final String? githubUrl;
  final String? portfolioUrl;
  final String? avatarUrl;
  final String preferredLanguage;
  final String? jobTitle;
  final bool emailNotifications;
  final bool interviewReminders;
  final int totalInterviews;
  final double? avgScore;
  final double? bestScore;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.bio,
    this.location,
    this.phone,
    this.linkedinUrl,
    this.githubUrl,
    this.portfolioUrl,
    this.avatarUrl,
    this.preferredLanguage = 'en',
    this.jobTitle,
    this.emailNotifications = true,
    this.interviewReminders = true,
    this.totalInterviews = 0,
    this.avgScore,
    this.bestScore,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        email: json['email'],
        fullName: json['full_name'],
        bio: json['bio'],
        location: json['location'],
        phone: json['phone'],
        linkedinUrl: json['linkedin_url'],
        githubUrl: json['github_url'],
        portfolioUrl: json['portfolio_url'],
        avatarUrl: json['avatar_url'],
        preferredLanguage: json['preferred_language'] ?? 'en',
        jobTitle: json['job_title'],
        emailNotifications: json['email_notifications'] ?? true,
        interviewReminders: json['interview_reminders'] ?? true,
        totalInterviews: json['total_interviews'] ?? 0,
        avgScore: (json['avg_score'] as num?)?.toDouble(),
        bestScore: (json['best_score'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toUpdateJson() => {
        if (fullName != null) 'full_name': fullName,
        if (bio != null) 'bio': bio,
        if (location != null) 'location': location,
        if (phone != null) 'phone': phone,
        if (linkedinUrl != null) 'linkedin_url': linkedinUrl,
        if (githubUrl != null) 'github_url': githubUrl,
        if (portfolioUrl != null) 'portfolio_url': portfolioUrl,
        if (jobTitle != null) 'job_title': jobTitle,
        'preferred_language': preferredLanguage,
      };

  UserProfile copyWith({
    String? fullName,
    String? bio,
    String? location,
    String? phone,
    String? linkedinUrl,
    String? githubUrl,
    String? portfolioUrl,
    String? avatarUrl,
    String? preferredLanguage,
    String? jobTitle,
    bool? emailNotifications,
    bool? interviewReminders,
  }) =>
      UserProfile(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        bio: bio ?? this.bio,
        location: location ?? this.location,
        phone: phone ?? this.phone,
        linkedinUrl: linkedinUrl ?? this.linkedinUrl,
        githubUrl: githubUrl ?? this.githubUrl,
        portfolioUrl: portfolioUrl ?? this.portfolioUrl,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        jobTitle: jobTitle ?? this.jobTitle,
        emailNotifications: emailNotifications ?? this.emailNotifications,
        interviewReminders: interviewReminders ?? this.interviewReminders,
        totalInterviews: totalInterviews,
        avgScore: avgScore,
        bestScore: bestScore,
        createdAt: createdAt,
      );

  String get initials {
    final name = fullName ?? email;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get displayName =>
      fullName?.isNotEmpty == true ? fullName! : email.split('@')[0];
}
