import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown_selectionarea.dart';

class AiHintPage extends StatefulWidget {
  final Map<String, dynamic> problem;
  const AiHintPage({super.key, required this.problem});

  @override
  State<AiHintPage> createState() => _AiHintPageState();
}

class _AiHintPageState extends State<AiHintPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  String? _cachedTutorial;

  @override
  void initState() {
    super.initState();
    _addMessage("ai",
        "Hello! I see you're working on **${widget.problem['name']}**. \n\nBefore I give a hint, what approach have you tried so far?");
  }

  void _addMessage(String role, String text) {
    if (!mounted) return;
    setState(() {
      _messages.add({'role': role, 'text': text});
    });

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
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _addMessage("user", text);
    setState(() => _isTyping = true);

    try {
      if (_cachedTutorial == null) {
        _cachedTutorial = await ApiService.getScrapedTutorial(
          widget.problem['contestId'],
          widget.problem['index'],
        );
      }

      List<String> history = _messages
          .map((m) =>
              "${m['role'] == 'user' ? 'Student' : 'Coach'}: ${m['text']}")
          .toList();

      final response = await ApiService.getRealAiHint(
        problemName: widget.problem['name'],
        contestId: widget.problem['contestId'],
        index: widget.problem['index'],
        tags: widget.problem['tags'] ?? [],
        rating: widget.problem['rating'] ?? 800,
        userQuery: text,
        previousChatHistory: history,
        tutorialContext: _cachedTutorial,
      );

      if (mounted) {
        setState(() => _isTyping = false);
        _addMessage("ai", response);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTyping = false);
        _addMessage("ai",
            "I'm having trouble connecting to my brain. Please try again!");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      appBar: AppBar(
        title: const Text("AI Coach"),
        backgroundColor: const Color(0xFF1B1D3A),
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
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF7B61FF)
                          : const Color(0xFF212436),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft:
                            isUser ? const Radius.circular(12) : Radius.zero,
                        bottomRight:
                            isUser ? Radius.zero : const Radius.circular(12),
                      ),
                    ),
                    child: isUser
                        ? Text(msg['text']!,
                            style: const TextStyle(color: Colors.white))
                        : MarkdownBody(
                            data: msg['text']!,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  color: Colors.white70, fontSize: 16),
                              strong: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              code: const TextStyle(
                                backgroundColor: Colors.black26,
                                fontFamily: 'monospace',
                                color: Color(0xFF7B61FF),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("AI is thinking...",
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1B1D3A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ask for a hint...",
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
