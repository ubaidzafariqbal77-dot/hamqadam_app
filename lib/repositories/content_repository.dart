import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Generic paginated content page.
class ContentPage<T> {
  const ContentPage({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage;
}

/// Content APIs: articles, success stories, advice, forums, webinars, etc.
class ContentRepository {
  ContentRepository(this._client);

  final ApiClient _client;

  // ---- Articles -------------------------------------------------------------

  /// `GET /content/articles` — list articles.
  Future<ContentPage<Map<String, dynamic>>> fetchArticles({String? query, int page = 1, int perPage = 15}) async {
    final Map<String, dynamic> params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (query != null && query.isNotEmpty) params['q'] = query;
    final ApiEnvelope res = await _client.get(ApiEndpoints.contentArticles, query: params);
    return _parsePage(res);
  }

  /// `GET /content/articles/{slug}` — single article detail.
  Future<Map<String, dynamic>> fetchArticle(String slug) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.contentArticle(slug));
    return res.dataMap;
  }

  // ---- Success Stories ------------------------------------------------------

  /// `GET /content/success-stories` — list approved stories.
  Future<ContentPage<Map<String, dynamic>>> fetchSuccessStories({int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentSuccessStories,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  /// `POST /content/success-stories` — submit a story.
  Future<void> submitSuccessStory({
    required String title,
    required String story,
    String? partnerName,
    bool isAnonymous = false,
  }) async {
    await _client.post(
      ApiEndpoints.contentSuccessStories,
      body: <String, dynamic>{
        'title': title,
        'story': story,
        if (partnerName != null) 'partner_name': partnerName,
        'is_anonymous': isAnonymous,
      },
    );
  }

  // ---- Advice ---------------------------------------------------------------

  /// `GET /content/advice` — relationship advice articles.
  Future<ContentPage<Map<String, dynamic>>> fetchAdvice({String? category, int page = 1, int perPage = 15}) async {
    final Map<String, dynamic> params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (category != null && category.isNotEmpty) params['category'] = category;
    final ApiEnvelope res = await _client.get(ApiEndpoints.contentAdvice, query: params);
    return _parsePage(res);
  }

  // ---- Expert Q&A -----------------------------------------------------------

  /// `GET /content/expert/questions` — answered expert questions.
  Future<ContentPage<Map<String, dynamic>>> fetchExpertQuestions({int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentExpertQuestions,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  /// `POST /content/expert/questions` — submit a question.
  Future<void> submitExpertQuestion({
    required String category,
    required String question,
    String? details,
    bool isAnonymous = true,
  }) async {
    await _client.post(
      ApiEndpoints.contentExpertQuestions,
      body: <String, dynamic>{
        'category': category,
        'question': question,
        if (details != null) 'details': details,
        'is_anonymous': isAnonymous,
      },
    );
  }

  // ---- Forums ---------------------------------------------------------------

  /// `GET /content/forums` — list community forums.
  Future<ContentPage<Map<String, dynamic>>> fetchForums({int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentForums,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  /// `GET /content/forums/{forum}/threads` — threads in a forum.
  Future<ContentPage<Map<String, dynamic>>> fetchForumThreads(int forumId, {int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentForumThreads(forumId),
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  /// `POST /content/forums/{forum}/threads` — create a thread.
  Future<void> createThread({
    required int forumId,
    required String title,
    required String body,
  }) async {
    await _client.post(
      ApiEndpoints.contentForumThreads(forumId),
      body: <String, dynamic>{'title': title, 'body': body},
    );
  }

  /// `GET /content/threads/{thread}/posts` — posts in a thread.
  Future<ContentPage<Map<String, dynamic>>> fetchThreadPosts(int threadId, {int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentThreadPosts(threadId),
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  /// `POST /content/threads/{thread}/posts` — reply to a thread.
  Future<void> replyToThread({required int threadId, required String body}) async {
    await _client.post(
      ApiEndpoints.contentThreadPosts(threadId),
      body: <String, dynamic>{'body': body},
    );
  }

  // ---- Webinars -------------------------------------------------------------

  /// `GET /content/webinars` — list upcoming webinars.
  Future<ContentPage<Map<String, dynamic>>> fetchWebinars({int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentWebinars,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  /// `POST /content/webinars/{webinar}/register` — register for a webinar.
  Future<void> registerWebinar(int webinarId) async {
    await _client.post(ApiEndpoints.contentWebinarRegister(webinarId));
  }

  // ---- Marriage Tips --------------------------------------------------------

  /// `GET /content/marriage-tips` — list marriage tips.
  Future<ContentPage<Map<String, dynamic>>> fetchMarriageTips({int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.contentMarriageTips,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return _parsePage(res);
  }

  // ---- Regional Updates -----------------------------------------------------

  /// `GET /content/regional-updates` — regional updates.
  Future<ContentPage<Map<String, dynamic>>> fetchRegionalUpdates({String? region, int page = 1, int perPage = 15}) async {
    final Map<String, dynamic> params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (region != null && region.isNotEmpty) params['region'] = region;
    final ApiEnvelope res = await _client.get(ApiEndpoints.contentRegionalUpdates, query: params);
    return _parsePage(res);
  }

  // ---- Helpers --------------------------------------------------------------

  ContentPage<Map<String, dynamic>> _parsePage(ApiEnvelope res) {
    final List<dynamic> raw = res.dataList;
    final List<Map<String, dynamic>> items = raw.whereType<Map<String, dynamic>>().toList();
    return ContentPage<Map<String, dynamic>>(
      items: items,
      currentPage: (res.meta?['current_page'] as int?) ?? 1,
      lastPage: (res.meta?['last_page'] as int?) ?? 1,
      total: (res.meta?['total'] as int?) ?? items.length,
    );
  }
}
