import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:uuid/uuid.dart'; // For session ID

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  html.File? _selectedImage;
  Uint8List? _imageBytes;

  final Uri backendUrl = Uri.parse("https://mzaid.pythonanywhere.com/api/chat/");
  late String sessionId;

  @override
  void initState() {
    super.initState();
    // Generate a unique session ID for this chat session
    sessionId = const Uuid().v4();
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
    final message = _controller.text.trim();
    print('Message: $message');
    print('Image selected:  [32m${_selectedImage != null} [0m');
    if (_selectedImage != null && _imageBytes != null) {
      print('Image filename: ${_selectedImage!.name}');
      print('Image bytes length: ${_imageBytes!.length}');
    }

    if (message.isEmpty && _imageBytes == null) return;

    final uri = backendUrl;
    var request = http.MultipartRequest('POST', uri);
    request.fields['message'] = message;
    request.fields['session_id'] = sessionId;

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

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    setState(() {
      _messages.add({'role': 'user', 'content': message, 'image': _imageBytes});
      _controller.clear();
      _selectedImage = null;
      _imageBytes = null;
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _messages.add({'role': 'ai', 'content': data['response']});
      });
    } else {
      setState(() {
        _messages.add({'role': 'ai', 'content': 'Error: Could not get reply 😢'});
      });
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
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
              Text(
                message['content'],
                style: const TextStyle(fontSize: 16),
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