part of carte_de_jour;

/**
 * Emulation of Java Enum class.
 *
 * Example:
 *
 * class Meter<int> extends Enum<int> {
 *
 *  const Meter(int val) : super (val);
 *
 *  static const Meter HIGH = const Meter(100);
 *  static const Meter MIDDLE = const Meter(50);
 *  static const Meter LOW = const Meter(10);
 * }
 *
 * and usage:
 *
 * assert (Meter.HIGH, 100);
 * assert (Meter.HIGH is Meter);
 */
abstract class Enum<T> {

  final T _value;

  const Enum(this._value);

  T get value => _value;
}

/**
 * Commands sent from a package validation isolate.
 */
class PackageValidationCommand<String> extends Enum<String> {
  const PackageValidationCommand(String val) : super (val);

  static const PackageValidationCommand PACKAGE_REMOVE_INBOX =
      const PackageValidationCommand("packageRemoveInbox");
  static const PackageValidationCommand PACKAGE_ADD_OUTBOX =
      const PackageValidationCommand("packageAddOutbox");
}

/**
 * Commands sent from a gce launcher isolate.
 */
class GceLauncherCommand<String> extends Enum<String> {
  const GceLauncherCommand(String val) : super (val);
  static const GceLauncherCommand PACKAGE_BUILD_COMPLETE =
      const GceLauncherCommand("packageBuildComplete");
}

/**
 * Commands sent from a queue isolate.
 */
class QueueCommand<String> extends Enum<String> {
  const QueueCommand(String val) : super (val);
  static const QueueCommand CHECK_PACKAGE =
      const QueueCommand("checkPackage");
  static const QueueCommand BUILD_PACKAGE =
      const QueueCommand("buildPackage");
}

/**
 * Commands sent from a main isolate.
 */
class MainIsolateCommand<String> extends Enum<String> {
  const MainIsolateCommand(String val) : super (val);
  static const MainIsolateCommand PACKAGE_ADD =
      const MainIsolateCommand("packageAdd");
}

/**
 * Creates a message object to be sent over a `SendPort`
 */
Map createMessage(Enum e, dynamic message) =>
    {'command': e.value, 'message': message.toJson() };

/**
 * Check data is a `Enum` command.
 */
bool isCommand(Enum e, Map data) => data['command'] == e.value;
