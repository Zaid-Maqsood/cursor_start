import openai
import base64
import PyPDF2
import re
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from uuid import uuid4
from decouple import config
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator


openai.api_key = config('OPENAI_API_KEY')

# Temporary in-memory session store (for dev/testing only)
session_history = {}

# Medical data storage per session
session_medical_data = {}

# Maximum number of sessions to keep in memory
MAX_SESSIONS = 20

class MedicalReportProcessor:
    """Simple medical report processor"""
    
    def extract_medical_data(self, pdf_file) -> dict:
        """Extract basic medical information from PDF"""
        try:
            # Read PDF content
            pdf_reader = PyPDF2.PdfReader(pdf_file)
            text = ""
            for page in pdf_reader.pages:
                text += page.extract_text()
            
            # Simple extraction of key medical info
            medical_data = {
                "conditions": self.extract_conditions(text),
                "medications": self.extract_medications(text),
                "allergies": self.extract_allergies(text),
                "raw_text": text[:500]  # Store first 500 chars
            }
            
            return medical_data
        except Exception as e:
            print(f"Error processing PDF: {e}")
            return {"error": f"Failed to process PDF: {str(e)}"}
    
    def extract_conditions(self, text: str) -> list:
        """Extract medical conditions"""
        conditions = []
        text_lower = text.lower()
        
        # Common conditions to look for
        common_conditions = [
            'diabetes', 'hypertension', 'heart disease', 'kidney disease', 
            'asthma', 'allergies', 'celiac disease', 'high cholesterol'
        ]
        
        for condition in common_conditions:
            if condition in text_lower:
                conditions.append(condition)
        
        return conditions
    
    def extract_medications(self, text: str) -> list:
        """Extract medications"""
        medications = []
        text_lower = text.lower()
        
        # Common medications
        common_meds = [
            'metformin', 'insulin', 'lisinopril', 'aspirin', 'warfarin'
        ]
        
        for med in common_meds:
            if med in text_lower:
                medications.append(med)
        
        return medications
    
    def extract_allergies(self, text: str) -> list:
        """Extract allergies"""
        allergies = []
        text_lower = text.lower()
        
        # Common allergies
        common_allergies = [
            'peanuts', 'tree nuts', 'dairy', 'eggs', 'soy', 'wheat', 'fish', 'shellfish'
        ]
        
        for allergy in common_allergies:
            if allergy in text_lower:
                allergies.append(allergy)
        
        return allergies

