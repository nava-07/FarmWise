import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/language_provider.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'chatbot_screen.dart';
import 'crop_rec_screen.dart';
import 'disease_screen.dart';
import 'weather_screen.dart';
import 'market_screen.dart';
import 'schemes_screen.dart';
import 'timeline_screen.dart';
import 'finance_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<Map<String, dynamic>> _modules = [
    {'name': 'Dashboard', 'title': 'Home', 'icon': Icons.home, 'color': const Color(0xFF10B981)},
    {'name': 'Chatbot', 'title': 'AI Assistant', 'icon': Icons.chat_bubble_outline, 'color': const Color(0xFF10B981)},
    {'name': 'CropRecs', 'title': 'Crop Advisory', 'icon': Icons.spa_outlined, 'color': const Color(0xFF059669)},
    {'name': 'Disease', 'title': 'Disease Scan', 'icon': Icons.qr_code_scanner_outlined, 'color': const Color(0xFFEF4444)},
    {'name': 'Weather', 'title': 'Weather', 'icon': Icons.wb_sunny_outlined, 'color': const Color(0xFFF59E0B)},
    {'name': 'Market', 'title': 'Market', 'icon': Icons.bar_chart_outlined, 'color': const Color(0xFF3B82F6)},
    {'name': 'Schemes', 'title': 'Schemes', 'icon': Icons.description_outlined, 'color': const Color(0xFF8B5CF6)},
    {'name': 'Tracker', 'title': 'Timeline', 'icon': Icons.calendar_month_outlined, 'color': const Color(0xFFEC4899)},
    {'name': 'Finance', 'title': 'Finance', 'icon': Icons.account_balance_wallet_outlined, 'color': const Color(0xFF059669)},
    {'name': 'Profile', 'title': 'Profile', 'icon': Icons.person_outline, 'color': const Color(0xFF64748B)},
  ];

  final List<Widget> _pages = const [
    DashboardScreen(),
    ChatbotScreen(),
    CropRecScreen(),
    DiseaseScreen(),
    WeatherScreen(),
    MarketScreen(),
    SchemesScreen(),
    TimelineScreen(),
    FinanceScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: isDesktop ? null : _buildDrawer(navProvider),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(navProvider),
          Expanded(
            child: _pages[navProvider.currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNav(navProvider) : null,
    );
  }

  void _showAllModulesBottomSheet(NavigationProvider navProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All FarmWise Modules'.tr(context),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: _modules.length,
                itemBuilder: (ctx, index) {
                  final mod = _modules[index];
                  final isSelected = navProvider.currentIndex == index;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(modalCtx);
                      navProvider.setIndex(index);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryLight : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mod['icon'] as IconData,
                            color: isSelected ? AppColors.primary : (mod['color'] as Color),
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (mod['title'] as String).tr(context),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(NavigationProvider navProvider) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _modules.length,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemBuilder: (context, index) {
            final mod = _modules[index];
            final isSelected = navProvider.currentIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => navProvider.setIndex(index),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                      border: isSelected ? null : Border.all(color: Colors.grey.shade300, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mod['icon'] as IconData,
                          size: isSelected ? 30 : 28,
                          color: isSelected ? Colors.white : AppColors.textMain,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              (mod['title'] as String).tr(context),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppColors.textMain,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar(NavigationProvider navProvider) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          _buildDrawerHeaderContent(),
          Expanded(child: _buildDrawerItemsList(navProvider)),
        ],
      ));
  }

  Widget _buildDrawer(NavigationProvider navProvider) {
    return Drawer(
      child: Container(
        color: const Color(0xFFFAFFFE),
        child: Column(
          children: [
            _buildDrawerHeaderContent(),
            Expanded(child: _buildDrawerItemsList(navProvider)),
          ],
        ),
      ));
  }

  Widget _buildDrawerHeaderContent() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark, Color(0xFF065F46)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/app_logo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.white24,
                child: const Icon(Icons.spa, size: 36, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'FarmWise',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            'Intelligent Agriculture'.tr(context),
            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ));
  }

  Widget _buildDrawerItemsList(NavigationProvider navProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final mod = _modules[index];
        final isSelected = navProvider.currentIndex == index;
        return ListTile(
          leading: Icon(mod['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textMuted),
          title: Text(
            mod['title'] as String,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              color: isSelected ? AppColors.primary : AppColors.textMain,
            ),
          ),
          selected: isSelected,
          selectedTileColor: AppColors.primaryLight.withOpacity(0.3),
          onTap: () {
            navProvider.setIndex(index);
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
}
