/// Envelope estándar del backend: `{ success, data, message, code }`.
/// Los servicios devuelven esto; consumir `data`.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? code;

  const ApiResponse({required this.success, this.data, this.message, this.code});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic data) parse,
  ) {
    return ApiResponse<T>(
      success: json['success'] == true,
      data: json['data'] == null ? null : parse(json['data']),
      message: json['message'] as String?,
      code: json['code'] as int?,
    );
  }
}
