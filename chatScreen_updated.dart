import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'session_manager.dart';

// Platform-specific imports
import 'dart:html' as html show FileUploadInputElement, FileReader, File;
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  // Universal variables that work for both platforms
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageContentType;
  
  // Medical PDF variables
  Uint8List? _medicalPdfBytes;
  String? _medicalPdfName;
  html.File? _webMedicalPdfFile;
  io.File? _mobileMedicalPdfFile;
  bool _hasMedicalReport = false;
  
  // Mobile-specific variables  
  io.File? _mobileImageFile;
  final ImagePicker _picker = ImagePicker();
  
  // Web-specific variables
  html.File? _webImageFile;
  
  bool _isSending = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Uri backendUrl = Uri.parse("https://zaidmaq.pythonanywhere.com/api/chat/");

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

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final file = uploadInput.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        reader.onLoadEnd.listen((event) {
          setState(() {
            _webImageFile = file;
            _imageBytes = reader.result as Uint8List;
            _imageName = file.name;
            _imageContentType = file.type.isNotEmpty ? file.type : _getContentType(file.name);
            _mobileImageFile = null;
          });
        });
      });
    } else {
      try {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        
        if (pickedFile != null) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _mobileImageFile = io.File(pickedFile.path);
            _imageBytes = bytes;
            _imageName = pickedFile.name;
            _imageContentType = pickedFile.mimeType ?? _getContentType(pickedFile.name);
            _webImageFile = null;
          });
        }
      } catch (e) {
        print('Error picking image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _pickMedicalReport() async {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement();
      uploadInput.accept = '.pdf,application/pdf';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final file = uploadInput.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        reader.onLoadEnd.listen((event) {
          setState(() {
            _webMedicalPdfFile = file;
            _medicalPdfBytes = reader.result as Uint8List;
            _medicalPdfName = file.name;
            _hasMedicalReport = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Medical report uploaded: ${file.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF upload is currently available on web only'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearMedicalReport() {
    setState(() {
      _webMedicalPdfFile = null;
      _mobileMedicalPdfFile = null;
      _medicalPdfBytes = null;
      _medicalPdfName = null;
      _hasMedicalReport = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medical report cleared'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    if (_controller.text.trim().isEmpty && _imageBytes == null) return;
    
    setState(() {
      _isSending = true;
    });

    final message = _controller.text.trim();

    try {
      var request = http.MultipartRequest('POST', backendUrl);
      
      request.fields['message'] = message;
      request.fields['session_id'] = SessionManager.sessionId;

      // Add medical PDF if present
      if (_medicalPdfBytes != null) {
        final stream = http.ByteStream.fromBytes(_medicalPdfBytes!);
        final length = _medicalPdfBytes!.length;
        request.files.add(http.MultipartFile(
          'medical_report',
          stream,
          length,
          filename: _medicalPdfName ?? 'medical_report.pdf',
          contentType: MediaType.parse('application/pdf'),
        ));
      }

      // Handle image upload
      if (kIsWeb && _webImageFile != null && _imageBytes != null) {
        final stream = http.ByteStream.fromBytes(_imageBytes!);
        final length = _imageBytes!.length;
        request.files.add(http.MultipartFile(
          'image',
          stream,
          length,
          filename: _imageName ?? 'image.jpg',
          contentType: MediaType.parse(_imageContentType ?? 'image/jpeg'),
        ));
      } else if (!kIsWeb && _mobileImageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _mobileImageFile!.path,
          contentType: MediaType.parse(_imageContentType ?? 'image/jpeg'),
          filename: _imageName,
        ));
      }

      setState(() {
        _messages.add({
          'role': 'user', 
          'content': message.isEmpty ? 'Analyze this image' : message, 
          'image': _imageBytes,
          'hasMedicalReport': _hasMedicalReport,
        });
        _controller.clear();
        _clearImageSelection();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({
            'role': 'ai', 
            'content': data['response'] ?? 'No response received',
            'medical_context_used': data['medical_context_used'] ?? false,
          });
        });
        
        if (data['session_id'] != null && data['session_id'] != SessionManager.sessionId) {
          SessionManager.setSessionId(data['session_id']);
        }
      } else {
        setState(() {
          _messages.add({
            'role': 'ai', 
            'content': 'Error: Could not get reply 😢 (Status: ${response.statusCode})'
          });
        });
        print('Backend error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'ai', 
          'content': 'Network error: Please check your connection 🌐'
        });
      });
      print('Network error: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _clearImageSelection() {
    _webImageFile = null;
    _mobileImageFile = null;
    _imageBytes = null;
    _imageName = null;
    _imageContentType = null;
  }

  Widget _buildMessage(Map<String, dynamic> message, double maxBubbleWidth, double fontSize) {
    final isUser = message['role'] == 'user';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              decoration: BoxDecoration(
                gradient: isUser 
                  ? const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser 
                      ? Colors.purple.withOpacity(0.3)
                      : Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (isUser && message['hasMedicalReport'] == true)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '📋 Medical report included',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    
                    if (!isUser && message['medical_context_used'] == true)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🏥 Personalized advice',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    
                    if (message['image'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            message['image'],
                            height: 150,
                            width: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (message['content'] != '')
                      Text(
                        message['content'],
                        style: TextStyle(
                          fontSize: fontSize,
                          color: isUser ? Colors.white : Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.person_rounded,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalReportCard() {
    if (!_hasMedicalReport) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Medical report: ${_medicalPdfName ?? "Uploaded"}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 16),
            onPressed: _clearMedicalReport,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Welcome to NutriLens!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Upload a photo of your food and I'll analyze its nutritional content, calories, and health benefits for you!",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureChip("📸 Photo Analysis"),
              const SizedBox(width: 8),
              _buildFeatureChip("🔢 Calorie Count"),
              const SizedBox(width: 8),
              _buildFeatureChip("🥗 Nutrition Facts"),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickMedicalReport,
              icon: Icon(Icons.medical_services_rounded, color: Colors.white),
              label: Text(
                'Upload Medical Report (PDF)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Upload your medical report for personalized health advice",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      width: 1,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.6),
            Colors.white.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    final double maxChatWidth = isMobile ? screenWidth : (isTablet ? 700 : 900);
    final double maxBubbleWidth = maxChatWidth * (isMobile ? 0.85 : 0.7);
    final double fontSize = isMobile ? 15 : (isTablet ? 16 : 17);
    final double sidebarWidth = isDesktop ? 250 : (isTablet ? 200 : 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NutriLens',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Smart Food Analysis',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _hasMedicalReport ? Icons.medical_services_rounded : Icons.medical_services_outlined,
              color: _hasMedicalReport ? Colors.green : Colors.white,
            ),
            onPressed: _pickMedicalReport,
            tooltip: 'Upload Medical Report',
          ),
          if (!isMobile)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              onPressed: () {
                // Settings functionality
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Row(
                children: [
                  if (!isMobile) ...[
                    SizedBox(width: sidebarWidth),
                    _buildSeparator(),
                  ],
                  
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxChatWidth),
                        child: Column(
                          children: [
                            _buildMedicalReportCard(),
                            
                            Expanded(
                              child: _messages.isEmpty
                                  ? SingleChildScrollView(
                                      child: _buildWelcomeMessage(),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: _buildMessage(_messages[index], maxBubbleWidth, fontSize),
                                        );
                                      },
                                    ),
                            ),
                            
                            if (_imageBytes != null)
                              Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _imageBytes!,
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _imageName ?? "Image ready to analyze",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _clearImageSelection();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            
                            Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 24),
                                      onPressed: _pickImage,
                                      tooltip: 'Upload Food Image',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      decoration: InputDecoration(
                                        hintText: _imageBytes != null 
                                          ? 'Add a message (optional)...'
                                          : 'Upload a food image to get started...',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: fontSize,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                      style: TextStyle(fontSize: fontSize),
                                      onSubmitted: (_) => _sendMessage(),
                                      maxLines: null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: _isSending 
                                        ? null 
                                        : const LinearGradient(
                                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                      color: _isSending ? Colors.grey[300] : null,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: IconButton(
                                      icon: _isSending
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                              ),
                                            )
                                          : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                                      onPressed: _isSending ? null : _sendMessage,
                                      tooltip: 'Send Message',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  if (!isMobile) ...[
                    _buildSeparator(),
                    SizedBox(width: sidebarWidth),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 