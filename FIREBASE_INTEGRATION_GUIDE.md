# Firebase Integration & Enhanced Chat System Setup Guide

## 🔐 **Security Architecture**

### **How User Data Isolation Works:**
```
Frontend (Firebase Auth) → Django Backend → Secure User-Specific Vector Storage
```

1. **User logs in** via Firebase on frontend
2. **Frontend gets Firebase ID token**
3. **Frontend sends token** with every API request
4. **Django verifies token** and extracts user ID
5. **All operations** are tied to that verified user ID
6. **Vector search** is filtered by user_id

## 📋 **Setup Requirements**

### **1. Firebase Configuration**
You need to add your Firebase service account key to your `.env` file:

```env
# Firebase Configuration
FIREBASE_SERVICE_ACCOUNT_KEY=path/to/your/firebase-service-account-key.json
PINECONE_API_KEY=your_pinecone_api_key_here
PINECONE_ENVIRONMENT=us-east-1-aws
PINECONE_INDEX_NAME=chatbot-index
```

### **2. Get Firebase Service Account Key**
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. Add the path to your `.env` file

## 🚀 **API Endpoints**

### **Enhanced Chat (Authenticated)**
```
POST /api/enhanced-chat/
Headers: Authorization: Bearer <firebase_id_token>
Body: {
  "message": "What are my blood test results?",
  "session_id": "optional_session_id",
  "image": <file>, // optional
  "medical_report": <file> // optional
}
```

### **Document Management**
```
GET /api/documents/
Headers: Authorization: Bearer <firebase_id_token>
Response: List of user's documents

DELETE /api/documents/<document_id>/
Headers: Authorization: Bearer <firebase_id_token>
Response: Document deleted confirmation
```

### **Chat History**
```
GET /api/chat-history/
Headers: Authorization: Bearer <firebase_id_token>
Response: List of user's chat sessions

GET /api/chat-history/?session_id=<session_id>
Headers: Authorization: Bearer <firebase_id_token>
Response: Messages in specific session
```

## 🔄 **System Flow**

### **1. Document Upload Flow**
```
User Uploads PDF → Extract Text → Create Chunks → Generate Embeddings → Store in Pinecone with User ID → Save Metadata in Django DB
```

### **2. Text Query Flow**
```
User Asks Question → Generate Query Embedding → Search User's Documents in Pinecone → Retrieve Relevant Context → Generate AI Response with Context
```

### **3. Image Query Flow**
```
User Uploads Image → Direct AI Analysis → Return Nutritional Information
```

## 🛡️ **Security Features**

### **Data Isolation:**
- All Pinecone queries filtered by `user_id`
- Users can only access their own documents
- Firebase token verification on every request
- Secure document storage with user-specific namespaces

### **Authentication Flow:**
```python
# Frontend sends request with Firebase token
headers = {
    'Authorization': f'Bearer {firebase_id_token}',
    'Content-Type': 'application/json'
}

# Django verifies token and extracts user_id
user_info = verify_firebase_token(id_token)
user_id = user_info['uid']

# All operations are tied to this user_id
```

## 📊 **Database Schema**

### **UserDocument Model:**
```python
{
    'id': 'uuid',
    'user_id': 'firebase_uid',
    'document_name': 'blood_test_report.pdf',
    'document_type': 'lab_result',
    'upload_date': '2024-01-15T10:30:00Z',
    'vector_ids': ['vector_id_1', 'vector_id_2', ...],
    'processing_status': 'completed'
}
```

### **DocumentChunk Model:**
```python
{
    'id': 'uuid',
    'document': 'foreign_key_to_document',
    'chunk_index': 0,
    'text_content': 'extracted text chunk',
    'vector_id': 'pinecone_vector_id',
    'embedding_model': 'text-embedding-ada-002'
}
```

## 🧪 **Testing the System**

### **1. Test Firebase Authentication**
```bash
# First, get a Firebase ID token from your frontend
# Then test the authenticated endpoint
curl -X POST http://localhost:8000/api/enhanced-chat/ \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, this is a test message"
  }'
```

### **2. Test Document Upload**
```bash
curl -X POST http://localhost:8000/api/enhanced-chat/ \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -F "medical_report=@path/to/your/document.pdf" \
  -F "message": "Please analyze this document"
```

### **3. Test RAG Query**
```bash
curl -X POST http://localhost:8000/api/enhanced-chat/ \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are my recent blood test results?"
  }'
```

## 🔧 **Frontend Integration**

### **Flutter/Dart Example:**
```dart
// Get Firebase ID token
String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

// Make authenticated request
final response = await http.post(
  Uri.parse('http://localhost:8000/api/enhanced-chat/'),
  headers: {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'message': 'What are my blood test results?',
  }),
);
```

### **JavaScript Example:**
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
```

## 🚨 **Important Notes**

### **1. Firebase Setup Required:**
- You must initialize Firebase Admin SDK with your service account key
- Update the `firebase_auth.py` file with your actual service account key path

### **2. Environment Variables:**
- All sensitive keys should be in `.env` file
- Never commit service account keys to version control

### **3. Database Migrations:**
- Run `python manage.py migrate` to create database tables
- The system automatically creates necessary indexes

### **4. Pinecone Setup:**
- Ensure your Pinecone index is created
- The system uses user-specific filtering for security

## 🔍 **Troubleshooting**

### **Common Issues:**

1. **Firebase Token Verification Fails:**
   - Check your service account key path
   - Verify the key is valid and has proper permissions

2. **Document Processing Fails:**
   - Check Pinecone API key and environment
   - Verify document is a valid PDF

3. **RAG Not Working:**
   - Ensure user has uploaded documents
   - Check Pinecone index exists and is accessible

4. **Authentication Errors:**
   - Verify Firebase token is valid and not expired
   - Check Authorization header format

## 📈 **Next Steps**

1. **Initialize Firebase Admin SDK** with your service account key
2. **Test authentication** with a valid Firebase token
3. **Upload test documents** to verify RAG functionality
4. **Integrate with your frontend** using the provided examples
5. **Monitor usage** and adjust chunk sizes as needed

The system is now ready for secure, user-specific document storage and retrieval with RAG capabilities!
