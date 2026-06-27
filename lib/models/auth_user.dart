import 'dart:convert';

/// Mirrors the React `AuthUser` (react/context/AuthContext.tsx) and the backend
/// `record.toJSON()` returned by user.service.js login.
class AuthUser {
  final int userId;
  final int companyId;
  final int? propertyId; // null = company-level user; non-null = one property (Hotel ID)
  final String name;
  final String email;
  final String role;
  final String? roleId;
  final String status;

  const AuthUser({
    required this.userId,
    required this.companyId,
    required this.propertyId,
    required this.name,
    required this.email,
    required this.role,
    required this.roleId,
    required this.status,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        userId: (j['user_id'] as num).toInt(),
        companyId: (j['company_id'] as num).toInt(),
        propertyId: j['property_id'] == null
            ? null
            : (j['property_id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? '',
        roleId: j['role_id'] as String?,
        status: j['status'] as String? ?? 'active',
      );

  /// JSON identical to what React persists in localStorage["auth_user"], so the
  /// injected value round-trips through AuthContext.hydrate() unchanged.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'company_id': companyId,
        'property_id': propertyId,
        'name': name,
        'email': email,
        'role': role,
        'role_id': roleId,
        'status': status,
      };

  String encode() => jsonEncode(toJson());

  static AuthUser decode(String s) =>
      AuthUser.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
