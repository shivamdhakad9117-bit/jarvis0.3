import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JarvisApp());
}

// ══════════════════════════════════════════
//  THEME CONSTANTS
// ══════════════════════════════════════════
const kBg       = Color(0xFF050D18);
const kCard     = Color(0xFF0D1B2A);
const kCyan     = Color(0xFF00E5FF);
const kCyanDark = Color(0xFF0097A7);
const kBorder   = Color(0xFF1A3A4A);
const kText     = Color(0xFFE0F7FA);
const kGrey     = Color(0xFF546E7A);

// ══════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════
class AlarmModel {
  String id, label;
  int hour, minute;
  bool active;

  AlarmModel({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    this.active = true,
  });

  String get timeStr {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${hour < 12 ? "AM" : "PM"}';
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'hour': hour, 'minute': minute, 'active': active};

  factory AlarmModel.fromJson(Map<String, dynamic> j) => AlarmModel(
        id: j['id'],
        label: j['label'],
        hour: j['hour'],
        minute: j['minute'],
        active: j['active'] ?? true,
      );
}

class ReminderModel {
  String id, label, type;
  int hour, minute;
  bool active;

  ReminderModel({
    required this.id,
    required this.label,
    required this.type,
    required this.hour,
    required this.minute,
    this.active = true,
  });

  String get timeStr {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${hour < 12 ? "AM" : "PM"}';
  }

  IconData get icon {
    switch (type) {
      case 'water':    return Icons.water_drop_outlined;
      case 'medicine': return Icons.medication_outlined;
      case 'exercise': return Icons.fitness_center;
      default:         return Icons.notifications_outlined;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'label': label, 'type': type,
        'hour': hour, 'minute': minute, 'active': active
      };

  factory ReminderModel.fromJson(Map<String, dynamic> j) => ReminderModel(
        id: j['id'], label: j['label'], type: j['type'] ?? 'general',
        hour: j['hour'], minute: j['minute'], active: j['active'] ?? true,
      );
}

class HabitModel {
  String id, name;
  bool done;

  HabitModel({required this.id, required this.name, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'done': done};

  factory HabitModel.fromJson(Map<String, dynamic> j) =>
      HabitModel(id: j['id'], name: j['name'], done: j['done'] ?? false);
}

// ══════════════════════════════════════════
//  ROOT APP
// ══════════════════════════════════════════
class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kCyan,
          secondary: kCyan,
          surface: kCard,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kCard,
          elevation: 0,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: kCard,
          selectedItemColor: kCyan,
          unselectedItemColor: kGrey,
          type: BottomNavigationBarType.fixed,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kCyan,
            foregroundColor: kBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kCard,
          hintStyle: const TextStyle(color: kGrey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kCyan, width: 1.5),
          ),
        ),
      ),
      home: const JarvisShell(),
    );
  }
}

// ══════════════════════════════════════════
//  SHELL (Bottom Nav + State)
// ══════════════════════════════════════════
class JarvisShell extends StatefulWidget {
  const JarvisShell({super.key});

  @override
  State<JarvisShell> createState() => _JarvisShellState();
}

class _JarvisShellState extends State<JarvisShell> {
  int _tab = 0;
  late SharedPreferences _prefs;
  bool _ready = false;

