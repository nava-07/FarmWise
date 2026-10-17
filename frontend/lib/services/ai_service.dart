import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/language_provider.dart';

class AIService {
  static final AIService _instance = AIService._internal();

  factory AIService() {
    return _instance;
  }

  AIService._internal();

  static const _cropRecApiKey = String.fromEnvironment('CROP_REC_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY');
  static const _diseaseScanApiKey = String.fromEnvironment('DISEASE_SCAN_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY');
  static const _assistantApiKey = String.fromEnvironment('ASSISTANT_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY');

  late final GenerativeModel _cropModel;
  late final GenerativeModel _diseaseModel;
  late final GenerativeModel _assistantModel;

  void init() {
    _cropModel = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _cropRecApiKey,
    );
    _diseaseModel = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _diseaseScanApiKey,
    );
    _assistantModel = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _assistantApiKey,
    );
  }

  String _extractValue(String line) {
    var val = line.replaceAll(RegExp(r'^[#* \-_]+'), '').replaceAll('**', '').trim();
    final idx = val.indexOf(':');
    if (idx != -1 && idx + 1 < val.length) {
      return val.substring(idx + 1).replaceAll('**', '').trim();
    }
    final idx2 = val.indexOf('-');
    if (idx2 != -1 && idx2 + 1 < val.length) {
      return val.substring(idx2 + 1).replaceAll('**', '').trim();
    }
    return val.replaceAll(RegExp(r'^[A-Z_ ]+[:\-]?\s*', caseSensitive: false), '').replaceAll('**', '').trim();
  }

  /// Starts a new interactive chat session
  ChatSession getChatSession() {
    return _assistantModel.startChat();
  }

  /// Generates a crop recommendation based on location and weather
  Future<String> getCropRecommendations(String location, String weather) async {
    final langName = LanguageProvider.currentLanguageName;
    final langNative = LanguageProvider.currentLanguageNative;
    
    final prompt = '''
You are an expert agronomist and agricultural scientist. Based on the following location and current weather data, provide a highly accurate, structured crop recommendation.

Please format your response strictly in Markdown using the following structure:
### Top Crop Recommendations
- List the top 3 most suitable crops to plant right now.
- Briefly explain why each is a perfect match for the climate.

### Soil Preparation & Needs
- Detail the soil type, pH, and organic matter needed.

### Planting Timeline & Yield
- Expected time to harvest and yield estimates.

### Step-by-Step Planting Guide
- Actionable steps for the farmer to get started immediately.

Location: $location
Current Weather: $weather

IMPORTANT REQUIREMENT: The user's selected language is $langName ($langNative). You MUST generate your entire response ONLY in $langName ($langNative). Do NOT respond in English unless English is the selected language.
''';

    try {
      final response = await _cropModel.generateContent([Content.text(prompt)]);
      return response.text ?? 'No recommendations could be generated.';
    } catch (e) {
      debugPrint('Error generating crop recommendations: $e');
      return 'Failed to generate recommendations. Please try again later.';
    }
  }

  /// Analyzes an image of a plant/leaf for diseases and suggests treatments
  Future<String> analyzePlantDisease(XFile imageFile) async {
    final langName = LanguageProvider.currentLanguageName;
    final langNative = LanguageProvider.currentLanguageNative;
    
    final prompt = '''
You are a world-class agricultural scientist and senior plant pathologist. 
Carefully examine this image of a plant, crop leaf, stem, or fruit.

STEP 1: Image Verification:
- If the image DOES NOT depict a plant, leaf, crop, or agricultural subject, state clearly: "Invalid Image: Please upload or capture a clear close-up photo of a crop leaf or plant stem for disease analysis."

STEP 2: Detailed Agricultural Analysis (if it is a plant/crop):
1. Crop Identification & Health Status:
   - Identify crop species (e.g. Tomato, Rice/Paddy, Cotton, Wheat, Maize, Chilli, Brinjal, Potato, etc.).
   - Determine if the plant is HEALTHY or DISEASED/PEST-AFFECTED.
2. Disease / Pest Diagnosis:
   - Provide the exact common name and scientific name of the disease, pathogen (fungal, bacterial, viral), pest infestation, or nutrient deficiency.
   - Include a realistic confidence percentage (e.g. 96.5%).
3. Observed Visual Symptoms:
   - List specific leaf spots, lesions, discoloration, chlorosis, wilting, rust, or pest damage observed.
4. Immediate Action Plan (To Stop Spread):
   - Urgent physical or cultural steps the farmer must take right now.
5. Treatment & Cure (Organic & Chemical):
   - Specific organic remedies (e.g. Neem oil spray, Panchagavya, Trichoderma).
   - Safe chemical fungicide/pesticide dosage if required.
6. Preventive Guidelines:
   - Crop rotation, water management, spacing, and soil health tips.

IMPORTANT REQUIREMENT: The user's selected language is $langName ($langNative). You MUST generate your entire response ONLY in $langName ($langNative).
''';

    try {
      final bytes = await imageFile.readAsBytes();
      final response = await _diseaseModel.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(imageFile.mimeType ?? 'image/jpeg', bytes),
        ])
      ]);
      return response.text ?? 'No analysis could be generated.';
    } catch (e) {
      debugPrint('Error analyzing plant disease: $e');
      return 'Failed to analyze the image. Please try again later.';
    }
  }

  /// Analyzes a plant disease and returns structured map formatted in the user's preferred language
  Future<Map<String, String>?> analyzePlantDiseaseStructured(XFile imageFile) async {
    final langName = LanguageProvider.currentLanguageName;
    final langNative = LanguageProvider.currentLanguageNative;
    
    final prompt = '''
You are an expert plant pathologist, botanist, and agricultural AI scientist.
Examine this crop or plant image and diagnose any disease, pest infestation, or nutrient stress.

CRITICAL CHECKS:
1. NON-PLANT IMAGE: If the image is NOT a plant, leaf, crop, or agricultural element:
   Set DISEASE_NAME: Non-Plant Image Detected
   Set CONFIDENCE_SCORE: 100%
   Set TREATMENT_PLAN: Please take or upload a clear, close-up photograph of a plant leaf, crop stem, or affected agricultural crop for an accurate disease scan.

2. HEALTHY PLANT: If the plant is completely healthy with no disease symptoms:
   Set DISEASE_NAME: Healthy Crop - No Disease Detected
   Set CONFIDENCE_SCORE: 98.5%
   Set TREATMENT_PLAN: The crop foliage shows normal healthy color and cell structure. Maintain regular watering, balanced soil fertilization, and pest monitoring.

3. DISEASED / PEST INFECTED CROP:
   Identify crop species and exact pathogen or disease name (e.g., Tomato - Early Blight / Alternaria solani, Paddy - Bacterial Leaf Blight, Cotton - Whitefly Attack, Chilli - Powdery Mildew, Potato - Late Blight).

IMPORTANT REQUIREMENT FOR LANGUAGE AND KEYS:
- The user's selected language is $langName ($langNative).
- ALL VALUES (the text after the colons) MUST be written ONLY in $langName ($langNative).
- DO NOT translate the KEY NAMES. Key names MUST remain strictly in English: DISEASE_NAME:, CONFIDENCE_SCORE:, TREATMENT_PLAN:.

Provide your response strictly in the following delimited format with NO markdown code blocks around it:

DISEASE_NAME: [Plant Name] - [Exact Disease or Health Condition in $langName]
CONFIDENCE_SCORE: [Confidence score e.g. 96.5%]
TREATMENT_PLAN:
- Visual Symptoms: [Key symptoms observed on leaves/stem in $langName]
- Immediate Action: [Urgent containment steps in $langName]
- Treatment Advisory: [Recommended organic cures, fungicides, or fertilizers in $langName]
- Prevention Strategy: [Future crop management steps in $langName]
''';

    try {
      final bytes = await imageFile.readAsBytes();
      final response = await _diseaseModel.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(imageFile.mimeType ?? 'image/jpeg', bytes),
        ])
      ]);
      String text = response.text ?? '';
      
      // Clean up markdown code block wrappers
      text = text.replaceAll(RegExp(r'^```[a-zA-Z]*\n', multiLine: true), '');
      text = text.replaceAll(RegExp(r'\n```$', multiLine: true), '');
      text = text.replaceAll('```', '').trim();

      String diseaseName = '';
      String confidenceScore = '96.0%';
      String treatmentPlan = '';
      String currentSection = '';

      final lines = text.split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final sanitized = trimmed.replaceAll(RegExp(r'^[#* \-_]+'), '').replaceAll('**', '').trim();
        final upper = sanitized.toUpperCase();

        if (upper.startsWith('DISEASE_NAME') || upper.startsWith('DISEASE NAME') || upper.startsWith('DIAGNOSIS') || upper.contains('DISEASE_NAME:')) {
          currentSection = 'disease';
          diseaseName = _extractValue(sanitized);
        } else if (upper.startsWith('CONFIDENCE_SCORE') || upper.startsWith('CONFIDENCE SCORE') || upper.startsWith('CONFIDENCE') || upper.contains('CONFIDENCE_SCORE:')) {
          currentSection = 'confidence';
          confidenceScore = _extractValue(sanitized);
        } else if (upper.startsWith('TREATMENT_PLAN') || upper.startsWith('TREATMENT PLAN') || upper.startsWith('TREATMENT') || upper.contains('TREATMENT_PLAN:')) {
          currentSection = 'treatment';
          final val = _extractValue(sanitized);
          if (val.isNotEmpty && val.toUpperCase() != 'TREATMENT_PLAN' && val.toUpperCase() != 'TREATMENT PLAN') {
            treatmentPlan = val;
          }
        } else if (currentSection == 'treatment') {
          if (treatmentPlan.isNotEmpty) {
            treatmentPlan += '\n' + trimmed;
          } else {
            treatmentPlan = trimmed;
          }
        } else if (currentSection == 'disease' && diseaseName.isNotEmpty && !upper.startsWith('CONFIDENCE') && !upper.startsWith('TREATMENT')) {
          diseaseName += ' ' + sanitized;
        }
      }

      diseaseName = diseaseName.replaceAll(RegExp(r'^[#* \-_:]+'), '').replaceAll('**', '').trim();

      if (diseaseName.isEmpty && text.isNotEmpty) {
        final nonEmpties = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        diseaseName = nonEmpties.isNotEmpty ? nonEmpties.first.replaceAll(RegExp(r'^[#* \-_:]+'), '').replaceAll('**', '').trim() : 'Plant Disease Diagnosis';
        if (diseaseName.length > 70) diseaseName = diseaseName.substring(0, 70) + '...';
        treatmentPlan = text;
      }

      if (diseaseName.isNotEmpty) {
        return {
          'disease': diseaseName,
          'confidence': confidenceScore.isEmpty ? '96.0%' : confidenceScore,
          'recommendation': treatmentPlan.isEmpty ? text : treatmentPlan,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error generating structured plant diagnosis with AI: $e');
      return null;
    }
  }

  /// Generates AI-driven agronomic recommendations based on location, soil type, and season
  Future<Map<String, dynamic>?> getAgronomicRecommendation({
    required String soilType,
    required String season,
    required String location,
  }) async {
    final langName = LanguageProvider.currentLanguageName;
    final langNative = LanguageProvider.currentLanguageNative;
    
    final prompt = '''
You are an expert Indian agricultural scientist and agronomist.
A farmer needs an instant crop recommendation and soil advisory based on the following:
- Farm Location: $location
- Soil Type / Profile: $soilType
- Cultivation Season: $season

IMPORTANT REQUIREMENT: The user's selected language is $langName ($langNative). You MUST generate ALL text values in your response ONLY in $langName ($langNative). Do NOT use English unless English is selected.

Provide your response strictly in the following exact format with NO markdown code blocks around it, exactly matching these keys followed by a colon and your translated text:

MAIN_CROP: [Name of recommended primary crop in $langName]
SECONDARY_CROPS: [Names of 3 alternative suitable crops in $langName]
FERTILIZER_TIP: [Fertilizer & Nutrient Advisory in $langName]
WATER_NEEDS: [Irrigation & Water Strategy in $langName]
SOIL_BENEFITS: [Soil Health Profile & benefits in $langName]
EXPECTED_YIELD: [Estimated harvest yield per hectare in $langName]
''';

    try {
      final response = await _cropModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      
      String mainCrop = '';
      String secondaryCrops = '';
      String fertilizerTip = '';
      String waterNeeds = '';
      String soilBenefits = '';
      String expectedYield = '';
      String currentKey = '';

      final lines = text.split('\n');
      for (var line in lines) {
        var l = line.replaceAll(RegExp(r'^[#* \-_]+'), '').replaceAll('**', '').trim();
        final lUpper = l.toUpperCase();
        if (lUpper.startsWith('MAIN_CROP') || lUpper.startsWith('MAIN CROP') || lUpper.startsWith('PRIMARY CROP') || lUpper.contains('MAIN_CROP:')) {
          currentKey = 'mainCrop';
          mainCrop = _extractValue(l);
        } else if (lUpper.startsWith('SECONDARY_CROPS') || lUpper.startsWith('SECONDARY CROPS') || lUpper.startsWith('ALTERNATIVE CROPS') || lUpper.contains('SECONDARY_CROPS:')) {
          currentKey = 'secondaryCrops';
          secondaryCrops = _extractValue(l);
        } else if (lUpper.startsWith('FERTILIZER_TIP') || lUpper.startsWith('FERTILIZER') || lUpper.startsWith('NUTRIENT') || lUpper.contains('FERTILIZER_TIP:')) {
          currentKey = 'fertilizerTip';
          fertilizerTip = _extractValue(l);
        } else if (lUpper.startsWith('WATER_NEEDS') || lUpper.startsWith('WATER') || lUpper.startsWith('IRRIGATION') || lUpper.contains('WATER_NEEDS:')) {
          currentKey = 'waterNeeds';
          waterNeeds = _extractValue(l);
        } else if (lUpper.startsWith('SOIL_BENEFITS') || lUpper.startsWith('SOIL HEALTH') || lUpper.startsWith('SOIL PROFILE') || lUpper.contains('SOIL_BENEFITS:')) {
          currentKey = 'soilBenefits';
          soilBenefits = _extractValue(l);
        } else if (lUpper.startsWith('EXPECTED_YIELD') || lUpper.startsWith('YIELD') || lUpper.startsWith('ESTIMATED YIELD') || lUpper.contains('EXPECTED_YIELD:')) {
          currentKey = 'expectedYield';
          expectedYield = _extractValue(l);
        } else if (l.isNotEmpty && currentKey.isNotEmpty) {
          if (currentKey == 'mainCrop') mainCrop += ' ' + l;
          else if (currentKey == 'secondaryCrops') secondaryCrops += ' ' + l;
          else if (currentKey == 'fertilizerTip') fertilizerTip += ' ' + l;
          else if (currentKey == 'waterNeeds') waterNeeds += ' ' + l;
          else if (currentKey == 'soilBenefits') soilBenefits += ' ' + l;
          else if (currentKey == 'expectedYield') expectedYield += ' ' + l;
        }
      }

      mainCrop = mainCrop.trim();
      secondaryCrops = secondaryCrops.trim();
      fertilizerTip = fertilizerTip.trim();
      waterNeeds = waterNeeds.trim();
      soilBenefits = soilBenefits.trim();
      expectedYield = expectedYield.trim();

      if (mainCrop.isEmpty && text.isNotEmpty) {
        final nonEmptyLines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        mainCrop = nonEmptyLines.isNotEmpty ? nonEmptyLines[0].replaceAll(RegExp(r'^[#* \-_]+'), '').replaceAll('**', '').trim() : 'AI Recommended Crop';
        secondaryCrops = nonEmptyLines.length > 1 ? nonEmptyLines[1] : 'Suitable rotational crops based on seasonal climate';
        fertilizerTip = nonEmptyLines.length > 2 ? nonEmptyLines[2] : 'Apply balanced organic compost and NPK nutrients';
        waterNeeds = nonEmptyLines.length > 3 ? nonEmptyLines[3] : 'Maintain optimal soil moisture according to crop stage';
        soilBenefits = nonEmptyLines.length > 4 ? nonEmptyLines[4] : 'Enhances long-term soil carbon and structure';
        expectedYield = nonEmptyLines.length > 5 ? nonEmptyLines.sublist(5).join(' ') : 'High yield with recommended agronomic care';
      }

      if (mainCrop.isNotEmpty) {
        return {
          'mainCrop': mainCrop,
          'secondaryCrops': secondaryCrops.isEmpty ? 'Suitable regional crops for $season' : secondaryCrops,
          'fertilizerTip': fertilizerTip.isEmpty ? 'Apply balanced NPK and organic manures' : fertilizerTip,
          'waterNeeds': waterNeeds.isEmpty ? 'Irrigate according to atmospheric evaporative demand' : waterNeeds,
          'soilBenefits': soilBenefits.isEmpty ? 'Improves soil health structure for $soilType' : soilBenefits,
          'expectedYield': expectedYield.isEmpty ? 'Optimal productivity for regional soil profile' : expectedYield,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error generating agronomic recommendation with AI: $e');
      return null;
    }
  }
}