class ChatView(APIView):
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def __init__(self):
        super().__init__()
        self.medical_processor = MedicalReportProcessor()

    def post(self, request):
        # Clear old sessions if we have too many
        if len(session_history) > MAX_SESSIONS:
            print(f"Clearing old sessions. Current count: {len(session_history)}")
            # Keep only the 10 most recent sessions
            recent_sessions = dict(list(session_history.items())[-10:])
            recent_medical_data = {k: session_medical_data.get(k) for k in recent_sessions.keys()}
            session_history.clear()
            session_medical_data.clear()
            session_history.update(recent_sessions)
            session_medical_data.update(recent_medical_data)
            print(f"Sessions after cleanup: {len(session_history)}")
        
        session_id = request.data.get('session_id') or str(uuid4())
        user_message = request.data.get('message', '').strip()
        image_file = request.FILES.get('image', None)
        medical_report_file = request.FILES.get('medical_report', None)

        # Process medical report if uploaded
        if medical_report_file:
            print(f"Processing medical report for session: {session_id}")
            medical_data = self.medical_processor.extract_medical_data(medical_report_file)
            session_medical_data[session_id] = medical_data
            print(f"Medical data extracted: {medical_data}")

        # Get medical context for this session
        medical_context = session_medical_data.get(session_id, {})

        # Initialize chat history if not present
        if session_id not in session_history:
            session_history[session_id] = [{
                "role": "system",
                "content": [{"type": "text", "text": "You are a helpful assistant."}]
            }]

        try:
            user_content = []

            if user_message:
                user_content.append({"type": "text", "text": user_message})

            if image_file:
                image_data = base64.b64encode(image_file.read()).decode("utf-8")
                image_base64 = f"data:{image_file.content_type};base64,{image_data}"
                user_content.append({"type": "image_url", "image_url": {"url": image_base64}})

                # If no text provided, add default image prompt
                if not user_message:
                    user_content.insert(0, {
                        "type": "text",
                        "text": "Analyse this image of food and describe the food in it and explicitly estimate calories, protein, carbohydrates, fats, and other key nutrients present in the portion shown."
                    })

            # Append user message
            session_history[session_id].append({
                "role": "user",
                "content": user_content
            })

            # Debug
            print(f"\nSession ID: {session_id}")
            print(f"Total sessions in memory: {len(session_history)}")
            print(f"Messages in current session: {len(session_history[session_id])}")
            print(f"Medical context available: {bool(medical_context)}")

            # Call OpenAI
            response = openai.ChatCompletion.create(
                model="gpt-4o",
                messages=session_history[session_id]
            )

            assistant_message = response.choices[0].message
            session_history[session_id].append({
                "role": "assistant",
                "content": assistant_message["content"]
            })

            # Convert assistant response
            reply = ""
            if isinstance(assistant_message["content"], list):
                for part in assistant_message["content"]:
                    if part["type"] == "text":
                        reply += part["text"] + "\n"
            else:
                reply = assistant_message["content"]

            # Generate personalized advice if medical context is available
            if medical_context and not medical_context.get("error"):
                # Create personalized prompt
                medical_info = self.create_medical_summary(medical_context)
                personalized_prompt = f"""Based on the user's medical information: {medical_info}

Analyze the food and provide:
1. Is it safe for this person to eat? (Yes/No with brief reason)
2. Complete nutritional breakdown (calories, protein, carbs, fat, etc.)
3. Any specific warnings based on their medical conditions

Keep the response clear and concise."""

                # Get personalized response
                personalized_response = openai.ChatCompletion.create(
                    model="gpt-4o",
                    messages=[
                        {"role": "system", "content": "You are a medical nutritionist."},
                        {"role": "user", "content": f"Food analysis: {reply}\n\n{personalized_prompt}"}
                    ]
                )
                
                final_response = personalized_response.choices[0].message["content"]
                medical_used = True
            else:
                final_response = reply
                medical_used = False

            if len(final_response) > 2000:
                final_response = final_response[:2000] + "..."

        except openai.error.InvalidRequestError as e:
            # Handle specific OpenAI API errors like "message too long"
            if "message too long" in str(e).lower():
                # Clear history and start fresh
                session_history[session_id] = [{
                    "role": "system",
                    "content": [{"type": "text", "text": "You are a helpful assistant."}]
                }]
                final_response = "The conversation was too long. I've started a new session. Please try your question again."
                medical_used = False
            else:
                final_response = f"OpenAI API Error: {str(e)}"
                medical_used = False
        except Exception as e:
            final_response = f"Error: {str(e)}"
            medical_used = False

        return Response({
            'response': final_response.strip(),
            'session_id': session_id,
            'medical_context_used': medical_used,
            'medical_data_available': bool(medical_context and not medical_context.get("error"))
        }, status=status.HTTP_200_OK)

    def create_medical_summary(self, medical_context: dict) -> str:
        """Create a simple summary of medical information"""
        conditions = medical_context.get("conditions", [])
        medications = medical_context.get("medications", [])
        allergies = medical_context.get("allergies", [])
        
        summary_parts = []
        
        if conditions:
            summary_parts.append(f"Medical conditions: {', '.join(conditions)}")
        if medications:
            summary_parts.append(f"Medications: {', '.join(medications)}")
        if allergies:
            summary_parts.append(f"Allergies: {', '.join(allergies)}")
        
        return "; ".join(summary_parts) if summary_parts else "No specific medical information available"