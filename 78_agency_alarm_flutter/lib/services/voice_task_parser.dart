import '../models/client_task.dart';

class ParsedVoiceTask {
  final String clientName;
  final String title;
  final DateTime scheduledAt;
  final TaskPriority priority;
  final String category;

  const ParsedVoiceTask({
    required this.clientName,
    required this.title,
    required this.scheduledAt,
    required this.priority,
    required this.category,
  });
}

class VoiceTaskParser {
  static ParsedVoiceTask parse(String rawText, List<String> existingClients) {
    final text = rawText.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();
    DateTime scheduled = now.add(const Duration(minutes: 15));

    final relMin = RegExp(r'(\d+)\s*(?:min|minute|minutes|mint)').firstMatch(lower);
    final relHr = RegExp(r'(\d+)\s*(?:ghant[ae]|hour|hours|hr)').firstMatch(lower);

    if (relMin != null) {
      scheduled = now.add(Duration(minutes: int.parse(relMin.group(1)!)));
    } else if (relHr != null) {
      scheduled = now.add(Duration(hours: int.parse(relHr.group(1)!)));
    } else {
      final clk = RegExp(r'(?:(subah|sham|raat|dopehar)\s*)?(\d{1,2})(?::(\d{2}))?\s*(baje|bajy|am|pm)?').firstMatch(lower);
      if (clk != null && (clk.group(1) != null || clk.group(3) != null || clk.group(4) != null)) {
        int h = int.parse(clk.group(2)!);
        final int m = int.parse(clk.group(3) ?? '0');
        final period = clk.group(1) ?? '';
        final suffix = clk.group(4) ?? '';

        if (suffix == 'pm' || period == 'sham' || period == 'raat' || period == 'dopehar') {
          if (h < 12) h += 12;
        } else if (suffix == 'am' || period == 'subah') {
          if (h == 12) h = 0;
        } else if (h >= 1 && h <= 11 && h < now.hour && h + 12 >= now.hour) {
          h += 12;
        }

        var dt = DateTime(now.year, now.month, now.day, h % 24, m % 60);
        if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
        scheduled = dt;
      }
    }

    String client = 'Voice Client';
    for (final c in existingClients) {
      final first = c.split(' ').first.toLowerCase();
      if (lower.contains(c.toLowerCase()) || (first.length > 2 && lower.contains(first))) {
        client = c;
        break;
      }
    }

    final priority = RegExp(r'urgent|zaroori|jaldi|high|important').hasMatch(lower)
        ? TaskPriority.high
        : TaskPriority.medium;

    final category = RegExp(r'call|phone|baat').hasMatch(lower)
        ? 'Client Call'
        : RegExp(r'ad|meta|campaign|report').hasMatch(lower)
            ? 'Ads & Marketing'
            : RegExp(r'design|reel|post|logo').hasMatch(lower)
                ? 'Design'
                : 'Delivery';

    return ParsedVoiceTask(
      clientName: client,
      title: text.isEmpty ? 'Voice Task Reminder' : text,
      scheduledAt: scheduled,
      priority: priority,
      category: category,
    );
  }
}
