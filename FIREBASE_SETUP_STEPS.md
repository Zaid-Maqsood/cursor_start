# Firebase Setup Step-by-Step Guide

## 🔧 **Step 1: Get Firebase Service Account Key**

### **1.1 Go to Firebase Console**
1. Visit [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click the **gear icon** (⚙️) next to "Project Overview" to open Project Settings
4. Click on the **"Service accounts"** tab

### **1.2 Generate Service Account Key**
1. Click **"Generate new private key"** button
2. Click **"Generate key"** in the popup
3. Download the JSON file (it will be named something like `your-project-firebase-adminsdk-xxxxx-xxxxxxxxxx.json`)

### **1.3 Store the Key File**
1. Create a `keys` folder in your project root:
   ```bash
   mkdir keys
   ```
2. Move the downloaded JSON file to the `keys` folder
3. **IMPORTANT**: Add `keys/` to your `.gitignore` file to keep it secure:
   ```
   # Add this to .gitignore
   keys/
   *.json
   ```

## 🔧 **Step 2: Configure Environment Variables**

### **2.1 Update Your .env File**
Add this line to your `.env` file:
```env
FIREBASE_SERVICE_ACCOUNT_KEY=keys/your-project-firebase-adminsdk-xxxxx-xxxxxxxxxx.json
```

**Replace** `your-project-firebase-adminsdk-xxxxx-xxxxxxxxxx.json` with your actual filename.

### **2.2 Example .env File**
Your `.env` file should look like this:
```env
# Django Configuration
DJANGO_SECRET_KEY=your_django_secret_key_here
DEBUG=True

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Pinecone Configuration
PINECONE_API_KEY=your_pinecone_api_key_here
PINECONE_ENVIRONMENT=us-east-1-aws
PINECONE_INDEX_NAME=chatbot-index

# Firebase Configuration
FIREBASE_SERVICE_ACCOUNT_KEY=keys/your-project-firebase-adminsdk-xxxxx-xxxxxxxxxx.json
```

## 🔧 **Step 3: Test Firebase Setup**

### **3.1 Run the Test Script**
```bash
python test_firebase_setup.py
```

You should see output like:
```
🔍 Testing Firebase Setup...
📋 Configuration:
   Service Account Key: ✅ Set

🔗 Initializing Firebase Admin SDK...
   ✅ Firebase Admin SDK initialized successfully

🧪 Testing token verification setup...
   ✅ Token verification setup working (correctly rejected invalid token)

🎉 Firebase setup test completed successfully!
```

### **3.2 If You Get Errors**

**Error: "Service account key file not found"**
- Check that the file path in `.env` is correct
- Make sure the JSON file is in the `keys` folder
- Verify the filename matches exactly

**Error: "Firebase Admin SDK initialization failed"**
- Check that your service account key is valid
- Verify your Firebase project is properly configured
- Make sure the service account has proper permissions

## 🔧 **Step 4: Test with Your Frontend**

### **4.1 Get Firebase ID Token from Frontend**
In your Flutter/Dart app, get the ID token:
```dart
String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
```

### **4.2 Test Authenticated Endpoint**
```bash
curl -X POST http://localhost:8000/api/enhanced-chat/ \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, this is a test message"
  }'
```

## 🔧 **Step 5: Verify Everything Works**

### **5.1 Test Document Upload**
```bash
curl -X POST http://localhost:8000/api/enhanced-chat/ \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -F "medical_report=@path/to/your/document.pdf" \
  -F "message": "Please analyze this document"
```

### **5.2 Test RAG Query**
```bash
curl -X POST http://localhost:8000/api/enhanced-chat/ \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are my recent blood test results?"
  }'
```

## 🔧 **Step 6: Frontend Integration**

### **6.1 Flutter/Dart Example**
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  static Future<Map<String, dynamic>> sendMessage(String message) async {
    // Get Firebase ID token
    String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    
    if (idToken == null) {
      throw Exception('User not authenticated');
    }
    
    // Make authenticated request
    final response = await http.post(
      Uri.parse('http://localhost:8000/api/enhanced-chat/'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }
}
```

### **6.2 JavaScript Example**
```javascript
// Get Firebase ID token
const idToken = await firebase.auth().currentUser.getIdToken();

// Make authenticated request
const response = await fetch('http://localhost:8000/api/enhanced-chat/', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${idToken}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    message: 'What are my blood test results?'
  }),
});

const data = await response.json();
console.log(data);
```

## 🚨 **Security Notes**

### **Important Security Practices:**
1. **Never commit** your service account key to version control
2. **Add `keys/` to `.gitignore`** to prevent accidental commits
3. **Use environment variables** for all sensitive configuration
4. **Rotate keys regularly** for production applications
5. **Limit service account permissions** to only what's needed

### **Production Considerations:**
1. **Use HTTPS** in production
2. **Set up proper CORS** configuration
3. **Implement rate limiting**
4. **Monitor authentication logs**
5. **Set up error tracking**

## 🔍 **Troubleshooting**

### **Common Issues:**

**1. "Firebase Admin SDK not initialized"**
- Check your service account key path
- Verify the JSON file is valid
- Ensure the file has proper read permissions

**2. "Invalid token" errors**
- Make sure you're using a valid Firebase ID token
- Check that the token hasn't expired
- Verify your Firebase project configuration

**3. "Permission denied" errors**
- Check your service account permissions in Firebase Console
- Ensure the service account has proper roles assigned

**4. "File not found" errors**
- Verify the file path in your `.env` file
- Check that the file exists in the specified location
- Make sure there are no typos in the filename

## ✅ **Success Checklist**

- [ ] Firebase service account key downloaded
- [ ] Key file placed in `keys/` folder
- [ ] `.env` file updated with key path
- [ ] `keys/` added to `.gitignore`
- [ ] `test_firebase_setup.py` runs successfully
- [ ] Authenticated endpoints work with valid tokens
- [ ] Document upload and RAG functionality tested
- [ ] Frontend integration working

Once you've completed all these steps, your Firebase authentication system will be fully functional! 🎉
