# Pinecone Vector Database Setup Guide

## Prerequisites
- Pinecone account created at https://www.pinecone.io/
- Pinecone API key from your dashboard
- Python environment with the required dependencies

## Setup Steps

### 1. Environment Variables
Add the following to your `.env` file:

```env
# Pinecone Configuration
PINECONE_API_KEY=your_pinecone_api_key_here
PINECONE_ENVIRONMENT=us-east-1-aws
PINECONE_INDEX_NAME=chatbot-index
```

**Important Notes:**
- Replace `your_pinecone_api_key_here` with your actual Pinecone API key
- The environment should match your Pinecone project's environment (check your Pinecone dashboard)
- The index name can be customized to your preference

### 2. Install Dependencies
```bash
pip install pinecone-client==3.1.0
```

### 3. Test Your Setup
Run the test script to verify everything is working:

```bash
python test_pinecone.py
```

### 4. Available API Endpoints

#### Vector Search Operations
- **POST** `/api/vector-search/`
  - Action: `store` - Store vectors in Pinecone
  - Action: `search` - Search for similar vectors
  - Action: `stats` - Get index statistics

#### Demo with OpenAI Embeddings
- **POST** `/api/vector-demo/`
  - Store text embeddings and perform similarity search

## New Pinecone API Features

This setup uses the latest Pinecone API which includes:

- **Automatic Embedding**: The index is configured with `llama-text-embed-v2` model
- **Serverless**: No need to manage infrastructure
- **Simplified API**: Cleaner initialization and index management

## Usage Examples

### Store Vectors
```bash
curl -X POST http://localhost:8000/api/vector-search/ \
  -H "Content-Type: application/json" \
  -d '{
    "action": "store",
    "vectors": [
      {
        "id": "doc1",
        "values": [0.1, 0.2, ...],
        "metadata": {"text": "sample document", "category": "demo"}
      }
    ]
  }'
```

### Search Vectors
```bash
curl -X POST http://localhost:8000/api/vector-search/ \
  -H "Content-Type: application/json" \
  -d '{
    "action": "search",
    "query_vector": [0.1, 0.2, ...],
    "top_k": 5
  }'
```

### Demo with Text Embeddings
```bash
curl -X POST http://localhost:8000/api/vector-demo/ \
  -H "Content-Type: application/json" \
  -d '{
    "texts": [
      "The quick brown fox jumps over the lazy dog",
      "Machine learning is a subset of artificial intelligence",
      "Python is a popular programming language"
    ],
    "query_text": "What is machine learning?"
  }'
```

## Troubleshooting

### Common Issues

1. **API Key Error**
   - Verify your Pinecone API key is correct
   - Check that the key is properly set in your `.env` file

2. **Environment Error**
   - Ensure the environment matches your Pinecone project
   - Common environments: `us-east-1-aws`, `us-west1-gcp`, `eu-west1-aws`

3. **Index Not Found**
   - The system will automatically create the index if it doesn't exist
   - Check your Pinecone dashboard to verify the index was created

4. **Dimension Mismatch**
   - The new API uses `llama-text-embed-v2` which has 4096 dimensions
   - The system automatically handles the correct dimensions

5. **API Version Issues**
   - Make sure you're using the latest `pinecone-client` version
   - The new API is incompatible with older versions

### Getting Help
- Check the Pinecone documentation: https://docs.pinecone.io/
- Verify your Pinecone dashboard for index status and usage
- Run the test script to identify specific issues

## Next Steps
- Integrate vector search into your chatbot for better context retrieval
- Store conversation embeddings for improved responses
- Implement semantic search for medical documents
- Consider using Pinecone's built-in embedding models for better performance
