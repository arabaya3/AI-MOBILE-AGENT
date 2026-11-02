/// The API sends naive ISO timestamps that are UTC; parse them as UTC, not local time.
DateTime? parseServerTime(Object? value) {
  if (value == null) return null;
  final text = '$value';
  if (text.isEmpty || text == 'null') return null;
  final zoned = text.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(text);
  return DateTime.tryParse(zoned ? text : '${text}Z')?.toUtc();
}
