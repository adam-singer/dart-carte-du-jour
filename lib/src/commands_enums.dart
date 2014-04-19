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

class PackageValidationCommand<String> extends Enum<String> {
  const PackageValidationCommand(String val) : super (val);

  static const PackageValidationCommand PACKAGE_REMOVE_INBOX =
      const PackageValidationCommand("packageRemoveInbox");
  static const PackageValidationCommand PACKAGE_ADD_OUTBOX =
      const PackageValidationCommand("packageAddOutbox");
}

class GceLauncherCommand<String> extends Enum<String> {
  const GceLauncherCommand(String val) : super (val);
  static const GceLauncherCommand PACKAGE_BUILD_COMPLETE =
      const GceLauncherCommand("packageBuildComplete");
}

class QueueCommand<String> extends Enum<String> {
  const QueueCommand(String val) : super (val);
  static const QueueCommand CHECK_PACKAGE =
      const QueueCommand("checkPackage");
  static const QueueCommand BUILD_PACKAGE =
      const QueueCommand("buildPackage");
}

class MainIsolateCommand<String> extends Enum<String> {
  const MainIsolateCommand(String val) : super (val);
  static const MainIsolateCommand PACKAGE_ADD =
      const MainIsolateCommand("packageAdd");
}

Map createMessage(Enum e, dynamic message) =>
    {'command': e.value, 'message': message.toJson() };
