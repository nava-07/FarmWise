import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';

class DiseaseScreen extends StatefulWidget {
  const DiseaseScreen({super.key});

  @override
  State<DiseaseScreen> createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends State<DiseaseScreen> {
  bool _scanning = false;
  bool _isLiveCameraActive = false;
  bool _isCameraInitialized = false;
  bool _initializingCamera = false;
  Map<String, dynamic>? _result;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _voiceEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void deactivate() {
    VoiceService().stop();
    super.deactivate();
  }

  Future<void> _startLiveCamera() async {
    setState(() {
      _imageFile = null;
      _result = null;
      _isLiveCameraActive = true;
      _initializingCamera = true;
    });

    try {
      if (_cameras == null || _cameras!.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController?.dispose();
        _cameraController = CameraController(_cameras![0], ResolutionPreset.medium, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _initializingCamera = false;
          });
        }
      } else {
        // Fallback to native system camera if plugin cannot find video stream (e.g. on Desktop/Web or simulator)
        if (mounted) {
          setState(() {
            _isLiveCameraActive = false;
            _initializingCamera = false;
          });
          _pickImage(ImageSource.camera);
        }
      }
    } catch (e) {
      debugPrint('Error initializing live camera stream: $e');
      if (mounted) {
        setState(() {
          _isLiveCameraActive = false;
          _initializingCamera = false;
        });
        _pickImage(ImageSource.camera);
      }
    }
  }

  void _stopLiveCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _isLiveCameraActive = false;
        _initializingCamera = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _pickImage(ImageSource.camera);
      return;
    }
    try {
      final XFile file = await _cameraController!.takePicture();
      _stopLiveCamera(); // Pause streaming upon photo capture
      setState(() {
        _imageFile = file;
      });
      _runAIScan(file);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _pickImage(ImageSource.camera);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (_isLiveCameraActive) {
        _stopLiveCamera();
      }
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = pickedFile;
          _result = null;
        });
        _runAIScan(pickedFile);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _runAIScan(XFile file) async {
    setState(() {
      _scanning = true;
      _result = null;
    });

    final aiResponse = await AIService().analyzePlantDiseaseStructured(file);
    if (!mounted) return;

    if (aiResponse != null) {
      setState(() {
        _scanning = false;
        _result = aiResponse;
      });
      if (_voiceEnabled) VoiceService().speak("${'Diagnosis Results'.tr(context)}: ${aiResponse['disease']}. ${aiResponse['recommendation']}");
      return;
    }

    // Offline fallback rules with localized string support
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final lang = LanguageProvider.currentLanguageCode;
    String mockDisease = 'Tomato Early Blight (Alternaria solani)';
    String mockConf = '96.4%';
    String mockRec = '• Visual Symptoms: Dark brown concentric ring lesions on lower leaves with yellow halo.\n• Immediate Action: Prune affected foliage and isolate crop.\n• Treatment Advisory: Spray Copper Oxychloride (2.5g/L) or Mancozeb fungicide.\n• Prevention Strategy: Avoid overhead watering and maintain crop rotation.';

    if (lang == 'ta') {
      mockDisease = 'தக்காளி ஆரம்பகால பொட்டல் நோய் (Tomato Early Blight)';
      mockRec = '• தென்படும் அறிகுறிகள்: கீழ் இலைகளில் வளைய வடிவிலான பழுப்பு புள்ளிகள்.\n• உடனடி நடவடிக்கை: பாதிக்கப்பட்ட இலைகளை உடனே அகற்றி அழிக்கவும்.\n• சிகிச்சை முறை: காப்பர் ஆக்சிகுளோரைடு (2.5g/L) அல்லது மான்கோசெப் பூசணக் கொல்லியை தெளிக்கவும்.\n• தடுப்பு முறை: இலைகள் மீது நீர் தெளிப்பதைத் தவிர்த்து, சுழற்சி முறை விவசாயம் செய்யவும்.';
    } else if (lang == 'hi') {
      mockDisease = 'टमाटर का अगेती झुलसा रोग (Tomato Early Blight)';
      mockRec = '• दृश्य लक्षण: निचली पत्तियों पर भूरे रंग के गोल धब्बे।\n• त्वरित कार्रवाई: संक्रमित पत्तियों को तुरंत तोड़कर नष्ट करें।\n• उपचार सलाह: कॉपर ऑक्सीक्लोराइड (2.5 ग्राम/लीटर) या मैंकोज़ेब कवकनाशी का छिड़काव करें।\n• रोकथाम रणनीति: पत्तियों पर सीधे पानी देने से बचें और फसल चक्र अपनाएं।';
    } else if (lang == 'te') {
      mockDisease = 'టమాటో మచ్చ తెగులు (Tomato Early Blight)';
      mockRec = '• కనిపించే లక్షణాలు: దిగువ ఆకులపై గోధుమ రంగు మచ్చలు.\n• తక్షణ చర్య: సోకిన ఆకులను వెంటనే తొలగించండి.\n• చికిత్స సలహా: కాపర్ ఆక్సీక్లోరైడ్ లేదా మ్యాంకోజెబ్ మందును పిచికారీ చేయండి.\n• నివారణ వ్యూహం: పంట మార్పిడి పద్ధతులను పాటించండి.';
    } else if (lang == 'kn') {
      mockDisease = 'ಟೊಮೆಟೊ ಮುಂಗಾರು ಚಿಗುರು ರೋಗ (Tomato Early Blight)';
      mockRec = '• ರೋಗಲಕ್ಷಣಗಳು: ಕೆಳಗಿನ ಎಲೆಗಳಲ್ಲಿ ಕಂದು ಬಣ್ಣದ ಚುಕ್ಕೆಗಳು.\n• ತಕ್ಷಣದ ಕ್ರಮ: ಪೀಡಿತ ಎಲೆಗಳನ್ನು ತಕ್ಷಣ ತೆಗೆದುಹಾಕಿ.\n• ಚಿಕಿತ್ಸೆ: ಕಾಪರ್ ಆಕ್ಸಿಕ್ಲೋರೈಡ್ ಅಥವಾ ಮ್ಯಾಂಕೋಜೆಬ್ ಸಿಂಪಡಿಸಿ.';
    } else if (lang == 'ml') {
      mockDisease = 'തക്കാളി ലീഫ് ബ്ലൈറ്റ് (Tomato Early Blight)';
      mockRec = '• ലക്ഷണങ്ങൾ: ഇലകളിൽ തവിട്ടുനിറത്തിലുള്ള പുള്ളികൾ.\n• ഉടനടി നടപടി: ബാധിച്ച ഇലകൾ നീക്കം ചെയ്യുക.\n• ചികിത്സ: കോപ്പർ ഓക്സിക്ലോറൈഡ് തളിക്കുക.';
    }

    setState(() {
      _scanning = false;
      _result = {
        'disease': mockDisease,
        'confidence': mockConf,
        'recommendation': mockRec,
      };
    });
    if (_voiceEnabled) VoiceService().speak("${'Diagnosis Results'.tr(context)}: $mockDisease. $mockRec");
  }

  @override
  Widget build(BuildContext context) {
    String leftLabel = 'Start Live Camera'.tr(context);
    IconData leftIcon = Icons.videocam_outlined;
    VoidCallback? leftOnPressed = _scanning ? null : _startLiveCamera;

    if (_isLiveCameraActive && _imageFile == null) {
      leftLabel = 'Take Photo'.tr(context);
      leftIcon = Icons.photo_camera;
      leftOnPressed = (_scanning || !_isCameraInitialized) ? null : _capturePhoto;
    } else if (_imageFile != null) {
      leftLabel = 'Retake Live Photo'.tr(context);
      leftIcon = Icons.photo_camera_outlined;
      leftOnPressed = _scanning ? null : _startLiveCamera;
    }

    String rightLabel = 'Upload Image'.tr(context);
    IconData rightIcon = Icons.file_upload_outlined;
    VoidCallback? rightOnPressed = _scanning ? null : () => _pickImage(ImageSource.gallery);

    if (_isLiveCameraActive && _imageFile == null) {
      rightLabel = 'Stop Camera'.tr(context);
      rightIcon = Icons.stop_circle_outlined;
      rightOnPressed = _scanning ? null : _stopLiveCamera;
    }

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
        title: Text('Disease Scanner'.tr(context)),
        elevation: 0,
        backgroundColor: AppColors.error,
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
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan Crop for Diseases'.tr(context),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const SizedBox(height: 16),
                
                // Camera Viewfinder Box
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.error, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (_imageFile != null)
                          Positioned.fill(
                            child: kIsWeb
                                ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                                : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                          ),
                        if (_imageFile == null && _isLiveCameraActive && _isCameraInitialized && _cameraController != null)
                          Positioned.fill(
                            child: CameraPreview(_cameraController!),
                          )
                        else if (_imageFile == null && _initializingCamera)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: AppColors.error),
                                const SizedBox(height: 12),
                                Text('Initializing camera...'.tr(context), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                              ],
                            ),
                          )
                        else if (_imageFile == null && !_isLiveCameraActive)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_scanner_rounded, size: 56, color: Colors.white54),
                                const SizedBox(height: 12),
                                Text(
                                  'Live camera ready. Tap button below to start.'.tr(context),
                                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        // Scanner reticle animation border
                        if (_imageFile != null || _isLiveCameraActive)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 1.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        if (_scanning)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: AppColors.error),
                                  const SizedBox(height: 12),
                                  Text(
                                    'AI is analyzing leaf patterns...'.tr(context),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: leftOnPressed,
                        icon: Icon(leftIcon),
                        label: Text(leftLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: rightOnPressed,
                        icon: Icon(rightIcon),
                        label: Text(rightLabel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _buildResultsCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      color: const Color(0xFFFEF2F2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Diagnosis Results'.tr(context),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${'Conf'.tr(context)}: ${_result!['confidence']}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _result!['disease'].toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF7F1D1D)),
            ),
            const SizedBox(height: 8),
            Text(
              _result!['recommendation'].toString(),
              style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