  List<AlarmModel>    _alarms    = [];
  List<ReminderModel> _reminders = [];
  List<HabitModel>    _habits    = [];
  String _motivation = '';
  String _habitDate  = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAll();
    _resetHabitsIfNewDay();
    _startTicker();
    setState(() => _ready = true);
  }

  // ── persistence ──────────────────────────
  void _loadAll() {
    try {
      final a = _prefs.getString('alarms');
      final r = _prefs.getString('reminders');
      final h = _prefs.getString('habits');
      if (a != null) _alarms    = (jsonDecode(a) as List).map((e) => AlarmModel.fromJson(e)).toList();
      if (r != null) _reminders = (jsonDecode(r) as List).map((e) => ReminderModel.fromJson(e)).toList();
      if (h != null) _habits    = (jsonDecode(h) as List).map((e) => HabitModel.fromJson(e)).toList();
      _motivation = _prefs.getString('motivation') ?? '';
      _habitDate  = _prefs.getString('habitDate')  ?? '';
    } catch (_) {}
  }

  void _saveAll() {
    _prefs.setString('alarms',    jsonEncode(_alarms.map((e) => e.toJson()).toList()));
    _prefs.setString('reminders', jsonEncode(_reminders.map((e) => e.toJson()).toList()));
    _prefs.setString('habits',    jsonEncode(_habits.map((e) => e.toJson()).toList()));
    _prefs.setString('motivation', _motivation);
    _prefs.setString('habitDate',  _habitDate);
  }

  void _resetHabitsIfNewDay() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_habitDate != today) {
      for (final h in _habits) h.done = false;
      _habitDate = today;
      _saveAll();
    }
  }

  // ── alarm / reminder ticker ───────────────
  void _startTicker() {
    Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      for (final a in _alarms) {
        if (a.active && a.hour == now.hour && a.minute == now.minute) {
          _showPopup('⏰  ALARM', a.label, Icons.alarm);
        }
      }
      for (final r in _reminders) {
        if (r.active && r.hour == now.hour && r.minute == now.minute) {
          _showPopup('📢  REMINDER', r.label, r.icon);
        }
      }
    });
  }

  void _showPopup(String title, String body, IconData icon) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kCyan, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: kCyan, size: 48),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: kCyan, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(color: kText, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('DISMISS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── voice panel ──────────────────────────
  void _openVoicePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: kBorder),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kGrey, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.mic, color: kCyan, size: 52),
            const SizedBox(height: 12),
            const Text('Voice Commands', style: TextStyle(color: kCyan, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _voiceCmd('"Set alarm 7 AM"', '→ Alarm tab khulega'),
            _voiceCmd('"Add reminder"',   '→ Reminder tab khulega'),
            _voiceCmd('"Open habits"',    '→ Habit tab khulega'),
            const SizedBox(height: 8),
            const Text('(Tap tab buttons to navigate)', style: TextStyle(color: kGrey, fontSize: 12)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _voiceCmd(String cmd, String action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.chevron_right, color: kCyan, size: 18),
        const SizedBox(width: 6),
        Text(cmd, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(action, style: const TextStyle(color: kGrey, fontSize: 13)),
      ],
    ),
  );

  // ── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kCyan, width: 1.5),
                color: kCard,
              ),
              child: const Center(
                child: Text('J', style: TextStyle(color: kCyan, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('JARVIS', style: TextStyle(color: kCyan, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 3)),
                Text('Personal Assistant', style: TextStyle(color: kGrey, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openVoicePanel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: kCyan, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic_none, color: kCyan, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          AlarmPage(
            alarms: _alarms,
            onChanged: () => setState(_saveAll),
          ),
          ReminderPage(
            reminders: _reminders,
            onChanged: () => setState(_saveAll),
          ),
          HabitPage(
            habits: _habits,
            motivation: _motivation,
            onChanged: () => setState(_saveAll),
            onMotivationChanged: (v) { _motivation = v; _saveAll(); },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.alarm_outlined), activeIcon: Icon(Icons.alarm), label: 'Alarm'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Reminder'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Habits'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  ALARM PAGE
// ══════════════════════════════════════════
class AlarmPage extends StatefulWidget {
  final List<AlarmModel> alarms;
  final VoidCallback onChanged;

  const AlarmPage({super.key, required this.alarms, required this.onChanged});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  final _label = TextEditingController();
  TimeOfDay? _time;

  void _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kCyan, surface: kCard),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  void _add() {
    final lbl = _label.text.trim();
    if (lbl.isEmpty || _time == null) {
      _snack('Label aur time dono daalo!', isError: true);
      return;
    }
    final alarm = AlarmModel(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      label: lbl,
      hour: _time!.hour,
      minute: _time!.minute,
    );
    setState(() { widget.alarms.add(alarm); _label.clear(); _time = null; });
    widget.onChanged();
    _snack('✅ Alarm set: ${alarm.label} @ ${alarm.timeStr}');
  }

  void _delete(int i) {
    setState(() => widget.alarms.removeAt(i));
    widget.onChanged();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[800] : kCyanDark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _SectionHeader(title: 'New Alarm', icon: Icons.add_alarm),
        _JCard(
          child: Column(
            children: [
              TextField(
                controller: _label,
                style: const TextStyle(color: kText),
                decoration: const InputDecoration(
                  hintText: 'Alarm naam (e.g. Wake Up)',
                  prefixIcon: Icon(Icons.label_outline, color: kGrey),
                ),
              ),
              const SizedBox(height: 12),
              _OutlineBtn(
                label: _time == null ? '🕐  Time Chuno' : '🕐  ${_time!.format(context)}',
                onTap: _pickTime,
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _add, child: const Text('SET ALARM'))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'Your Alarms (${widget.alarms.length})', icon: Icons.alarm),
        if (widget.alarms.isEmpty)
          _EmptyState(msg: 'Koi alarm set nahi hai')
        else
          ...widget.alarms.asMap().entries.map((e) => _AlarmCard(
            alarm: e.value,
            onToggle: (v) { setState(() => e.value.active = v); widget.onChanged(); },
            onDelete: () => _delete(e.key),
          )),
      ],
    );
  }

  @override
  void dispose() { _label.dispose(); super.dispose(); }
}

class _AlarmCard extends StatelessWidget {
  final AlarmModel alarm;
  final Function(bool) onToggle;
  final VoidCallback onDelete;

  const _AlarmCard({required this.alarm, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => _JCard(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: alarm.active ? kCyan : kBorder),
          ),
          child: Icon(Icons.alarm, color: alarm.active ? kCyan : kGrey, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alarm.label, style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 15)),
              Text(alarm.timeStr, style: const TextStyle(color: kCyan, fontSize: 13)),
            ],
          ),
        ),
        Switch(activeColor: kCyan, value: alarm.active, onChanged: onToggle),
        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: onDelete),
      ],
    ),
  );
}

