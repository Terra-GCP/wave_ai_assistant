"""
Wave AI - Simple AI Assistant (v1.0)
Basic version for workshops - clean and easy to understand
Created by Ayush Shukla
"""

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
import os
from datetime import datetime
import uvicorn

# Load environment variables
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = FastAPI(
    title="Wave AI",
    description="Simple AI Assistant for Workshops",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Initialize Gemini AI with dynamic model discovery
def initialize_ai():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("❌ GEMINI_API_KEY not found")
        return None
    
    # Clean and validate API key to prevent header validation errors
    api_key = api_key.strip()
    
    # Basic API key format validation
    if not api_key.startswith("AIza") or len(api_key) != 39:
        print("❌ Invalid API key format detected")
        print("💡 API key should start with 'AIza' and be 39 characters long")
        return None
    
    # Check for invalid characters that cause header validation errors
    if not api_key.replace("-", "").replace("_", "").isalnum():
        print("❌ API key contains invalid characters")
        return None
    
    try:
        print("🔑 Configuring Gemini API...")
        genai.configure(api_key=api_key)
        
        # Discover available models dynamically
        print("🔍 Discovering available Gemini models...")
        try:
            available_models = list(genai.list_models())
            if not available_models:
                print("❌ No models found in your account")
                return None
                
            print("📋 Available models:")
            for model in available_models[:5]:  # Show first 5 models
                print("   - {}".format(model.name))
            
            # Preferred models in order of preference
            preferred_models = [
                "models/gemini-1.5-flash",
                "models/gemini-1.5-pro", 
                "models/gemini-pro",
                "models/gemini-1.0-pro",
            ]
            
            # Find the first available preferred model
            selected_model_name = None
            for pref_model in preferred_models:
                for available_model in available_models:
                    if available_model.name == pref_model:
                        if 'generateContent' in available_model.supported_generation_methods:
                            selected_model_name = pref_model
                            break
                if selected_model_name:
                    break
            
            # If no preferred model found, use the first available model that supports generateContent
            if not selected_model_name:
                for available_model in available_models:
                    if 'generateContent' in available_model.supported_generation_methods:
                        selected_model_name = available_model.name
                        break
            
            if not selected_model_name:
                print("❌ No models support generateContent method")
                return None
                
            print("🤖 Selected model: {}".format(selected_model_name))
            model = genai.GenerativeModel(selected_model_name)
            
        except Exception as discovery_e:
            print("⚠️ Model discovery failed, trying fallback: {}".format(str(discovery_e)))
            # Fallback to hardcoded model names
            fallback_models = ["gemini-1.5-flash", "gemini-pro", "gemini-1.0-pro"]
            model = None
            for fallback_name in fallback_models:
                try:
                    print("🔄 Trying fallback model: {}".format(fallback_name))
                    model = genai.GenerativeModel(fallback_name)
                    break
                except:
                    continue
            
            if not model:
                print("❌ All fallback models failed")
                return None
        
        # Test the selected model
        try:
            print("🧪 Testing AI connection...")
            test_response = model.generate_content("Test", generation_config={"max_output_tokens": 10})
            if test_response and test_response.text:
                print("✅ Wave AI initialized and tested successfully")
                return model
            else:
                print("⚠️ AI initialized but test failed")
                return model  # Still return model, might work for actual requests
        except Exception as test_e:
            print("⚠️ AI initialized but connection test failed: {}".format(str(test_e)))
            return model  # Still return model, might work for actual requests
            
    except Exception as e:
        error_msg = str(e).lower()
        if "api" in error_msg and "key" in error_msg:
            print("❌ Invalid API key - please check your Gemini API key")
        elif "quota" in error_msg or "limit" in error_msg:
            print("❌ API quota exceeded - please check your Gemini API limits")
        else:
            print("❌ Failed to initialize AI: {}".format(str(e)))
        return None

# Initialize AI
wave_ai = initialize_ai()

# Startup event to validate everything is ready
@app.on_event("startup")
async def startup_event():
    print("🌊 Wave AI container starting...")
    print("📡 Port configured for: {}".format(os.getenv('PORT', '8000')))
    print("🔑 API Key configured: {}".format('✅' if os.getenv('GEMINI_API_KEY') else '❌'))
    if wave_ai:
        print("✅ Wave AI ready to serve requests")
    else:
        print("⚠️  Wave AI started but AI model may not be available")

# Data Models
class ChatMessage(BaseModel):
    message: str

class ChatResponse(BaseModel):
    response: str
    success: bool = True

# In-memory conversations
conversations = []

# Generate AI Response with timeout protection
async def generate_response(message: str) -> str:
    if not wave_ai:
        return "❌ AI is currently offline. Please check configuration."
    
    try:
        # Enhanced generation config with timeout protection  
        prompt = "You are Wave AI, a helpful assistant created by Ayush Shukla. Provide clear and helpful responses.\n\nHuman: {}\n\nWave AI:".format(message)
        
        response = wave_ai.generate_content(
            prompt,
            generation_config={
                "max_output_tokens": 1024,
                "temperature": 0.7,
                "top_p": 0.8,
                "top_k": 40,
                "stop_sequences": []
            },
            safety_settings=[
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"}
            ]
        )
        
        if response and response.text:
            return response.text.strip()
        else:
            return "I couldn't generate a response. Please try rephrasing your question."
        
    except Exception as e:
        error_str = str(e).lower()
        
        # Handle specific error types with user-friendly messages
        if "quota" in error_str or "limit" in error_str:
            return "⏱️ I'm experiencing high demand right now. Please try again in a moment."
        elif "timeout" in error_str or "deadline" in error_str:
            return "⏱️ Request timed out. Please try again with a shorter message."
        elif "api" in error_str and "key" in error_str:
            return "🔑 Configuration issue detected. Please contact support."
        elif "network" in error_str or "connection" in error_str:
            return "🌐 Network connectivity issue. Please try again."
        else:
            print("🔍 AI Generation Error: {}".format(str(e)))  # For debugging
            return "⚠️ I encountered an error while processing your request. Please try again."

# Routes
@app.get("/")
async def root():
    return FileResponse("static/index.html")

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "ai_online": wave_ai is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/chat")
async def chat(message: ChatMessage):
    try:
        print("💬 Received message: {}...".format(message.message[:50]))
        
        # Generate AI response
        response_text = await generate_response(message.message)
        
        print("✅ Response generated successfully")
        
        # Store conversation
        conversations.append({
            "user": message.message,
            "assistant": response_text,
            "timestamp": datetime.now().isoformat()
        })
        
        return ChatResponse(response=response_text, success=True)
        
    except Exception as e:
        print("❌ Chat endpoint error: {}".format(str(e)))
        return ChatResponse(
            response="Sorry, I encountered an unexpected error. Please try again.", 
            success=False
        )

@app.get("/conversations")
async def get_conversations():
    return {"conversations": conversations[-10:]}  # Last 10 messages

@app.delete("/conversations") 
async def clear_conversations():
    global conversations
    conversations = []
    return {"message": "Chat cleared"}

# For local development only
# if __name__ == "__main__":
#     port = int(os.getenv("PORT", 8000))
#     print("🌊 Starting Wave AI...")
#     uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
