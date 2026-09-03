import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/call_log_entry.dart';
import '../../models/call_model.dart';
import '../utils/app_logger.dart';

/// The device's own call history, kept in SharedPreferences.
///
/// Every call this member takes part in is written here as it happens, so the
/// Calls tab is a local read: instant, complete, and available with no network.
/// The server's per-conversation `GET /chat/threads/{id}/calls` is still the
/// authority on a single conversation's calls, but it cannot answer "show me my
/// calls" without one request per thread — which is what the tab used to do,
/// capped at ten threads and silently missing everything beyond them.
class CallLogService {
  CallLogService(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'call_log_v1';

  /// Enough for a long history without turning a preferences read into a
  /// noticeable cost. Oldest rows fall off the end.
  static const int _cap = 200;

  /// Newest first — the order the Calls tab shows them in.
  final RxList<CallLogEntry> entries = <CallLogEntry>[].obs;

  /// Missed calls the member has not looked at yet, for the tab badge.
  int get unseenMissedCount =>
      entries.where((CallLogEntry e) => e.isMissedCall && !e.seen).length;

  /// Reads the stored history into memory. Call once at startup.
  void load() {
    try {
      final List<String>? raw = _prefs.getStringList(_key);
      if (raw == null || raw.isEmpty) return;

      final List<CallLogEntry> loaded = <CallLogEntry>[];
      for (final String line in raw) {
        try {
          final dynamic decoded = jsonDecode(line);
          if (decoded is Map<String, dynamic>) {
            final CallLogEntry? entry = CallLogEntry.fromJson(decoded);
            if (entry != null) loaded.add(entry);
          }
        } catch (_) {
          // One unreadable row must not lose the rest of the history.
        }
      }
      _sort(loaded);
      entries.assignAll(loaded);
      AppLogger.i('Call log loaded: ${entries.length} entr(ies).');
    } catch (e) {
      AppLogger.w('Could not load the call log: $e');
    }
  }

  /// Records what just happened to a call, replacing any earlier row for it.
  ///
  /// One call produces several of these as it progresses — ringing, answered,
  /// ended — and they collapse onto a single row keyed by [CallLogEntry.callId].
  /// A later state never loses information the earlier one had: the peer's name
  /// and the duration are carried forward when the newer payload omits them.
  Future<void> record(CallLogEntry entry) async {
    final int index =
        entries.indexWhere((CallLogEntry e) => e.callId == entry.callId);

    if (index >= 0) {
      final CallLogEntry existing = entries[index];
      entries[index] = entry.copyWith(
        // A hang-up payload can report zero seconds; the connected one knew
        // better.
        durationSeconds: entry.durationSeconds > 0
            ? entry.durationSeconds
            : existing.durationSeconds,
        peerName: entry.peerName.trim().isEmpty ? existing.peerName : null,
        peerPhoto: entry.peerPhoto ?? existing.peerPhoto,
        // Once seen, stays seen.
        seen: existing.seen || entry.seen,
      );
    } else {
      entries.insert(0, entry);
    }

    _sort(entries);
    while (entries.length > _cap) {
      entries.removeLast();
    }
    await _persist();
  }

  /// Convenience wrapper for the call controller: builds the row and stores it.
  Future<void> recordCall(
    CallModel call, {
    required int myUserId,
    CallLogDirection? direction,
    CallLogOutcome? outcome,
  }) async {
    final CallLogEntry? entry = CallLogEntry.fromCall(
      call,
      myUserId: myUserId,
      direction: direction,
      outcome: outcome,
    );
    if (entry == null) return;
    await record(entry);
  }

  /// Clears the missed-call badge. Called when the Calls tab is opened.
  Future<void> markAllSeen() async {
    if (entries.every((CallLogEntry e) => e.seen)) return;
    for (int i = 0; i < entries.length; i++) {
      if (!entries[i].seen) entries[i] = entries[i].copyWith(seen: true);
    }
    entries.refresh();
    await _persist();
  }

  Future<void> remove(int callId) async {
    entries.removeWhere((CallLogEntry e) => e.callId == callId);
    await _persist();
  }

  /// Wipes the history — used on logout, so the next member on this device
  /// does not inherit the previous one's calls.
  Future<void> clear() async {
    entries.clear();
    try {
      await _prefs.remove(_key);
    } catch (e) {
      AppLogger.w('Could not clear the call log: $e');
    }
  }

  static void _sort(List<CallLogEntry> list) {
    list.sort((CallLogEntry a, CallLogEntry b) {
      final int byTime = b.startedAt.compareTo(a.startedAt);
      if (byTime != 0) return byTime;
      return b.callId.compareTo(a.callId);
    });
  }

  Future<void> _persist() async {
    try {
      await _prefs.setStringList(
        _key,
        entries.map((CallLogEntry e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      AppLogger.w('Could not save the call log: $e');
    }
  }
}
