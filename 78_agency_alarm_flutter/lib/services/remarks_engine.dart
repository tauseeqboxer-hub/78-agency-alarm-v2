import '../models/client_task.dart';

class PerformanceReport {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int score;
  final String grade;
  final int? onTimeRate;
  final int streak;
  final String badge;
  final String title;
  final String message;

  const PerformanceReport({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.score,
    required this.grade,
    required this.onTimeRate,
    required this.streak,
    required this.badge,
    required this.title,
    required this.message,
  });
}

class RemarksEngine {
  static PerformanceReport evaluate(
    List<ClientTask> tasks, {
    required bool isRomanUrdu,
  }) {
    final total = tasks.length;
    final completedTasks = tasks.where((t) => t.completed).toList();
    final completed = completedTasks.length;
    final pendingTasks = tasks.where((t) => !t.completed).toList();
    final overdue = pendingTasks.where((t) => t.isOverdue).length;

    final onTimeDone =
        completedTasks.where((t) => t.completedOnTime != false).length;
    final int? onTimeRate =
        completed > 0 ? ((onTimeDone / completed) * 100).round() : null;

    int score = 0;
    if (total > 0 && completed > 0) {
      final completionRatio = completed / total;
      final punctualityRatio = onTimeDone / completed;
      final highTotal =
          tasks.where((t) => t.priority == TaskPriority.high).length;
      final highDone =
          completedTasks.where((t) => t.priority == TaskPriority.high).length;
      final highBonus = highTotal > 0 ? (highDone / highTotal) * 10 : 10.0;

      score = (completionRatio * 65 + punctualityRatio * 25 + highBonus).round();
      if (overdue > 0) {
        score = (score - overdue * 5).clamp(10, 100);
      } else {
        score = score.clamp(0, 100);
      }
    }

    String grade = '--';
    if (completed > 0) {
      if (score >= 92) {
        grade = 'A+';
      } else if (score >= 80) {
        grade = 'A';
      } else if (score >= 65) {
        grade = 'B+';
      } else if (score >= 50) {
        grade = 'B';
      } else {
        grade = 'C';
      }
    }

    int streak = 0;
    for (int i = completedTasks.length - 1; i >= 0; i--) {
      if (completedTasks[i].completedOnTime != false) {
        streak++;
      } else {
        break;
      }
    }

    String badge;
    String title;
    String message;

    if (total == 0) {
      badge = 'Fresh Day';
      title = isRomanUrdu
          ? 'Din ki planning shuru karein!'
          : 'Start planning your agency day!';
      message = isRomanUrdu
          ? 'Aaj ke clients ka kaam + button se add karein. Har kaam ka exact phone alarm set ho jayega aur completion par aapko remarks milenge.'
          : 'Tap + to add your client tasks with native alarms. Complete them on time to earn your daily score and remarks.';
    } else if (completed == 0) {
      if (overdue > 0) {
        badge = 'Attention';
        title = isRomanUrdu
            ? '$overdue Client Tasks Overdue Hain!'
            : '$overdue Client Tasks Are Overdue!';
        message = isRomanUrdu
            ? 'Abhi koi task done nahi hua aur $overdue kaam time se upar nikal gaye hain. Pehle overdue client ko clear karein!'
            : 'No tasks completed yet and $overdue passed their alarm time. Knock out overdue tasks first!';
      } else {
        badge = 'Ready';
        title = isRomanUrdu
            ? 'Chalein Bismillah Karein!'
            : 'Ready to crush today!';
        message = isRomanUrdu
            ? 'Aaj $total client tasks set hain. Pehla kaam waqt pe complete karein — aapka score turant upar jayega!'
            : 'You have $total client tasks lined up. Finish your first task on time to unlock your grade.';
      }
    } else if (score >= 90) {
      badge = 'Top Performer';
      title = isRomanUrdu
          ? 'Zabardast Boss! 10/10 Agency Execution!'
          : 'Outstanding Agency Execution!';
      message = isRomanUrdu
          ? 'Kamaal kar diya! $completed/$total tasks mukammal (${onTimeRate ?? 100}% on-time). Aisi discipline se aapke clients hamesha khush rahenge!'
          : 'Completed $completed/$total tasks with ${onTimeRate ?? 100}% on-time delivery. Clients love this consistency!';
    } else if (score >= 75) {
      badge = 'Great Pace';
      title = isRomanUrdu
          ? 'Bohat Aala Kaam Chal Raha Hai!'
          : 'Strong Momentum Today!';
      message = isRomanUrdu
          ? '$completed tasks done ho chuke hain. Baqi ${total - completed} kaam aur waqt pe clear karein, aaj ka din perfect hoga!'
          : '$completed tasks done already. Finish the remaining ${total - completed} on schedule for an A+ day.';
    } else if (score >= 50) {
      badge = 'Steady';
      title = isRomanUrdu
          ? 'Acha Ja Raha Hai — Speed Barhayein!'
          : 'Solid Progress — Keep Pushing!';
      message = isRomanUrdu
          ? '$completed/$total tasks complete hain.${overdue > 0 ? ' Pehle $overdue overdue kaam nipta lein.' : ' High-priority clients pe focus rakhein!'}'
          : '$completed of $total tasks done.${overdue > 0 ? ' Clear the $overdue overdue task(s) next.' : ' Focus on high-priority clients for an A!'}';
    } else {
      badge = 'Warming Up';
      title = isRomanUrdu
          ? 'Shuruat Achi Hai — Ab Gear Badlein!'
          : 'Good Start — Shift Into High Gear!';
      message = isRomanUrdu
          ? '$completed task complete hua hai, ${total - completed} baqi hain. Agla alarm miss na karein — ek ek karke sab clear ho jayega!'
          : '$completed done, ${total - completed} pending. Catch the next alarm on time to boost your score!';
    }

    return PerformanceReport(
      total: total,
      completed: completed,
      pending: pendingTasks.length,
      overdue: overdue,
      score: score,
      grade: grade,
      onTimeRate: onTimeRate,
      streak: streak,
      badge: badge,
      title: title,
      message: message,
    );
  }

  static String completionSnackbar(
    ClientTask task,
    bool onTime, {
    required bool isRomanUrdu,
  }) {
    if (onTime) {
      return isRomanUrdu
          ? 'Shabash! ${task.clientName} ka kaam waqt pe complete hua! ✓'
          : 'Nailed it! Completed ${task.clientName} on time! ✓';
    }
    return isRomanUrdu
        ? '${task.clientName} ka kaam mukammal hua (thora late). Agla task time pe pakrein!'
        : 'Wrapped up ${task.clientName} (slightly late). Catch the next alarm on time!';
  }
}
