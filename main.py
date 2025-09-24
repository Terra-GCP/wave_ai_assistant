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

# Initialize Gemini AI
def initialize_ai():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("❌ GEMINI_API_KEY not found")
        return None
    
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-pro")
        print("✅ Wave AI initialized successfully")
        return model
    except Exception as e:
        print(f"❌ Failed to initialize AI: {e}")
        return None

# Initialize AI
wave_ai = initialize_ai()

# Startup event to validate everything is ready
@app.on_event("startup")
async def startup_event():
    print("🌊 Wave AI container starting...")
    print(f"📡 Port configured for: {os.getenv('PORT', '8000')}")
    print(f"🔑 API Key configured: {'✅' if os.getenv('GEMINI_API_KEY') else '❌'}")
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

# Generate AI Response
async def generate_response(message: str) -> str:
    if not wave_ai:
        return "❌ AI is currently offline. Please check configuration."
    
    try:
        response = wave_ai.generate_content(
            f"You are Wave AI, a helpful assistant created by Ayush Shukla. Provide clear and helpful responses.\n\nHuman: {message}\n\nWave AI:",
            generation_config={
                "max_output_tokens": 1024,
                "temperature": 0.7,
            }
        )
        
        return response.text if response and response.text else "I couldn't generate a response."
        
    except Exception as e:
        return f"⚠️ Error: {str(e)}"

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
    response_text = await generate_response(message.message)
    
    # Store conversation
    conversations.append({
        "user": message.message,
        "assistant": response_text,
        "timestamp": datetime.now().isoformat()
    })
    
    return ChatResponse(response=response_text, success=True)

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
