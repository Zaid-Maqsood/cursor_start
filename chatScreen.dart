import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'session_manager.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  html.File? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSending = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Uri backendUrl = Uri.parse("https://mzaid.pythonanywhere.com/api/chat/");

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final file = uploadInput.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((event) {
        setState(() {
          _selectedImage = file;
          _imageBytes = reader.result as Uint8List;
        });
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    if (_controller.text.trim().isEmpty && _imageBytes == null) return;
    
    setState(() {
      _isSending = true;
    });

    final message = _controller.text.trim();

    var request = http.MultipartRequest('POST', backendUrl);
    request.headers['Content-Type'] = 'multipart/form-data';
    request.fields['message'] = message;
    request.fields['session_id'] = SessionManager.sessionId;

    if (_selectedImage != null && _imageBytes != null) {
      final stream = http.ByteStream.fromBytes(_imageBytes!);
      final length = _imageBytes!.length;
      request.files.add(http.MultipartFile(
        'image',
        stream,
        length,
        filename: _selectedImage!.name,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    setState(() {
      _messages.add({'role': 'user', 'content': message, 'image': _imageBytes});
      _controller.clear();
      _selectedImage = null;
      _imageBytes = null;
    });

    // Scroll to bottom after adding user message
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      print('Sending request to: $backendUrl');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('Response status: ${response.statusCode}');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String responseText = data['response'] ?? 'No response received';
        
        print('Response text length: ${responseText.length}');
        
        // Truncate response if it's too long
        if (responseText.length > 3000) {
          responseText = responseText.substring(0, 3000) + '...\n\n[Response truncated due to length]';
        }
        
        setState(() {
          _messages.add({'role': 'ai', 'content': responseText});
        });
      } else {
        print('Error status code: ${response.statusCode}');
        print('Error response: ${response.body}');
        setState(() {
          _messages.add({'role': 'ai', 'content': 'Error: Server returned status ${response.statusCode} 😢'});
        });
      }
    } catch (e) {
      print('Network error: $e');
      setState(() {
        _messages.add({'role': 'ai', 'content': 'Network error: Please check your connection 🌐\nError: $e'});
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      
      // Scroll to bottom after AI response
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message['image'] != null)
              Image.memory(
                message['image'],
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            if (message['content'] != '')
              Flexible(
                child: Text(
                  message['content'],
                  style: const TextStyle(fontSize: 16),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chatbot')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.memory(
                _imageBytes!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration:
                      const InputDecoration(hintText: 'Type your message...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
} 