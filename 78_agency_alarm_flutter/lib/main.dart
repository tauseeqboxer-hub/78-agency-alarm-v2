import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/client_task.dart';
import 'services/alarm_service.dart';
import 'services/remarks_engine.dart';
import 'services/storage_service.dart';
import 'services/voice_task_parser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Agency78AlarmApp());
}

class Agency78AlarmApp extends StatefulWidget {
  const Agency78AlarmApp({super.key});

  @override
  State<Agency78AlarmApp> createState() => _Agency78AlarmAppState();
}

class _Agency78AlarmAppState extends State<Agency78AlarmApp> {
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('agency_78_dark_mode');
    if (saved != null && mounted) {
      setState(() => _isDark = saved);
    }
  }

  Future<void> _toggleTheme() async {
    setState(() => _isDark = !_isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('agency_78_dark_mode', _isDark);
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF6366F1),
      scaffoldBackgroundColor: const Color(0xFF090D16),
      cardColor: const Color(0xFF131B2E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF090D16),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF4F46E5),
      scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F6FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );

    return MaterialApp(
      title: '78 Agency Alarm',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: AgencyHomeScreen(
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class AgencyHomeScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AgencyHomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<AgencyHomeScreen> createState() => _AgencyHomeScreenState();
}

class _AgencyHomeScreenState extends State<AgencyHomeScreen> {
  List<ClientTask> _tasks = [];
  bool _isRomanUrdu = true;
  int _tabIndex = 0;
  String _statusFilter = 'all';
  String _clientFilter = 'ALL';
  Timer? _clockTimer;
  final SpeechToText _speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    AlarmService.instance.stopVoice();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await AlarmService.instance.init(
      onNotificationTap: (payload) {
        if (!mounted || payload == null || payload == 'test_alarm') return;
        final matches = _tasks.where((t) => t.id == payload).toList();
        if (matches.isNotEmpty) {
          _showAlarmActionDialog(matches.first);
        }
      },
    );

    final tasks = await StorageService.loadTasks();
    final isUr = await StorageService.loadIsRomanUrdu();

    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _isRomanUrdu = isUr;
    });
  }

  Future<void> _persist() async {
    await StorageService.saveTasks(_tasks);
  }

  void _showSnack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg ?? const Color(0xFF4F46E5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
  }

  Future<void> _addTask({
    required String clientName,
    required String title,
    required DateTime scheduledAt,
    required TaskPriority priority,
    required String category,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final task = ClientTask(
      id: 't_$nowMs',
      notificationId: nowMs % 100000000,
      clientName: clientName.trim(),
      title: title.trim(),
      scheduledAt: scheduledAt,
      priority: priority,
      category: category,
    );

    if (!mounted) return;
    setState(() => _tasks.add(task));
    await _persist();
    await AlarmService.instance.scheduleTaskAlarm(task);

    _showSnack(
      _isRomanUrdu
          ? '⏰ Alarm set: ${task.clientName} (${DateFormat.jm().format(task.scheduledAt)})'
          : '⏰ Alarm set: ${task.clientName} (${DateFormat.jm().format(task.scheduledAt)})',
    );
  }

  Future<void> _toggleComplete(ClientTask task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return;

    final markingDone = !task.completed;
    final now = DateTime.now();
    final onTime = now.isBefore(task.scheduledAt.add(const Duration(minutes: 10)));

    final updated = markingDone
        ? task.copyWith(completed: true, completedAt: now, completedOnTime: onTime)
        : task.copyWith(completed: false, clearCompletion: true);

    if (!mounted) return;
    setState(() => _tasks[idx] = updated);
    await _persist();

    if (markingDone) {
      await AlarmService.instance.cancelTaskAlarm(task.notificationId);
      _showSnack(
        RemarksEngine.completionSnackbar(updated, onTime, isRomanUrdu: _isRomanUrdu),
        bg: onTime ? const Color(0xFF059669) : const Color(0xFFD97706),
      );
    } else {
      await AlarmService.instance.scheduleTaskAlarm(updated);
    }
  }

  Future<void> _snoozeTask(ClientTask task, int minutes) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return;
    final newTime = DateTime.now().add(Duration(minutes: minutes));
    final updated = task.copyWith(scheduledAt: newTime);

    if (!mounted) return;
    setState(() => _tasks[idx] = updated);
    await _persist();
    await AlarmService.instance.cancelTaskAlarm(task.notificationId);
    await AlarmService.instance.scheduleTaskAlarm(updated);

    _showSnack(
      _isRomanUrdu
          ? 'Snooze +$minutes min: ${updated.clientName}'
          : 'Snoozed +$minutes min: ${updated.clientName}',
      bg: const Color(0xFFD97706),
    );
  }

  Future<void> _deleteTask(ClientTask task) async {
    if (!mounted) return;
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    await _persist();
    await AlarmService.instance.cancelTaskAlarm(task.notificationId);
  }

  Future<void> _sendWhatsAppUpdate(ClientTask task) async {
    try {
      final msg = task.completed
          ? 'Assalam o Alaikum ${task.clientName}, aapka kaam (${task.title}) mukammal ho gaya hai! — 78 Agency'
          : 'Assalam o Alaikum ${task.clientName}, aapke kaam (${task.title}) par update share kar rahe hain — 78 Agency';
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack('WhatsApp open nahi ho saka.', bg: Colors.redAccent);
    }
  }

  void _showAlarmActionDialog(ClientTask task) {
    AlarmService.instance.startLoudVoiceLoop(
      task.clientName,
      isRomanUrdu: _isRomanUrdu,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active, color: Colors.redAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(
              '⏰ ${DateFormat.jm().format(task.scheduledAt)} — Kaam karna hai!',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AlarmService.instance.stopVoice();
              Navigator.pop(ctx);
              _snoozeTask(task, 10);
            },
            child: const Text('Snooze 10m'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () {
              AlarmService.instance.stopVoice();
              Navigator.pop(ctx);
              if (!task.completed) _toggleComplete(task);
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(_isRomanUrdu ? 'Kaam Ho Gaya!' : 'Mark Done'),
          ),
        ],
      ),
    );
  }

  void _openVoiceTaskSheet() {
    final textCtrl = TextEditingController();
    bool listening = false;
    String status = _isRomanUrdu ? 'Mic daba kar bolein...' : 'Tap mic & speak...';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> toggleListen() async {
            if (listening) {
              await _speech.stop();
              if (ctx.mounted) {
                setSheetState(() {
                  listening = false;
                  status = _isRomanUrdu ? 'Sun liya! Ab Save dabayein.' : 'Done! Tap Save below.';
                });
              }
              return;
            }
            try {
              final ok = await _speech.initialize();
              if (!ok) {
                if (ctx.mounted) {
                  setSheetState(() => status = 'Mic permission allow karein ya neeche likhein.');
                }
                return;
              }
              if (ctx.mounted) {
                setSheetState(() {
                  listening = true;
                  status = _isRomanUrdu ? '🎙️ Sun raha hoon... bolein!' : '🎙️ Listening... speak now!';
                });
              }
              await _speech.listen(
                localeId: _isRomanUrdu ? 'ur_PK' : 'en_US',
                onResult: (res) {
                  if (ctx.mounted) {
                    setSheetState(() => textCtrl.text = res.recognizedWords);
                  }
                },
              );
            } catch (_) {
              if (ctx.mounted) {
                setSheetState(() => status = 'Mic available nahi — neeche likhein.');
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isRomanUrdu ? '🎙️ Bol Kar Kaam Likhwain' : '🎙️ Voice Task & Alarm',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRomanUrdu
                        ? 'Misal: "5 baje Al-Noor ko report bhejni hai"'
                        : 'Example: "In 30 minutes call TechNova client"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: toggleListen,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: listening ? 76 : 68,
                      height: listening ? 76 : 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: listening
                              ? [const Color(0xFFEF4444), const Color(0xFFF97316)]
                              : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (listening ? Colors.redAccent : const Color(0xFF6366F1)).withOpacity(0.38),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        listening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _isRomanUrdu ? 'Jo aap bolenge yahan likha aayega...' : 'Your voice text appears here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.alarm_add_rounded),
                      label: Text(
                        _isRomanUrdu ? 'Likh Lo & Alarm Lagao!' : 'Save & Set Alarm',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () async {
                        if (listening) await _speech.stop();
                        if (textCtrl.text.trim().isEmpty) return;
                        final existing = _tasks.map((t) => t.clientName).toSet().toList();
                        final parsed = VoiceTaskParser.parse(textCtrl.text, existing);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _addTask(
                          clientName: parsed.clientName,
                          title: parsed.title,
                          scheduledAt: parsed.scheduledAt,
                          priority: parsed.priority,
                          category: parsed.category,
                        );
                        await AlarmService.instance.speakAlarmVoice(
                          parsed.clientName,
                          isRomanUrdu: _isRomanUrdu,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddTaskSheet() {
    final clientCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    DateTime pickedDateTime = DateTime.now().add(const Duration(minutes: 15));
    TaskPriority priority = TaskPriority.medium;
    String category = 'Delivery';
    final existingClients = _tasks.map((t) => t.clientName).toSet().toList()..sort();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isRomanUrdu ? 'Naya Client Kaam Likhein' : 'Add New Client Task',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: clientCtrl,
                    decoration: InputDecoration(
                      labelText: _isRomanUrdu ? 'Client ka Naam' : 'Client Name',
                      hintText: 'e.g. Al-Noor Real Estate',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (existingClients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: existingClients
                          .map((c) => ActionChip(
                                label: Text(c, style: const TextStyle(fontSize: 12)),
                                onPressed: () => clientCtrl.text = c,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _isRomanUrdu ? 'Kya Kaam Karna Hai?' : 'Task Details',
                      hintText: 'e.g. Meta Ads report bhejni hai',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.alarm_rounded),
                          label: Text(DateFormat.jm().format(pickedDateTime)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(pickedDateTime),
                            );
                            if (picked != null && ctx.mounted) {
                              final now = DateTime.now();
                              var dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                              if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
                              setSheetState(() => pickedDateTime = dt);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<TaskPriority>(
                        value: priority,
                        items: const [
                          DropdownMenuItem(value: TaskPriority.high, child: Text('High')),
                          DropdownMenuItem(value: TaskPriority.medium, child: Text('Medium')),
                          DropdownMenuItem(value: TaskPriority.low, child: Text('Low')),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => priority = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [5, 15, 30, 60].map((mins) {
                      return ChoiceChip(
                        label: Text('+$mins min'),
                        selected: false,
                        onSelected: (_) {
                          setSheetState(() => pickedDateTime = DateTime.now().add(Duration(minutes: mins)));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      'Delivery',
                      'Ads & Marketing',
                      'Design',
                      'Client Call',
                      'Follow-up',
                      'Dev & Tech',
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.alarm_add_rounded),
                      label: Text(
                        _isRomanUrdu ? 'Save & Alarm Lagayein' : 'Add & Set Alarm',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () {
                        if (clientCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        _addTask(
                          clientName: clientCtrl.text,
                          title: titleCtrl.text,
                          scheduledAt: pickedDateTime,
                          priority: priority,
                          category: category,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<ClientTask> get _filteredTasks {
    final list = _tasks.where((t) {
      if (_clientFilter != 'ALL' && t.clientName != _clientFilter) return false;
      if (_statusFilter == 'pending' && t.completed) return false;
      if (_statusFilter == 'done' && !t.completed) return false;
      if (_statusFilter == 'overdue' && !t.isOverdue) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      return a.scheduledAt.compareTo(b.scheduledAt);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final report = RemarksEngine.evaluate(_tasks, isRomanUrdu: _isRomanUrdu);
    final clients = _tasks.map((t) => t.clientName).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '78 Agency Alarm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  Text(
                    _isRomanUrdu ? 'Client Tasks & Alarms' : 'Client Task Coach',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Test Alarm',
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.amber),
            onPressed: () => AlarmService.instance.triggerTestAlarm(),
          ),
          IconButton(
            tooltip: 'Theme',
            icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
          TextButton(
            onPressed: () async {
              setState(() => _isRomanUrdu = !_isRomanUrdu);
              await StorageService.saveIsRomanUrdu(_isRomanUrdu);
            },
            child: Text(
              _isRomanUrdu ? 'UR' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _tabIndex == 0
              ? _buildTasksTab(report, clients)
              : _buildRemarksTab(report, clients),
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'voice_fab',
            backgroundColor: const Color(0xFFF43F5E),
            foregroundColor: Colors.white,
            onPressed: _openVoiceTaskSheet,
            child: const Icon(Icons.mic_rounded),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'add_fab',
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            onPressed: _openAddTaskSheet,
            icon: const Icon(Icons.add_alarm_rounded),
            label: Text(
              _isRomanUrdu ? 'Naya Kaam' : 'Add Task',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.checklist_rounded),
            label: _isRomanUrdu ? 'Kaam & Alarms' : 'Tasks',
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_rounded),
            label: 'Remarks ${report.score}%',
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab(PerformanceReport report, List<String> clients) {
    final tasks = _filteredTasks;
    return ListView(
      key: const ValueKey('tasks_tab'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Flagship Gradient Hero Score Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF0EA5E9)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '🔥 ${report.streak} STREAK',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.pending} ${_isRomanUrdu ? "baqi" : "pending"} • ${report.completed}/${report.total} done',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                height: 60,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: report.score / 100.0),
                  duration: const Duration(milliseconds: 550),
                  builder: (context, val, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: val,
                        strokeWidth: 5,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${report.score}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              report.grade,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Status Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ['all', 'pending', 'overdue', 'done'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    selected: _statusFilter == f,
                    onSelected: (_) => setState(() => _statusFilter = f),
                  ),
                ),
            ],
          ),
        ),

        if (clients.isNotEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All Clients'),
                    selected: _clientFilter == 'ALL',
                    onSelected: (_) => setState(() => _clientFilter = 'ALL'),
                  ),
                ),
                for (final c in clients)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c),
                      selected: _clientFilter == c,
                      onSelected: (_) => setState(() => _clientFilter = _clientFilter == c ? 'ALL' : c),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.18)),
            ),
            child: Column(
              children: [
                Icon(Icons.task_alt_rounded, size: 42, color: Theme.of(context).hintColor),
                const SizedBox(height: 10),
                Text(
                  _isRomanUrdu
                      ? 'Koi task nahi hai. Red Mic daba kar bolein ya "+ Naya Kaam" dabayein!'
                      : 'No tasks here. Tap the Mic to speak or "+ Add Task" below!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                ),
              ],
            ),
          )
        else
          for (final task in tasks) _buildTaskCard(task),
      ],
    );
  }

  Widget _buildTaskCard(ClientTask task) {
    final isOverdue = task.isOverdue;
    final accentColor = task.completed
        ? const Color(0xFF10B981)
        : task.priority == TaskPriority.high
            ? const Color(0xFFF43F5E)
            : task.priority == TaskPriority.medium
                ? const Color(0xFFF59E0B)
                : const Color(0xFF38BDF8);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.grey.withOpacity(widget.isDark ? 0.16 : 0.2),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: task.completed,
                      activeColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: (_) => _toggleComplete(task),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  task.clientName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                              Text(
                                task.priority.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: task.priority == TaskPriority.high
                                      ? Colors.redAccent
                                      : Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              decoration: task.completed ? TextDecoration.lineThrough : null,
                              color: task.completed ? Theme.of(context).hintColor : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.alarm_rounded,
                                size: 14,
                                color: isOverdue ? Colors.redAccent : const Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.jm().format(task.scheduledAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isOverdue ? Colors.redAccent : const Color(0xFF38BDF8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '• ${task.category}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'WhatsApp Update',
                          icon: const Icon(Icons.chat_rounded, color: Color(0xFF10B981), size: 20),
                          onPressed: () => _sendWhatsAppUpdate(task),
                        ),
                        PopupMenuButton<String>(
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'snooze') _snoozeTask(task, 10);
                            if (value == 'delete') _deleteTask(task);
                          },
                          itemBuilder: (_) => [
                            if (!task.completed)
                              const PopupMenuItem(value: 'snooze', child: Text('Snooze +10 min')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksTab(PerformanceReport report, List<String> clients) {
    return ListView(
      key: const ValueKey('remarks_tab'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.18)),
          ),
          child: Column(
            children: [
              Text(
                _isRomanUrdu ? 'Aaj Ke Performance Remarks' : 'Daily Performance Remarks',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 128,
                height: 128,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: report.score / 100.0),
                  duration: const Duration(milliseconds: 650),
                  builder: (context, val, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: val,
                        strokeWidth: 10,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        color: report.score >= 80 ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${report.score}%',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Grade ${report.grade}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF312E81),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(report.message, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statBox(
                      'On-Time Rate',
                      report.onTimeRate != null ? '${report.onTimeRate}%' : '--',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statBox('On-Time Streak', '${report.streak} 🔥'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isRomanUrdu ? 'Client-Wise Hisab' : 'Client Breakdown',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (clients.isEmpty)
          Text('No clients yet.', style: TextStyle(color: Theme.of(context).hintColor))
        else
          for (final c in clients) _buildClientRow(c),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildClientRow(String client) {
    final cTasks = _tasks.where((t) => t.clientName == client).toList();
    final done = cTasks.where((t) => t.completed).length;
    final pct = cTasks.isEmpty ? 0.0 : done / cTasks.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  client,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$done / ${cTasks.length} done',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: done == cTasks.length ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: pct == 1.0 ? const Color(0xFF10B981) : const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }
}
