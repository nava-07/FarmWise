import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';
import 'profile_screen.dart';

class CropRecScreen extends StatefulWidget {
  const CropRecScreen({super.key});

  @override
  State<CropRecScreen> createState() => _CropRecScreenState();
}

class _CropRecScreenState extends State<CropRecScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedSoilType;
  String? _selectedSeason;

  bool _loading = false;
  Map<String, dynamic>? _recommendationData;
  bool _voiceEnabled = false;

  @override
  void deactivate() {
    VoiceService().stop();
    super.deactivate();
  }

  List<String> _getLocalizedSoilTypes(String code, String nativeName) {
    switch (code) {
      case 'hi':
        return [
          'जलोढ़ मिट्टी (Alluvial Soil)',
          'काली मिट्टी (Black Soil)',
          'लाल मिट्टी (Red Soil)',
          'चिकनी / दोमट मिट्टी (Clay / Loam)',
          'बलुई मिट्टी (Sandy Soil)',
          'लेटराइट मिट्टी (Laterite Soil)',
        ];
      case 'ta':
        return [
          'வண்டல் மண் (Alluvial Soil)',
          'கரிசல் மண் (Black Soil)',
          'செம்மண் (Red Soil)',
          'களிமண் / வண்டல் (Clay / Loam)',
          'மணல் பாங்கான மண் (Sandy Soil)',
          'சரளை மண் (Laterite Soil)',
        ];
      case 'te':
        return [
          'ఒండ్రు మట్టి (Alluvial Soil)',
          'నల్లరేగడి మట్టి (Black Soil)',
          'ఎర్ర మట్టి (Red Soil)',
          'బంకమట్టి (Clay / Loamy)',
          'ఇసుక నేల (Sandy Soil)',
          'లాటరైట్ మట్టి (Laterite Soil)',
        ];
      case 'kn':
        return [
          'ಮೊಕ್ಕಲು ಮಣ್ಣು (Alluvial Soil)',
          'ಕಪ್ಪು ಮಣ್ಣು (Black Soil)',
          'ಕೆಂಪು ಮಣ್ಣು (Red Soil)',
          'ಜೇಡಿಮಣ್ಣು (Clay / Loamy)',
          'ಮರಳು ಮಣ್ಣು (Sandy Soil)',
          'ಲ್ಯಾಟರೈಟ್ ಮಣ್ಣು (Laterite Soil)',
        ];
      case 'ml':
        return [
          'എക്കൽ മണ്ണ് (Alluvial Soil)',
          'കരിമണ്ണ് (Black Soil)',
          'ചെമ്മണ്ണ് (Red Soil)',
          'കളിമണ്ണ് (Clay / Loamy)',
          'മണൽ മണ്ണ് (Sandy Soil)',
          'ലാറ്ററൈറ്റ് മണ്ണ് (Laterite Soil)',
        ];
      case 'mr':
        return [
          'गाळाची जमीन (Alluvial Soil)',
          'काळी जमीन (Black Soil)',
          'लाल माती (Red Soil)',
          'चिकणमाती (Clay / Loamy)',
          'वाळूची माती (Sandy Soil)',
          'जांभी माती (Laterite Soil)',
        ];
      case 'gu':
        return [
          'કાંપનાળ જમીન (Alluvial Soil)',
          'કાળી જમીન (Black Soil)',
          'લાલ જમીન (Red Soil)',
          'ચીકણી જમીન (Clay / Loamy)',
          'રેતાળ જમીન (Sandy Soil)',
          'પડખાઉ જમીન (Laterite Soil)',
        ];
      case 'bn':
        return [
          'পলি মাটি (Alluvial Soil)',
          'কালো মাটি (Black Soil)',
          'लाल মাটি (Red Soil)',
          'এঁটেল / দোঁয়াশ মাটি (Clay / Loamy)',
          'বেলে মাটি (Sandy Soil)',
          'ল্যাটেরাইট মাটি (Laterite Soil)',
        ];
      case 'pa':
        return [
          'ਜਲੋਢ ਮਿੱਟੀ (Alluvial Soil)',
          'ਕਾਲੀ ਮਿੱਟੀ (Black Soil)',
          'ਲਾਲ ਮਿੱਟੀ (Red Soil)',
          'ਚੀਕਣੀ ਮਿੱਟੀ (Clay / Loamy)',
          'ਰੇਤਲੀ ਮਿੱਟੀ (Sandy Soil)',
          'ਲੈਟੇਰਾਈਟ ਮਿੱਟੀ (Laterite Soil)',
        ];
      case 'or':
        return [
          'ପଟୁ ମାଟି (Alluvial Soil)',
          'କଳା ମାଟି (Black Soil)',
          'ଲାଲ ମାଟି (Red Soil)',
          'ମଟାଳ ମାଟି (Clay / Loamy)',
          'ବାଲିଆ ମାଟି (Sandy Soil)',
          'ଲାଟେରାଇଟ୍ ମାଟି (Laterite Soil)',
        ];
      case 'ur':
        return [
          'جلوڈھ مٹی (Alluvial Soil)',
          'کالی مٹی (Black Soil)',
          'لال مٹی (Red Soil)',
          'چکنی مٹی (Clay / Loam)',
          'ریتلی مٹی (Sandy Soil)',
          'لیٹرائٹ مٹی (Laterite)',
        ];
      case 'sa':
        return [
          'जलज मृदा (Alluvial Soil)',
          'कृष्ण मृदा (Black Soil)',
          'रक्त मृदा (Red Soil)',
          'मृत्तिका / दोमट (Clay / Loam)',
          'सिकता मृदा (Sandy Soil)',
          'इष्टिका मृदा (Laterite Soil)',
        ];
      case 'en':
        return [
          'Alluvial Soil',
          'Black Soil',
          'Red Soil',
          'Clay / Loamy Soil',
          'Sandy Soil',
          'Laterite Soil',
        ];
      default:
        return [
          'Alluvial Soil',
          'Black Soil',
          'Red Soil',
          'Clay / Loamy Soil',
          'Sandy Soil',
          'Laterite Soil',
        ];
    }
  }

  List<String> _getLocalizedSeasons(String code, String nativeName) {
    switch (code) {
      case 'hi':
        return [
          'खरीफ / मानसून (Monsoon / Kharif)',
          'रबी / सर्दी (Winter / Rabi)',
          'जायद / गर्मी (Summer / Zaid)',
          'वर्षभर / बारहमासी (Year-Round)',
        ];
      case 'ta':
        return [
          'குறுவை / மழைக்காலம் (Monsoon / Kharif)',
          'தாளடி / குளிர்காலம் (Winter / Rabi)',
          'கோடைக்காலம் (Summer / Zaid)',
          'ஆண்டு முழுவதும் (Year-Round)',
        ];
      case 'te':
        return [
          'ఖరీఫ్ / వర్షాకాలం (Monsoon / Kharif)',
          'రబీ / శీతాకాలం (Winter / Rabi)',
          'వేసవి కాలం (Summer / Zaid)',
          'ఏడాది పొడవునా (Year-Round)',
        ];
      case 'kn':
        return [
          'ಖರೀಫ್ / ಮಳೆಗಾಲ (Monsoon / Kharif)',
          'ರಬಿ / ಚಳಿಗಾಲ (Winter / Rabi)',
          'ಬೇಸಿಗೆ (Summer / Zaid)',
          'ವರ್ಷವಿಡೀ (Year-Round)',
        ];
      case 'ml':
        return [
          'ഖരീഫ് / വർഷകാലം (Monsoon / Kharif)',
          'രബി / ശൈത്യകാലം (Winter / Rabi)',
          'വേനൽക്കാലം (Summer / Zaid)',
          'വർഷം മുഴുവൻ (Year-Round)',
        ];
      case 'mr':
        return [
          'खरीप / पावसाळा (Monsoon / Kharif)',
          'रब्बी / हिवाळा (Winter / Rabi)',
          'उन्हाळा (Summer / Zaid)',
          'वर्षभर (Year-Round)',
        ];
      case 'gu':
        return [
          'ખરીફ / ચોમાસુ (Monsoon / Kharif)',
          'રબી / શિયાળો (Winter / Rabi)',
          'ઉનાળો (Summer / Zaid)',
          'આખું વર્ષ (Year-Round)',
        ];
      case 'bn':
        return [
          'খরিফ / বর্ষা (Monsoon / Kharif)',
          'রবি / শীত (Winter / Rabi)',
          'গ্রীষ্মকালীন (Summer / Zaid)',
          'সারাবছর (Year-Round)',
        ];
      case 'pa':
        return [
          'ਖਰੀਫ਼ / ਮਾਨਸੂਨ (Monsoon / Kharif)',
          'ਰਬੀ / ਸਰਦੀ (Winter / Rabi)',
          'ਗਰਮੀ (Summer / Zaid)',
          'ਸਾਲ ਭਰ (Year-Round)',
        ];
      case 'or':
        return [
          'ଖରୀଫ / ବର୍ଷା (Monsoon / Kharif)',
          'ରବି / ଶୀତ (Winter / Rabi)',
          'ଖରାଦିନେ (Summer / Zaid)',
          'ବର୍ଷ ତମାମ (Year-Round)',
        ];
      case 'en':
        return [
          'Monsoon Season',
          'Winter Season',
          'Summer Season',
          'Year-Round',
        ];
      default:
        return [
          'Monsoon Season',
          'Winter Season',
          'Summer Season',
          'Year-Round',
        ];
    }
  }

  void _navigateToProfile() {
    try {
      Provider.of<NavigationProvider>(context, listen: false).setIndex(9);
    } catch (_) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  Future<void> _generateRecommendation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSoilType == null || _selectedSeason == null) {
      return;
    }
    
    setState(() {
      _loading = true;
      _recommendationData = null;
    });

    final locProvider = Provider.of<LocationProvider>(context, listen: false);
    final userLoc = locProvider.userLocation;
    final bool isLocationSet = userLoc != null && userLoc.address.isNotEmpty && userLoc.address != 'Not set';
    if (!isLocationSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please set your farm location in your Profile for precise AI recommendations!'.tr(context)),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Set Location'.tr(context),
            textColor: Colors.white,
            onPressed: _navigateToProfile,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    final locationStr = isLocationSet
        ? userLoc.address
        : 'India (Default Agricultural Belt)';

    // Call Gemini AI for localized agronomic recommendation
    final aiResult = await AIService().getAgronomicRecommendation(
      soilType: _selectedSoilType!,
      season: _selectedSeason!,
      location: locationStr,
    );

    if (aiResult != null && mounted) {
      setState(() {
        _recommendationData = aiResult;
        _loading = false;
      });
      if (_voiceEnabled) VoiceService().speak('${'Recommended Primary Crop'.tr(context)}: ${aiResult['mainCrop']}');
      return;
    }

    // Offline fallback rules with localization translation support
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final soil = _selectedSoilType!.toLowerCase();
    final season = _selectedSeason!.toLowerCase();
    
    String mainCrop = 'Paddy (Rice / நெல்)'.tr(context);
    String secondaryCrops = 'Sugarcane, Maize, Black Gram'.tr(context);
    String fertilizerTip = 'Apply N-P-K in ratio 100:50:50 kg/ha. Use Urea and DAP during vegetative phase.'.tr(context);
    String waterNeeds = 'High irrigation required; keep water standing during early vegetative and reproductive growth.'.tr(context);
    String soilBenefits = 'Highly rich in potash and phosphoric acid, ideal for intensive cereal farming.'.tr(context);
    String expectedYield = '4.5 - 6.0 Tons per hectare with proper nutrient management.'.tr(context);

    if (soil.contains('black') || soil.contains('கரிசல்') || soil.contains('काली') || soil.contains('నల్ల')) {
      if (season.contains('winter') || season.contains('rabi') || season.contains('குளிர்காலம்') || season.contains('रबी')) {
        mainCrop = 'Bengal Gram / Chickpea (கொண்டைக்கடலை)'.tr(context);
        secondaryCrops = 'Sorghum (சோளம்), Wheat, Mustard, Coriander'.tr(context);
        fertilizerTip = 'Apply 20:40:20 NPK kg/ha as basic dose. Use Rhizobium inoculation with seeds.'.tr(context);
        waterNeeds = 'Moderate to low; depends heavily on conserved moisture in black soils.'.tr(context);
        soilBenefits = 'Excellent moisture retention; self-plowing nature ideal for dryland farming.'.tr(context);
        expectedYield = '1.8 - 2.5 Tons per hectare.'.tr(context);
      } else {
        mainCrop = 'Cotton (பருத்தி / B.T. Cotton)'.tr(context);
        secondaryCrops = 'Soybean, Sunflower, Red Gram (துவரம் பருப்பு)'.tr(context);
        fertilizerTip = 'NPK 80:40:40 kg/ha. Zinc sulfate spray recommended during early bolling stage.'.tr(context);
        waterNeeds = 'Moderate irrigation every 10-15 days during flowering and square formation.'.tr(context);
        soilBenefits = 'Deep black soils hold high organic magnesium and clay fraction.'.tr(context);
        expectedYield = '2.5 - 3.2 Tons of raw seed cotton per hectare.'.tr(context);
      }
    } else if (soil.contains('red') || soil.contains('செம்மண்') || soil.contains('लाल') || soil.contains('ఎర్ర')) {
      if (season.contains('summer') || season.contains('zaid') || season.contains('கோடை') || season.contains('गर्मी')) {
        mainCrop = 'Groundnut / Peanuts (வேர்க்கடலை)'.tr(context);
        secondaryCrops = 'Gingelly / Sesame (எள்), Green Gram, Millets'.tr(context);
        fertilizerTip = 'NPK 25:50:75 kg/ha along with Gypsum application @ 400 kg/ha at pegging stage.'.tr(context);
        waterNeeds = 'Light sprinkler irrigation every 7-10 days; avoid water stagnation.'.tr(context);
        soilBenefits = 'Porous structure allows easy penetration of pods and roots.'.tr(context);
        expectedYield = '2.0 - 2.8 Tons of dry pods per hectare.'.tr(context);
      } else {
        mainCrop = 'Millets - Finger Millet / Ragi (கேழ்వరగు)'.tr(context);
        secondaryCrops = 'Pearl Millet (கம்பு), Sorghum (சோளம்), Horse Gram'.tr(context);
        fertilizerTip = 'Apply organic farmyard manure (FYM) @ 12.5 t/ha plus basic NPK 60:30:30.'.tr(context);
        waterNeeds = 'Drought-tolerant; requires supplementary irrigation only during grain filling.'.tr(context);
        soilBenefits = 'Rich in iron content, highly adaptable to rain-fed farming.'.tr(context);
        expectedYield = '2.2 - 3.5 Tons per hectare.'.tr(context);
      }
    } else if (soil.contains('clay') || soil.contains('loamy') || soil.contains('loam') || soil.contains('களிமண்') || soil.contains('दोमट')) {
      mainCrop = 'Banana (வாழை / Poovan, Robusta)'.tr(context);
      secondaryCrops = 'Turmeric (மஞ்சள்), Vegetables (Tomato, Brinjal), Taro'.tr(context);
      fertilizerTip = 'High nutrient demands: 200 g N, 50 g P2O5, 300 g K2O per plant split into 5 doses.'.tr(context);
      waterNeeds = 'Consistent soil moisture essential; regular drip irrigation recommended.'.tr(context);
      soilBenefits = 'High fertility and water nutrient exchange capacity.'.tr(context);
      expectedYield = '35 - 45 Tons per hectare over 10-12 month cycle.'.tr(context);
    } else if (soil.contains('sandy') || soil.contains('laterite') || soil.contains('மணல்') || soil.contains('சரளை') || soil.contains('बलुई')) {
      mainCrop = 'Coconut (தென்னை) & Cashew (முந்திரி)'.tr(context);
      secondaryCrops = 'Tapioca / Cassava (மரவள்ளிக்கிழங்கு), Drumstick (முருங்கை), Moringa'.tr(context);
      fertilizerTip = 'Apply organic compost regularly. NPK 1.3 kg : 2.0 kg : 2.0 kg per adult palm annually.'.tr(context);
      waterNeeds = 'Drip irrigation basin method; crucial during dry summer spells.'.tr(context);
      soilBenefits = 'Well-drained soil structure prevents root rot in perennial arboriculture.'.tr(context);
      expectedYield = '100 - 150 nuts per tree/year; high commercial export value.'.tr(context);
    }

    if (mounted) {
      setState(() {
        _recommendationData = {
          'mainCrop': mainCrop,
          'secondaryCrops': secondaryCrops,
          'fertilizerTip': fertilizerTip,
          'waterNeeds': waterNeeds,
          'soilBenefits': soilBenefits,
          'expectedYield': expectedYield,
        };
        _loading = false;
      });
      if (_voiceEnabled) VoiceService().speak('${'Recommended Primary Crop'.tr(context)}: $mainCrop');
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final locProvider = Provider.of<LocationProvider>(context);
    final userLoc = locProvider.userLocation;
    
    final bool isLocationSet = userLoc != null && userLoc.address.isNotEmpty && userLoc.address != 'Not set';
    final String locationTitle = isLocationSet ? 'Farm Location Profile'.tr(context) : '⚠️ Location Not Set - Action Required!'.tr(context);
    final String locationStr = isLocationSet ? userLoc.address : 'Tap here to go to your Profile and set your farm location for precise AI crop recommendations.'.tr(context);
    final Color borderColor = isLocationSet ? AppColors.primary.withValues(alpha: 0.3) : AppColors.warning;
    final Color bgColor = isLocationSet ? AppColors.primaryLight : const Color(0xFFFFFBEB);
    final IconData locIcon = isLocationSet ? Icons.location_on : Icons.add_location_alt;
    final Color iconColor = isLocationSet ? AppColors.primary : AppColors.warning;

    final soilTypes = _getLocalizedSoilTypes(langProvider.currentLanguage.code, langProvider.currentLanguage.nativeName);
    final seasons = _getLocalizedSeasons(langProvider.currentLanguage.code, langProvider.currentLanguage.nativeName);

    if (_selectedSoilType == null || !soilTypes.contains(_selectedSoilType)) {
      _selectedSoilType = soilTypes.first;
    }
    if (_selectedSeason == null || !seasons.contains(_selectedSeason)) {
      _selectedSeason = seasons.first;
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
        title: Text('Crop Recommendation & Soil Advisory'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _voiceEnabled ? Icons.volume_up : Icons.volume_off_outlined,
              color: _voiceEnabled ? Colors.white : Colors.white70,
            ),
            tooltip: _voiceEnabled ? 'Voice Enabled'.tr(context) : 'Voice Disabled'.tr(context),
            onPressed: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                if (!_voiceEnabled) {
                  VoiceService().stop();
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_voiceEnabled
                    ? '${'Voice Assistant Enabled'.tr(context)} - ${LanguageProvider.currentLanguageName}'
                    : 'Voice Assistant Disabled'.tr(context)),
                  backgroundColor: _voiceEnabled ? AppColors.primary : Colors.grey,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _navigateToProfile,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: isLocationSet ? 1.0 : 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(locIcon, color: iconColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(locationTitle, style: TextStyle(fontSize: 12, color: isLocationSet ? AppColors.textMuted : AppColors.warning, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(locationStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Soil & Season'.tr(context),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.landscape, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Soil Profile'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain, fontSize: 15)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedSoilType,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: soilTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                            onChanged: (val) => setState(() => _selectedSoilType = val!),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Cultivation Season'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain, fontSize: 15)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedSeason,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: seasons.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                            onChanged: (val) => setState(() => _selectedSeason = val!),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _loading ? const SizedBox.shrink() : const Icon(Icons.analytics_outlined),
                              label: _loading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : Text('Get Agronomic Recommendation'.tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              onPressed: _loading ? null : _generateRecommendation,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_recommendationData != null) _buildRecommendationResult(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationResult() {
    final data = _recommendationData!;
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFFBBF24), size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Recommended Primary Crop'.tr(context), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data['mainCrop'],
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.compare_arrows, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${'Alternative Suitable Crops'.tr(context)}: ${data['secondaryCrops']}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(Icons.science, 'Fertilizer & Nutrient Advisory'.tr(context), data['fertilizerTip'], const Color(0xFF10B981)),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.water_drop, 'Irrigation & Water Strategy'.tr(context), data['waterNeeds'], const Color(0xFF3B82F6)),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.eco, 'Soil Health Profile'.tr(context), data['soilBenefits'], const Color(0xFFF59E0B)),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.trending_up, 'Estimated Harvest Yield'.tr(context), data['expectedYield'], const Color(0xFF8B5CF6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String description, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain, fontSize: 15)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: AppColors.textLight, fontSize: 13.5, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
