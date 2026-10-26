import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_push/mobile_push.dart';

import 'customer_session.dart';
import 'event_log.dart';
import 'foreground_display.dart';
import 'sallapush_status.dart';

/// The SallaPush example app.
class SallaPushExampleApp extends StatelessWidget {
  /// Creates the app for [session], with the events of [log].
  const SallaPushExampleApp({
    super.key,
    required this.session,
    required this.log,
  });

  /// The customer session the example signs in and out.
  final CustomerSession session;

  /// The SallaPush events the example received.
  final EventLog log;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SallaPush Flutter',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: SallaPushHome(session: session, log: log),
    );
  }
}

/// The example's one screen: SallaPush's status, every action, the foreground
/// mode and the event log.
class SallaPushHome extends StatefulWidget {
  /// Creates the screen.
  const SallaPushHome({super.key, required this.session, required this.log});

  /// The customer session the screen signs in and out.
  final CustomerSession session;

  /// The SallaPush events the screen shows.
  final EventLog log;

  @override
  State<SallaPushHome> createState() => _SallaPushHomeState();
}

class _SallaPushHomeState extends State<SallaPushHome> {
  final TextEditingController _externalId = TextEditingController();
  final TextEditingController _identityToken = TextEditingController();
  final TextEditingController _tagKey = TextEditingController();
  final TextEditingController _tagValue = TextEditingController();
  final TextEditingController _language = TextEditingController();
  final TextEditingController _androidNotificationId = TextEditingController();
  late final ForegroundDisplay _foreground = ForegroundDisplay(widget.log);

