#!/usr/bin/env python3
"""
Test script for Pinecone setup
Run this script to verify your Pinecone configuration is working correctly.
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

from api.pinecone_utils import get_pinecone_manager
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)

def test_pinecone_setup():
    """Test the Pinecone setup"""
    print("🔍 Testing Pinecone Setup...")
    
    # Check environment variables
    api_key = os.getenv('PINECONE_API_KEY')
    environment = os.getenv('PINECONE_ENVIRONMENT', 'us-east-1-aws')
    index_name = os.getenv('PINECONE_INDEX_NAME', 'chatbot-index')
    
    print(f"📋 Configuration:")
    print(f"   API Key: {'✅ Set' if api_key else '❌ Missing'}")
    print(f"   Environment: {environment}")
    print(f"   Index Name: {index_name}")
    
    if not api_key:
        print("\n❌ ERROR: PINECONE_API_KEY is not set in your environment variables!")
        print("Please add your Pinecone API key to your .env file:")
        print("PINECONE_API_KEY=your_api_key_here")
        return False
    
    try:
        # Initialize Pinecone manager
        print("\n🔗 Initializing Pinecone connection...")
        manager = get_pinecone_manager()
        
        # Test index creation with new API
        print("📊 Creating index if it doesn't exist...")
        manager.create_index_if_not_exists()
        
        # Test getting stats
        print("📈 Getting index statistics...")
        stats = manager.get_index_stats()
        print(f"   Index stats: {stats}")
        
        # Test vector operations
        print("\n🧪 Testing vector operations...")
        
        # Test vector (using llama-text-embed-v2 dimensions)
        test_vector = [0.1] * 4096  # llama-text-embed-v2 uses 4096 dimensions
        test_metadata = {"text": "test document", "source": "test"}
        
        # Upsert test vector
        print("   Upserting test vector...")
        success = manager.upsert_vectors([{
            "id": "test-vector-1",
            "values": test_vector,
            "metadata": test_metadata
        }])
        
        if success:
            print("   ✅ Test vector upserted successfully")
            
            # Query test vector
            print("   Querying test vector...")
            results = manager.query_vectors(test_vector, top_k=1)
            
            if results:
                print(f"   ✅ Query successful, found {len(results)} matches")
                print(f"   Top match score: {results[0].score}")
            else:
                print("   ⚠️ Query returned no results")
            
            # Clean up test vector
            print("   Cleaning up test vector...")
            manager.delete_vectors(["test-vector-1"])
            print("   ✅ Test vector deleted")
        else:
            print("   ❌ Failed to upsert test vector")
        
        print("\n🎉 Pinecone setup test completed successfully!")
        return True
        
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        print("\nTroubleshooting tips:")
        print("1. Make sure your Pinecone API key is correct")
        print("2. Check your internet connection")
        print("3. Verify your Pinecone environment is correct")
        print("4. Ensure you have sufficient Pinecone credits")
        print("5. Make sure you're using the latest pinecone-client version")
        return False

if __name__ == "__main__":
    success = test_pinecone_setup()
    sys.exit(0 if success else 1)
