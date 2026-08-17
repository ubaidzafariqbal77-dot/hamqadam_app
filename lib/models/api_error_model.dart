/// Parsed representation of the API error envelope.
///
/// HamQadam has been observed to return two shapes, both handled here:
///   Laravel default: `{ message, errors: { field: [..] } }`
///   HamQadam v1:     `{ success:false, message, error: { code, errors: {..} } }`
class ApiErrorModel {
  const ApiErrorModel({
    required this.message,
    this.errors = const <String, List<String>>{},
    this.code,
  });

  final String message;
  final Map<String, List<String>> errors;

  /// Machine-readable `error.code` (e.g. `email_already_verified`), when the
  /// v1 envelope supplies one. The human [message] is not safe to branch on.
  final String? code;

  bool get hasFieldErrors => errors.isNotEmpty;

  factory ApiErrorModel.fromJson(Map<String, dynamic> json) {
    // Field errors can live at top-level `errors` OR nested under `error.errors`.
    dynamic rawErrors = json['errors'];
    final dynamic errorNode = json['error'];
    if (rawErrors == null && errorNode is Map) {
      rawErrors = errorNode['errors'];
    }

    final Map<String, List<String>> parsed = <String, List<String>>{};
    if (rawErrors is Map) {
      rawErrors.forEach((dynamic key, dynamic value) {
        if (value is List) {
          parsed[key.toString()] = value.map((dynamic e) => e.toString()).toList();
        } else if (value != null) {
          parsed[key.toString()] = <String>[value.toString()];
        }
      });
    }

    // Prefer the human message; fall back to a nested error message if present.
    String message = (json['message'] ?? '').toString();
    if (message.isEmpty && errorNode is Map) {
      message = (errorNode['message'] ?? errorNode['code'] ?? '').toString();
    }
    if (message.isEmpty) message = 'Request failed.';

    return ApiErrorModel(
      message: message,
      errors: parsed,
      code: errorNode is Map ? errorNode['code']?.toString() : null,
    );
  }
}
