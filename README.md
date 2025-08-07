# NutriLens - AI-Powered Food Analysis with Medical Context

A comprehensive food analysis application that combines AI-powered nutrition analysis with personalized health advice based on medical reports.

## Features

### 🍎 Food Analysis
- **Image Upload**: Upload food photos for instant nutritional analysis
- **Text Queries**: Ask questions about food and nutrition
- **AI-Powered**: Uses OpenAI GPT-4o for intelligent food recognition and analysis

### 🏥 Medical Context Integration
- **PDF Medical Reports**: Upload medical reports (PDF format) for personalized advice
- **Health Risk Assessment**: Get personalized warnings and recommendations based on your medical conditions
- **Allergy Alerts**: Automatic detection of potential allergens in food
- **Medication Interactions**: Check for food-medication interactions
- **Session-Based**: Medical data is stored per session for privacy

### 💡 Personalized Health Advice
- **Diabetes Management**: Carb counting and blood sugar monitoring advice
- **Heart Health**: Sodium and fat content warnings
- **Kidney Disease**: Potassium and phosphorus monitoring
- **Portion Control**: Personalized portion recommendations
- **Safety Warnings**: Clear alerts for unsafe foods

## Backend Architecture

### API Endpoints
- `POST /api/chat/` - Main endpoint for all interactions

### Request Format
```json
{
  "session_id": "unique_session_id",
  "message": "optional_text_message",
  "image": "optional_food_image_file",
  "medical_report": "optional_medical_pdf_file"
}
```

### Response Format
```json
{
  "response": "AI-generated response with nutritional analysis",
  "session_id": "session_id",
  "health_assessment": {
    "safe_to_eat": true,
    "risk_level": "low",
    "warnings": [],
    "recommendations": [],
    "portions": "normal"
  },
  "medical_context_used": true,
  "medical_data_available": true
}
```

## Installation

### Backend Setup
1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Set environment variables:
   ```bash
   OPENAI_API_KEY=your_openai_api_key
   DJANGO_SECRET_KEY=your_django_secret_key
   ```

3. Run migrations:
   ```bash
   python manage.py migrate
   ```

4. Start the server:
   ```bash
   python manage.py runserver
   ```

### Frontend Setup
1. Install Flutter dependencies
2. Update the backend URL in `chatScreen.dart`
3. Run the Flutter app

## Usage Examples

### Basic Food Analysis
1. Upload a food image
2. Get instant nutritional analysis
3. Receive general health tips

### Personalized Analysis
1. Upload your medical report (PDF)
2. Upload food images
3. Receive personalized advice based on your health conditions

### Text Queries
1. Ask questions like "Is this food good for diabetics?"
2. Get context-aware responses

## Medical Data Processing

The system extracts the following information from medical reports:
- **Medical Conditions**: Diabetes, hypertension, heart disease, etc.
- **Medications**: Current prescriptions and dosages
- **Allergies**: Food and medication allergies
- **Blood Work**: Lab results and values

## Security & Privacy

- Medical data is stored in session memory only
- No persistent storage of medical information
- Data is cleared when session ends
- No user authentication required (session-based)

## Testing

Run the test suite:
```bash
python test_backend.py
```

This will test:
- Text-only queries
- Image-only uploads
- Medical PDF uploads
- Combined functionality
- Session persistence

## Dependencies

### Backend
- Django 5.2.4
- Django REST Framework 3.16.0
- OpenAI 0.28.0
- PyPDF2 3.0.1
- Python Decouple 3.8

### Frontend
- Flutter
- HTTP package
- Image picker
- File upload support

## Deployment

The application is configured for deployment on:
- **Render.com**: Use the provided `render.yaml`
- **PythonAnywhere**: Compatible with the current setup

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License. 
