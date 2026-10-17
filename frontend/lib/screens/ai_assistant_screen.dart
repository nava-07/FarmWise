import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/navigation_provider.dart';
import '../providers/language_provider.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String? ?? '',
    isUser: json['isUser'] as bool? ?? false,
  );
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late ChatSession _chatSession;
  bool _isLoading = false;
  bool _isListening = false;
  final List<ChatMessage> _messages = [];
  bool _voiceEnabled = false;

  @override
  void deactivate() {
    VoiceService().stop();
    super.deactivate();
  }

  @override
  void initState() {
    super.initState();
    _chatSession = AIService().getChatSession();
    _loadSavedChats();
  }

  Future<void> _loadSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('ai_saved_chats') ?? [];
    if (savedList.isNotEmpty && mounted) {
      final loaded = savedList
          .map((item) => ChatMessage.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
      setState(() {
        _messages.clear();
        _messages.addAll(loaded);
      });
      _scrollToBottom();
    } else if (_messages.isEmpty && mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Hello! I am your FarmWise AI Assistant powered by Gemini. How can I help with your crops or weather intel today?',
            isUser: false,
          ),
        );
      });
      _saveChatsToStorage();
    }
  }

  Future<void> _saveChatsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedList = _messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList('ai_saved_chats', encodedList);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          text: 'Hello! I am your FarmWise AI Assistant powered by Gemini. How can I help with your crops or weather intel today?',
          isUser: false,
        ),
      );
    }
  }

  void _clearAllChats() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          text: 'Hello! I am your FarmWise AI Assistant powered by Gemini. How can I help with your crops or weather intel today?',
          isUser: false,
        ),
      );
    });
    _saveChatsToStorage();
    VoiceService().stop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All chats cleared.'.tr(context)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteMessage(int index) {
    setState(() {
      _messages.removeAt(index);
    });
    _saveChatsToStorage();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message deleted.'.tr(context)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showMessageOptions(int index) {
    final msg = _messages[index];
    final text = msg.text;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.volume_up, color: AppColors.primary),
                title: Text('Read Aloud (Voice AI)'.tr(context)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_voiceEnabled) VoiceService().speak(text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Delete Message'.tr(context)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleVoiceAssistant() async {
    if (_isListening) {
      await VoiceService().stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    setState(() {
      _isListening = true;
    });

    final langName = LanguageProvider.currentLanguageName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${'Listening in'.tr(context)} $langName... ${'Speak now.'.tr(context)}'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );

    final spokenText = await VoiceService().listen(onProgress: (text) {
      if (mounted && text.isNotEmpty) {
        setState(() {
          _textController.text = text;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      }
    });
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
    if (spokenText != null && spokenText.isNotEmpty) {
      _textController.text = spokenText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _saveChatsToStorage();
    _scrollToBottom();

    try {
      final langName = LanguageProvider.currentLanguageName;
      final langNative = LanguageProvider.currentLanguageNative;
      final promptedText = 'IMPORTANT REQUIREMENT: The user selected language is $langName ($langNative). You MUST generate your entire response ONLY in $langName ($langNative). Do not use English unless English is selected. Answer concisely and professionally as an agricultural advisor: $text';
      
      final response = await _chatSession.sendMessage(Content.text(promptedText));
      if (!mounted) return;
      final reply = response.text ?? 'I could not generate a response. Please try again.'.tr(context);
      setState(() {
        _messages.add(ChatMessage(
          text: reply,
          isUser: false,
        ));
      });
      _saveChatsToStorage();
      if (_voiceEnabled) VoiceService().speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: '${'Error connecting to AI Assistant:'.tr(context)} $e',
          isUser: false,
        ));
      });
      _saveChatsToStorage();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;

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
        title: Text('AI Agricultural Advisor'.tr(context)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'Clear All Chats'.tr(context),
            onPressed: _clearAllChats,
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(index),
                        onTap: () => _showMessageOptions(index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: msg.isUser ? AppColors.primary : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
                              bottomLeft: !msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            msg.text.tr(context),
                            style: TextStyle(
                              color: msg.isUser ? Colors.white : AppColors.textMain,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Ask about crop care, soil, weather...'.tr(context),
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? AppColors.error : AppColors.primary,
                      ),
                      tooltip: 'Voice Assistant'.tr(context),
                      onPressed: _voiceEnabled ? _toggleVoiceAssistant : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Enable Voice Assistant first (tap speaker icon in AppBar)'.tr(context)),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      backgroundColor: AppColors.primary,
                      elevation: 2,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
