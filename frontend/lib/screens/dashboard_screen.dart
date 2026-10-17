import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/location_provider.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

import 'weather_screen.dart';
import 'timeline_screen.dart';
import 'finance_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _currentTime = DateTime.now();
  late Timer _clockTimer;
  bool _is24Hour = false;

  Map<String, dynamic>? _weatherData;
  bool _loadingWeather = true;

  Map<String, dynamic>? _financeSummary;
  bool _loadingFinance = true;
  late Timer _financeTimer;

  final List<Map<String, dynamic>> _modules = [
    {'name': 'Chatbot', 'title': 'AI Assistant', 'icon': Icons.chat_bubble_outline, 'color': Color(0xFF10B981), 'bg': Color(0xFFECFDF5)},
    {'name': 'CropRecs', 'title': 'Crop Advisory', 'icon': Icons.spa_outlined, 'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5)},
    {'name': 'Disease', 'title': 'Disease Scan', 'icon': Icons.qr_code_scanner_outlined, 'color': Color(0xFFEF4444), 'bg': Color(0xFFFEF2F2)},
    {'name': 'Weather', 'title': 'Weather', 'icon': Icons.wb_sunny_outlined, 'color': Color(0xFFF59E0B), 'bg': Color(0xFFFFFBEB)},
    {'name': 'Market', 'title': 'Market', 'icon': Icons.bar_chart_outlined, 'color': Color(0xFF3B82F6), 'bg': Color(0xFFEFF6FF)},
    {'name': 'Schemes', 'title': 'Schemes', 'icon': Icons.description_outlined, 'color': Color(0xFF8B5CF6), 'bg': Color(0xFFF5F3FF)},
    {'name': 'Tracker', 'title': 'Timeline', 'icon': Icons.calendar_month_outlined, 'color': Color(0xFFEC4899), 'bg': Color(0xFFFDF2F8)},
    {'name': 'Finance', 'title': 'Finance', 'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF059669), 'bg': Color(0xFFECFDF5)},
    {'name': 'Profile', 'title': 'Profile', 'icon': Icons.person_outline, 'color': Color(0xFF64748B), 'bg': Color(0xFFF8FAFC)},
  ];

  String _farmerName = 'Farmer';
  Map<String, List<CropEvent>> _todayTasks = {'irrigation': [], 'other': []};
  bool _loadingTasks = true;

  @override
  void initState() {
    super.initState();
    _loadTimeFormat();
    _loadFarmerName();
    _startClock();
    _fetchFinance();
    _fetchTodayTasks();
    _financeTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchFinance();
      _loadFarmerName();
      _fetchTodayTasks();
      if (_weatherData == null || (_lastWeatherFetch != null && DateTime.now().difference(_lastWeatherFetch!).inMinutes >= 5)) {
        _fetchWeather();
      }
    });
  }

  Future<void> _loadFarmerName() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('profile_name');
    final firstName = (fullName == null || fullName.isEmpty || fullName == 'Farmer Profile' || fullName == 'Ramesh Kumar')
        ? 'Farmer'
        : fullName.split(' ').first;
    if (mounted && _farmerName != firstName) {
      setState(() {
        _farmerName = firstName;
      });
    }
  }

  DateTime? _lastWeatherFetch;
  double? _lastLat;
  double? _lastLon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFarmerName();
    _fetchTodayTasks();
    final userLoc = Provider.of<LocationProvider>(context).userLocation;
    if (userLoc != null) {
      if (userLoc.lat != _lastLat || userLoc.lon != _lastLon || _weatherData == null || (_lastWeatherFetch != null && DateTime.now().difference(_lastWeatherFetch!).inMinutes >= 5)) {
        _lastLat = userLoc.lat;
        _lastLon = userLoc.lon;
        _lastWeatherFetch = DateTime.now();
        _fetchWeather();
      }
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _financeTimer.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _is24Hour = prefs.getBool('timeFormat24h') ?? false;
      });
    }
  }

  Future<void> toggleTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _is24Hour = !_is24Hour;
    });
    await prefs.setBool('timeFormat24h', _is24Hour);
  }

  Future<void> _fetchFinance() async {
    try {
      final summary = await FinanceScreen.getFinanceSummary();
      if (mounted) {
        setState(() {
          _financeSummary = summary;
          _loadingFinance = false;
        });
      }
    } catch (e) {
      debugPrint('Finance summary fetch failed: $e');
      if (mounted) {
        setState(() {
          _loadingFinance = false;
        });
      }
    }
  }

  Future<void> _fetchTodayTasks() async {
    try {
      final tasks = await TimelineScreen.getTodayTasks();
      if (mounted) {
        setState(() {
          _todayTasks = tasks;
          _loadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint('Today tasks fetch failed: $e');
      if (mounted) {
        setState(() {
          _loadingTasks = false;
        });
      }
    }
  }

  Future<void> _fetchWeather() async {
    final locProvider = Provider.of<LocationProvider>(context, listen: false);
    final userLoc = locProvider.userLocation;
    if (userLoc == null) {
      setState(() {
        _loadingWeather = false;
      });
      return;
    }

    try {
      setState(() {
        _loadingWeather = true;
      });
      final data = await WeatherScreen.fetchWeatherData(userLoc.lat, userLoc.lon);
      if (mounted) {
        setState(() {
          _weatherData = data;
        });
      }
    } catch (e) {
      debugPrint('Dashboard weather fetch failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingWeather = false;
        });
      }
    }
  }

  String? _getExpectedRainTime() {
    try {
      if (_weatherData == null || _weatherData!['hourly'] == null || _weatherData!['daily'] == null) return null;
      final hourly = _weatherData!['hourly'] as Map<String, dynamic>;
      final times = hourly['time'] as List<dynamic>? ?? [];
      final precip = hourly['precipitation'] as List<dynamic>? ?? [];
      if (times.isEmpty || precip.isEmpty) return null;

      final daily = _weatherData!['daily'] as Map<String, dynamic>;
      final dailyTimes = daily['time'] as List<dynamic>? ?? [];
      if (dailyTimes.isEmpty) return null;
      final todayStr = dailyTimes[0] as String; // e.g. "2026-07-06"
      final now = DateTime.now();

      for (int i = 0; i < times.length && i < precip.length; i++) {
        final time = times[i] as String;
        if (time.startsWith(todayStr)) {
          final p = (precip[i] as num?)?.toDouble() ?? 0.0;
          if (p > 0) {
            final parsedTime = DateTime.tryParse(time);
            if (parsedTime != null && (parsedTime.isAfter(now) || parsedTime.hour == now.hour)) {
              return DateFormat('h:mm a').format(parsedTime);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing dashboard rain time: $e');
    }
    return null;
  }

  String getGreeting() {
    final hour = _currentTime.hour;
    if (hour < 12) return 'Good Morning'.tr(context);
    if (hour < 17) return 'Good Afternoon'.tr(context);
    return 'Good Evening'.tr(context);
  }

  String formatTime() {
    final pattern = _is24Hour ? 'HH:mm:ss' : 'hh:mm:ss a';
    return DateFormat(pattern).format(_currentTime);
  }

  String formatDate() {
    return DateFormat('EEEE, MMM d, yyyy').format(_currentTime);
  }

  IconData getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if ([1, 2, 3].contains(code)) return Icons.wb_cloudy_outlined;
    if ([45, 48].contains(code)) return Icons.blur_on_outlined;
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return Icons.umbrella_outlined;
    if ([71, 73, 75, 77].contains(code)) return Icons.ac_unit_outlined;
    if ([95, 96, 99].contains(code)) return Icons.thunderstorm_outlined;
    return Icons.cloud_outlined;
  }

  Color getWeatherIconColor(int code) {
    if (code == 0 || [1, 2, 3].contains(code)) return AppColors.warning;
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return AppColors.secondary;
    if ([95, 96, 99].contains(code)) return AppColors.error;
    return AppColors.textMuted;
  }

  String getWeatherLabel(int code) {
    if (code == 0) return 'Clear Sky'.tr(context);
    if ([1, 2, 3].contains(code)) return 'Partly Cloudy'.tr(context);
    if ([45, 48].contains(code)) return 'Foggy'.tr(context);
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Rainy'.tr(context);
    if ([95, 96, 99].contains(code)) return 'Thunderstorm'.tr(context);
    return 'Cloudy'.tr(context);
  }

  String getWeatherImageUrl(int code) {
    if (code == 0) return 'https://openweathermap.org/img/wn/01d@4x.png';
    if ([1, 2, 3].contains(code)) return 'https://openweathermap.org/img/wn/02d@4x.png';
    if ([45, 48].contains(code)) return 'https://openweathermap.org/img/wn/50d@4x.png';
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'https://openweathermap.org/img/wn/10d@4x.png';
    if ([71, 73, 75, 77].contains(code)) return 'https://openweathermap.org/img/wn/13d@4x.png';
    if ([95, 96, 99].contains(code)) return 'https://openweathermap.org/img/wn/11d@4x.png';
    return 'https://openweathermap.org/img/wn/03d@4x.png';
  }

  void _navigateToModule(String moduleName) {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    switch (moduleName) {
      case 'Chatbot': navProvider.setIndex(1); break;
      case 'CropRecs': navProvider.setIndex(2); break;
      case 'Disease': navProvider.setIndex(3); break;
      case 'Weather': navProvider.setIndex(4); break;
      case 'Market': navProvider.setIndex(5); break;
      case 'Schemes': navProvider.setIndex(6); break;
      case 'Tracker': navProvider.setIndex(7); break;
      case 'Finance': navProvider.setIndex(8); break;
      case 'Profile': navProvider.setIndex(9); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<LocationProvider>(context);
    final userLoc = locProvider.userLocation;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_pin, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section (Row on Desktop, Column on Mobile)
                      isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: _buildHeroCard()),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: _buildWeatherWidget(userLoc)),
                              ],
                            )
                          : Column(
                              children: [
                                _buildHeroCard(),
                                const SizedBox(height: 16),
                                _buildWeatherWidget(userLoc),
                              ],
                            ),
                      const SizedBox(height: 24),

                      // Today's Farm & Irrigation Tasks
                      _buildTodayTasksCard(),
                      const SizedBox(height: 24),

                      // Quick Access Title
                      Text(
                        'Quick Access'.tr(context),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 12),

                      // Responsive Grid of Modules
                      _buildModulesGrid(isDesktop),

                      const SizedBox(height: 24),

                      // Finance Section
                      _buildFinanceCard(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${getGreeting()}, $_farmerName! 🌾',
                style: TextStyle(
                  fontSize: isDesktop ? 26 : 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your farm is looking great today'.tr(context),
                style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: toggleTimeFormat,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      formatTime(),
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _is24Hour ? '24H' : '12H',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDate(),
                style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ));
  }

  Widget _buildWeatherWidget(UserLocation? userLoc) {
    if (_loadingWeather) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 12),
              Text('Loading weather info...'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ));
  }    if (userLoc == null || userLoc.address.isEmpty || userLoc.address == 'Not set') {
      return InkWell(
        onTap: () => _navigateToModule('Profile'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warning, width: 1.5),
          ),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_location_alt_rounded, size: 36, color: AppColors.warning),
                const SizedBox(height: 8),
                Text(
                  '⚠️ Location Not Set - Action Required!'.tr(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap here to go to your Profile and set your farm location for real-time local weather.'.tr(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMain, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_weatherData == null || _weatherData!['current_weather'] == null || _weatherData!['daily'] == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 36, color: AppColors.error),
              const SizedBox(height: 8),
              Text('Weather details unavailable'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ));
    }

    final current = (_weatherData?['current_weather'] as Map<String, dynamic>?) ?? {};
    final daily = (_weatherData?['daily'] as Map<String, dynamic>?) ?? {};
    final weatherCode = (current['weathercode'] as num?)?.toInt() ?? 1;

    final maxTempList = daily['temperature_2m_max'] as List<dynamic>? ?? [];
    final maxTemp = maxTempList.isNotEmpty ? ((maxTempList[0] as num?)?.toStringAsFixed(0) ?? '32') : '32';
    final minTempList = daily['temperature_2m_min'] as List<dynamic>? ?? [];
    final minTemp = minTempList.isNotEmpty ? ((minTempList[0] as num?)?.toStringAsFixed(0) ?? '23') : '23';
    final precipList = daily['precipitation_sum'] as List<dynamic>? ?? [];
    final double rainSum = precipList.isNotEmpty
        ? ((precipList[0] as num?)?.toDouble() ?? 0.0)
        : 0.0;
    int rainProb = 0;
    final probList = daily['precipitation_probability_max'] as List<dynamic>? ?? [];
    if (probList.isNotEmpty) {
      rainProb = (probList[0] as num?)?.toInt() ?? 0;
    }
    if (rainSum > 0 && rainProb == 0) {
      rainProb = 85;
    }
    final rainTimeStr = _getExpectedRainTime();
    final windspeed = (current['windspeed'] as num?)?.toStringAsFixed(1) ?? '10.0';
    final tempVal = (current['temperature'] as num?)?.toStringAsFixed(1) ?? '--';

    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Weather'.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A), fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userLoc.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: Image.network(
                  getWeatherImageUrl(weatherCode),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    getWeatherIcon(weatherCode),
                    size: 38,
                    color: getWeatherIconColor(weatherCode),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tempVal°C',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    getWeatherLabel(weatherCode),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.secondary),
                  ),
                ],
              ),
              Container(width: 1, height: 50, color: Colors.blue.shade200),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeatherDetailItem(Icons.thermostat, '${'Min/Max:'.tr(context)} $minTemp° / $maxTemp°'),
                  _buildWeatherDetailItem(Icons.water_drop, '${'Rain:'.tr(context)} ${rainSum}mm ($rainProb%)${rainTimeStr != null ? ' @ $rainTimeStr' : ''}'),
                  _buildWeatherDetailItem(Icons.air, '${'Wind:'.tr(context)} $windspeed km/h'),
                ],
              ),
            ],
          ),
        ],
      ));
  }

  Widget _buildWeatherDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
        ),
      ],
    );
  }

  Widget _buildModulesGrid(bool isDesktop) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = isDesktop ? 6 : (width > 480 ? 4 : 3);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: width < 380 ? 0.82 : 0.88,
      ),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final mod = _modules[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => _navigateToModule(mod['name'] as String),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mod['bg'] as Color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      mod['icon'] as IconData,
                      color: mod['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (mod['title'] as String).tr(context),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMain, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinanceCard() {
    if (_loadingFinance) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()));
  }

    if (_financeSummary == null) {
      return const SizedBox();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _navigateToModule('Finance'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wallet, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Finance Overview'.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildFinanceSummaryCol(
                      'Income'.tr(context),
                      '₹${_financeSummary!['totalIncome']}',
                      const Color(0xFF10B981),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildFinanceSummaryCol(
                      'Expense'.tr(context),
                      '₹${_financeSummary!['totalExpense']}',
                      const Color(0xFFEF4444),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildFinanceSummaryCol(
                      'Profit'.tr(context),
                      '₹${_financeSummary!['profit']}',
                      (_financeSummary!['profit'] as num) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ));
  }

  Widget _buildFinanceSummaryCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildTodayTasksCard() {
    final irrigationList = _todayTasks['irrigation'] ?? [];
    final otherList = _todayTasks['other'] ?? [];
    final totalTasks = irrigationList.length + otherList.length;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Farm & Crop Tasks".tr(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain, height: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalTasks == 0 ? 'No active tasks scheduled for today'.tr(context) : '$totalTasks ${'items scheduled for today'.tr(context)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Separate Section 1: Irrigation & Water Management
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'💧 Irrigation & Water Management'.tr(context)} (${irrigationList.length})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingTasks)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (irrigationList.isEmpty)
                    Text(
                      'No irrigation or water cycles scheduled for today.'.tr(context),
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    )
                  else
                    Column(
                      children: irrigationList.map((task) => _buildDashboardTaskItem(task, const Color(0xFF2563EB), const Color(0xFFEFF6FF))).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Separate Section 2: All Other Crop Tasks
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grass, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${'🌾 All Other Crop Tasks'.tr(context)} (${otherList.length})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingTasks)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (otherList.isEmpty)
                    Text(
                      'No general farming, fertilizer, or pest tasks scheduled for today.'.tr(context),
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    )
                  else
                    Column(
                      children: otherList.map((task) => _buildDashboardTaskItem(task, AppColors.primary, AppColors.primaryLight)).toList(),
                    ),
                ],
              ),
            ),

            if (totalTasks == 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _navigateToModule('Tracker'),
                icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                label: Flexible(
                  child: Text(
                    'Schedule Farm or Irrigation Tasks'.tr(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTaskItem(CropEvent task, Color color, Color bg) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: task.isCompleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: task.isCompleted ? Colors.grey.shade300 : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              await TimelineScreen.toggleTaskCompletion(task.id);
              _fetchTodayTasks();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted ? AppColors.primary : Colors.transparent,
                border: Border.all(color: task.isCompleted ? AppColors.primary : Colors.grey.shade400, width: 2),
              ),
              child: Icon(Icons.check, size: 14, color: task.isCompleted ? Colors.white : Colors.transparent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: task.isCompleted ? Colors.grey : AppColors.textMain,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        task.category,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                    if (task.isCompleted) ...[
                      const SizedBox(width: 6),
                      Text('• Done'.tr(context), style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
