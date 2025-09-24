// Wave AI - Enhanced JavaScript Interface
// Professional functionality with sidebar, chat history, and animations

let isLoading = false;
let messageHistory = [];
let chatSessions = [];
let currentChatId = null;

// Initialize app
document.addEventListener('DOMContentLoaded', function() {
    checkStatus();
    focusInput();
    setupEventListeners();
    initializeChat();
});

function setupEventListeners() {
    const input = document.getElementById('messageInput');
    
    // Auto-resize textarea and toggle send button
    input.addEventListener('input', function() {
        autoResize(this);
        toggleSendButton();
    });
    
    // Focus input when clicking anywhere (but not on sidebar or modal)
    document.addEventListener('click', function(e) {
        if (!e.target.closest('.sidebar') && 
            !e.target.closest('.modal') && 
            !e.target.closest('button') &&
            !e.target.closest('.header-actions')) {
            input.focus();
        }
    });

    // Close sidebar when clicking outside on mobile
    document.addEventListener('click', function(e) {
        const sidebar = document.getElementById('sidebar');
        const sidebarToggle = document.getElementById('sidebarToggle');
        
        if (window.innerWidth <= 768 && 
            sidebar.classList.contains('open') &&
            !sidebar.contains(e.target) && 
            !sidebarToggle.contains(e.target)) {
            toggleSidebar();
        }
    });
}

function initializeChat() {
    currentChatId = generateChatId();
    updateChatHistory();
}

function autoResize(textarea) {
    textarea.style.height = 'auto';
    textarea.style.height = Math.min(textarea.scrollHeight, 120) + 'px';
}

function toggleSendButton() {
    const input = document.getElementById('messageInput');
    const sendBtn = document.getElementById('sendBtn');
    const hasContent = input.value.trim().length > 0;
    sendBtn.disabled = !hasContent || isLoading;
}

function handleKeyDown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
    }
}

function focusInput() {
    document.getElementById('messageInput').focus();
}

// Check AI status
async function checkStatus() {
    try {
        const response = await fetch('/health');
        const data = await response.json();
        const statusDot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        
        if (data.ai_online) {
            statusDot.classList.remove('offline');
            statusText.textContent = 'AI Online';
        } else {
            statusDot.classList.add('offline');
            statusText.textContent = 'AI Offline';
        }
    } catch (error) {
        console.error('Health check failed:', error);
        document.getElementById('statusDot').classList.add('offline');
        document.getElementById('statusText').textContent = 'Connection Error';
    }
}

// Send sample question
function sendSample(message) {
    document.getElementById('messageInput').value = message;
    autoResize(document.getElementById('messageInput'));
    toggleSendButton();
    sendMessage();
}

// Send message to AI
async function sendMessage() {
    if (isLoading) return;
    
    const input = document.getElementById('messageInput');
    const message = input.value.trim();
    if (!message) return;
    
    // Hide welcome message
    const welcomeMessage = document.querySelector('.welcome-message');
    if (welcomeMessage) {
        welcomeMessage.style.display = 'none';
    }
    
    // Add user message
    addMessage('user', message);
    messageHistory.push({role: 'user', content: message});
    
    // Clear input
    input.value = '';
    autoResize(input);
    toggleSendButton();
    
    // Show typing indicator
    showTyping();
    
    try {
        isLoading = true;
        const response = await fetch('/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: message })
        });
        
        const data = await response.json();
        hideTyping();
        
        if (data.success) {
            addMessage('assistant', data.response);
            messageHistory.push({role: 'assistant', content: data.response});
        } else {
            addMessage('assistant', data.response || 'Sorry, I encountered an error.');
        }
        
    } catch (error) {
        console.error('Chat request failed:', error);
        hideTyping();
        addMessage('assistant', 'Sorry, I encountered a connection error. Please try again.');
    } finally {
        isLoading = false;
        toggleSendButton();
        focusInput();
    }
}


// Format message content
function formatMessage(content) {
    return content
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/`(.*?)`/g, '<code style="background: var(--bg-tertiary); padding: 2px 6px; border-radius: 4px; font-family: monospace;">$1</code>')
        .replace(/\n/g, '<br>')
        .replace(/```([\\s\\S]*?)```/g, '<pre style="background: var(--bg-tertiary); padding: 1rem; border-radius: 8px; overflow-x: auto; margin: 0.5rem 0; border: 1px solid var(--border);"><code>$1</code></pre>');
}

// Show typing indicator
function showTyping() {
    const typingIndicator = document.getElementById('typingIndicator');
    typingIndicator.style.display = 'flex';
    document.getElementById('messages').scrollTop = document.getElementById('messages').scrollHeight;
}

// Hide typing indicator
function hideTyping() {
    document.getElementById('typingIndicator').style.display = 'none';
}

// Clear chat
async function clearChat() {
    if (messageHistory.length === 0) {
        return;
    }
    
    if (confirm('Are you sure you want to clear the chat?')) {
        try {
            await fetch('/conversations', { method: 'DELETE' });
            
            // Clear messages
            messageHistory = [];
            const messages = document.getElementById('messages');
            messages.innerHTML = `
                <div class="welcome-message">
                    <div class="welcome-icon">🌊</div>
                    <h2>Welcome to Wave AI</h2>
                    <p>Your professional AI assistant powered by enterprise-grade technology, ready to help with anything you need.</p>
                    <div class="sample-questions">
                        <button class="sample-btn" onclick="sendSample('Tell me a fun fact')">Tell me a fun fact</button>
                        <button class="sample-btn" onclick="sendSample('Help me write an email')">Help me write an email</button>
                        <button class="sample-btn" onclick="sendSample('Explain quantum computing')">Explain quantum computing</button>
                    </div>
                </div>
            `;
            
            focusInput();
            
        } catch (error) {
            console.error('Failed to clear chat:', error);
        }
    }
}

