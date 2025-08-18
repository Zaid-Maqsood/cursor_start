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
from .pinecone_utils import get_pinecone_manager


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


class VectorSearchView(APIView):
    """View for vector search operations using Pinecone"""
    
    def post(self, request):
        """Store vectors and perform similarity search"""
        try:
            action = request.data.get('action')
            
            if action == 'store':
                return self._store_vectors(request)
            elif action == 'search':
                return self._search_vectors(request)
            elif action == 'stats':
                return self._get_stats(request)
            else:
                return Response({
                    'error': 'Invalid action. Use "store", "search", or "stats"'
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            return Response({
                'error': f'Vector search error: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _store_vectors(self, request):
        """Store vectors in Pinecone"""
        vectors_data = request.data.get('vectors', [])
        
        if not vectors_data:
            return Response({
                'error': 'No vectors provided'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            manager = get_pinecone_manager()
            
            # Ensure index exists
            manager.create_index_if_not_exists(dimension=1536, metric="cosine")
            
            # Store vectors
            success = manager.upsert_vectors(vectors_data)
            
            if success:
                return Response({
                    'message': f'Successfully stored {len(vectors_data)} vectors',
                    'vectors_stored': len(vectors_data)
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'error': 'Failed to store vectors'
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
                
        except Exception as e:
            return Response({
                'error': f'Error storing vectors: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _search_vectors(self, request):
        """Search for similar vectors"""
        query_vector = request.data.get('query_vector')
        top_k = request.data.get('top_k', 5)
        filter_dict = request.data.get('filter', None)
        
        if not query_vector:
            return Response({
                'error': 'No query vector provided'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            manager = get_pinecone_manager()
            
            # Perform search
            results = manager.query_vectors(
                query_vector=query_vector,
                top_k=top_k,
                include_metadata=True,
                filter=filter_dict
            )
            
            # Format results
            formatted_results = []
            for match in results:
                formatted_results.append({
                    'id': match.id,
                    'score': match.score,
                    'metadata': match.metadata
                })
            
            return Response({
                'results': formatted_results,
                'total_matches': len(formatted_results)
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'error': f'Error searching vectors: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _get_stats(self, request):
        """Get Pinecone index statistics"""
        try:
            manager = get_pinecone_manager()
            stats = manager.get_index_stats()
            
            return Response({
                'stats': stats
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'error': f'Error getting stats: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class VectorDemoView(APIView):
    """Demo view to show how to use Pinecone with OpenAI embeddings"""
    
    def post(self, request):
        """Demo: Store text embeddings and search"""
        try:
            texts = request.data.get('texts', [])
            query_text = request.data.get('query_text', '')
            
            if not texts:
                return Response({
                    'error': 'No texts provided for embedding'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Generate embeddings using OpenAI (still using text-embedding-ada-002 for compatibility)
            embeddings = []
            for i, text in enumerate(texts):
                response = openai.Embedding.create(
                    input=text,
                    model="text-embedding-ada-002"
                )
                embedding = response['data'][0]['embedding']
                
                embeddings.append({
                    'id': f'text-{i}',
                    'values': embedding,
                    'metadata': {
                        'text': text,
                        'source': 'demo'
                    }
                })
            
            # Store in Pinecone
            manager = get_pinecone_manager()
            manager.create_index_if_not_exists()
            manager.upsert_vectors(embeddings)
            
            # Search if query provided
            search_results = []
            if query_text:
                # Generate query embedding
                query_response = openai.Embedding.create(
                    input=query_text,
                    model="text-embedding-ada-002"
                )
                query_embedding = query_response['data'][0]['embedding']
                
                # Search
                results = manager.query_vectors(query_embedding, top_k=3)
                search_results = [
                    {
                        'id': match.id,
                        'score': match.score,
                        'text': match.metadata.get('text', ''),
                        'metadata': match.metadata
                    }
                    for match in results
                ]
            
            return Response({
                'message': f'Stored {len(texts)} text embeddings',
                'texts_stored': texts,
                'search_results': search_results if search_results else None
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'error': f'Demo error: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)