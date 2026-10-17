import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/language_provider.dart';

/// VoiceService manages Speech-to-Text (listening) and Text-to-Speech (speaking)
/// strictly tailored to the user's selected language in LanguageProvider.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();

  factory VoiceService() => _instance;

  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _speechInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;

  /// Speaks the given text aloud using the currently selected language locale.
  /// AI voice responses must always match the selected language.
  Future<void> speak(String text) async {
    final locale = LanguageProvider.currentLocaleCode.replaceAll('_', '-');
    final langName = LanguageProvider.currentLanguageName;
    debugPrint('🎙️ [VoiceService TTS ($langName / $locale)]: $text');

    try {
      _isSpeaking = true;
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
      _isSpeaking = false;
    } catch (e) {
      debugPrint('Error speaking TTS: $e');
      _isSpeaking = false;
    }
  }

  /// Stops any currently playing speech or active listening session.
  Future<void> stop() async {
    _isSpeaking = false;
    _isListening = false;
    try {
      await _tts.stop();
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
    debugPrint('🛑 [VoiceService]: Stopped audio.');
  }

  /// Starts listening to user voice input using the currently selected language locale.
  /// Streams recognized words in real-time via [onProgress], typing content directly in preferred language.
  Future<String?> listen({Function(String text)? onProgress}) async {
    final locale = LanguageProvider.currentLocaleCode; // e.g., 'ta_IN', 'hi_IN', 'te_IN', 'en_IN'
    final langCode = LanguageProvider.currentLanguageCode; // e.g., 'ta', 'hi', 'te', 'en'
    final langName = LanguageProvider.currentLanguageName;
    debugPrint('🎧 [VoiceService STT Listening in ($langName / $locale)]...');

    _isListening = true;
    final Completer<String?> completer = Completer<String?>();
    String lastWords = '';

    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onStatus: (status) {
            debugPrint('🎧 [VoiceService Status]: $status');
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
              if (!completer.isCompleted) {
                completer.complete(lastWords.isNotEmpty ? lastWords : null);
              }
            }
          },
          onError: (errorNotification) {
            debugPrint('🎧 [VoiceService Error]: ${errorNotification.errorMsg}');
            _isListening = false;
            if (!completer.isCompleted) {
              completer.complete(lastWords.isNotEmpty ? lastWords : null);
            }
          },
        );
      }

      if (_speechInitialized) {
        List<stt.LocaleName> locales = await _speech.locales();
        String selectedLocaleId = locale.replaceAll('_', '-'); // default fallback e.g. ta-IN
        
        stt.LocaleName? match;
        for (var l in locales) {
          if (l.localeId.replaceAll('_', '-').toLowerCase() == selectedLocaleId.toLowerCase() ||
              l.localeId.replaceAll('_', '-').toLowerCase() == locale.toLowerCase()) {
            match = l;
            break;
          }
        }

        if (match == null) {
          for (var l in locales) {
            if (l.localeId.toLowerCase().startsWith(langCode.toLowerCase())) {
              match = l;
              break;
            }
          }
        }

        if (match != null) {
          selectedLocaleId = match.localeId;
        }

        debugPrint('🎧 [VoiceService]: Using speech localeId: $selectedLocaleId');

        await _speech.listen(
          onResult: (result) {
            lastWords = result.recognizedWords;
            debugPrint('🎧 [VoiceService Recognized]: $lastWords');
            if (onProgress != null && lastWords.isNotEmpty) {
              onProgress(lastWords);
            }
            if (result.finalResult && !completer.isCompleted) {
              _isListening = false;
              completer.complete(lastWords.isNotEmpty ? lastWords : null);
            }
          },
          localeId: selectedLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        );
      } else {
        debugPrint('🎧 [VoiceService]: SpeechToText initialization failed or unavailable on this browser/device.');
        _isListening = false;
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    } catch (e) {
      debugPrint('Error starting speech listening: $e');
      _isListening = false;
      if (!completer.isCompleted) {
        completer.complete(lastWords.isNotEmpty ? lastWords : null);
      }
    }

    // Backup safety timeout
    Future.delayed(const Duration(seconds: 35), () {
      if (!completer.isCompleted) {
        _isListening = false;
        completer.complete(lastWords.isNotEmpty ? lastWords : null);
      }
    });

    return completer.future;
  }
}
