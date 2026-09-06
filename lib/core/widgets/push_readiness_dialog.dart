import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/push_readiness_service.dart';

/// Explains, in the member's own terms, why a closed app is not ringing — and
/// offers the taps that fix it.
///
/// Deliberately not a silent log line. Each of these three grants is invisible,
/// unforceable from code, and indistinguishable from a server outage: the app
/// keeps working perfectly while it is open, because the Pusher socket is
/// carrying everything, and goes quiet the moment it is closed. Saying so is
/// the only thing that turns "the app is broken" into a fixable device setting.
class PushReadinessDialog extends StatefulWidget {
  const PushReadinessDialog({required this.state, super.key});

  final PushReadiness state;

  /// Shows the sheet and records that it was shown. Returns when it closes.
  static Future<void> show(PushReadiness state) async {
    await Get.dialog<void>(
      PushReadinessDialog(state: state),
      barrierDismissible: true,
    );
    await PushReadinessService.instance.markPrompted();
  }

  @override
  State<PushReadinessDialog> createState() => _PushReadinessDialogState();
}

class _PushReadinessDialogState extends State<PushReadinessDialog> {
  late PushReadiness _state = widget.state;

  /// Re-reads the OS after the member comes back from a settings page, so a
  /// fixed row disappears instead of sitting there looking broken.
  Future<void> _recheck() async {
    final PushReadiness fresh = await PushReadinessService.instance.check();
    if (!mounted) return;
    if (fresh.isReady) {
      // Guarded: this runs on the way back from a system settings page, and an
      // unguarded pop here would close whatever is on top if the dialog had
      // already been dismissed — taking the home screen with it.
      if (Get.isDialogOpen ?? false) Get.back<void>();
      return;
    }
    setState(() => _state = fresh);
  }

  Future<void> _run(Future<void> Function() fix) async {
    await fix();
    await _recheck();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> rows = <Widget>[
      if (_state.notificationsBlocked)
        _FixRow(
          icon: Icons.notifications_off_rounded,
          title: 'Notifications are turned off',
          // The honest consequence, not a generic "for the best experience".
          body: 'Messages and calls can only reach you while the app is open. '
              'Turn notifications on so they arrive when it is closed.',
          action: 'Open settings',
          onPressed: () =>
              _run(PushReadinessService.instance.fixNotifications),
        ),
      if (_state.fullScreenBlocked)
        _FixRow(
          icon: Icons.phone_locked_rounded,
          title: 'Calls cannot ring on the lock screen',
          body: 'Incoming calls will only show a small banner. Allow full '
              'screen notifications so a call rings like a phone call.',
          action: 'Allow',
          onPressed: () =>
              _run(PushReadinessService.instance.fixFullScreenRinging),
        ),
      if (_state.batteryOptimised)
        _FixRow(
          icon: Icons.battery_alert_rounded,
          title: 'Battery saver can stop calls',
          body: 'Your phone may close HamQadam in the background, and a closed '
              'app receives nothing until you open it again.',
          action: 'Allow',
          onPressed: () =>
              _run(PushReadinessService.instance.fixBatteryOptimisation),
        ),
    ];

    return AlertDialog(
      title: Text(
        _state.isPushDead
            ? 'Turn on notifications'
            : 'Make sure calls reach you',
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: 24),
              rows[i],
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Get.back<void>(),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}

class _FixRow extends StatelessWidget {
  const _FixRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodySmall),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onPressed,
                  child: Text(action),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
