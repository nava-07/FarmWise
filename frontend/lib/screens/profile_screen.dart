import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/location_selector_field.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Farmer Profile';
  String _phone = 'Not linked';
  String _farmSize = 'Not set';
  String _soilType = 'Not set';
  String _primaryCrop = 'Not set';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedName = prefs.getString('profile_name');
      final savedPhone = prefs.getString('profile_phone');
      final savedSize = prefs.getString('profile_farm_size');
      final savedSoil = prefs.getString('profile_soil_type');
      final savedCrop = prefs.getString('profile_primary_crop');

      _name = (savedName == null || savedName.trim().isEmpty || savedName == 'Ramesh Kumar') ? 'Farmer Profile' : savedName;
      _phone = (savedPhone == null || savedPhone.trim().isEmpty || savedPhone == '+91 98765 43210') ? 'Not linked' : savedPhone;
      _farmSize = (savedSize == null || savedSize.trim().isEmpty || savedSize == '12.5 Acres') ? 'Not set' : savedSize;
      _soilType = (savedSoil == null || savedSoil.trim().isEmpty || savedSoil == 'Alluvial & Black Soil') ? 'Not set' : savedSoil;
      _primaryCrop = (savedCrop == null || savedCrop.trim().isEmpty || savedCrop == 'Paddy, Wheat & Cotton') ? 'Not set' : savedCrop;
      
      _loading = false;
    });
  }

  Future<void> _saveProfile(String name, String phone, String size, String soil, String crop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_phone', phone);
    await prefs.setString('profile_farm_size', size);
    await prefs.setString('profile_soil_type', soil);
    await prefs.setString('profile_primary_crop', crop);
    setState(() {
      _name = name;
      _phone = phone;
      _farmSize = size;
      _soilType = soil;
      _primaryCrop = crop;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Farmer Profile & Farm Settings saved!'.tr(context)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showEditModal() {
    final nameCtrl = TextEditingController(text: _name == 'Farmer Profile' ? '' : _name);
    final phoneCtrl = TextEditingController(text: _phone == 'Not linked' ? '' : _phone);
    final sizeCtrl = TextEditingController(text: _farmSize == 'Not set' ? '' : _farmSize);
    final soilCtrl = TextEditingController(text: _soilType == 'Not set' ? '' : _soilType);
    final cropCtrl = TextEditingController(text: _primaryCrop == 'Not set' ? '' : _primaryCrop);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text('Edit'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField('Full Name'.tr(context), nameCtrl, Icons.person_outline, 'Enter your name'),
              const SizedBox(height: 12),
              _buildDialogField('Phone Number'.tr(context), phoneCtrl, Icons.phone_android, 'Enter mobile number'),
              const SizedBox(height: 12),
              _buildDialogField('Farm Area'.tr(context), sizeCtrl, Icons.landscape, 'e.g. 5 Acres'),
              const SizedBox(height: 12),
              _buildDialogField('Soil Profile'.tr(context), soilCtrl, Icons.compost, 'e.g. Black & Red Soil'),
              const SizedBox(height: 12),
              _buildDialogField('Active Crops'.tr(context), cropCtrl, Icons.spa, 'e.g. Wheat, Maize'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel'.tr(context), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _saveProfile(
                nameCtrl.text.trim().isEmpty ? 'Farmer Profile' : nameCtrl.text.trim(),
                phoneCtrl.text.trim().isEmpty ? 'Not linked' : phoneCtrl.text.trim(),
                sizeCtrl.text.trim().isEmpty ? 'Not set' : sizeCtrl.text.trim(),
                soilCtrl.text.trim().isEmpty ? 'Not set' : soilCtrl.text.trim(),
                cropCtrl.text.trim().isEmpty ? 'Not set' : cropCtrl.text.trim(),
              );
              Navigator.pop(dialogCtx);
            },
            child: Text('Save Task to Schedule'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, IconData icon, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showLanguageSelectorModal() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final languageProvider = Provider.of<LanguageProvider>(ctx);
            final filteredLanguages = LanguageProvider.supportedLanguages.where((lang) {
              return lang.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                     lang.nativeName.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20, left: 20, right: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.language, color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Select Language'.tr(context),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textMain),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search languages...'.tr(context),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredLanguages.length,
                        separatorBuilder: (c, i) => Divider(color: Colors.grey.shade200, height: 1),
                        itemBuilder: (c, index) {
                          final lang = filteredLanguages[index];
                          final isSelected = languageProvider.currentLanguage.code == lang.code;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            tileColor: isSelected ? const Color(0xFFD1FAE5).withValues(alpha: 0.4) : null,
                            title: Text(
                              lang.nativeName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                fontSize: 17,
                                color: isSelected ? AppColors.primary : AppColors.textMain,
                              ),
                            ),
                            subtitle: Text(
                              lang.name,
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppColors.primary, size: 26)
                                : const Icon(Icons.circle_outlined, color: Colors.grey, size: 24),
                            onTap: () async {
                              await languageProvider.setLanguage(lang);
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInfoDialog(String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Text(title.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textMain)),
          ],
        ),
        content: Text(content.tr(context), style: const TextStyle(color: AppColors.textLight, fontSize: 14.5, height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it!'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final activeCropCount = (_primaryCrop == 'Not set' || _primaryCrop.isEmpty) 
        ? '0' 
        : _primaryCrop.split(',').length.toString();

    final stats = [
      {'label': 'Active Crops'.tr(context), 'value': activeCropCount, 'icon': Icons.spa, 'color': AppColors.primary},
      {'label': 'Farm Area'.tr(context), 'value': _farmSize, 'icon': Icons.map, 'color': const Color(0xFF0284C7)},
      {'label': 'Soil Profile'.tr(context), 'value': _soilType.length > 11 ? '${_soilType.substring(0, 11)}..' : _soilType, 'icon': Icons.compost, 'color': AppColors.warning},
    ];

    final menuItems = [
      {
        'title': 'Language'.tr(context),
        'subtitle': '${languageProvider.currentLanguage.name} (${languageProvider.currentLanguage.nativeName})',
        'icon': Icons.language,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFE0F2FE),
        'action': () => _showLanguageSelectorModal(),
      },
      {
        'title': 'Account & Farming Preferences'.tr(context),
        'subtitle': 'Manage crop notifications and mandi rate regions'.tr(context),
        'icon': Icons.tune,
        'color': AppColors.primary,
        'bg': AppColors.primaryLight,
        'action': () => _showEditModal(),
      },
      {
        'title': 'Offline Weather & SMS Alerts'.tr(context),
        'subtitle': _phone == 'Not linked' ? 'Link your mobile number to enable daily alerts'.tr(context) : 'Active SMS alerts to $_phone',
        'icon': Icons.notifications_active_outlined,
        'color': AppColors.warning,
        'bg': const Color(0xFFFFFBEB),
        'action': () => _showInfoDialog('Offline Weather & SMS Alerts', _phone == 'Not linked' ? 'Please add your phone number in Edit Profile to start receiving daily agricultural bulletins, weather warnings, and Mandi price updates.' : 'Your phone number ($_phone) is actively subscribed to receive daily agricultural bulletins and market rate warnings.', Icons.notifications_active, AppColors.warning),
      },
      {
        'title': 'Data Security & Cloud Sync'.tr(context),
        'subtitle': '256-bit encrypted offline-first SQLite database',
        'icon': Icons.shield_outlined,
        'color': AppColors.secondary,
        'bg': const Color(0xFFEFF6FF),
        'action': () => _showInfoDialog('Data Security & Cloud Sync', 'Your financial records and agronomic crop notes are stored securely on your local device with zero data mining.', Icons.shield, AppColors.secondary),
      },
      {
        'title': 'Government Subsidies Helpline'.tr(context),
        'subtitle': 'Direct toll-free connection to Kisan Call Center (1800-180-1551)',
        'icon': Icons.support_agent,
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFFF5F3FF),
        'action': () => _showInfoDialog('Government Subsidies Helpline', 'You can connect directly to agricultural scientists and government officers anytime by calling Toll-Free Helpline: 1800-180-1551 (Available 6:00 AM - 10:00 PM in all Indian languages).', Icons.support_agent, const Color(0xFF8B5CF6)),
      },
      {
        'title': 'About FarmWise AI Engine'.tr(context),
        'subtitle': 'Version 2.0.0 from NVT groups'.tr(context),
        'icon': Icons.info_outline,
        'color': AppColors.textMuted,
        'bg': const Color(0xFFF8FAFC),
        'action': () => _showInfoDialog('About FarmWise AI Engine', 'FarmWise is India\'s advanced agentic AI farming companion built for high precision weather forecasting, real-time APMC Mandi rates, and bilingual agronomy assistance.', Icons.info_outline, AppColors.primary),
      },
    ];

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
        title: Text('My Farmer Profile & Settings'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            tooltip: 'Edit Profile'.tr(context),
            onPressed: _showEditModal,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                ),
                child: Column(
                  children: [
                    // Top Emerald Header section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 20, bottom: 40, left: 20, right: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF047857)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(36),
                          bottomRight: Radius.circular(36),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: const CircleAvatar(
                                      radius: 46,
                                      backgroundColor: Color(0xFFD1FAE5),
                                      child: Icon(Icons.person, size: 58, color: AppColors.primary),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _showEditModal,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _name,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _phone,
                                style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBadge('Verified Farmer', const Color(0xFF065F46), const Color(0xFFD1FAE5), Icons.verified),
                                  const SizedBox(width: 8),
                                  _buildBadge('Kisan Pro Card', const Color(0xFF1E40AF), const Color(0xFFDBEAFE), Icons.workspace_premium),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Main Content Section
                    Transform.translate(
                      offset: const Offset(0, -25),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Stats Row
                              Row(
                                children: stats.map((stat) {
                                  return Expanded(
                                    child: Card(
                                      elevation: 4,
                                      shadowColor: Colors.black.withValues(alpha: 0.08),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                        child: Column(
                                          children: [
                                            Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 26),
                                            const SizedBox(height: 8),
                                            Text(
                                              stat['value'] as String,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              stat['label'] as String,
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),

                              // Farm Technical Specifications Card
                              Card(
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Farm Specifications',
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textMain),
                                          ),
                                          TextButton.icon(
                                            onPressed: _showEditModal,
                                            icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                            label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      _buildSpecRow(Icons.landscape_outlined, 'Total Holding Area', _farmSize, Colors.green.shade700),
                                      const SizedBox(height: 12),
                                      _buildSpecRow(Icons.compost_outlined, 'Soil Quality Profile', _soilType, Colors.brown.shade600),
                                      const SizedBox(height: 12),
                                      _buildSpecRow(Icons.eco_outlined, 'Main Cultivated Crops', _primaryCrop, Colors.teal.shade700),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Location Settings & GPS Sync Card
                              Card(
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.location_on, color: AppColors.primary, size: 22),
                                          SizedBox(width: 8),
                                          Text(
                                            'Mandi & Weather Region Settings',
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textMain),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Set your village, town, or pincode to sync live agricultural weather forecasts and daily mandi rates.',
                                        style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4),
                                      ),
                                      const SizedBox(height: 16),
                                      const LocationSelectorField(
                                        labelText: 'Current Farm & Region Location',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Settings Menu
                              Card(
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                color: Colors.white,
                                child: Column(
                                  children: menuItems.map((item) {
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: item['bg'] as Color,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                                      ),
                                      title: Text(
                                        item['title'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                                      ),
                                      subtitle: Text(
                                        item['subtitle'] as String,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                      onTap: item['action'] as VoidCallback?,
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Login Button
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.login, color: AppColors.primary, size: 20),
                                label: Text('Login'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Login feature will be available soon!'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String val, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(val, style: const TextStyle(fontSize: 15, color: AppColors.textMain, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
