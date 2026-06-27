/// One field-level validation error from the API envelope (`errors[]`).
class FieldValidationError {
  final String field;
  final String message;
  const FieldValidationError(this.field, this.message);
}

/// Typed error thrown by the native HTTP layer, mirroring React's ApiError
/// (react/lib/api.ts). Carries the envelope's code, message, HTTP status and
/// any field-level validation errors so the login screen can show them inline.
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  final List<FieldValidationError> validationErrors;

  const ApiException(
    this.code,
    this.message, {
    this.status = 0,
    this.validationErrors = const [],
  });

  bool get isNetwork => code == 'NETWORK_ERROR';
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}
