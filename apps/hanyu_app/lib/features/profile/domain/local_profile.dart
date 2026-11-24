import '../../../core/local/local_models.dart';

/// Local learning preferences, never an authenticated account or identity.
class LocalProfile {
  const LocalProfile({
    this.name = '',
    this.level = 1,
    this.minutes = 15,
    this.sound = true,
    this.helpVersionSeen,
  });

  factory LocalProfile.fromPreferences(
    LocalPreferences preferences, {
    String? helpVersionSeen,
  }) => LocalProfile(
    name: preferences.name,
    level: preferences.level,
    minutes: preferences.minutes,
    sound: preferences.sound,
    helpVersionSeen: helpVersionSeen,
  );

  static const currentHelpVersion = 'local-help-v1';
  static const dailyMinutes = [5, 10, 15, 20, 30];
  final String name;
  final int level, minutes;
  final bool sound;
  final String? helpVersionSeen;

  LocalProfile validated() {
    final normalizedName = name.trim();
    final help = helpVersionSeen;
    if (normalizedName.runes.length > 80 ||
        level < 1 ||
        level > 3 ||
        !dailyMinutes.contains(minutes) ||
        (help != null && (help.trim().isEmpty || help.runes.length > 40))) {
      throw const LocalDataException('Thiết lập học chưa hợp lệ.');
    }
    return LocalProfile(
      name: normalizedName,
      level: level,
      minutes: minutes,
      sound: sound,
      helpVersionSeen: help,
    );
  }

  LocalPreferences toPreferences() {
    final profile = validated();
    return LocalPreferences(
      name: profile.name,
      level: profile.level,
      minutes: profile.minutes,
      sound: profile.sound,
    );
  }
}
