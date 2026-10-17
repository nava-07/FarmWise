import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../providers/language_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/voice_service.dart';
import '../theme.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _isListening = false;
  final _scrollController = ScrollController();
  bool _voiceEnabled = false;

  @override
  void deactivate() {
    VoiceService().stop();
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add({
        'text': 'Hello! I am your AI Farming Assistant. How can I help you today?',
        'isUser': false,
      });
    }
  }

  void _clearAllChats() {
    setState(() {
      _messages.clear();
      _messages.add({
        'text': 'Hello! I am your AI Farming Assistant. How can I help you today?',
        'isUser': false,
      });
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message deleted.'.tr(context)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showMessageOptions(int index) {
    final msg = _messages[index];
    final text = msg['text'] as String;

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

    final spokenText = await VoiceService().listen();
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
    if (spokenText != null && spokenText.isNotEmpty) {
      _messageController.text = spokenText;
      _sendMessage();
    } else {
      if (_voiceEnabled) VoiceService().speak('I am ready to listen in $langName. Please type or speak your agricultural question.'.tr(context));
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _loading = true;
    });
    _scrollToBottom();

    final langName = LanguageProvider.currentLanguageName;
    final langNative = LanguageProvider.currentLanguageNative;

    try {
      final promptedText = 'IMPORTANT REQUIREMENT: The user selected language is $langName ($langNative). You MUST generate your entire response ONLY in $langName ($langNative). Do not use English unless English is selected. Answer concisely and professionally as an agricultural advisor: $text';
      
      final chatSession = AIService().getChatSession();
      final response = await chatSession.sendMessage(Content.text(promptedText));
      if (!mounted) return;
      final reply = response.text ?? 'I could not generate a response. Please try again.'.tr(context);
      setState(() {
        _messages.add({'text': reply, 'isUser': false});
      });
      if (_voiceEnabled) VoiceService().speak(reply);
    } catch (e) {
      if (!mounted) return;
      final fallbackReply = 'For optimal yields, ensure balanced NPK application and consistent soil moisture.'.tr(context);
      setState(() {
        _messages.add({'text': fallbackReply, 'isUser': false});
      });
      if (_voiceEnabled) VoiceService().speak(fallbackReply);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Home'.tr(context),
          onPressed: () {
            VoiceService().stop();
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
            }
          },
        ),
        title: Text('AI Assistant'.tr(context)),
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
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'Clear All Chats'.tr(context),
            onPressed: _clearAllChats,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: () => _showMessageOptions(index),
                    onTap: () => _showMessageOptions(index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isUser
                              ? const Radius.circular(16)
                              : Radius.zero,
                          bottomRight: isUser
                              ? Radius.zero
                              : const Radius.circular(16),
                        ),
                        border: isUser
                            ? null
                            : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        (msg['text'] as String).tr(context),
                        style: TextStyle(
                          color: isUser ? Colors.white : AppColors.textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type your farming question...'.tr(context),
                      hintStyle: const TextStyle(color: AppColors.textLight),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
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
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
