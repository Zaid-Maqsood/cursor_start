import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType

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

  final String backendUrl = 'http://127.0.0.1:8000/api/chat/';

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
    if (message.isEmpty && _imageBytes == null) return;

    setState(() {
      _messages.add({'role': 'user', 'content': message, 'image': _imageBytes});
      _controller.clear();
      _selectedImage = null;
      _imageBytes = null;
    });

    var uri = Uri.parse(backendUrl);
    var request = http.MultipartRequest('POST', uri);
    request.fields['message'] = message;

    if (_imageBytes != null && _selectedImage != null) {
      // Try to detect the content type from the file name
      String? mimeType = _selectedImage!.type;
      String mainType = 'image';
      String subType = 'jpeg';
      if (mimeType != null && mimeType.contains('/')) {
        final parts = mimeType.split('/');
        mainType = parts[0];
        subType = parts[1];
      }
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        _imageBytes!,
        filename: _selectedImage!.name,
        contentType: MediaType(mainType, subType),
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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