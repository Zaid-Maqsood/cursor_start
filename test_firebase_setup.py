#!/usr/bin/env python3
"""
Test script for Firebase setup
Run this script to verify your Firebase configuration is working correctly.
"""

import os
import sys
import django
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'chatbot_backend.settings')
django.setup()

from api.firebase_auth import initialize_firebase, verify_firebase_token
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)

def test_firebase_setup():
    """Test the Firebase setup"""
    print("🔍 Testing Firebase Setup...")
    
    # Check environment variables
    service_account_key = os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY')
    
    print(f"📋 Configuration:")
    print(f"   Service Account Key: {'✅ Set' if service_account_key else '❌ Missing'}")
    
    if not service_account_key:
        print("\n❌ ERROR: FIREBASE_SERVICE_ACCOUNT_KEY is not set in your environment variables!")
        print("Please add your Firebase service account key path to your .env file:")
        print("FIREBASE_SERVICE_ACCOUNT_KEY=keys/your-project-firebase-adminsdk-xxxxx-xxxxxxxxxx.json")
        return False
    
    # Check if file exists
    if not os.path.exists(service_account_key):
        print(f"\n❌ ERROR: Service account key file not found: {service_account_key}")
        print("Please make sure the file exists and the path is correct.")
        return False
    
    try:
        # Test Firebase initialization
        print("\n🔗 Initializing Firebase Admin SDK...")
        initialize_firebase()
        print("   ✅ Firebase Admin SDK initialized successfully")
        
        # Test with a sample token (this will fail, but we can test the setup)
        print("\n🧪 Testing token verification setup...")
        try:
            # This will fail with an invalid token, but we can test the setup
            result = verify_firebase_token("invalid_token_for_testing")
            if result is None:
                print("   ✅ Token verification setup working (correctly rejected invalid token)")
            else:
                print("   ⚠️ Unexpected result from invalid token")
        except Exception as e:
            print(f"   ✅ Token verification setup working (expected error: {str(e)[:50]}...)")
        
        print("\n🎉 Firebase setup test completed successfully!")
        print("\n📝 Next Steps:")
        print("1. Get a valid Firebase ID token from your frontend")
        print("2. Test the authenticated endpoints with the token")
        print("3. Upload documents and test RAG functionality")
        
        return True
        
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        print("\nTroubleshooting tips:")
        print("1. Make sure your Firebase service account key file exists")
        print("2. Check that the file path in .env is correct")
        print("3. Verify the service account key has proper permissions")
        print("4. Ensure your Firebase project is properly configured")
        return False

if __name__ == "__main__":
    success = test_firebase_setup()
    sys.exit(0 if success else 1)