// ══════════════════════════════════════════
//  REMINDER PAGE
// ══════════════════════════════════════════
class ReminderPage extends StatefulWidget {
  final List<ReminderModel> reminders;
  final VoidCallback onChanged;

  const ReminderPage({super.key, required this.reminders, required this.onChanged});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final _label = TextEditingController();
  TimeOfDay? _time;
  String _type = 'general';

  final _types = const [
    ('general',  '📌 General',  ),
    ('water',    '💧 Paani',    ),
    ('medicine', '💊 Dawai',    ),
    ('exercise', '🏃 Exercise', ),
  ];

  void _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kCyan, surface: kCard),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  void _add() {
    final lbl = _label.text.trim();
    if (lbl.isEmpty || _time == null) {
      _snack('Sab fields bharo!', isError: true);
      return;
    }
    final r = ReminderModel(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      label: lbl, type: _type,
      hour: _time!.hour, minute: _time!.minute,
    );
    setState(() { widget.reminders.add(r); _label.clear(); _time = null; _type = 'general'; });
    widget.onChanged();
    _snack('✅ Reminder add ho gaya!');
  }

  void _delete(int i) {
    setState(() => widget.reminders.removeAt(i));
    widget.onChanged();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[800] : kCyanDark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _SectionHeader(title: 'New Reminder', icon: Icons.add_alert),
        _JCard(
          child: Column(
            children: [
              TextField(
                controller: _label,
                style: const TextStyle(color: kText),
                decoration: const InputDecoration(
                  hintText: 'Reminder naam (e.g. Paani Piyo)',
                  prefixIcon: Icon(Icons.edit_outlined, color: kGrey),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    dropdownColor: kCard,
                    items: _types.map((t) => DropdownMenuItem(
                      value: t.$1,
                      child: Text(t.$2, style: const TextStyle(color: kText)),
                    )).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _OutlineBtn(
                label: _time == null ? '🕐  Time Chuno' : '🕐  ${_time!.format(context)}',
                onTap: _pickTime,
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _add, child: const Text('ADD REMINDER'))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'Your Reminders (${widget.reminders.length})', icon: Icons.notifications),
        if (widget.reminders.isEmpty)
          _EmptyState(msg: 'Koi reminder nahi hai')
        else
          ...widget.reminders.asMap().entries.map((e) => _ReminderCard(
            r: e.value,
            onToggle: (v) { setState(() => e.value.active = v); widget.onChanged(); },
            onDelete: () => _delete(e.key),
          )),
      ],
    );
  }

  @override
  void dispose() { _label.dispose(); super.dispose(); }
}

class _ReminderCard extends StatelessWidget {
  final ReminderModel r;
  final Function(bool) onToggle;
  final VoidCallback onDelete;

  const _ReminderCard({required this.r, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => _JCard(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: r.active ? kCyan : kBorder),
          ),
          child: Icon(r.icon, color: r.active ? kCyan : kGrey, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.label, style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 15)),
              Text('${r.type.toUpperCase()}  •  ${r.timeStr}', style: const TextStyle(color: kCyan, fontSize: 12)),
            ],
          ),
        ),
        Switch(activeColor: kCyan, value: r.active, onChanged: onToggle),
        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: onDelete),
      ],
    ),
  );
}

