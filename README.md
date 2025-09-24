# 🌊 Wave AI - Simple AI Assistant (v1.0)

**Workshop-Ready AI Assistant - Clean, Professional & Easy to Use**

> *The simplified version of Pixel AI - perfect for workshops, learning, and demonstrations. Built with FastAPI and Google Gemini.*

[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.8+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Gemini](https://img.shields.io/badge/Google%20Gemini-1.5%20Pro-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)

---

## ✨ **What Makes Wave AI Special?**

Wave AI is the **simplified version** of Pixel AI, designed specifically for **workshops and learning**. No complex features or overwhelming options - just essential AI chat functionality that works perfectly for:

- **🎓 Educational Workshops** - Perfect for teaching AI basics
- **👶 Beginners** - Simple, clean interface that's easy to understand  
- **💬 Pure Chat Focus** - Just you and the AI, no distractions
- **🌊 Professional Design** - Beautiful dark black theme with smooth animations
- **⚡ Based on Pixel AI** - Uses the same proven, reliable architecture
- **📚 Learning Friendly** - Great for demonstrations and training sessions

---

## 🚀 **Quick Start - Choose Your Deployment Method**

### **🔑 Prerequisites**
1. **Google AI Studio**: Go to [Google AI Studio](https://ai.google.dev)
   - Create a free account
   - Generate your Gemini API key
2. **Google Cloud Project**: Set up with **Owner** permissions
   - Create or use existing GCP project
   - Enable billing (required for Cloud Run)
   - **You must have Owner role** on the project for the script to work
3. **Google Cloud Shell**: Use GCP Cloud Shell (recommended)
   - Automatically authenticated with your GCP account
   - Pre-installed with `gcloud` CLI
   - No local setup required

---

## **Option 1: 🤖 Automated Deployment (Recommended)**

**One-click deployment with our smart script!**

```bash
# Clone the project
git clone <your-repo-url>
cd wave_ai_assistant

# Run the automated deployment script
chmod +x deploy.sh
./deploy.sh
```

**✨ What the script does:**
- 🔍 Checks your Google Cloud setup
- 🏗️ Creates all required infrastructure
- 🚀 Deploys Wave AI to Cloud Run
- 🌐 Provides you with a live URL

**Perfect for:** Beginners, workshops, quick demos

---

## **Option 2: 📖 Manual Deployment (For Learning)**

**Step-by-step deployment to understand the process!**

Follow the detailed guide: **[📋 MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)**

**What you'll learn:**
- 🛠️ Google Cloud resource setup
- 🏗️ Docker containerization
- ☁️ Cloud Run deployment
- 🔧 Troubleshooting techniques

**Perfect for:** Students, developers wanting to understand the architecture

---

**🌐 Result:** Your Wave AI will be live on Google Cloud Run with a public URL!

---

## 🎯 **Key Features**

### **🧠 Smart AI Modes**
Choose the perfect mode for your needs:

- **💬 General** - Everyday questions and help
- **💻 Developer** - Programming and tech help  
- **🎨 Creative** - Writing and brainstorming
- **🎓 Tutor** - Learning and explanations
- **💼 Professional** - Business and career advice

### **📱 Beginner-Friendly Features**
- **Simple Interface** - No confusing buttons or menus
- **Quick Starters** - Click to try common tasks
- **Smart Suggestions** - Get ideas for follow-up questions
- **Conversation History** - Save and revisit your chats
- **Export Chats** - Download your conversations as CSV

### **🌙 Beautiful Dark Theme**
- **Easy on the Eyes** - Perfect for extended use
- **Modern Design** - Clean and professional
- **Responsive** - Works on any device
- **Animated** - Smooth and engaging

---

## 💡 **Perfect for Workshops**

Wave AI is ideal for AI workshops and training because:

- **No Complex Setup** - Just install and run
- **Clear Examples** - Easy to demonstrate
- **Multiple Modes** - Show different AI personalities
- **Conversation Export** - Students can save their work
- **Developer Info** - Built-in "About" section

---

## 🛠️ **What's Included**

```
📦 Wave AI
├── 🚀 main.py             # FastAPI application with built-in UI
├── 📋 requirements.txt    # Production dependencies
├── 🚢 deploy.sh          # Deployment script
├── 🐳 Dockerfile         # Container setup
└── 📖 README.md          # This guide
```

---

## 🌍 **Deployment Options**

### **Local Development** (Recommended for workshops)
```bash
python main.py
```

### **Google Cloud Run**
```bash
./deploy.sh  # One-command deployment
```

### **Docker**
```bash
docker build -t wave-ai .
docker run -p 8000:8000 -e GEMINI_API_KEY=your-key wave-ai
```

---

## 🎯 **Use Cases**

### **For Beginners**
- **Learn AI Basics** - Understand how AI assistants work
- **Practice Conversations** - Get comfortable with AI interaction
- **Explore Different Modes** - See AI adapt to different roles

### **For Workshops**
- **Demonstrate AI** - Show how modern AI works
- **Interactive Learning** - Let students try different prompts
- **Export Results** - Students can save and review conversations

### **For Everyday Use**
- **Get Quick Answers** - Ask anything you want to know
- **Creative Help** - Brainstorm ideas and solve problems
- **Learning Support** - Explain complex topics simply

---

## 🎨 **Screenshots**

### **Main Interface**
- 🌊 **Wave Animation** - Beautiful animated title
- 💬 **Clean Chat** - Simple message interface
- 🎯 **Quick Starters** - Easy buttons to get started

### **Features**
- 📊 **Live Stats** - See your conversation progress
- 🔄 **Smart Suggestions** - AI suggests follow-up questions
- 📱 **Mobile Friendly** - Works perfectly on phones

---

## ⚙️ **Configuration**

### **Required**
```bash
GEMINI_API_KEY=your_google_gemini_api_key
```

### **Optional (Advanced)**
Wave AI works great with defaults, but you can customize:
- AI model temperature
- Response length
- Conversation history

---

## 👨‍💻 **About the Developer**

**Ayush Shukla**  
*Cloud & DevOps Professional | AI Innovator*

> *"Let my work speak for myself...Cheers....!!!! 🥂 😁"*

### 📬 Connect
- **📧 Email**: [ayush2511shukla@gmail.com](mailto:ayush2511shukla@gmail.com)
- **💼 LinkedIn**: [Connect with me](http://linkedin.com/in/ayush-shukla-15957a196)
- **🐙 GitHub**: [Terra-GCP](https://github.com/Terra-GCP)
- **📱 Phone**: +91-7843904780

---

## 🆚 **Wave AI vs Complex AI Tools**

| Feature | Wave AI | Complex Tools |
|---------|---------|---------------|
| **Setup Time** | < 5 minutes | Hours |
| **Dependencies** | 4 packages | 20+ packages |
| **Interface** | Simple & Clean | Complex & Overwhelming |
| **Learning Curve** | Minutes | Days |
| **Workshop Ready** | ✅ Perfect | ❌ Too Complex |
| **Beginner Friendly** | ✅ Yes | ❌ No |

---

## 🚨 **Troubleshooting**

### **Common Issues**

**❌ "API Key not found"**
```bash
# Make sure you set your key
export GEMINI_API_KEY="your-actual-key-here"
```

**❌ "FastAPI not found"**
```bash
# Install the requirements
pip install -r requirements.txt
```

**❌ "Port already in use"**
```bash
# Use a different port
uvicorn main:app --host 0.0.0.0 --port 8001
```

---

## 🤝 **Contributing**

Wave AI is open source! We welcome:
- **Bug Reports** - Help us improve
- **Feature Requests** - Tell us what you need
- **Code Contributions** - Make it better

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📄 **License**

MIT License - Use freely, modify as needed, share with others!

---

## 🙏 **Acknowledgments**

- **Google Gemini** - Powerful AI capabilities
- **Streamlit** - Amazing Python web framework
- **Python Community** - Continuous inspiration
- **Workshop Participants** - Feedback and ideas

---

## 🎯 **What's Next?**

Wave AI is continuously improving based on user feedback:

- **More AI Modes** - Additional specialized assistants
- **Better Export** - More file formats
- **Enhanced UI** - Even more beginner-friendly
- **Workshop Tools** - Special features for training

---

**© 2024 Wave AI • Built with ❤️ by Ayush Shukla • Powered by Google Gemini AI**

*Simple • Intelligent • Reliable • Perfect for Beginners*

---

## 🎉 **Ready to Get Started?**

1. **Get your free Gemini API key** → [Google AI Studio](https://ai.google.dev)
2. **Install Wave AI** → `pip install -r requirements.txt`
3. **Set your key** → `export GEMINI_API_KEY="your-key"`
4. **Start chatting** → `python main.py`

**Welcome to the future of simple AI! 🌊**