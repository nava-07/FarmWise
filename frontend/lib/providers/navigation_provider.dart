import 'package:flutter/material.dart';
import '../services/voice_service.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      // Stop any active voice playback/listening when switching modules
      VoiceService().stop();
      _currentIndex = index;
      notifyListeners();
    }
  }
}
