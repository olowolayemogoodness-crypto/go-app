import 'package:http/http.dart' as http;

class GhDay {
  final DateTime date;
  final int level; // 0 (none) to 4 (most)
  const GhDay(this.date, this.level);
}

/// Reads the public contribution calendar GitHub shows on a profile page.
class GithubService {
  static final Map<String, (int, List<GhDay>)> _cache = {};

  static Future<List<GhDay>> contributions(String user, {bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = _cache[user];
    if (!force && c != null && now - c.$1 < 5 * 60 * 1000) return c.$2;
    final r = await http
        .get(Uri.parse('https://github.com/users/${Uri.encodeComponent(user)}/contributions'),
            headers: {'accept': 'text/html'})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 404) throw Exception('GitHub user not found');
    if (r.statusCode != 200) throw Exception('GitHub returned ${r.statusCode}');
    final days = <GhDay>[];
    for (final m in RegExp(r'<td[^>]*>').allMatches(r.body)) {
      final tag = m.group(0)!;
      final d = RegExp(r'data-date="(\d{4}-\d{2}-\d{2})"').firstMatch(tag);
      final l = RegExp(r'data-level="(\d)"').firstMatch(tag);
      if (d == null || l == null) continue;
      days.add(GhDay(DateTime.parse(d.group(1)!), int.parse(l.group(1)!)));
    }
    if (days.isEmpty) throw Exception('No activity data found');
    days.sort((a, b) => a.date.compareTo(b.date));
    _cache[user] = (now, days);
    return days;
  }
}
