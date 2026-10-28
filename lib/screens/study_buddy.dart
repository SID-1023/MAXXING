// MAXXING STUDY BUDDY
// Dashboard + AI Chat + study notes + quiz + flashcards.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const Color _background = Color(0xFF17132B);
const Color _panel = Color(0xFF241D42);
const Color _cream = Color(0xFFF6EFE3);
const Color _coral = Color(0xFFFF8A65);
const Color _yellow = Color(0xFFFFD66B);
const Color _mint = Color(0xFF7ED9B0);
const Color _muted = Color(0xFFB9B1D0);
const Color _border = Color(0xFF51466F);

// -----------------------------------------------------------------------------
// STUDY BUDDY DASHBOARD (Time-Based Backgrounds + Rain)
// -----------------------------------------------------------------------------

class AiReviewScreen extends StatefulWidget {
  const AiReviewScreen({super.key});

  @override
  State<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends State<AiReviewScreen> {
  String _studySceneAsset = 'assets/images/study_buddy_scene.png';
  Timer? _studySceneTimer;

  @override
  void initState() {
    super.initState();
    _studySceneAsset = _getStudySceneForTime(DateTime.now());
    _studySceneTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshStudyScene(),
    );
  }

  String _getStudySceneForTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11)
      return 'assets/images/study_buddy_scene_morning.png';
    if (hour >= 11 && hour < 16) return 'assets/images/study_buddy_scene.png';
    if (hour >= 16 && hour < 19)
      return 'assets/images/study_buddy_scene_evening.png';
    return 'assets/images/study_buddy_scene_night.png';
  }

  void _refreshStudyScene() {
    if (!mounted) return;
    final nextScene = _getStudySceneForTime(DateTime.now());
    if (nextScene != _studySceneAsset) {
      setState(() => _studySceneAsset = nextScene);
    }
  }

  @override
  void dispose() {
    _studySceneTimer?.cancel();
    super.dispose();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _cream,
        elevation: 0,
        title: const Text(
          'Study Buddy',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            // 1. Study Scene with Time-based Crossfade and Rain
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1000),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: Image.asset(
                        _studySceneAsset,
                        key: ValueKey<String>(_studySceneAsset),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/study_buddy_scene.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder:
                                (context, fallbackError, fallbackStack) {
                                  return const ColoredBox(
                                    color: Color(0xFF17132B),
                                  );
                                },
                          );
                        },
                      ),
                    ),
                    // Rain overlay
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Positioned(
                              left: constraints.maxWidth * 0.335,
                              top: constraints.maxHeight * 0.01,
                              width: constraints.maxWidth * 0.425,
                              height: constraints.maxHeight * 0.42,
                              child: const _RainOverlay(),
                            ),
                          ],
                        );
                      },
                    ),
                    // Subtle shading
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33000000),
                            Color(0x00000000),
                            Color(0x44000000),
                          ],
                        ),
                      ),
                    ),
                    // Label
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _background.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Text(
                          'STUDY DEN',
                          style: TextStyle(
                            color: _yellow,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Main Dashboard Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -5,
                    top: 0,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 78,
                      color: _yellow.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _mint.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'YOUR PERSONAL STUDY SPACE',
                          style: TextStyle(
                            color: _mint,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Learn something\nawesome today.',
                        style: TextStyle(
                          color: _cream,
                          fontSize: 27,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Understand difficult topics, organise your '
                        'notes, and test what you know.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () =>
                            _open(context, const StudyChatScreen()),
                        style: FilledButton.styleFrom(
                          backgroundColor: _yellow,
                          foregroundColor: _background,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text(
                          'Ask a question',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 3. Feature Cards
            const Text(
              'YOUR LEARNING TOOLS',
              style: TextStyle(
                color: _cream,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Choose how you want to learn.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            _StudyFeatureCard(
              icon: Icons.chat_bubble_rounded,
              iconColor: _mint,
              title: 'Ask & Understand',
              subtitle: 'Ask questions and get clear explanations.',
              tag: 'AI LEARNING',
              onTap: () => _open(context, const StudyChatScreen()),
            ),
            const SizedBox(height: 12),
            _StudyFeatureCard(
              icon: Icons.menu_book_rounded,
              iconColor: _yellow,
              title: 'My Study Notes',
              subtitle: 'Write, organise, and review your notes.',
              tag: 'NOTEBOOK',
              onTap: () => _open(context, const StudyNotesScreen()),
            ),
            const SizedBox(height: 12),
            _StudyFeatureCard(
              icon: Icons.psychology_rounded,
              iconColor: _coral,
              title: 'Quiz Challenge',
              subtitle: 'Practise questions and check your answers.',
              tag: 'PRACTICE',
              onTap: () => _open(context, const StudyQuizScreen()),
            ),
            const SizedBox(height: 12),
            _StudyFeatureCard(
              icon: Icons.style_rounded,
              iconColor: const Color(0xFFC8A8FF),
              title: 'Flashcards',
              subtitle: 'Revise concepts one card at a time.',
              tag: 'QUICK REVISION',
              onTap: () => _open(context, const StudyFlashcardsScreen()),
            ),

            const SizedBox(height: 24),

            // 4. Footer Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pets_rounded, color: _yellow, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biscuit says...',
                          style: TextStyle(
                            color: _yellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'You do not have to learn everything at once. '
                          'One small step is still progress!',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  const _StudyFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border.withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _muted,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ASK & UNDERSTAND (REAL AI CHAT)
// -----------------------------------------------------------------------------

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

class StudyChatScreen extends StatefulWidget {
  const StudyChatScreen({super.key});

  @override
  State<StudyChatScreen> createState() => _StudyChatScreenState();
}

class _StudyChatScreenState extends State<StudyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  String _level = 'College';

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            "Hi there! I'm your AI Study Buddy. What subject or topic are we exploring today?",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    // Call the real AI function
    final aiResponse = await _getGeminiResponse(text, _level);

    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(text: aiResponse, isUser: false));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  Future<String> _getGeminiResponse(String query, String level) async {
    const String appId = 'PoV3sm59TQm50Iw5xUl4DZHhOXTm8zqN6FxDFyEE';
    const String restApiKey = 'RHCgKs8UgRpOkt7bRYsV9p8FFWS7CJsR1n4DrMCB';

    final url = Uri.parse('https://parseapi.back4app.com/functions/askGemini');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
        },
        body: jsonEncode({"query": query, "level": level}),
      ).timeout(const Duration(seconds: 30));

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode == 200) {
          return 'Back4App returned an invalid response. Check that the '
              'askGemini function returns JSON with a "result" string.';
        }
      }

      if (response.statusCode != 200) {
        final details = data is Map ? data['error']?.toString() : null;
        final message = details?.isNotEmpty == true
            ? details!
            : response.body.trim();
        return 'Back4App returned HTTP ${response.statusCode}'
            '${message.isEmpty ? '.' : ': $message'}';
      }

      if (data is Map && data['result'] is String) {
        final result = (data['result'] as String).trim();
        if (result.isNotEmpty) return result;
      }
      return 'Back4App received the request, but askGemini did not return '
          'a text result. Check the Cloud Code response format.';
    } on TimeoutException {
      return 'The request to Back4App timed out. Check your connection and '
          'that the askGemini function is responding.';
    } on http.ClientException catch (error) {
      return 'Could not connect to Back4App: ${error.message}';
    }
  }

  void _saveToNotes(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Answer saved to My Study Notes!'),
        backgroundColor: _panel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _cream,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask & Understand',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'AI Tutor',
              style: TextStyle(
                color: _mint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _level,
                dropdownColor: _panel,
                icon: const Icon(Icons.tune_rounded, color: _mint),
                style: const TextStyle(color: _cream, fontSize: 12),
                onChanged: (val) {
                  if (val != null) setState(() => _level = val);
                },
                items: const [
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'School', child: Text('School')),
                  DropdownMenuItem(value: 'College', child: Text('College')),
                  DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildChatBubble(msg);
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _mint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI is thinking...',
                      style: TextStyle(
                        color: _muted.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: _background,
                border: Border(
                  top: BorderSide(color: _border.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: _cream),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask a follow-up question...',
                        hintStyle: const TextStyle(color: _muted, fontSize: 14),
                        filled: true,
                        fillColor: _panel,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: _mint,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: _background),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _mint.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _mint,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? _yellow : _panel,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 18),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? _background : _cream,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 8),
              child: Wrap(
                spacing: 12,
                children: [
                  _actionButton(Icons.copy_rounded, 'Copy', () {}),
                  _actionButton(Icons.note_add_rounded, 'Save to Notes', () {
                    _saveToNotes(msg.text);
                  }),
                  _actionButton(Icons.quiz_rounded, 'Make Quiz', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudyQuizScreen(),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MY STUDY NOTES
// -----------------------------------------------------------------------------

class _StudyNote {
  final String title;
  final String content;
  final DateTime createdAt;

  _StudyNote({
    required this.title,
    required this.content,
    required this.createdAt,
  });
}

class StudyNotesScreen extends StatefulWidget {
  const StudyNotesScreen({super.key});

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  final List<_StudyNote> _notes = [];

  Future<void> _addNote() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<_StudyNote>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('New study note', style: TextStyle(color: _cream)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: _cream),
                decoration: _noteDecoration('Subject or note title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(color: _cream),
                decoration: _noteDecoration('Write your notes here...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: _background,
            ),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (title.isEmpty || content.isEmpty) return;

              Navigator.pop(
                dialogContext,
                _StudyNote(
                  title: title,
                  content: content,
                  createdAt: DateTime.now(),
                ),
              );
            },
            child: const Text('Add note'),
          ),
        ],
      ),
    );

    titleController.dispose();
    contentController.dispose();

    if (!mounted || result == null) return;

    setState(() => _notes.insert(0, result));
  }

  InputDecoration _noteDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 12),
      filled: true,
      fillColor: _background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
    );
  }

  void _viewNote(_StudyNote note) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: Text(note.title, style: const TextStyle(color: _cream)),
        content: SingleChildScrollView(
          child: Text(
            note.content,
            style: const TextStyle(color: _muted, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _cream,
        title: const Text('My Study Notes'),
        actions: [
          IconButton(
            onPressed: _addNote,
            tooltip: 'Add note',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        backgroundColor: _yellow,
        foregroundColor: _background,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('Add note'),
      ),
      body: _notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: _yellow,
                      size: 62,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your notebook starts here',
                      style: TextStyle(
                        color: _cream,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Write down important concepts, formulas, '
                      'definitions, and revision points.',
                      style: TextStyle(color: _muted, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Notes are currently kept in memory while this '
                      'screen is open. They are not yet saved permanently.',
                      style: TextStyle(
                        color: _muted.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];

                return Card(
                  color: _panel,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: _border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x33FFD66B),
                      child: Icon(Icons.description_rounded, color: _yellow),
                    ),
                    title: Text(
                      note.title,
                      style: const TextStyle(
                        color: _cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                    onTap: () => _viewNote(note),
                    trailing: IconButton(
                      tooltip: 'Delete note',
                      onPressed: () {
                        setState(() => _notes.removeAt(index));
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: _coral,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// QUIZ CHALLENGE
// -----------------------------------------------------------------------------

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

const List<_QuizQuestion> _sampleQuestions = [
  _QuizQuestion(
    question: 'Which part of a plant cell performs photosynthesis?',
    options: ['Mitochondrion', 'Chloroplast', 'Nucleus', 'Ribosome'],
    correctIndex: 1,
    explanation:
        'Chloroplasts contain chlorophyll, which captures light energy '
        'used during photosynthesis.',
  ),
  _QuizQuestion(
    question: 'What does CPU stand for?',
    options: [
      'Computer Processing Utility',
      'Central Program Unit',
      'Central Processing Unit',
      'Control Process Utility',
    ],
    correctIndex: 2,
    explanation:
        'CPU stands for Central Processing Unit. It executes instructions '
        'and performs calculations in a computer.',
  ),
  _QuizQuestion(
    question: 'Which data structure follows FIFO?',
    options: ['Stack', 'Queue', 'Tree', 'Graph'],
    correctIndex: 1,
    explanation:
        'A queue follows First In, First Out (FIFO): the first item added '
        'is the first item removed.',
  ),
  _QuizQuestion(
    question: 'What is the chemical formula of water?',
    options: ['CO2', 'O2', 'NaCl', 'H2O'],
    correctIndex: 3,
    explanation:
        'A water molecule contains two hydrogen atoms and one oxygen atom, '
        'giving it the formula H2O.',
  ),
  _QuizQuestion(
    question: 'Which language is primarily used to style web pages?',
    options: ['CSS', 'SQL', 'Python', 'Dart'],
    correctIndex: 0,
    explanation:
        'CSS controls the visual presentation of web pages, including '
        'colours, layouts, fonts, and spacing.',
  ),
];

class StudyQuizScreen extends StatefulWidget {
  const StudyQuizScreen({super.key});

  @override
  State<StudyQuizScreen> createState() => _StudyQuizScreenState();
}

class _StudyQuizScreenState extends State<StudyQuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _finished = false;

  void _selectAnswer(int index) {
    if (_selectedIndex != null) return;

    setState(() {
      _selectedIndex = index;

      if (index == _sampleQuestions[_questionIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_questionIndex == _sampleQuestions.length - 1) {
      setState(() => _finished = true);
      return;
    }

    setState(() {
      _questionIndex++;
      _selectedIndex = null;
    });
  }

  void _restart() {
    setState(() {
      _questionIndex = 0;
      _score = 0;
      _selectedIndex = null;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _cream,
        title: const Text('Quiz Challenge'),
      ),
      body: SafeArea(child: _finished ? _buildResults() : _buildQuestion()),
    );
  }

  Widget _buildQuestion() {
    final question = _sampleQuestions[_questionIndex];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.psychology_rounded, color: _coral, size: 24),
            const SizedBox(width: 8),
            Text(
              'QUESTION ${_questionIndex + 1} OF ${_sampleQuestions.length}',
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_questionIndex + 1) / _sampleQuestions.length,
            minHeight: 6,
            backgroundColor: _panel,
            color: _coral,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          question.question,
          style: const TextStyle(
            color: _cream,
            fontSize: 23,
            height: 1.35,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(question.options.length, (index) {
          final isSelected = _selectedIndex == index;
          final isCorrect = question.correctIndex == index;

          Color borderColor = _border;
          Color backgroundColor = _panel;
          Color textColor = _cream;

          if (_selectedIndex != null && isCorrect) {
            borderColor = _mint;
            backgroundColor = _mint.withValues(alpha: 0.10);
            textColor = _mint;
          } else if (isSelected) {
            borderColor = _coral;
            backgroundColor = _coral.withValues(alpha: 0.10);
            textColor = _coral;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _selectAnswer(index),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question.options[index],
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_selectedIndex != null && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: _mint)
                    else if (isSelected)
                      const Icon(Icons.cancel_rounded, color: _coral),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_selectedIndex != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedIndex == question.correctIndex
                      ? 'Correct! Great work.'
                      : 'Not quite. Keep learning!',
                  style: TextStyle(
                    color: _selectedIndex == question.correctIndex
                        ? _mint
                        : _coral,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  question.explanation,
                  style: const TextStyle(color: _muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _nextQuestion,
              style: FilledButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: _background,
              ),
              child: Text(
                _questionIndex == _sampleQuestions.length - 1
                    ? 'See my results'
                    : 'Next question',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResults() {
    final percentage = (_score / _sampleQuestions.length * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, color: _yellow, size: 78),
            const SizedBox(height: 20),
            const Text(
              'Challenge complete!',
              style: TextStyle(
                color: _cream,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '$_score / ${_sampleQuestions.length}',
              style: const TextStyle(
                color: _yellow,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text('$percentage% correct', style: const TextStyle(color: _muted)),
            const SizedBox(height: 14),
            const Text(
              'Review the explanations and try again to strengthen '
              'your understanding.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _restart,
                style: FilledButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: _background,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Try again',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FLASHCARDS
// -----------------------------------------------------------------------------

class _Flashcard {
  final String topic;
  final String question;
  final String answer;

  const _Flashcard({
    required this.topic,
    required this.question,
    required this.answer,
  });
}

const List<_Flashcard> _sampleFlashcards = [
  _Flashcard(
    topic: 'BIOLOGY',
    question: 'What is photosynthesis?',
    answer:
        'The process by which plants use light energy, water, and carbon '
        'dioxide to produce glucose and release oxygen.',
  ),
  _Flashcard(
    topic: 'COMPUTER SCIENCE',
    question: 'What is an algorithm?',
    answer:
        'A finite, ordered set of instructions used to solve a problem '
        'or complete a task.',
  ),
  _Flashcard(
    topic: 'WEB DEVELOPMENT',
    question: 'What is the purpose of CSS?',
    answer:
        'CSS describes how HTML elements should look, including their '
        'colours, typography, spacing, and layout.',
  ),
  _Flashcard(
    topic: 'MATHEMATICS',
    question: 'What is the formula for the area of a rectangle?',
    answer: 'Area = length × width.',
  ),
];

class StudyFlashcardsScreen extends StatefulWidget {
  const StudyFlashcardsScreen({super.key});

  @override
  State<StudyFlashcardsScreen> createState() => _StudyFlashcardsScreenState();
}

class _StudyFlashcardsScreenState extends State<StudyFlashcardsScreen> {
  int _index = 0;
  bool _showAnswer = false;

  void _move(int amount) {
    setState(() {
      _index = (_index + amount) % _sampleFlashcards.length;

      if (_index < 0) {
        _index += _sampleFlashcards.length;
      }

      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _sampleFlashcards[_index];

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _cream,
        title: const Text('Flashcards'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QUICK REVISION',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  Text(
                    '${_index + 1} / ${_sampleFlashcards.length}',
                    style: const TextStyle(
                      color: _yellow,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _sampleFlashcards.length,
                  minHeight: 5,
                  backgroundColor: _panel,
                  color: _yellow,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showAnswer = !_showAnswer);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _showAnswer ? _mint : _border,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showAnswer
                              ? Icons.lightbulb_rounded
                              : Icons.style_rounded,
                          color: _showAnswer ? _mint : _yellow,
                          size: 42,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          card.topic,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _showAnswer ? _mint : _yellow,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _showAnswer ? card.answer : card.question,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _cream,
                            fontSize: _showAnswer ? 18 : 23,
                            height: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _showAnswer
                              ? 'TAP TO SEE THE QUESTION'
                              : 'TAP TO REVEAL THE ANSWER',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _move(-1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cream,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _move(1),
                      style: FilledButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: _background,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RAIN ANIMATION
// -----------------------------------------------------------------------------

class _RainOverlay extends StatefulWidget {
  const _RainOverlay();

  @override
  State<_RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<_RainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _RainPainter(progress: _controller.value),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  final double progress;

  const _RainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const dropCount = 80;

    for (int i = 0; i < dropCount; i++) {
      final xFraction = ((i * 47) % 101) / 101.0;
      final yStart = ((i * 73) % 103) / 103.0;

      final x = xFraction * size.width;
      final y = ((yStart + progress * 1.5) % 1.0) * size.height;

      final color = i % 3 == 0
          ? const Color(0xFFE0F0FF)
          : const Color(0xFF90C8FF);

      final paint = Paint()
        ..color = color.withValues(alpha: 0.15 + (i % 3) * 0.10)
        ..strokeWidth = i % 4 == 0 ? 1.8 : 1.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, y), Offset(x - 3.0, y + 12 + (i % 5)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
