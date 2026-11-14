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
  int _selectedGrowthStageIndex = -1;

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

                // Crop Growth Stage Timeline Diagram
                _buildCropGrowthStagesDiagram(),

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

  Widget _buildCropGrowthStagesDiagram() {
    final stages = [
      {
        'title': 'Sowing & Germination'.tr(context),
        'range': 'Days 0 - 15',
        'min': 0,
        'max': 15,
        'icon': Icons.grass,
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFECFDF5),
        'desc': 'Land preparation, basal NPK fertilizer, and uniform seed sowing with light moisture.'.tr(context),
      },
      {
        'title': 'Vegetative Tillering'.tr(context),
        'range': 'Days 16 - 45',
        'min': 16,
        'max': 45,
        'icon': Icons.spa,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFEFF6FF),
        'desc': 'Active leaf growth, root establishment, first weeding, and secondary nitrogen top-dressing.'.tr(context),
      },
      {
        'title': 'Flowering & Budding'.tr(context),
        'range': 'Days 46 - 75',
        'min': 46,
        'max': 75,
        'icon': Icons.local_florist,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFFFBEB),
        'desc': 'Pollination & flowering. Keep consistent soil moisture; strictly prevent water stress.'.tr(context),
      },
      {
        'title': 'Ripening & Grain Fill'.tr(context),
        'range': 'Days 76 - 105',
        'min': 76,
        'max': 105,
        'icon': Icons.wb_sunny,
        'color': const Color(0xFFEA580C),
        'bg': const Color(0xFFFFF7ED),
        'desc': 'Kernel/fruit expansion. Monitor pest infestations; taper off heavy irrigation.'.tr(context),
      },
      {
        'title': 'Harvest & Storage'.tr(context),
        'range': 'Days 106 - 120+',
        'min': 106,
        'max': 999,
        'icon': Icons.agriculture,
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFF0FDF4),
        'desc': 'Harvest during clear dry weather. Dry produce to optimal moisture for storage.'.tr(context),
      },
    ];

    final now = DateTime.now();
    final start = _batchStart ?? now.subtract(const Duration(days: 2));
    final end = _batchEnd ?? now.add(const Duration(days: 28));
    final totalDays = end.difference(start).inDays;
    final elapsedDays = now.difference(start).inDays.clamp(0, totalDays > 0 ? totalDays : 1);

    int autoActiveIndex = 0;
    for (int i = 0; i < stages.length; i++) {
      final minD = stages[i]['min'] as int;
      final maxD = stages[i]['max'] as int;
      if (elapsedDays >= minD && elapsedDays <= maxD) {
        autoActiveIndex = i;
        break;
      }
      if (i == stages.length - 1 && elapsedDays > maxD) {
        autoActiveIndex = i;
      }
    }

    final inspectedIndex = _selectedGrowthStageIndex >= 0 ? _selectedGrowthStageIndex : autoActiveIndex;
    final inspectedStage = stages[inspectedIndex];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timeline, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crop Growth Stage Timeline'.tr(context),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$_batchCropName • ${"Day".tr(context)} $elapsedDays ${"of".tr(context)} $totalDays',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Text(
                    '${"Stage".tr(context)} ${autoActiveIndex + 1} / ${stages.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Horizontal Stepper Milestone Timeline Track Diagram
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(stages.length, (idx) {
                  final s = stages[idx];
                  final isPassed = idx < autoActiveIndex;
                  final isCurrent = idx == autoActiveIndex;
                  final isInspected = idx == inspectedIndex;
                  final nodeColor = isCurrent ? (s['color'] as Color) : (isPassed ? const Color(0xFF10B981) : Colors.grey.shade400);

                  return Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedGrowthStageIndex = idx;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isInspected ? (s['bg'] as Color) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isInspected ? (s['color'] as Color) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent ? nodeColor : (isPassed ? const Color(0xFFD1FAE5) : Colors.grey.shade100),
                                  border: Border.all(
                                    color: nodeColor,
                                    width: isCurrent ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: nodeColor.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  isPassed ? Icons.check : (s['icon'] as IconData),
                                  size: 18,
                                  color: isCurrent ? Colors.white : (isPassed ? const Color(0xFF059669) : Colors.grey.shade500),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s['title'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isCurrent || isInspected ? FontWeight.w800 : FontWeight.w600,
                                  color: isCurrent || isInspected ? (s['color'] as Color) : AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['range'] as String,
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: nodeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ACTIVE'.tr(context),
                                    style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                      if (idx < stages.length - 1)
                        Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: idx < autoActiveIndex ? const Color(0xFF10B981) : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 14),

            // Active / Inspected Stage Detail Callout Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: inspectedStage['bg'] as Color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (inspectedStage['color'] as Color).withValues(alpha: 0.3), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(inspectedStage['icon'] as IconData, color: inspectedStage['color'] as Color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${inspectedStage['title']} (${inspectedStage['range']})',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: inspectedStage['color'] as Color),
                            ),
                            if (inspectedIndex == autoActiveIndex) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: inspectedStage['color'] as Color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Current Stage'.tr(context),
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inspectedStage['desc'] as String,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMain, height: 1.35, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
                      const SizedBox(width: 8),
                      Text('💧 ${"Recurring Irrigation Schedule".tr(context)}'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle, size: 18),
                      const SizedBox(width: 8),
                      Text('🌱 ${"Single Day Custom Task".tr(context)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 350,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Recurring Irrigation Generator
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  physics: const BouncingScrollPhysics(),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 620;
                          return isNarrow
                              ? Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final p = await showDatePicker(
                                                context: context,
                                                initialDate: _irrigationStart,
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2035),
                                              );
                                              if (p != null) setState(() => _irrigationStart = p);
                                            },
                                            child: Container(
                                              height: 50,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('Start Date'.tr(context), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                        Text(DateFormat('MMM d, yyyy').format(_irrigationStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2563EB)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final p = await showDatePicker(
                                                context: context,
                                                initialDate: _irrigationEnd,
                                                firstDate: _irrigationStart,
                                                lastDate: DateTime(2035),
                                              );
                                              if (p != null) setState(() => _irrigationEnd = p);
                                            },
                                            child: Container(
                                              height: 50,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('End Date'.tr(context), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                        Text(DateFormat('MMM d, yyyy').format(_irrigationEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(Icons.calendar_month, size: 16, color: Color(0xFF2563EB)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 50,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
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
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final p = await showDatePicker(
                                            context: context,
                                            initialDate: _irrigationStart,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (p != null) setState(() => _irrigationStart = p);
                                        },
                                        child: Container(
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Start Date'.tr(context), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                    Text(DateFormat('MMM d, yyyy').format(_irrigationStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2563EB)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final p = await showDatePicker(
                                            context: context,
                                            initialDate: _irrigationEnd,
                                            firstDate: _irrigationStart,
                                            lastDate: DateTime(2035),
                                          );
                                          if (p != null) setState(() => _irrigationEnd = p);
                                        },
                                        child: Container(
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('End Date'.tr(context), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                    Text(DateFormat('MMM d, yyyy').format(_irrigationEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.calendar_month, size: 16, color: Color(0xFF2563EB)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                );
                        },
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
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Add Task for Selected Date:'.tr(context),
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textMain),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '📅 ${DateFormat('MMM d, yyyy').format(_selectedDay)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12.5),
                            ),
                          ),
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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

  Widget _buildBatchTimelineBar() {
    if (_batchStart == null || _batchEnd == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final totalDays = _batchEnd!.difference(_batchStart!).inDays;
    final elapsedDays = now.difference(_batchStart!).inDays.clamp(0, totalDays > 0 ? totalDays : 1);
    final progress = totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;
    final percentStr = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$_batchCropName Cycle',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF065F46)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${"Day".tr(context)} $elapsedDays ${"of".tr(context)} $totalDays ($percentStr%)',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.green.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🌱 Start: ${DateFormat('MMM d, yyyy').format(_batchStart!)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600),
              ),
              Text(
                '🌾 End: ${DateFormat('MMM d, yyyy').format(_batchEnd!)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600),
              ),
            ],
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
            // Header with Crop Batch Plan Badge
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final badgeWidget = InkWell(
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
                );

                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule & Dates'.tr(context),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textMain),
                          ),
                          const SizedBox(height: 8),
                          badgeWidget,
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Schedule & Dates'.tr(context),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textMain),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          badgeWidget,
                        ],
                      );
              },
            ),

            // Embedded Crop Batch Timeline Progress Bar
            _buildBatchTimelineBar(),

            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
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
                            maxLines: 1,
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
                    itemBuilder: (context, idx) => _buildTimelineTaskItem(
                      event: irrigationEvents[idx],
                      color: const Color(0xFF2563EB),
                      bg: const Color(0xFFEFF6FF),
                      isFirst: idx == 0,
                      isLast: idx == irrigationEvents.length - 1,
                    ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Fertilizers, Weeding, Pest Control & Harvesting'.tr(context),
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      return _buildTimelineTaskItem(
                        event: e,
                        color: cat['color'] as Color,
                        bg: cat['bg'] as Color,
                        isFirst: idx == 0,
                        isLast: idx == otherEvents.length - 1,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTaskItem({
    required CropEvent event,
    required Color color,
    required Color bg,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical Timeline Track Line & Node
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top connector
                Container(
                  width: 2.5,
                  height: 14,
                  color: isFirst
                      ? Colors.transparent
                      : (event.isCompleted ? Colors.grey.shade300 : color.withValues(alpha: 0.4)),
                ),
                // Circular timeline node dot
                InkWell(
                  onTap: () => _toggleEventCompletion(event.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: event.isCompleted ? AppColors.primary : Colors.white,
                      border: Border.all(
                        color: event.isCompleted ? AppColors.primary : color,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (event.isCompleted ? AppColors.primary : color).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: event.isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Icon(
                              event.isIrrigationTask ? Icons.water_drop : Icons.eco,
                              size: 12,
                              color: color,
                            ),
                    ),
                  ),
                ),
                // Bottom connector
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: isLast
                        ? Colors.transparent
                        : (event.isCompleted ? Colors.grey.shade300 : color.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Event Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: event.isCompleted ? Colors.grey.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: event.isCompleted ? Colors.grey.shade300 : color.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: event.isCompleted
                    ? null
                    : [
                        BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: event.isCompleted ? Colors.grey.shade500 : const Color(0xFF0F172A),
                            decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
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
                            if (event.isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '• Done'.tr(context),
                                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    tooltip: 'Delete Task'.tr(context),
                    onPressed: () => _deleteEvent(event.id),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
