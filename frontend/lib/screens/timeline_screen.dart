import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/scheduler_service.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';

class CropEvent {
  final String id;
  final String date;
  final String title;
  final String category;
  final bool isCompleted;

  CropEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    this.isCompleted = false,
  });

  bool get isIrrigationTask {
    final lower = '$category $title'.toLowerCase();
    return category.toLowerCase() == 'irrigation' ||
        lower.contains('water') ||
        lower.contains('irriga') ||
        lower.contains('drip') ||
        lower.contains('moisture') ||
        lower.contains('pump');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'category': category,
        'isCompleted': isCompleted,
      };

  factory CropEvent.fromJson(Map<String, dynamic> json) => CropEvent(
        id: json['id'] as String,
        date: json['date'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  static Future<Map<String, List<CropEvent>>> getTodayTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('crop_events');
    List<CropEvent> allEvents = [];
    if (stored != null) {
      if (stored.contains('Water Tomato crop')) {
        await prefs.remove('crop_events');
        return {'irrigation': [], 'other': []};
      }
      try {
        final decoded = jsonDecode(stored) as List<dynamic>;
        allEvents = decoded.map((item) => CropEvent.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error loading crop events: $e');
      }
    }
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayEvents = allEvents.where((e) => e.date == todayStr).toList();
    
    final irrigation = todayEvents.where((e) => e.isIrrigationTask).toList();
    final other = todayEvents.where((e) => !e.isIrrigationTask).toList();
    return {'irrigation': irrigation, 'other': other};
  }

  static Future<void> toggleTaskCompletion(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('crop_events');
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored) as List<dynamic>;
        final list = decoded.map((item) => CropEvent.fromJson(item as Map<String, dynamic>)).toList();
        final idx = list.indexWhere((e) => e.id == id);
        if (idx != -1) {
          final old = list[idx];
          list[idx] = CropEvent(
            id: old.id,
            date: old.date,
            title: old.title,
            category: old.category,
            isCompleted: !old.isCompleted,
          );
          await prefs.setString('crop_events', jsonEncode(list.map((e) => e.toJson()).toList()));
          SchedulerService.schedulePreciseNotifications();
        }
      } catch (e) {
        debugPrint('Error toggling event completion: $e');
      }
    }
  }

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Single Day Custom Task Controllers
  final _customTaskController = TextEditingController();
  String _selectedCategory = 'General Care';

  // Recurring Irrigation Generator Variables
  final _irrigationTitleController = TextEditingController(text: 'Field Drip Irrigation & Moisture Cycle');
  DateTime _irrigationStart = DateTime.now();
  DateTime _irrigationEnd = DateTime.now().add(const Duration(days: 20));
  int _intervalDays = 2; // e.g. every 2 days once

  // Crop Batch Plan Variables
  String _batchCropName = 'Kharif Season Batch';
  DateTime? _batchStart;
  DateTime? _batchEnd;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  List<CropEvent> _events = [];

  final List<Map<String, dynamic>> _categories = [
    {'label': 'General Care', 'color': const Color(0xFF059669), 'bg': const Color(0xFFECFDF5), 'icon': Icons.spa},
    {'label': 'Fertilizing', 'color': const Color(0xFF10B981), 'bg': const Color(0xFFD1FAE5), 'icon': Icons.science},
    {'label': 'Pest Control', 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEF2F2), 'icon': Icons.bug_report},
    {'label': 'Harvesting', 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFFFBEB), 'icon': Icons.content_cut},
    {'label': 'Irrigation', 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFEFF6FF), 'icon': Icons.water_drop},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEventsAndBatchPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customTaskController.dispose();
    _irrigationTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsAndBatchPlan() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Crop Batch Plan
    final bName = prefs.getString('batch_crop_name');
    final bStartStr = prefs.getString('batch_start_date');
    final bEndStr = prefs.getString('batch_end_date');
    if (bName != null) _batchCropName = bName;
    if (bStartStr != null) _batchStart = DateTime.tryParse(bStartStr);
    if (bEndStr != null) _batchEnd = DateTime.tryParse(bEndStr);
    
    // Set default initial batch if none exists so user immediately sees calendar range demo
    if (_batchStart == null || _batchEnd == null) {
      _batchStart = DateTime.now().subtract(const Duration(days: 2));
      _batchEnd = DateTime.now().add(const Duration(days: 28));
    }

    // Load Events
    final stored = prefs.getString('crop_events');
    if (stored != null) {
      if (stored.contains('Water Tomato crop')) {
        await prefs.remove('crop_events');
        if (mounted) setState(() => _events = []);
        return;
      }
      try {
        final decoded = jsonDecode(stored) as List<dynamic>;
        if (mounted) {
          setState(() {
            _events = decoded.map((item) => CropEvent.fromJson(item as Map<String, dynamic>)).toList();
          });
        }
      } catch (e) {
        debugPrint('Failed to decode stored crop events: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _events = [];
        });
      }
    }
  }

  Future<void> _saveEvents(List<CropEvent> newEvents) async {
    setState(() {
      _events = newEvents;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crop_events', jsonEncode(newEvents.map((e) => e.toJson()).toList()));
    SchedulerService.schedulePreciseNotifications();
  }

  Future<void> _saveBatchPlan(String name, DateTime start, DateTime end) async {
    setState(() {
      _batchCropName = name;
      _batchStart = start;
      _batchEnd = end;
      _focusedDay = start;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('batch_crop_name', name);
    await prefs.setString('batch_start_date', start.toIso8601String());
    await prefs.setString('batch_end_date', end.toIso8601String());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌾 ${'Crop Batch Plan set:'.tr(context)} ${DateFormat('MMM d').format(start)} ➔ ${DateFormat('MMM d').format(end)}!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _generateIrrigationSchedule() {
    final title = _irrigationTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ ${'Please enter an irrigation task title.'.tr(context)}')),
      );
      return;
    }
    if (_irrigationEnd.isBefore(_irrigationStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ ${'End date must be after Start date.'.tr(context)}')),
      );
      return;
    }

    final List<CropEvent> generated = [];
    DateTime curr = _irrigationStart;
    int count = 0;

    while (!curr.isAfter(_irrigationEnd)) {
      final dateStr = DateFormat('yyyy-MM-dd').format(curr);
      generated.add(CropEvent(
        id: 'irrig-${DateTime.now().millisecondsSinceEpoch}-$count',
        date: dateStr,
        title: title,
        category: 'Irrigation',
        isCompleted: false,
      ));
      curr = curr.add(Duration(days: _intervalDays));
      count++;
    }

    _saveEvents([..._events, ...generated]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💧 ${'Generated'.tr(context)} $count ${'recurring irrigation tasks'.tr(context)} (${'Every'.tr(context)} $_intervalDays ${'days'.tr(context)})!'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addCustomTask() {
    final title = _customTaskController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ ${'Please enter a task description before saving.'.tr(context)}')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final newEvent = CropEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: dateStr,
      title: title,
      category: _selectedCategory,
      isCompleted: false,
    );

    _saveEvents([..._events, newEvent]);
    _customTaskController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${'Task added to schedule for'.tr(context)} ${DateFormat('MMM d').format(_selectedDay)}!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteEvent(String id) {
    final updated = _events.where((e) => e.id != id).toList();
    _saveEvents(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🗑️ ${'Task removed from timeline.'.tr(context)}'), duration: const Duration(seconds: 2)),
    );
  }

  void _toggleEventCompletion(String id) {
    final updated = _events.map((e) {
      if (e.id == id) {
        return CropEvent(
          id: e.id,
          date: e.date,
          title: e.title,
          category: e.category,
          isCompleted: !e.isCompleted,
        );
      }
      return e;
    }).toList();
    _saveEvents(updated);
  }

  Color _getCategoryColor(String category) {
    final found = _categories.firstWhere((c) => c['label'] == category, orElse: () => _categories[0]);
    return found['color'] as Color;
  }

  void _showCropBatchDialog() {
    final nameController = TextEditingController(text: _batchCropName);
    DateTime tempStart = _batchStart ?? DateTime.now();
    DateTime tempEnd = _batchEnd ?? DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.grass, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Set Crop Batch Plan'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Define your crop cycle duration. The entire start-to-end date range will be highlighted directly across the calendar.'.tr(context),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Crop Batch Name (e.g. Kharif Cotton)'.tr(context),
                  prefixIcon: const Icon(Icons.spa_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempStart,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setStateDialog(() => tempStart = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start Date'.tr(context), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            Text(DateFormat('MMM d, yyyy').format(tempStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempEnd,
                          firstDate: tempStart,
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setStateDialog(() => tempEnd = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End Date'.tr(context), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 4),
                            Text(DateFormat('MMM d, yyyy').format(tempEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'.tr(context), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _saveBatchPlan(nameController.text.trim().isEmpty ? 'Crop Batch' : nameController.text.trim(), tempStart, tempEnd);
                Navigator.pop(ctx);
              },
              child: Text('Save & Mark on Calendar'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final dayEvents = _events.where((e) => e.date == selectedDateStr).toList();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Home'.tr(context),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
            }
          },
        ),
        title: Text('Irrigation & Farm Timeline'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header Gradient Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month, color: Colors.white, size: 32),
                          SizedBox(width: 12),
                          Icon(Icons.water_drop, color: Color(0xFF7DD3FC), size: 28),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Irrigation Cycles & Crop Batch Planning'.tr(context),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Automatically generate recurring irrigation schedules (e.g., every 2 days once) and mark your overall crop batch season directly on the calendar.'.tr(context),
                        style: const TextStyle(fontSize: 13.5, color: Colors.white70, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Task & Irrigation Scheduler Card
                _buildSchedulerCard(),

                const SizedBox(height: 16),

                // Calendar + Agenda split view
                isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 13, child: _buildCalendarCard()),
                          const SizedBox(width: 16),
                          Expanded(flex: 11, child: _buildSeparatedAgendaCard(dayEvents)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCalendarCard(),
                          const SizedBox(height: 16),
                          _buildSeparatedAgendaCard(dayEvents),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchedulerCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop, size: 18),
                      const SizedBox(width: 6),
                      Flexible(child: Text('💧 ${"Recurring Irrigation Schedule".tr(context)}', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle, size: 18),
                      const SizedBox(width: 6),
                      Flexible(child: Text('🌱 ${"Single Day Custom Task".tr(context)}', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 310,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Recurring Irrigation Generator
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Automatic Irrigation Dates (Start ➔ End)'.tr(context),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _irrigationTitleController,
                        decoration: InputDecoration(
                          labelText: 'Irrigation Activity Name'.tr(context),
                          prefixIcon: const Icon(Icons.water, color: Color(0xFF2563EB)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width < 600
                                ? (MediaQuery.of(context).size.width - 72) / 2
                                : 200,
                            child: InkWell(
                              onTap: () async {
                                final p = await showDatePicker(context: context, initialDate: _irrigationStart, firstDate: DateTime(2020), lastDate: DateTime(2035));
                                if (p != null) setState(() => _irrigationStart = p);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Start Date'.tr(context), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                          Text(DateFormat('MMM d, yyyy').format(_irrigationStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2563EB)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width < 600
                                ? (MediaQuery.of(context).size.width - 72) / 2
                                : 200,
                            child: InkWell(
                              onTap: () async {
                                final p = await showDatePicker(context: context, initialDate: _irrigationEnd, firstDate: _irrigationStart, lastDate: DateTime(2035));
                                if (p != null) setState(() => _irrigationEnd = p);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('End Date'.tr(context), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                          Text(DateFormat('MMM d, yyyy').format(_irrigationEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month, size: 16, color: Color(0xFF2563EB)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width < 600
                                ? MediaQuery.of(context).size.width - 72
                                : 200,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _intervalDays,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text('Every Day (1d)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: 2, child: Text('2 Days Once (2d)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                                    DropdownMenuItem(value: 3, child: Text('3 Days Once (3d)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: 4, child: Text('4 Days Once (4d)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: 7, child: Text('Weekly Once (7d)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _intervalDays = v);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generateIrrigationSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.water_drop, size: 18),
                          label: Text('Generate & Mark Irrigation Dates on Calendar'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Single Day Custom Task
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Add Task for Selected Date:'.tr(context), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textMain), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text('📅 ${DateFormat('MMM d, yyyy').format(_selectedDay)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customTaskController,
                        decoration: InputDecoration(
                          labelText: 'Task description (e.g., Basal compost application, Neem spray)'.tr(context),
                          prefixIcon: const Icon(Icons.edit_note, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _addCustomTask(),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _categories.map((c) {
                          final isSel = _selectedCategory == c['label'];
                          return ChoiceChip(
                            label: Text(c['label'] as String),
                            selected: isSel,
                            avatar: Icon(c['icon'] as IconData, size: 14, color: c['color'] as Color),
                            backgroundColor: Colors.white,
                            selectedColor: c['bg'] as Color,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isSel ? c['color'] as Color : AppColors.textMuted,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isSel ? (c['color'] as Color) : Colors.grey.shade300),
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedCategory = c['label'] as String);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addCustomTask,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text('Add Task to Schedule'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Crop Batch Plan Badge on TOP RIGHT
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Schedule & Dates'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textMain),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: InkWell(
                    onTap: _showCropBatchDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.grass, size: 15, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _batchStart != null && _batchEnd != null
                                  ? '$_batchCropName: ${DateFormat('MMM d').format(_batchStart!)} - ${DateFormat('MMM d').format(_batchEnd!)}'
                                  : 'Set Crop Batch Plan (Start - End)'.tr(context),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 13, color: Color(0xFF059669)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TableCalendar(
              firstDay: DateTime.utc(2025, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              rangeStartDay: _batchStart,
              rangeEndDay: _batchEnd,
              rangeSelectionMode: RangeSelectionMode.enforced,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) {
                final dStr = DateFormat('yyyy-MM-dd').format(day);
                return _events.where((e) => e.date == dStr).toList();
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), shape: BoxShape.circle),
                rangeHighlightColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                rangeStartDecoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                rangeEndDecoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                withinRangeTextStyle: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w800),
                defaultTextStyle: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
                outsideTextStyle: const TextStyle(color: Colors.grey),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  final cropEvents = events.cast<CropEvent>();
                  final dotColors = cropEvents.map((e) => _getCategoryColor(e.category)).toSet().toList();

                  return Positioned(
                    bottom: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: dotColors
                          .take(3)
                          .map((color) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Crop Batch Plan Season'.tr(context), style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Irrigation Task'.tr(context), style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Other Farm Care'.tr(context), style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparatedAgendaCard(List<CropEvent> dayEvents) {
    final irrigationEvents = dayEvents.where((e) => e.isIrrigationTask).toList();
    final otherEvents = dayEvents.where((e) => !e.isIrrigationTask).toList();

    return Column(
      children: [
        // Section 1: Irrigation Tasks Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.water_drop, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'Irrigation & Water Tasks'.tr(context)} (${irrigationEvents.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain, fontSize: 15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'For ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (irrigationEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.water_drop_outlined, color: Colors.grey, size: 28),
                          const SizedBox(height: 6),
                          Text('No irrigation tasks scheduled for this date.'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: irrigationEvents.length,
                    itemBuilder: (context, idx) => _buildTaskListItem(irrigationEvents[idx], const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Section 2: All Other Crop Tasks Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.grass, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'All Other Crop Tasks'.tr(context)} (${otherEvents.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain, fontSize: 15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Fertilizers, Weeding, Pest Control & Harvesting'.tr(context),
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (otherEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.grey, size: 28),
                          const SizedBox(height: 6),
                          Text('No other agricultural tasks scheduled for this date.'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: otherEvents.length,
                    itemBuilder: (context, idx) {
                      final e = otherEvents[idx];
                      final cat = _categories.firstWhere((c) => c['label'] == e.category, orElse: () => _categories[0]);
                      return _buildTaskListItem(e, cat['color'] as Color, cat['bg'] as Color);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskListItem(CropEvent event, Color color, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: event.isCompleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: event.isCompleted ? Colors.grey.shade300 : color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: event.isCompleted ? null : [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: InkWell(
          onTap: () => _toggleEventCompletion(event.id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: event.isCompleted ? AppColors.primary : Colors.transparent,
              border: Border.all(color: event.isCompleted ? AppColors.primary : Colors.grey.shade400, width: 2),
            ),
            child: Icon(
              Icons.check,
              size: 20,
              color: event.isCompleted ? Colors.white : Colors.transparent,
            ),
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: event.isCompleted ? Colors.grey : const Color(0xFF0F172A),
            decoration: event.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      event.isIrrigationTask ? Icons.water_drop : Icons.eco,
                      size: 11,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.category,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                    ),
                  ],
                ),
              ),
              if (event.isCompleted) ...[
                const SizedBox(width: 8),
                Text('• Completed'.tr(context), style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
          tooltip: 'Delete Task',
          onPressed: () => _deleteEvent(event.id),
        ),
      ),
    );
  }
}
