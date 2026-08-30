// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Realtime Pusher service for Chat and notification streams.
///
/// Broadcast channels:
/// - `App.User.{userId}` / `private-App.User.{userId}`: Inbox, unread-count, thread preview updates
/// - `chat-thread.{threadId}` / `private-chat-thread.{threadId}`: Active conversation stream (messages, typing)
class PusherChatService {
  PusherChatService({required SecureStorageService storage}) : _storage = storage;

  final SecureStorageService _storage;
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  bool _initialized = false;
  bool _connected = false;
  String? _currentUserChannel;
  String? _currentThreadChannel;

  // Callbacks
  void Function(Map<String, dynamic> data)? onUserEvent;
  void Function(Map<String, dynamic> data)? onThreadMessage;
  void Function(Map<String, dynamic> data)? onThreadTyping;
  void Function(Map<String, dynamic> data)? onThreadUpdated;

  bool get isConnected => _connected;

  /// Initialize and connect to Pusher.
  Future<void> init() async {
    if (_initialized) return;

    final String key = PusherConfig.key;
    if (key.isEmpty || key == 'YOUR_PUSHER_APP_KEY') {
      AppLogger.i('Pusher key not set yet; dual realtime engine using active smart heartbeat polling.');
      return;
    }

    try {
      final String? token = _storage.cachedToken;
      await _pusher.init(
        apiKey: key,
        cluster: PusherConfig.cluster,
        authEndpoint: PusherConfig.authEndpoint,
        onConnectionStateChange: (dynamic currentState, dynamic previousState) {
          AppLogger.i('Pusher state: $previousState -> $currentState');
          _connected = currentState == 'CONNECTED';
        },
        onError: (String message, int? code, dynamic e) {
          AppLogger.w('Pusher error: $message (code: $code, err: $e)');
        },
        onSubscriptionSucceeded: (String channelName, dynamic data) {
          AppLogger.i('Pusher subscribed to: $channelName');
        },
        onEvent: (PusherEvent event) {
          _handlePusherEvent(event);
        },
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
          // Authorization headers for private/presence channels
          return <String, dynamic>{
            'headers': <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          };
        },
      );

      await _pusher.connect();
      _initialized = true;
    } catch (e) {
      AppLogger.w('Pusher initialization error: $e');
    }
  }

  /// Subscribe to the user's inbox channel: `App.User.{userId}`.
  Future<void> subscribeToUserChannel(int userId) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final String channelName = 'App.User.$userId';
    if (_currentUserChannel == channelName) return;

    if (_currentUserChannel != null) {
      await _pusher.unsubscribe(channelName: _currentUserChannel!);
    }

    _currentUserChannel = channelName;
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      AppLogger.w('Failed to subscribe to $channelName: $e');
    }
  }

  /// Unsubscribe from user channel (e.g. on logout).
  Future<void> unsubscribeUserChannel() async {
    if (_currentUserChannel != null) {
      try {
        await _pusher.unsubscribe(channelName: _currentUserChannel!);
      } catch (_) {}
      _currentUserChannel = null;
    }
  }

  /// Subscribe to active conversation thread channel: `chat-thread.{threadId}`.
  Future<void> subscribeToThreadChannel(int threadId) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final String channelName = 'chat-thread.$threadId';
    if (_currentThreadChannel == channelName) return;

    if (_currentThreadChannel != null) {
      await _pusher.unsubscribe(channelName: _currentThreadChannel!);
    }

    _currentThreadChannel = channelName;
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      AppLogger.w('Failed to subscribe to $channelName: $e');
    }
  }

  /// Unsubscribe from active conversation thread channel.
  Future<void> unsubscribeThreadChannel() async {
    if (_currentThreadChannel != null) {
      try {
        await _pusher.unsubscribe(channelName: _currentThreadChannel!);
      } catch (_) {}
      _currentThreadChannel = null;
    }
  }

  /// Disconnect on app close / logout.
  Future<void> disconnect() async {
    try {
      await unsubscribeThreadChannel();
      await unsubscribeUserChannel();
      if (_connected) {
        await _pusher.disconnect();
      }
    } catch (_) {}
    _connected = false;
    _initialized = false;
  }

  void _handlePusherEvent(PusherEvent event) {
    if (event.eventName.startsWith('pusher:') || event.eventName.startsWith('pusher_internal:')) {
      return;
    }

    AppLogger.i('Pusher event received: ${event.eventName} on ${event.channelName}');
    Map<String, dynamic> data = <String, dynamic>{};
    if (event.data != null) {
      try {
        final dynamic decoded = jsonDecode(event.data.toString());
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = <String, dynamic>{'raw': event.data};
      }
    }

    final String channel = event.channelName;
    final String evName = event.eventName.toLowerCase();

    if (channel.contains('User.') || channel.contains('App.User')) {
      onUserEvent?.call(data);
    } else if (channel.contains('chat-thread')) {
      if (evName.contains('typing')) {
        onThreadTyping?.call(data);
      } else if (evName.contains('block') ||
          evName.contains('unblock') ||
          evName.contains('clear') ||
          evName.contains('report')) {
        onThreadUpdated?.call(data);
      } else {
        onThreadMessage?.call(data);
      }
    }
  }
}
