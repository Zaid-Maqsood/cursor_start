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

# Limit to last 10 exchanges to avoid "message too long"
MAX_EXCHANGES = 15

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

            # Truncate history to avoid "message too long" error
            # Keep system message and limit to last MAX_EXCHANGES pairs
            system_message = session_history[session_id][0]  # keep system prompt
            history_body = session_history[session_id][1:]  # all messages after system
            
            # Calculate how many complete exchanges we can keep
            max_messages = MAX_EXCHANGES * 2  # user + assistant pairs
            
            if len(history_body) > max_messages:
                # Keep the most recent messages
                history_body = history_body[-max_messages:]
            
            session_history[session_id] = [system_message] + history_body

            # Debug
            print("\nSession ID:", session_id)
            import json
            print(json.dumps(session_history[session_id], indent=2))

            # Call OpenAI
            response = openai.ChatCompletion.create(
                model="gpt-4o",
                messages=session_history[session_id],
                max_tokens=1000
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

            if len(reply) > 2000:
                reply = reply[:2000] + "..."

        except openai.error.InvalidRequestError as e:
            # Handle specific OpenAI API errors like "message too long"
            if "message too long" in str(e).lower():
                # Clear history and start fresh
                session_history[session_id] = [{
                    "role": "system",
                    "content": [{"type": "text", "text": "You are a helpful assistant."}]
                }]
                reply = "The conversation was too long. I've started a new session. Please try your question again."
            else:
                reply = f"OpenAI API Error: {str(e)}"
        except Exception as e:
            reply = f"Error: {str(e)}"

        return Response({
            'response': reply.strip(),
            'session_id': session_id
        }, status=status.HTTP_200_OK)
