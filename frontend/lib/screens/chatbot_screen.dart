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
  ChatSession? _chatSession;

  @override
  void initState() {
    super.initState();
    _chatSession = AIService().getChatSession();
  }

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
    _chatSession = AIService().getChatSession();
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
      final promptedText = 'You are a senior agricultural advisor and plant scientist. The farmer speaks $langName ($langNative). You MUST answer completely in $langName ($langNative). Provide a clear, thorough, and scientifically accurate agricultural answer with practical steps: $text';
      
      _chatSession ??= AIService().getChatSession();
      final response = await _chatSession!.sendMessage(Content.text(promptedText));
      if (!mounted) return;
      final reply = response.text ?? 'I could not generate a response. Please try again.'.tr(context);
      setState(() {
        _messages.add({'text': reply, 'isUser': false});
      });
      if (_voiceEnabled) VoiceService().speak(reply);
    } catch (e) {
      debugPrint('Chat error: $e');
      if (!mounted) return;
      // Try a fresh chat session fallback if previous session had an issue
      try {
        _chatSession = AIService().getChatSession();
        final response = await _chatSession!.sendMessage(Content.text('Please answer in $langName ($langNative) as an expert farming advisor: $text'));
        final reply = response.text;
        if (reply != null && reply.isNotEmpty) {
          setState(() {
            _messages.add({'text': reply, 'isUser': false});
          });
          if (_voiceEnabled) VoiceService().speak(reply);
          return;
        }
      } catch (_) {}

      final fallbackReply = 'For optimal yields, ensure balanced NPK application, regular pest monitoring, and consistent soil moisture according to your crop cycle.'.tr(context);
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
          _buildVoiceAssistantCard(),
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
          if (_isListening)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.graphic_eq, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${'Listening in'.tr(context)} ${LanguageProvider.currentLanguageName}... ${'Speak now.'.tr(context)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _isListening ? Colors.red.shade300 : Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening to your voice... Speak now! 🎙️'.tr(context)
                          : 'Type your farming question...'.tr(context),
                      hintStyle: TextStyle(
                        color: _isListening ? Colors.red.shade700 : AppColors.textLight,
                        fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: _isListening ? const Color(0xFFFEF2F2) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _isListening ? Colors.red.shade400 : Colors.grey.shade300,
                          width: _isListening ? 2.0 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _isListening ? Colors.red : AppColors.primary,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : AppColors.primary,
                    ),
                    tooltip: _isListening ? 'Stop Listening'.tr(context) : 'Voice Typing'.tr(context),
                    onPressed: _toggleVoiceAssistant,
                  ),
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

  Widget _buildVoiceAssistantCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _voiceEnabled ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _voiceEnabled ? AppColors.primary : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _voiceEnabled ? AppColors.primary : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _voiceEnabled ? 'Voice Assistant: ON'.tr(context) : 'Voice Assistant: OFF'.tr(context),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _voiceEnabled ? AppColors.primary : AppColors.textMain,
                  ),
                ),
                Text(
                  _voiceEnabled
                      ? 'Reads AI responses aloud in ${LanguageProvider.currentLanguageName}'
                      : 'Turn on to hear spoken answers'.tr(context),
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _voiceEnabled,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _voiceEnabled = val;
                if (!_voiceEnabled) {
                  VoiceService().stop();
                } else {
                  VoiceService().speak('Voice Assistant is now active'.tr(context));
                }
              });
            },
          ),
        ],
      ),
    );
  }
}
