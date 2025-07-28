import openai
import base64
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from uuid import uuid4
from decouple import config


openai.api_key = config('OPENAI_API_KEY')

# Temporary in-memory session store (for dev/testing only)
session_history = {}

class ChatView(APIView):
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def post(self, request):
        session_id = request.data.get('session_id') or str(uuid4())
        user_message = request.data.get('message', '').strip()
        image_file = request.FILES.get('image', None)

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

                # If no text provided, add default text prompt
                if not user_message:
                    user_content.insert(0, {"type": "text", "text": "Analyse this image of food and explicitly estimate calories, protein, carbohydrates, fats, and other key nutrients present in the portion shown."})

            # Append user message in correct format
            session_history[session_id].append({
                "role": "user",
                "content": user_content
            })

            # (Optional) Debug logs
            print("\nSession ID:", session_id)
            print("Formatted session history being sent to OpenAI:\n")
            import json
            print(json.dumps(session_history[session_id], indent=2))

            # Get response from OpenAI
            response = openai.ChatCompletion.create(
                model="gpt-4o",
                messages=session_history[session_id],
                max_tokens=1000  # Limit response length
            )

            assistant_message = response.choices[0].message
            session_history[session_id].append({
                "role": "assistant",
                "content": assistant_message["content"]
            })

            # Convert response content to string for frontend
            reply = ""
            if isinstance(assistant_message["content"], list):
                for part in assistant_message["content"]:
                    if part["type"] == "text":
                        reply += part["text"] + "\n"
            else:
                reply = assistant_message["content"]

            # Truncate response if it's too long (additional safety)
            if len(reply) > 2000:
                reply = reply[:2000] + "..."

        except Exception as e:
            reply = f"Error: {str(e)}"

        return Response({
            'response': reply.strip(),
            'session_id': session_id
        }, status=status.HTTP_200_OK)
