import openai
import base64
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.core.files.storage import default_storage
from uuid import uuid4
from decouple import config


openai.api_key = config('OPENAI_API_KEY')

# Temporary in-memory session store (for dev/testing only)
session_history = {}

class ChatView(APIView):
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def post(self, request):
        session_id = request.data.get('session_id') or str(uuid4())
        user_message = request.data.get('message', '')
        image_file = request.FILES.get('image', None)

        # Initialize history if not exists
        if session_id not in session_history:
            session_history[session_id] = [{"role": "system", "content": "You are a helpful assistant."}]

        try:
            if image_file:
                image_data = base64.b64encode(image_file.read()).decode("utf-8")
                image_base64 = f"data:{image_file.content_type};base64,{image_data}"

                if not user_message:
                    user_message = "Analyze this screenshot and describe the user's query based on image"

                session_history[session_id].append({
                    "role": "user",
                    "content": [
                        {"type": "text", "text": user_message},
                        {"type": "image_url", "image_url": {"url": image_base64}}
                    ]
                })
            else:
                session_history[session_id].append({"role": "user", "content": user_message})

            response = openai.ChatCompletion.create(
                model="gpt-4o",
                messages=session_history[session_id]
            )

            reply = response.choices[0].message['content']
            session_history[session_id].append({"role": "assistant", "content": reply})

        except Exception as e:
            reply = f"Error: {str(e)}"

        return Response({
            'response': reply,
            'session_id': session_id
        }, status=status.HTTP_200_OK)
