#!/usr/bin/env python3
"""
Test script for the enhanced backend with medical PDF upload functionality
"""

import requests
import json
from io import BytesIO

# Test configuration
BACKEND_URL = "http://localhost:8000/api/chat/"
TEST_IMAGE_PATH = "test_food.jpg"  # You'll need to create this
TEST_PDF_PATH = "test_medical_report.pdf"  # You'll need to create this

def test_text_only():
    """Test sending text message only"""
    print("=== Testing Text Only ===")
    
    data = {
        'message': 'What are the nutritional benefits of apples?',
        'session_id': 'test_session_1'
    }
    
    response = requests.post(BACKEND_URL, data=data)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    print()

def test_image_only():
    """Test sending image only"""
    print("=== Testing Image Only ===")
    
    try:
        with open(TEST_IMAGE_PATH, 'rb') as f:
            files = {'image': f}
            data = {'session_id': 'test_session_2'}
            
            response = requests.post(BACKEND_URL, data=data, files=files)
            print(f"Status: {response.status_code}")
            print(f"Response: {response.json()}")
    except FileNotFoundError:
        print(f"Test image file {TEST_IMAGE_PATH} not found. Skipping image test.")
    print()

def test_medical_pdf_only():
    """Test uploading medical PDF only"""
    print("=== Testing Medical PDF Only ===")
    
    try:
        with open(TEST_PDF_PATH, 'rb') as f:
            files = {'medical_report': f}
            data = {'session_id': 'test_session_3'}
            
            response = requests.post(BACKEND_URL, data=data, files=files)
            print(f"Status: {response.status_code}")
            print(f"Response: {response.json()}")
    except FileNotFoundError:
        print(f"Test PDF file {TEST_PDF_PATH} not found. Skipping PDF test.")
    print()

def test_combined():
    """Test sending image + text + medical PDF"""
    print("=== Testing Combined (Image + Text + Medical PDF) ===")
    
    try:
        with open(TEST_IMAGE_PATH, 'rb') as img_f, open(TEST_PDF_PATH, 'rb') as pdf_f:
            files = {
                'image': img_f,
                'medical_report': pdf_f
            }
            data = {
                'message': 'Is this food safe for me to eat?',
                'session_id': 'test_session_4'
            }
            
            response = requests.post(BACKEND_URL, data=data, files=files)
            print(f"Status: {response.status_code}")
            result = response.json()
            print(f"Response: {result['response'][:200]}...")  # Show first 200 chars
            print(f"Medical context used: {result.get('medical_context_used', False)}")
            print(f"Health assessment: {result.get('health_assessment', {})}")
    except FileNotFoundError as e:
        print(f"Test file not found: {e}. Skipping combined test.")
    print()

def test_session_persistence():
    """Test that medical data persists in session"""
    print("=== Testing Session Persistence ===")
    
    session_id = 'test_session_persistent'
    
    # First, upload medical PDF
    try:
        with open(TEST_PDF_PATH, 'rb') as f:
            files = {'medical_report': f}
            data = {'session_id': session_id}
            
            response = requests.post(BACKEND_URL, data=data, files=files)
            print(f"PDF upload status: {response.status_code}")
    except FileNotFoundError:
        print(f"Test PDF file {TEST_PDF_PATH} not found. Skipping persistence test.")
        return
    
    # Then, send text query (should use medical context)
    data = {
        'message': 'What should I avoid eating?',
        'session_id': session_id
    }
    
    response = requests.post(BACKEND_URL, data=data)
    print(f"Text query status: {response.status_code}")
    result = response.json()
    print(f"Medical context used: {result.get('medical_context_used', False)}")
    print(f"Medical data available: {result.get('medical_data_available', False)}")
    print()

def create_test_files():
    """Create simple test files for testing"""
    print("=== Creating Test Files ===")
    
    # Create a simple test PDF (this is a basic example)
    try:
        from reportlab.pdfgen import canvas
        from reportlab.lib.pagesizes import letter
        
        # Create test medical report PDF
        c = canvas.Canvas("test_medical_report.pdf", pagesize=letter)
        c.drawString(100, 750, "Medical Report")
        c.drawString(100, 730, "Patient: John Doe")
        c.drawString(100, 710, "Conditions: Diabetes, Hypertension")
        c.drawString(100, 690, "Medications: Metformin 500mg, Lisinopril 10mg")
        c.drawString(100, 670, "Allergies: Peanuts, Shellfish")
        c.drawString(100, 650, "Blood Work:")
        c.drawString(100, 630, "Glucose: 120 mg/dL")
        c.drawString(100, 610, "Cholesterol: 200 mg/dL")
        c.drawString(100, 590, "HbA1c: 7.2%")
        c.save()
        print("Created test_medical_report.pdf")
    except ImportError:
        print("reportlab not available. Please create test_medical_report.pdf manually.")
    
    # Create a simple test image (you'll need to create this manually)
    print("Please create test_food.jpg manually for image testing.")
    print()

if __name__ == "__main__":
    print("Backend Test Suite")
    print("=" * 50)
    
    # Create test files first
    create_test_files()
    
    # Run tests
    test_text_only()
    test_image_only()
    test_medical_pdf_only()
    test_combined()
    test_session_persistence()
    
    print("Test suite completed!") 