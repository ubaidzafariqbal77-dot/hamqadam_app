import 'package:get/get.dart';
import '../repositories/ai_helper_repository.dart';
import '../widgets/app_snackbar.dart';

/// AI helper features: bio, conversation starters, profile quality, scam check, red flag check.
class AiHelperController extends GetxController {
  AiHelperController(this._repo);

  final AiHelperRepository _repo;

  final RxBool busy = false.obs;
  final Rxn<AiHelperResult> lastResult = Rxn<AiHelperResult>();

  Future<AiHelperResult?> generateBio(String text) async {
    return _call(() => _repo.generateBio(text));
  }

  Future<AiHelperResult?> generateConversationStarters(int matchedUserId) async {
    return _call(() => _repo.generateConversationStarters(matchedUserId: matchedUserId));
  }

  Future<AiHelperResult?> checkProfileQuality(String text) async {
    return _call(() => _repo.checkProfileQuality(text));
  }

  Future<AiHelperResult?> scamCheck(String text) async {
    return _call(() => _repo.scamCheck(text));
  }

  Future<AiHelperResult?> redFlagCheck(String text) async {
    return _call(() => _repo.redFlagCheck(text));
  }

  Future<AiHelperResult?> _call(Future<AiHelperResult> Function() fn) async {
    if (busy.value) return null;
    busy.value = true;
    try {
      final AiHelperResult result = await fn();
      lastResult.value = result;
      return result;
    } catch (e) {
      AppSnackbar.error('AI request failed: $e');
      return null;
    } finally {
      busy.value = false;
    }
  }
}
