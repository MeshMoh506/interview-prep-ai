class User {
  final int id;
  final String email;
  final String fullName;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id:         json["id"] ?? 0,
      email:      json["email"] ?? "",
      fullName:   json["full_name"] ?? json["fullName"] ?? "User",
      isActive:   json["is_active"] ?? true,
      isVerified: json["is_verified"] ?? false,
      createdAt:  json["created_at"] != null
                  ? DateTime.parse(json["created_at"])
                  : DateTime.now(),
      updatedAt:  json["updated_at"] != null
                  ? DateTime.parse(json["updated_at"])
                  : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id":         id,
      "email":      email,
      "full_name":  fullName,
      "is_active":  isActive,
      "is_verified": isVerified,
      "created_at": createdAt.toIso8601String(),
      "updated_at": updatedAt.toIso8601String(),
    };
  }
}