// ══════════════════════════════════════════
//  HABIT PAGE
// ══════════════════════════════════════════
class HabitPage extends StatefulWidget {
  final List<HabitModel> habits;
  final String motivation;
  final VoidCallback onChanged;
  final Function(String) onMotivationChanged;

  const HabitPage({
    super.key,
    required this.habits,
    required this.motivation,
    required this.onChanged,
    required this.onMotivationChanged,
  });

  @override
  State<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends State<HabitPage> {
  final _habitCtrl = TextEditingController();
  final _motivCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _motivCtrl.text = widget.motivation;
  }

  void _addHabit() {
    final name = _habitCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      widget.habits.add(HabitModel(id: '${DateTime.now().millisecondsSinceEpoch}', name: name));
      _habitCtrl.clear();
    });
    widget.onChanged();
  }

  void _deleteHabit(int i) {
    setState(() => widget.habits.removeAt(i));
    widget.onChanged();
  }

  void _saveMotivation() {
    final words = _motivCtrl.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words > 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Max 20 words allowed!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    widget.onMotivationChanged(_motivCtrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Motivation save ho gaya!'),
      backgroundColor: kCyanDark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  int get _done => widget.habits.where((h) => h.done).length;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Header
        _JCard(
          child: Column(
            children: [
              Text(today, style: const TextStyle(color: kGrey, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                '$_done / ${widget.habits.length} Complete',
                style: const TextStyle(color: kCyan, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: widget.habits.isEmpty ? 0 : _done / widget.habits.length,
                  backgroundColor: kBorder,
                  color: kCyan,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Add habit
        _JCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _habitCtrl,
                  style: const TextStyle(color: kText),
                  decoration: const InputDecoration(
                    hintText: 'Nayi activity (e.g. Morning Run)',
                    prefixIcon: Icon(Icons.add_task, color: kGrey),
                  ),
                  onSubmitted: (_) => _addHabit(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addHabit,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kCyan,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: kBg, size: 22),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Habit list
        _SectionHeader(title: "Aaj Ki Activities", icon: Icons.check_circle_outline),
        if (widget.habits.isEmpty)
          _EmptyState(msg: 'Koi activity nahi — add karo!')
        else
          ...widget.habits.asMap().entries.map((e) => _JCard(
            child: Row(
              children: [
                Checkbox(
                  value: e.value.done,
                  activeColor: kCyan,
                  checkColor: kBg,
                  side: const BorderSide(color: kGrey),
                  onChanged: (v) {
                    setState(() => e.value.done = v ?? false);
                    widget.onChanged();
                  },
                ),
                Expanded(
                  child: Text(
                    e.value.name,
                    style: TextStyle(
                      color: e.value.done ? kGrey : kText,
                      fontSize: 15,
                      decoration: e.value.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteHabit(e.key),
                ),
              ],
            ),
          )),
        const SizedBox(height: 16),
        // Motivation
        _SectionHeader(title: 'Aaj Ka Motivation', icon: Icons.lightbulb_outline),
        _JCard(
          child: Column(
            children: [
              TextField(
                controller: _motivCtrl,
                maxLines: 3,
                style: const TextStyle(color: kText),
                decoration: const InputDecoration(
                  hintText: 'Kuch inspiring likho... (max 20 words)',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.format_quote, color: kGrey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveMotivation, child: const Text('SAVE'))),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() { _habitCtrl.dispose(); _motivCtrl.dispose(); super.dispose(); }
}

// ══════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════
class _JCard extends StatelessWidget {
  final Widget child;
  const _JCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(
      children: [
        Icon(icon, color: kCyan, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
      ],
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: kCyan,
        side: const BorderSide(color: kCyan),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: kGrey, size: 40),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(color: kGrey, fontSize: 14)),
        ],
      ),
    ),
  );
}
