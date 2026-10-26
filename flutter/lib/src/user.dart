import 'channels.dart';
import 'mapping.dart';
import 'messages.g.dart';
import 'models.dart';
import 'push_subscription.dart';

/// The user of this device: the customer the app logged in, tags, language and
/// the push subscription.
///
/// Make the launch `SallaPush.login` or `SallaPush.logout` call before any tag
/// call, so that tags always belong to the right customer.
final class SallaPushUser {
  const SallaPushUser._();

  /// This device's push subscription.
  SallaPushSubscription get pushSubscription => pushSubscriptionNamespace;

  /// The external id of the last `SallaPush.login`, from the moment that call
  /// returns; null for a guest, after `SallaPush.logout`, and while consent is
  /// withdrawn. It doesn't say whether the SallaPush server accepted the
  /// link.
  Future<String?> get externalId => _host.externalId();

  /// True after `SallaPush.login` until the next `SallaPush.logout`. A login
  /// that SallaPush ignored for an invalid argument changes nothing.
  Future<bool> get isLoggedIn => _host.isLoggedIn();

  /// Adds or replaces the tag [key] with [value].
  ///
  /// SallaPush trims and lowercases keys, which must then be 1 to 64
  /// characters of a-z, 0-9 and _. It cuts values to 255 characters, and an
  /// empty value removes the tag. A device has at most 100 tags. Invalid tags
  /// are logged and dropped. Changes are kept on the device and sent until
  /// the SallaPush server confirms them.
  Future<void> addTag(String key, String value) => _host.addTag(key, value);

  /// Adds or replaces several tags, with the rules of [addTag] for each.
  Future<void> addTags(Map<String, String> tags) => _host.addTags(tags);

  /// Removes the tag [key].
  Future<void> removeTag(String key) => _host.removeTag(key);

  /// Removes the tags [keys].
  Future<void> removeTags(List<String> keys) => _host.removeTags(keys);

  /// This device's tags as SallaPush knows them, including changes not sent
  /// yet, normalised as they will be sent. Right after a cold start, they hold
  /// only this launch's changes until SallaPush has loaded the saved tags.
  Future<Map<String, String>> getTags() => _host.getTags();

  /// Sets the language SallaPush reports for this device, for example "ar"
  /// (trimmed, at most 16 characters). Null reports the language of the
  /// device.
  Future<void> setLanguage(String? language) => _host.setLanguage(language);

  /// Changes of externalId or isLoggedIn after native handled a call. No
  /// replay on listen: the state SallaPush loads at launch is no change.
  Stream<SallaPushUserChangedState> get onChange {
    final SallaPushChannels channels = SallaPushChannels.current;
    return _onChange[channels] ??= channels.userChanges.map(
      (UserChangedMessage message) => message.state,
    );
  }

  /// Refusals of the current login, each once. A login that links the device
  /// raises no event.
  Stream<SallaPushLoginFailure> get onLoginFailure {
    final SallaPushChannels channels = SallaPushChannels.current;
    return _onLoginFailure[channels] ??= channels.loginFailures.map(
      (LoginFailureEventMessage message) => message.failure.failure,
    );
  }

  static SallaPushHostApi get _host => SallaPushChannels.current.host;

  static final Expando<Stream<SallaPushUserChangedState>> _onChange =
      Expando<Stream<SallaPushUserChangedState>>();
  static final Expando<Stream<SallaPushLoginFailure>> _onLoginFailure =
      Expando<Stream<SallaPushLoginFailure>>();
}

/// The one [SallaPushUser], `SallaPush.user`.
const SallaPushUser userNamespace = SallaPushUser._();
