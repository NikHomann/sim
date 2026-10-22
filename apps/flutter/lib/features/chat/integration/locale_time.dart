/// Locale-aware clock time of the timer watch label, approximating
/// `toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'})`
/// (`watch-activity.tsx:24-28`) without an ICU data dependency: English
/// locales of 12-hour regions read `hh:mm AM`/`PM` (en-US "09:05 PM"),
/// every other locale reads 24-hour `HH:mm` (de-DE "21:05", en-GB "21:05").
/// Non-English 12-hour conventions (ko "오후 09:05", ar, zh) fall back to
/// 24-hour.
library;

import 'dart:ui' show Locale;

/// English-speaking regions whose CLDR preferred hour cycle is 12-hour.
const Set<String> _twelveHourRegions = {
  'US',
  'CA',
  'AU',
  'NZ',
  'IN',
  'PK',
  'BD',
  'PH',
  'EG',
  'SA',
  'AE',
  'JO',
  'KW',
  'QA',
  'OM',
  'BH',
  'MY',
  'SG',
  'GH',
  'NG',
  'KE',
  'ZA',
  'AS',
  'GU',
  'MP',
  'PR',
  'UM',
  'VI',
};

String _two(int value) => value.toString().padLeft(2, '0');

/// `hh:mm AM` in English 12-hour regions (a bare `en` is en-US, as the
/// browser resolves it), `HH:mm` elsewhere.
String formatLocaleTime(DateTime at, Locale locale) {
  final region = locale.countryCode?.toUpperCase();
  final twelveHour =
      locale.languageCode == 'en' &&
      (region == null || region.isEmpty || _twelveHourRegions.contains(region));
  if (!twelveHour) return '${_two(at.hour)}:${_two(at.minute)}';
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '${_two(hour)}:${_two(at.minute)} ${at.hour < 12 ? 'AM' : 'PM'}';
}
