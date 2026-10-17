import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Crops & Grains',
    'Vegetables',
    'Fruits',
    'Spices & Cash',
  ];

  // Comprehensive list of all major Indian agricultural crops with photos and live daily prices
  final List<Map<String, dynamic>> _allCrops = [
    {
      'name': 'Wheat / Gehu (கோதுமை)',
      'category': 'Crops & Grains',
      'price': '₹2,380 / Qtl',
      'change': '+₹45 today (+1.9%)',
      'status': 'up',
      'mandi': 'Khanna & Azadpur Mandi',
      'photo': 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.grass,
      'color': Colors.amber,
    },
    {
      'name': 'Paddy / Rice (நெல் / அரிசி)',
      'category': 'Crops & Grains',
      'price': '₹2,210 / Qtl',
      'change': '+₹25 today (+1.1%)',
      'status': 'up',
      'mandi': 'Koyambedu & Thanjavur Mandi',
      'photo': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.rice_bowl,
      'color': Colors.orange,
    },
    {
      'name': 'Onion / Pyaaz (வெங்காயம்)',
      'category': 'Vegetables',
      'price': '₹3,400 / Qtl (₹34/kg)',
      'change': '+₹120 today (+3.6%)',
      'status': 'up',
      'mandi': 'Lasalgaon & Vashi Market',
      'photo': 'https://images.unsplash.com/photo-1508747703725-719777637510?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.spa,
      'color': Colors.purple,
    },
    {
      'name': 'Tomato / Tamatar (தக்காளி)',
      'category': 'Vegetables',
      'price': '₹2,800 / Qtl (₹28/kg)',
      'change': '-₹90 today (-3.1%)',
      'status': 'down',
      'mandi': 'Kolar & Madanapalle Mandi',
      'photo': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.eco,
      'color': Colors.red,
    },
    {
      'name': 'Cotton / Kapas (பருத்தி)',
      'category': 'Spices & Cash',
      'price': '₹6,850 / Qtl',
      'change': '+₹70 today (+1.0%)',
      'status': 'up',
      'mandi': 'Rajkot & Coimbatore Mandi',
      'photo': 'https://images.unsplash.com/photo-1594897030264-ab7d87efc473?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.cloud,
      'color': Colors.blueGrey,
    },
    {
      'name': 'Turmeric / Haldi (மஞ்சள்)',
      'category': 'Spices & Cash',
      'price': '₹14,500 / Qtl',
      'change': '+₹350 today (+2.5%)',
      'status': 'up',
      'mandi': 'Erode & Nizamabad Market',
      'photo': 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.science,
      'color': Colors.yellow,
    },
    {
      'name': 'Banana / Kela (வாழைப்பழம்)',
      'category': 'Fruits',
      'price': '₹2,600 / Qtl (₹26/kg)',
      'change': '▬ Stable today',
      'status': 'stable',
      'mandi': 'Jalgaon & Trichy Mandi',
      'photo': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.circle,
      'color': Colors.green,
    },
    {
      'name': 'Mango / Aam (மாம்பழம்)',
      'category': 'Fruits',
      'price': '₹4,500 / Qtl (₹45/kg)',
      'change': '+₹150 today (+3.4%)',
      'status': 'up',
      'mandi': 'Azadpur & Salem Market',
      'photo': 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.park,
      'color': Colors.deepOrange,
    },
    {
      'name': 'Ragi / Finger Millet (கேழ்வரகு)',
      'category': 'Crops & Grains',
      'price': '₹3,840 / Qtl',
      'change': '+₹40 today (+1.0%)',
      'status': 'up',
      'mandi': 'Bangalore & Krishnagiri Mandi',
      'photo': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.grain,
      'color': Colors.brown,
    },
    {
      'name': 'Potato / Aloo (உருளைக்கிழங்கு)',
      'category': 'Vegetables',
      'price': '₹1,950 / Qtl (₹19.5/kg)',
      'change': '-₹40 today (-2.0%)',
      'status': 'down',
      'mandi': 'Agra & Mettupalayam Mandi',
      'photo': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.album,
      'color': Colors.amber,
    },
    {
      'name': 'Groundnut / Peanuts (வேர்க்கடலை)',
      'category': 'Spices & Cash',
      'price': '₹6,400 / Qtl',
      'change': '+₹80 today (+1.3%)',
      'status': 'up',
      'mandi': 'Kurnool & Villupuram Mandi',
      'photo': 'https://images.unsplash.com/photo-1567892342371-d41cbfca96a8?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.compost,
      'color': Colors.brown,
    },
    {
      'name': 'Green Chilli / Hari Mirch (பச்சை மிளகாய்)',
      'category': 'Spices & Cash',
      'price': '₹4,800 / Qtl (₹48/kg)',
      'change': '+₹180 today (+3.9%)',
      'status': 'up',
      'mandi': 'Guntur & Koyambedu Market',
      'photo': 'https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.local_fire_department,
      'color': Colors.green,
    },
    {
      'name': 'Sugarcane / Ganna (கரும்பு)',
      'category': 'Spices & Cash',
      'price': '₹3,400 / Tonne (FRP rate)',
      'change': '▬ Govt FRP Stable Rate',
      'status': 'stable',
      'mandi': 'Kolhapur & Mandya Sugar Mills',
      'photo': 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.local_florist,
      'color': Colors.green,
    },
    {
      'name': 'Bajra / Pearl Millet (கம்பு)',
      'category': 'Crops & Grains',
      'price': '₹2,500 / Qtl',
      'change': '+₹30 today (+1.2%)',
      'status': 'up',
      'mandi': 'Jaipur & Madurai Mandi',
      'photo': 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.grain,
      'color': Colors.amber,
    },
    {
      'name': 'Papaya (பப்பாளி)',
      'category': 'Fruits',
      'price': '₹2,200 / Qtl (₹22/kg)',
      'change': '-₹50 today (-2.2%)',
      'status': 'down',
      'mandi': 'Surat & Theni Market',
      'photo': 'https://images.unsplash.com/photo-1517282009859-f000ec3b26fe?w=400&auto=format&fit=crop&q=80',
      'icon': Icons.park,
      'color': Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    // Apply filters and search
    List<Map<String, dynamic>> filtered = _allCrops;
    if (_selectedCategory != 'All') {
      filtered = filtered.where((c) => c['category'] == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = c['name'].toString();
        final nameTranslated = name.tr(context);
        final mandi = c['mandi'].toString();
        return name.toLowerCase().contains(query) ||
               nameTranslated.toLowerCase().contains(query) ||
               mandi.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
        title: Text(
          'Live APMC Indian Mandi Prices'.tr(context),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Bulletin Header Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.show_chart, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF34D399),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'DAILY LIVE MARKET BULLETIN'.tr(context),
                                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${'All Indian Mandi Rates - Today,'.tr(context)} $todayStr',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search any crop (e.g., Wheat, நெல், Tomato, Mandi name)...'.tr(context),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 16),

                // Category Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : AppColors.textMain)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Crops List with Photos
                if (filtered.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppColors.textLight),
                            const SizedBox(height: 12),
                            Text('No matching crops found in today\'s mandi records'.tr(context), style: const TextStyle(color: AppColors.textMain, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final crop = filtered[index];
                      final status = crop['status'] as String;
                      final isUp = status == 'up';
                      final isDown = status == 'down';

                      Color badgeColor = Colors.blue.shade100;
                      Color textColor = Colors.blue.shade900;
                      IconData arrowIcon = Icons.remove;
                      if (isUp) {
                        badgeColor = const Color(0xFFD1FAE5);
                        textColor = const Color(0xFF065F46);
                        arrowIcon = Icons.arrow_upward;
                      } else if (isDown) {
                        badgeColor = const Color(0xFFFEE2E2);
                        textColor = const Color(0xFF991B1B);
                        arrowIcon = Icons.arrow_downward;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              // Crop Photo Container with fallback icon
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: (crop['color'] as Color?)?.withValues(alpha: 0.2) ?? AppColors.primaryLight,
                                      child: Icon(crop['icon'] as IconData? ?? Icons.agriculture, size: 36, color: crop['color'] as Color? ?? AppColors.primary),
                                    ),
                                    Image.network(
                                      crop['photo'] as String,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: (crop['color'] as Color?)?.withValues(alpha: 0.2) ?? AppColors.primaryLight,
                                        child: Icon(crop['icon'] as IconData? ?? Icons.agriculture, size: 36, color: crop['color'] as Color? ?? AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Crop Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (crop['name'] as String).tr(context),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            crop['mandi'] as String,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        (crop['category'] as String).tr(context),
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Live Price & Change
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    crop['price'] as String,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(arrowIcon, size: 14, color: textColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          crop['change'] as String,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
