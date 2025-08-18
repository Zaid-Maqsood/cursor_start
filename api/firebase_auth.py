import firebase_admin
from firebase_admin import credentials, auth
from django.conf import settings
from rest_framework import status
from rest_framework.response import Response
import logging
import os

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
def initialize_firebase():
    """Initialize Firebase Admin SDK with service account key"""
    try:
        # Check if already initialized
        firebase_admin.get_app()
        logger.info("Firebase Admin SDK already initialized")
        return
    except ValueError:
        # Not initialized yet, proceed with initialization
        pass
    
    try:
        # Get service account key path from settings
        service_account_key_path = settings.FIREBASE_SERVICE_ACCOUNT_KEY
        
        if not service_account_key_path:
            logger.error("FIREBASE_SERVICE_ACCOUNT_KEY not set in environment variables")
            raise ValueError("Firebase service account key path not configured")
        
        # Check if file exists
        if not os.path.exists(service_account_key_path):
            logger.error(f"Firebase service account key file not found: {service_account_key_path}")
            raise FileNotFoundError(f"Service account key file not found: {service_account_key_path}")
        
        # Initialize Firebase Admin SDK
        cred = credentials.Certificate(service_account_key_path)
        firebase_admin.initialize_app(cred)
        
        logger.info("Firebase Admin SDK initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {str(e)}")
        raise

def verify_firebase_token(id_token):
    """Verify Firebase ID token and return user info"""
    try:
        # Ensure Firebase is initialized
        initialize_firebase()
        
        # Verify the ID token
        decoded_token = auth.verify_id_token(id_token)
        
        # Extract user information
        user_info = {
            'uid': decoded_token['uid'],
            'email': decoded_token.get('email', ''),
            'email_verified': decoded_token.get('email_verified', False),
            'name': decoded_token.get('name', ''),
            'picture': decoded_token.get('picture', '')
        }
        
        logger.info(f"Successfully verified token for user: {user_info['uid']}")
        return user_info
        
    except Exception as e:
        logger.error(f"Token verification failed: {str(e)}")
        return None

def get_user_from_request(request):
    """Extract and verify user from request headers"""
    try:
        # Get the Authorization header
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return None, Response({
                'error': 'Missing or invalid Authorization header'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        # Extract the token
        id_token = auth_header.split('Bearer ')[1]
        
        # Verify the token
        user_info = verify_firebase_token(id_token)
        
        if not user_info:
            return None, Response({
                'error': 'Invalid or expired token'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        return user_info, None
        
    except Exception as e:
        logger.error(f"Error extracting user from request: {str(e)}")
        return None, Response({
            'error': 'Authentication error'
        }, status=status.HTTP_401_UNAUTHORIZED)

def require_auth(view_func):
    """Decorator to require Firebase authentication"""
    def wrapper(self, request, *args, **kwargs):
        user_info, error_response = get_user_from_request(request)
        
        if error_response:
            return error_response
        
        # Add user info to request
        request.user_info = user_info
        request.user_id = user_info['uid']
        
        return view_func(self, request, *args, **kwargs)
    
    return wrapper
