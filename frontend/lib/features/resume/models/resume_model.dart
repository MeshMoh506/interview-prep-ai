import "package:flutter/material.dart";

class Resume {
  final int id;
  final int userId;
  final String? title;
  final String fileType;
  final String? parsedContent;
  final Map<String, dynamic>? contactInfo;
  final List<dynamic>? education;
  final List<dynamic>? experience;
  final List<dynamic>? skills;
  final double? analysisScore;
  final double? atsScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Resume({
    required this.id,
    required this.userId,
    this.title,
    required this.fileType,
    this.parsedContent,
    this.contactInfo,
    this.education,
    this.experience,
    this.skills,
    this.analysisScore,
    this.atsScore,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed getters used by resume_list_page ──────────────────────────────
  bool get isParsed =>
      parsedContent != null && parsedContent!.isNotEmpty;

  String get statusLabel {
    if (!isParsed) return "Not Parsed";
    if (analysisScore != null) return "Analyzed";
    return "Parsed";
  }

  Color get statusColor {
    if (!isParsed) return Colors.grey;
    if (analysisScore != null) return Colors.green;
    return Colors.blue;
  }

  factory Resume.fromJson(Map<String, dynamic> json) {
    return Resume(
      id: json["id"],
      userId: json["user_id"] ?? 0,
      title: json["title"],
      fileType: json["file_type"] ?? "pdf",
      parsedContent: json["parsed_content"],
      contactInfo: json["contact_info"] != null
          ? Map<String, dynamic>.from(json["contact_info"])
          : null,
      education: json["education"] != null
          ? List<dynamic>.from(json["education"])
          : null,
      experience: json["experience"] != null
          ? List<dynamic>.from(json["experience"])
          : null,
      skills: json["skills"] != null
          ? List<dynamic>.from(json["skills"])
          : null,
      analysisScore: json["analysis_score"] != null
          ? (json["analysis_score"] as num).toDouble()
          : null,
      atsScore: json["ats_score"] != null
          ? (json["ats_score"] as num).toDouble()
          : null,
      createdAt: DateTime.parse(
          json["created_at"] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json["updated_at"] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "title": title,
      "file_type": fileType,
      "parsed_content": parsedContent,
      "contact_info": contactInfo,
      "education": education,
      "experience": experience,
      "skills": skills,
      "analysis_score": analysisScore,
      "ats_score": atsScore,
      "created_at": createdAt.toIso8601String(),
      "updated_at": updatedAt.toIso8601String(),
    };
  }
}
