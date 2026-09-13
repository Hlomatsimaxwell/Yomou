DateTime? parseHumanChapterDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  final iso = DateTime.tryParse(text);
  if (iso != null) return iso.toLocal();

  final m = RegExp(
    r'(?:Today|Yesterday)?\s*([A-Za-z]{3,9})\s+(\d{1,2}),?\s*(\d{4})',
  ).firstMatch(text);
  if (m != null) {
    final month = months[m.group(1)!.substring(0, 3).toLowerCase()];
    final day = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (month != null && day != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  final k = RegExp(r'([A-Za-z]{3})-(\d{1,2})-(\d{4})').firstMatch(text);
  if (k != null) {
    final month = months[k.group(1)!.toLowerCase()];
    final day = int.tryParse(k.group(2)!);
    final year = int.tryParse(k.group(3)!);
    if (month != null && day != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return null;
}