import '../l10n/app_localizations.dart';

String deviceGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  return hour < 12 ? tr('greetingMorning') : tr('greetingEvening');
}