// Show about modal
function showAbout() {
    document.getElementById('aboutModal').style.display = 'flex';
}

// Hide about modal
function hideAbout() {
    document.getElementById('aboutModal').style.display = 'none';
}

// Close modal when clicking outside
document.addEventListener('click', function(e) {
    const modal = document.getElementById('aboutModal');
    if (e.target === modal) {
        hideAbout();
    }
});

// ===== SIDEBAR & CHAT MANAGEMENT =====

function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const hamburger = document.querySelector('.hamburger');
    
    sidebar.classList.toggle('open');
    hamburger.classList.toggle('active');
}

function generateChatId() {
    return 'chat_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

function createNewChat() {
    // Save current chat if it has messages
    if (messageHistory.length > 0) {
        saveChatSession();
    }
    
    // Create new chat
    currentChatId = generateChatId();
    messageHistory = [];
    
    // Reset interface
    resetChatInterface();
    updateChatHistory();
    focusInput();
}

function saveChatSession() {
    if (messageHistory.length === 0) return;
    
    const firstMessage = messageHistory.find(msg => msg.role === 'user');
    const title = firstMessage ? 
        firstMessage.content.substring(0, 40) + (firstMessage.content.length > 40 ? '...' : '') :
        'New Conversation';
    
    const existingIndex = chatSessions.findIndex(chat => chat.id === currentChatId);
    const chatData = {
        id: currentChatId,
        title: title,
        messages: [...messageHistory],
        timestamp: new Date(),
        preview: firstMessage ? firstMessage.content.substring(0, 60) + '...' : ''
    };
    
    if (existingIndex !== -1) {
        chatSessions[existingIndex] = chatData;
    } else {
        chatSessions.unshift(chatData);
    }
    
    // Keep only last 20 chats
    chatSessions = chatSessions.slice(0, 20);
}

function loadChatSession(chatId) {
    // Save current chat first
    if (messageHistory.length > 0) {
        saveChatSession();
    }
    
    const chat = chatSessions.find(c => c.id === chatId);
    if (!chat) return;
    
    currentChatId = chatId;
    messageHistory = [...chat.messages];
    
    // Clear and rebuild messages
    resetChatInterface();
    messageHistory.forEach(msg => {
        addMessage(msg.role, msg.content, false);
    });
    
    updateChatHistory();
}

function updateChatHistory() {
    const chatList = document.getElementById('chatList');
    
    if (chatSessions.length === 0) {
        chatList.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon floating">💭</div>
                <p>No conversations yet</p>
            </div>
        `;
        return;
    }
    
    chatList.innerHTML = chatSessions.map(chat => `
        <div class="chat-item ${chat.id === currentChatId ? 'active' : ''}" 
             onclick="loadChatSession('${chat.id}')">
            <div class="chat-title">${chat.title}</div>
            <div class="chat-preview">${chat.preview}</div>
        </div>
    `).join('');
}

function clearCurrentChat() {
    if (messageHistory.length === 0) return;
    
    if (confirm('Clear the current chat?')) {
        messageHistory = [];
        resetChatInterface();
        
        // Remove from saved sessions if it exists
        chatSessions = chatSessions.filter(chat => chat.id !== currentChatId);
        updateChatHistory();
        
        // Create new chat
        currentChatId = generateChatId();
        focusInput();
    }
}

function clearAllChats() {
    if (chatSessions.length === 0 && messageHistory.length === 0) return;
    
    if (confirm('Clear all chat history? This cannot be undone.')) {
        chatSessions = [];
        messageHistory = [];
        resetChatInterface();
        updateChatHistory();
        
        // Create new chat
        currentChatId = generateChatId();
        focusInput();
    }
}

function resetChatInterface() {
    const messages = document.getElementById('messages');
    messages.innerHTML = `
        <div class="welcome-message">
            <div class="welcome-icon">🌊</div>
            <h2>Welcome to Wave AI</h2>
            <p>Your professional AI assistant powered by enterprise-grade technology, ready to help with anything you need.</p>
            <div class="sample-questions">
                <button class="sample-btn" onclick="sendSample('Tell me a fun fact')">Tell me a fun fact</button>
                <button class="sample-btn" onclick="sendSample('Help me write an email')">Help me write an email</button>
                <button class="sample-btn" onclick="sendSample('Explain quantum computing')">Explain quantum computing</button>
            </div>
        </div>
    `;
}

// ===== ENHANCED MESSAGE HANDLING =====

// Add message to chat with session saving
function addMessage(role, content, shouldSave = true) {
    const messages = document.getElementById('messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;
    
    const time = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
    const avatar = role === 'user' ? '👤' : '🌊';
    
    messageDiv.innerHTML = `
        <div class="message-avatar">${avatar}</div>
        <div class="message-content">
            <div class="message-bubble">${formatMessage(content)}</div>
            <div class="message-time">${time}</div>
        </div>
    `;
    
    messages.appendChild(messageDiv);
    messages.scrollTop = messages.scrollHeight;
    
    if (shouldSave) {
        // Auto-save chat session after each message
        setTimeout(() => {
            saveChatSession();
            updateChatHistory();
        }, 100);
    }
}

// Override clearChat to use new functions
function clearChat() {
    clearCurrentChat();
}

// Check status periodically
setInterval(checkStatus, 30000);

// Auto-save chat sessions every 30 seconds
setInterval(() => {
    if (messageHistory.length > 0) {
        saveChatSession();
    }
}, 30000);

// Initialize send button state
setTimeout(toggleSendButton, 100);