  SallaPushStatus? _status;
  Object? _statusError;
  int _reads = 0;
  LoggedEvent? _lastEvent;
  bool _fallbackToSettings = false;
  bool _consentRequired = false;
  bool _consentGiven = false;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    widget.log.addListener(_onEvent);
    unawaited(widget.session.restore());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    widget.log.removeListener(_onEvent);
    _foreground.dispose();
    for (final TextEditingController controller in <TextEditingController>[
      _externalId,
      _identityToken,
      _tagKey,
      _tagValue,
      _language,
      _androidNotificationId,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Reads the status again after each SallaPush event but log entries, which
  /// reading the status can itself cause.
  void _onEvent() {
    final LoggedEvent? latest = widget.log.latest;
    if (latest == null || identical(latest, _lastEvent)) {
      return;
    }
    _lastEvent = latest;
    if (latest.kind != EventKind.log) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final int read = ++_reads;
    try {
      final SallaPushStatus status = await SallaPushStatus.read();
      if (mounted && read == _reads) {
        setState(() {
          _status = status;
          _statusError = null;
        });
      }
    } on Exception catch (error) {
      if (mounted && read == _reads) {
        setState(() => _statusError = error);
      }
    }
  }

  /// Runs [action], shows [message] for its result, and reads the status
  /// again.
  Future<void> _run<T>(
    Future<T> Function() action, [
    String Function(T result)? message,
  ]) async {
    try {
      final T result = await action();
      if (message != null) {
        _show(message(result));
      }
    } on Exception catch (error) {
      _show('$error');
    }
    await _refresh();
  }

  void _show(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _signIn() => widget.session.signIn(
    Customer(id: _externalId.text, identityToken: _identityToken.text),
  );

  Future<void> _addTag() => SallaPush.user.addTag(_tagKey.text, _tagValue.text);

  Future<void> _removeTag() => SallaPush.user.removeTag(_tagKey.text);

  Future<void> _setLanguage() {
    final String language = _language.text.trim();
    return SallaPush.user.setLanguage(language.isEmpty ? null : language);
  }

  Future<bool> _requestPermission() => SallaPush.notifications
      .requestPermission(fallbackToSettings: _fallbackToSettings);

  Future<void> _removeNotification() async {
    final int? id = int.tryParse(_androidNotificationId.text);
    if (id != null) {
      await SallaPush.notifications.removeNotification(id);
    }
  }

  static String _allowed(bool allowed) =>
      allowed ? 'Notifications are allowed.' : 'Notifications are not allowed.';

  @override
  Widget build(BuildContext context) {
    final SallaPushStatus? status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SallaPush Flutter'),
        actions: <Widget>[
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (status != null && status.appId == null) const _NotConfigured(),
          _statusSection(status),
          _customerSection(),
          _tagsSection(),
          _subscriptionSection(),
          _notificationsSection(),
          _foregroundSection(),
          _consentSection(),
          _loggingSection(status),
          _eventsSection(),
        ],
      ),
    );
  }

  Widget _statusSection(SallaPushStatus? status) {
    final Object? error = _statusError;
    return _Section(
      title: 'Status',
      children: <Widget>[
        if (error != null)
          Text('$error')
        else if (status == null)
          const Text('Reading…')
        else
          _StatusTable(status: status, showPermissionStatus: _isIOS),
      ],
    );
  }

  Widget _customerSection() {
    return _Section(
      title: 'Customer',
      children: <Widget>[
        TextField(
          controller: _externalId,
          decoration: const InputDecoration(labelText: 'External id'),
        ),
        TextField(
          controller: _identityToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Identity token'),
        ),
        _Buttons(<Widget>[
          FilledButton(
            onPressed: () => _run(_signIn),
            child: const Text('Log in'),
          ),
          OutlinedButton(
            onPressed: () => _run(widget.session.signOut),
            child: const Text('Log out'),
          ),
        ]),
      ],
    );
  }

  Widget _tagsSection() {
    return _Section(
      title: 'Tags and language',
      children: <Widget>[
        Row(
          spacing: 8,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _tagKey,
                decoration: const InputDecoration(labelText: 'Tag key'),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _tagValue,
                decoration: const InputDecoration(labelText: 'Tag value'),
              ),
            ),
          ],
        ),
        _Buttons(<Widget>[
          FilledButton.tonal(
            onPressed: () => _run(_addTag),
            child: const Text('Add tag'),
          ),
          OutlinedButton(
            onPressed: () => _run(_removeTag),
            child: const Text('Remove tag'),
          ),
        ]),
        TextField(
          controller: _language,
          decoration: const InputDecoration(
            labelText: 'Language',
            helperText: "Empty for the device's language",
          ),
        ),
        _Buttons(<Widget>[
          FilledButton.tonal(
            onPressed: () => _run(_setLanguage),
            child: const Text('Set language'),
          ),
        ]),
      ],
    );
  }

  Widget _subscriptionSection() {
    final SallaPushSubscription subscription = SallaPush.user.pushSubscription;
    return _Section(
      title: 'Push subscription',
      children: <Widget>[
        _Buttons(<Widget>[
          FilledButton.tonal(
            onPressed: () => _run(subscription.optIn),
            child: const Text('Opt in'),
          ),
          OutlinedButton(
            onPressed: () => _run(subscription.optOut),
            child: const Text('Opt out'),
          ),
        ]),
      ],
    );
  }

  Widget _notificationsSection() {
    final SallaPushNotifications notifications = SallaPush.notifications;
    return _Section(
      title: 'Notifications',
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fall back to settings'),
          subtitle: const Text(
            "When the prompt can't show any more, open the app's "
            'notification settings instead.',
          ),
          value: _fallbackToSettings,
          onChanged: (bool fallback) =>
              setState(() => _fallbackToSettings = fallback),
        ),
        _Buttons(<Widget>[
          FilledButton(
            onPressed: () => _run(_requestPermission, _allowed),
            child: const Text('Request permission'),
          ),
          if (_isIOS)
            FilledButton.tonal(
              onPressed: () => _run(
                notifications.registerForProvisionalAuthorization,
                _allowed,
              ),
              child: const Text('Provisional'),
            ),
          OutlinedButton(
            onPressed: () => _run(notifications.refreshPermission),
            child: const Text('Refresh permission'),
          ),
          if (_isIOS)
            OutlinedButton(
              onPressed: () =>
                  _run(notifications.registerForRemoteNotifications),
              child: const Text('Register'),
            ),
          OutlinedButton(
            onPressed: () => _run(notifications.clearAll),
            child: const Text('Clear all'),
          ),
        ]),
        if (_isAndroid)
          Row(
            spacing: 8,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _androidNotificationId,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Android notification id',
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => _run(_removeNotification),
                child: const Text('Remove'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _foregroundSection() {
    return ListenableBuilder(
      listenable: _foreground,
      builder: (BuildContext context, Widget? child) {
        final ForegroundMode mode = _foreground.mode;
        return _Section(
          title: 'Foreground notifications',
          children: <Widget>[
            SegmentedButton<ForegroundMode>(
              segments: const <ButtonSegment<ForegroundMode>>[
                ButtonSegment<ForegroundMode>(
                  value: ForegroundMode.off,
                  label: Text('Off'),
                ),
                ButtonSegment<ForegroundMode>(
                  value: ForegroundMode.show,
                  label: Text('Show'),
                ),
                ButtonSegment<ForegroundMode>(
                  value: ForegroundMode.hold,
                  label: Text('Hold'),
                ),
              ],
              selected: <ForegroundMode>{mode},
              onSelectionChanged: (Set<ForegroundMode> modes) =>
                  _foreground.mode = modes.single,
            ),
            Text(switch (mode) {
              ForegroundMode.off =>
                'No will-display listener: SallaPush shows each notification '
                    'itself, as it was sent.',
              ForegroundMode.show =>
                'A will-display listener lets each notification show. On iOS '
                    "it shows SallaPush's copy, without image or action "
                    'buttons.',
              ForegroundMode.hold =>
                'A will-display listener holds each notification. Display one '
                    'within 10 minutes of its arrival.',
            }),
            for (final SallaPushNotification notification in _foreground.held)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(describeNotification(notification)),
                subtitle: Text(notification.body ?? ''),
                trailing: TextButton(
                  onPressed: () =>
                      _run(() => _foreground.display(notification)),
                  child: const Text('Display'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _consentSection() {
    return _Section(
      title: 'Consent',
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Consent required'),
          subtitle: const Text(
            'With the static app id, require consent with the '
            'SallaPushRequiresUserConsent or '
            'com.salla.push.REQUIRES_USER_CONSENT key instead.',
          ),
          value: _consentRequired,
          onChanged: (bool required) {
            setState(() => _consentRequired = required);
            unawaited(_run(() => SallaPush.setConsentRequired(required)));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Consent given'),
          value: _consentGiven,
          onChanged: (bool given) {
            setState(() => _consentGiven = given);
            unawaited(_run(() => SallaPush.setConsentGiven(given)));
          },
        ),
      ],
    );
  }

  Widget _loggingSection(SallaPushStatus? status) {
    return _Section(
      title: 'Logging',
      children: <Widget>[
        _LevelPicker(
          label: 'Console level',
          level: status?.logLevel,
          onChanged: (SallaPushLogLevel level) =>
              _run(() => SallaPush.debug.setLogLevel(level)),
        ),
        ListenableBuilder(
          listenable: widget.log,
          builder: (BuildContext context, Widget? child) => _LevelPicker(
            label: 'Event log level',
            level: widget.log.logLevel,
            onChanged: (SallaPushLogLevel level) =>
                _run(() => widget.log.setLogLevel(level)),
          ),
        ),
      ],
    );
  }

  Widget _eventsSection() {
    return ListenableBuilder(
      listenable: widget.log,
      builder: (BuildContext context, Widget? child) {
        final List<LoggedEvent> entries = widget.log.entries;
        return _Section(
          title: 'Events',
          children: <Widget>[
            if (entries.isEmpty)
              const Text('No events yet.')
            else ...<Widget>[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: widget.log.clear,
                  child: const Text('Clear'),
                ),
              ),
              for (final LoggedEvent entry in entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${entry.kind.label}: ${entry.text}'),
                  subtitle: Text(_time(entry.time)),
                ),
            ],
          ],
        );
      },
    );
  }

  static String _time(DateTime time) => <int>[
    time.hour,
    time.minute,
    time.second,
  ].map((int part) => part.toString().padLeft(2, '0')).join(':');
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: const ListTile(
        leading: Icon(Icons.warning_amber),
        title: Text('Not configured'),
        subtitle: Text(
          'SallaPush has no app id, so it did not start. Set '
          'SALLAPUSH_APP_ID (iOS) or sallapushAppId (Android) as the '
          "example's README says.",
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _StatusTable extends StatelessWidget {
  const _StatusTable({
    required this.status,
    required this.showPermissionStatus,
  });

  final SallaPushStatus status;
  final bool showPermissionStatus;

  @override
  Widget build(BuildContext context) {
    final String? tokenEnd = status.tokenEnd;
    final Map<String, String> tags = status.tags;
    return Column(
      children: <Widget>[
        _StatusRow('Initialized', _yesNo(status.isInitialized)),
        _StatusRow('App id', status.appId ?? 'None'),
        _StatusRow('SallaPush SDK', status.sdkVersion),
        _StatusRow('Device id', status.deviceId ?? 'Not registered'),
        _StatusRow('Opted in', _yesNo(status.optedIn)),
        _StatusRow('Token', tokenEnd == null ? 'None' : '…$tokenEnd'),
        _StatusRow('Permission', status.permission ? 'Allowed' : 'Not allowed'),
        if (showPermissionStatus)
          _StatusRow(
            'Permission status',
            status.permissionStatus?.name ?? 'Unknown',
          ),
        _StatusRow('External id', status.externalId ?? 'None'),
        _StatusRow('Logged in', _yesNo(status.isLoggedIn)),
        _StatusRow(
          'Tags',
          tags.isEmpty
              ? 'None'
              : <String>[
                  for (final MapEntry<String, String> tag in tags.entries)
                    '${tag.key}=${tag.value}',
                ].join(', '),
        ),
      ],
    );
  }

  static String _yesNo(bool value) => value ? 'Yes' : 'No';
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          Expanded(
            flex: 2,
            child: Text(value, key: ValueKey<String>('status:$label')),
          ),
        ],
      ),
    );
  }
}

class _LevelPicker extends StatelessWidget {
  const _LevelPicker({
    required this.label,
    required this.level,
    required this.onChanged,
  });

  final String label;
  final SallaPushLogLevel? level;
  final ValueChanged<SallaPushLogLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        DropdownButton<SallaPushLogLevel>(
          key: ValueKey<String>('level:$label'),
          value: level,
          items: <DropdownMenuItem<SallaPushLogLevel>>[
            for (final SallaPushLogLevel value in SallaPushLogLevel.values)
              DropdownMenuItem<SallaPushLogLevel>(
                value: value,
                child: Text(value.name),
              ),
          ],
          onChanged: (SallaPushLogLevel? value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }
}
