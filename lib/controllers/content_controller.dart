import 'package:get/get.dart';
import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../repositories/content_repository.dart';
import '../widgets/app_snackbar.dart';

/// Content features: articles, stories, advice, forums, webinars, tips, regional updates.
class ContentController extends GetxController {
  ContentController(this._repo);

  final ContentRepository _repo;

  // ---- Articles
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> articlesState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Success Stories
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> storiesState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Advice
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> adviceState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Expert Q&A
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> expertState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Forums
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> forumsState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Webinars
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> webinarsState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Marriage Tips
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> tipsState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  // ---- Forum threads / thread posts (drill-down) --------------------------
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> threadsState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;
  final Rx<ApiState<ContentPage<Map<String, dynamic>>>> postsState =
      const ApiState<ContentPage<Map<String, dynamic>>>.initial().obs;

  /// The forum whose threads are on screen.
  final Rxn<Map<String, dynamic>> selectedForum = Rxn<Map<String, dynamic>>();

  /// The thread whose posts are on screen.
  final Rxn<Map<String, dynamic>> selectedThread = Rxn<Map<String, dynamic>>();

  /// Webinars the member has registered for this session (id → true), so the
  /// button flips without a refetch.
  final RxSet<int> registeredWebinars = <int>{}.obs;

  // ---- Articles
  Future<void> loadArticles({String? query}) async {
    articlesState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchArticles(query: query);
      articlesState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No articles found.')
          : ApiState.success(page);
    } on AppException catch (e) {
      articlesState.value = ApiState.fromException(e);
    } catch (e) {
      articlesState.value = ApiState.serverError(e.toString());
    }
  }

  Future<Map<String, dynamic>?> fetchArticle(String slug) async {
    try {
      return await _repo.fetchArticle(slug);
    } catch (e) {
      AppSnackbar.error('Failed to load article.');
      return null;
    }
  }

  // ---- Success Stories
  Future<void> loadStories() async {
    storiesState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchSuccessStories();
      storiesState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No stories yet.')
          : ApiState.success(page);
    } on AppException catch (e) {
      storiesState.value = ApiState.fromException(e);
    } catch (e) {
      storiesState.value = ApiState.serverError(e.toString());
    }
  }

  Future<bool> submitStory({required String title, required String story, String? partnerName, bool anonymous = false}) async {
    try {
      await _repo.submitSuccessStory(title: title, story: story, partnerName: partnerName, isAnonymous: anonymous);
      AppSnackbar.success('Story submitted for review.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to submit story.');
      return false;
    }
  }

  // ---- Advice
  Future<void> loadAdvice({String? category}) async {
    adviceState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchAdvice(category: category);
      adviceState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No advice articles found.')
          : ApiState.success(page);
    } on AppException catch (e) {
      adviceState.value = ApiState.fromException(e);
    } catch (e) {
      adviceState.value = ApiState.serverError(e.toString());
    }
  }

  // ---- Expert Q&A
  Future<void> loadExpertQuestions() async {
    expertState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchExpertQuestions();
      expertState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No expert questions yet.')
          : ApiState.success(page);
    } on AppException catch (e) {
      expertState.value = ApiState.fromException(e);
    } catch (e) {
      expertState.value = ApiState.serverError(e.toString());
    }
  }

  Future<bool> submitQuestion({
    required String category,
    required String question,
    String? details,
    bool anonymous = true,
  }) async {
    try {
      await _repo.submitExpertQuestion(
        category: category,
        question: question,
        details: details,
        isAnonymous: anonymous,
      );
      AppSnackbar.success('Question sent to the experts.');
      return true;
    } catch (e) {
      AppSnackbar.error('Could not submit your question.');
      return false;
    }
  }

  // ---- Forums
  Future<void> loadForums() async {
    forumsState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchForums();
      forumsState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No forums available.')
          : ApiState.success(page);
    } on AppException catch (e) {
      forumsState.value = ApiState.fromException(e);
    } catch (e) {
      forumsState.value = ApiState.serverError(e.toString());
    }
  }

  // ---- Webinars
  Future<void> loadWebinars() async {
    webinarsState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchWebinars();
      webinarsState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No upcoming webinars.')
          : ApiState.success(page);
    } on AppException catch (e) {
      webinarsState.value = ApiState.fromException(e);
    } catch (e) {
      webinarsState.value = ApiState.serverError(e.toString());
    }
  }

  Future<void> registerWebinar(int webinarId) async {
    try {
      await _repo.registerWebinar(webinarId);
      registeredWebinars.add(webinarId);
      AppSnackbar.success('Registered! You will get the joining details.');
    } catch (e) {
      AppSnackbar.error('Registration failed.');
    }
  }

  // ---- Forum drill-down -----------------------------------------------------

  Future<void> loadForumThreads(Map<String, dynamic> forum) async {
    selectedForum.value = forum;
    final int forumId = (forum['id'] as num?)?.toInt() ?? 0;
    if (forumId <= 0) return;
    threadsState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchForumThreads(forumId);
      threadsState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No discussions here yet. Start the first one!')
          : ApiState.success(page);
    } on AppException catch (e) {
      threadsState.value = ApiState.fromException(e);
    } catch (e) {
      threadsState.value = ApiState.serverError(e.toString());
    }
  }

  Future<bool> createThread({required String title, required String body}) async {
    final Map<String, dynamic>? forum = selectedForum.value;
    final int forumId = (forum?['id'] as num?)?.toInt() ?? 0;
    if (forum == null || forumId <= 0) return false;
    try {
      await _repo.createThread(forumId: forumId, title: title, body: body);
      AppSnackbar.success('Discussion posted.');
      await loadForumThreads(forum);
      return true;
    } catch (e) {
      AppSnackbar.error('Could not post the discussion.');
      return false;
    }
  }

  Future<void> loadThreadPosts(Map<String, dynamic> thread) async {
    selectedThread.value = thread;
    final int threadId = (thread['id'] as num?)?.toInt() ?? 0;
    if (threadId <= 0) return;
    postsState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchThreadPosts(threadId);
      postsState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No replies yet. Share your thoughts.')
          : ApiState.success(page);
    } on AppException catch (e) {
      postsState.value = ApiState.fromException(e);
    } catch (e) {
      postsState.value = ApiState.serverError(e.toString());
    }
  }

  Future<bool> replyToThread({required String body}) async {
    final Map<String, dynamic>? thread = selectedThread.value;
    final int threadId = (thread?['id'] as num?)?.toInt() ?? 0;
    if (thread == null || threadId <= 0 || body.trim().isEmpty) return false;
    try {
      await _repo.replyToThread(threadId: threadId, body: body.trim());
      await loadThreadPosts(thread);
      return true;
    } catch (e) {
      AppSnackbar.error('Reply failed.');
      return false;
    }
  }

  // ---- Marriage Tips
  Future<void> loadMarriageTips() async {
    tipsState.value = const ApiState.loading();
    try {
      final page = await _repo.fetchMarriageTips();
      tipsState.value = page.items.isEmpty
          ? const ApiState.empty(message: 'No tips available.')
          : ApiState.success(page);
    } on AppException catch (e) {
      tipsState.value = ApiState.fromException(e);
    } catch (e) {
      tipsState.value = ApiState.serverError(e.toString());
    }
  }
}
