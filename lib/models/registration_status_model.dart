import '../constants/app_constants.dart';

/// Server-authoritative registration progress from `GET /auth/register/status`.
///
/// Defensive against: missing next_step, empty/absent completed_steps, unknown
/// future step names, out-of-range percentage, and null fields — nothing here
/// throws on a malformed payload.
class RegistrationStatusModel {
  const RegistrationStatusModel({
    required this.totalSteps,
    required this.completedSteps,
    required this.nextStep,
    required this.completionPercentage,
  });

  final int totalSteps;
  final List<String> completedSteps;

  /// Normalised step key like `step5`, or `null` when nothing is pending.
  final String? nextStep;
  final int completionPercentage;

  bool get isComplete => nextStep == null || completedSteps.length >= totalSteps;

  int get completedCount => completedSteps.length;

  /// 1-based number of the next step to show; falls back to the first
  /// incomplete step, then to step 1.
  int get nextStepNumber {
    final int? parsed = _stepNumber(nextStep);
    if (parsed != null && parsed >= 1 && parsed <= totalSteps) return parsed;
    for (int i = 1; i <= totalSteps; i++) {
      if (!completedSteps.contains('step$i')) return i;
    }
    return totalSteps;
  }

  bool isStepCompleted(int stepNumber) => completedSteps.contains('step$stepNumber');

  factory RegistrationStatusModel.fromJson(Map<String, dynamic> json) {
    final int total = _asInt(json['total_steps'], AppConstants.totalRegistrationSteps);

    final List<String> completed = <String>[];
    final dynamic rawCompleted = json['completed_steps'];
    if (rawCompleted is List) {
      for (final dynamic e in rawCompleted) {
        final String key = e.toString().trim().toLowerCase();
        if (key.isNotEmpty) completed.add(key);
      }
    }

    String? next = json['next_step']?.toString().trim().toLowerCase();
    if (next != null && (next.isEmpty || next == 'null' || next == 'completed')) {
      next = null;
    }

    int pct = _asInt(json['profile_completion_percentage'], 0);
    pct = pct.clamp(0, 100);

    return RegistrationStatusModel(
      totalSteps: total <= 0 ? AppConstants.totalRegistrationSteps : total,
      completedSteps: completed,
      nextStep: next,
      completionPercentage: pct,
    );
  }

  /// A safe default used before the first successful status sync.
  factory RegistrationStatusModel.empty() => const RegistrationStatusModel(
    totalSteps: AppConstants.totalRegistrationSteps,
    completedSteps: <String>[],
    nextStep: 'step1',
    completionPercentage: 0,
  );

  static int? _stepNumber(String? key) {
    if (key == null) return null;
    final Match? m = RegExp(r'(\d+)').firstMatch(key);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static int _asInt(dynamic v, int fallback) => v is int ? v : int.tryParse('$v') ?? fallback;
}
