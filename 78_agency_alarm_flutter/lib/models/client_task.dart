import 'dart:convert';

enum TaskPriority { high, medium, low }

class ClientTask {
  final String id;
  final int notificationId;
  final String clientName;
  final String title;
  final DateTime scheduledAt;
  final TaskPriority priority;
  final String category;
  final bool completed;
  final DateTime? completedAt;
  final bool? completedOnTime;

  const ClientTask({
    required this.id,
    required this.notificationId,
    required this.clientName,
    required this.title,
    required this.scheduledAt,
    required this.priority,
    required this.category,
    this.completed = false,
    this.completedAt,
    this.completedOnTime,
  });

  bool get isOverdue => !completed && scheduledAt.isBefore(DateTime.now());

  ClientTask copyWith({
    String? clientName,
    String? title,
    DateTime? scheduledAt,
    TaskPriority? priority,
    String? category,
    bool? completed,
    DateTime? completedAt,
    bool? completedOnTime,
    bool clearCompletion = false,
  }) {
    return ClientTask(
      id: id,
      notificationId: notificationId,
      clientName: clientName ?? this.clientName,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      completedAt: clearCompletion ? null : (completedAt ?? this.completedAt),
      completedOnTime:
          clearCompletion ? null : (completedOnTime ?? this.completedOnTime),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationId': notificationId,
        'clientName': clientName,
        'title': title,
        'scheduledAt': scheduledAt.toIso8601String(),
        'priority': priority.name,
        'category': category,
        'completed': completed,
        'completedAt': completedAt?.toIso8601String(),
        'completedOnTime': completedOnTime,
      };

  factory ClientTask.fromJson(Map<String, dynamic> json) {
    return ClientTask(
      id: json['id'] as String,
      notificationId: json['notificationId'] as int,
      clientName: json['clientName'] as String,
      title: json['title'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: (json['category'] as String?) ?? 'Delivery',
      completed: (json['completed'] as bool?) ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      completedOnTime: json['completedOnTime'] as bool?,
    );
  }

  static String encodeList(List<ClientTask> tasks) =>
      jsonEncode(tasks.map((t) => t.toJson()).toList());

  static List<ClientTask> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ClientTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
