import 'dart:io';

/// Global, non-secret configuration.
class ApiConfig {
  const ApiConfig._();

  /// Single source of truth for the site root. Uploaded media (photos, video /
  /// voice intros) are stored relative to this, e.g. `uploads/profile/…`.
  static const String assetBaseUrl = 'https://hamqadam.com';

  /// Single source of truth for the API base URL. `{{APP_URL}}/api/v1`.
  static const String baseUrl = '$assetBaseUrl/api/v1';

  /// Builds an absolute media URL from a server-relative [path]. Returns null
  /// for empty paths and leaves already-absolute URLs untouched.
  static String? mediaUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final String p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '$assetBaseUrl/${p.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60); // uploads

  /// Backend accepts only `android` or `ios` for device_type (verified).
  static String get deviceType => Platform.isIOS ? 'ios' : 'android';
}

/// App-wide business constants.
class AppConstants {
  const AppConstants._();

  static const int totalRegistrationSteps = 18;

  /// Backend minimum-age rule for date_of_birth (see step 1 requirements).
  static const int minAgeYears = 18;
  static const int maxAgeYears = 90;

  // Media limits (step 9 / verification).
  static const int maxGalleryImages = 6;
  static const int maxImageBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxVideoBytes = 25 * 1024 * 1024; // 25 MB
  static const int maxAudioBytes = 10 * 1024 * 1024; // 10 MB

  static const List<String> allowedImageExt = <String>['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedVideoExt = <String>['mp4', 'mov', 'm4v'];
  static const List<String> allowedAudioExt = <String>['mp3', 'm4a', 'aac', 'wav'];

  /// Debounce before persisting a draft while the user types.
  static const Duration draftDebounce = Duration(milliseconds: 600);

  /// Single SharedPreferences slot that stores the whole registration buffer.
  static const String bufferDraftKey = 'reg_buffer_v1';

  /// UI step keys for the 18-step flow (draft namespace).
  static const List<String> stepKeys = <String>[
    'step1', 'step2', 'step3', 'step4', 'step5', 'step6', //
    'step7', 'step8', 'step9', 'step10', 'step11', 'step12', //
    'step13', 'step14', 'step15', 'step16', 'step17', 'step18', //
  ];
}

/// Pusher Channels configuration for realtime chat.
/// Keys are non-secret – they identify the Pusher app, not the user.
class PusherConfig {
  const PusherConfig._();

  /// Pusher app key obtained from hamqadam.com Pusher dashboard.
  static const String key = 'YOUR_PUSHER_APP_KEY';

  /// Cluster (e.g. 'ap2', 'eu', 'mt1').
  static const String cluster = 'mt1';

  /// Laravel Echo / Pusher auth endpoint for private/presence channels.
  static const String authEndpoint = '${ApiConfig.baseUrl}/broadcasting/auth';
}
