# GPT & Gemini Feature Parity Plan

## Executive Summary
This document outlines all features needed to transform TEIA AI Agents into a system comparable to ChatGPT and Google Gemini, covering tool/function calling, web search, multimodal capabilities, advanced UI features, and more.

**Current Status**: ✅ Strong RAG foundation | ⚠️ Missing advanced GPT/Gemini features

---

## Current System Analysis

### ✅ What You Already Have
1. **Strong RAG Foundation**
   - Document processing (PDF, Excel, PowerPoint, Word, JSON, HTML, Markdown)
   - Vector search with Milvus (HNSW indexing)
   - Hybrid search (dense + BM25 sparse)
   - Cross-encoder reranking
   - Advanced chunking (recursive, semantic)

2. **Production Backend**
   - FastAPI with async support
   - PostgreSQL for data persistence
   - JWT authentication
   - Streaming responses (SSE)
   - LLM provider abstraction (OpenAI, Anthropic ready)
   - Observability (tracing, logging)
   - Security (PII detection, rate limiting)

3. **Modern Frontend**
   - React + TypeScript + Material-UI
   - Real-time streaming chat
   - Document management
   - Session/history management
   - Admin panel
   - Authentication

### ❌ What's Missing (GPT/Gemini Features)

---

## CRITICAL MISSING FEATURES

### 🔧 1. Function/Tool Calling System

**What GPT/Gemini Have:**
- Define custom functions/tools
- AI decides when to call tools
- Execute tools and return results
- Multi-step reasoning with tool chains
- Parallel tool execution

**What You Need to Build:**

#### Backend Implementation

**File Structure:**
```
src/services/tools/
├── __init__.py
├── base.py              # Base tool class
├── registry.py          # Tool registry
├── executor.py          # Tool execution engine
├── builtin/
│   ├── __init__.py
│   ├── web_search.py    # Web search tool
│   ├── calculator.py    # Math operations
│   ├── code_executor.py # Code execution
│   ├── file_ops.py      # File operations
│   └── database.py      # Database queries
```

**Implementation Steps:**

1. **Base Tool Class** (`src/services/tools/base.py`):
```python
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

class ToolParameter(BaseModel):
    name: str
    type: str  # string, number, boolean, array, object
    description: str
    required: bool = True
    enum: Optional[List[Any]] = None

class ToolDefinition(BaseModel):
    name: str
    description: str
    parameters: List[ToolParameter]
    
    def to_openai_schema(self) -> Dict:
        """Convert to OpenAI function calling format"""
        properties = {}
        required = []
        
        for param in self.parameters:
            properties[param.name] = {
                "type": param.type,
                "description": param.description
            }
            if param.enum:
                properties[param.name]["enum"] = param.enum
            if param.required:
                required.append(param.name)
        
        return {
            "name": self.name,
            "description": self.description,
            "parameters": {
                "type": "object",
                "properties": properties,
                "required": required
            }
        }

class BaseTool(ABC):
    """Base class for all tools"""
    
    @property
    @abstractmethod
    def definition(self) -> ToolDefinition:
        """Return tool definition"""
        pass
    
    @abstractmethod
    async def execute(self, **kwargs) -> Dict[str, Any]:
        """Execute the tool"""
        pass
    
    def validate_input(self, **kwargs) -> bool:
        """Validate input parameters"""
        required = [p.name for p in self.definition.parameters if p.required]
        return all(k in kwargs for k in required)
```

2. **Tool Registry** (`src/services/tools/registry.py`):
```python
from typing import Dict, List, Optional
from src.services.tools.base import BaseTool, ToolDefinition

class ToolRegistry:
    """Central registry for all tools"""
    
    def __init__(self):
        self._tools: Dict[str, BaseTool] = {}
    
    def register(self, tool: BaseTool):
        """Register a tool"""
        self._tools[tool.definition.name] = tool
    
    def get(self, name: str) -> Optional[BaseTool]:
        """Get tool by name"""
        return self._tools.get(name)
    
    def list_tools(self) -> List[ToolDefinition]:
        """List all registered tools"""
        return [tool.definition for tool in self._tools.values()]
    
    def get_openai_functions(self) -> List[Dict]:
        """Get all tools in OpenAI function calling format"""
        return [tool.definition.to_openai_schema() for tool in self._tools.values()]

# Global registry instance
tool_registry = ToolRegistry()
```

3. **Web Search Tool** (`src/services/tools/builtin/web_search.py`):
```python
import asyncio
import httpx
from typing import Dict, Any, List
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter

class WebSearchTool(BaseTool):
    """Search the web for current information"""
    
    def __init__(self, api_key: str, search_engine: str = "serper"):
        self.api_key = api_key
        self.search_engine = search_engine
    
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="web_search",
            description="Search the web for current information, news, facts, or data. Use this when you need up-to-date information not in the documents.",
            parameters=[
                ToolParameter(
                    name="query",
                    type="string",
                    description="The search query string",
                    required=True
                ),
                ToolParameter(
                    name="num_results",
                    type="number",
                    description="Number of results to return (default: 5)",
                    required=False
                )
            ]
        )
    
    async def execute(self, query: str, num_results: int = 5) -> Dict[str, Any]:
        """Execute web search using Serper API"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://google.serper.dev/search",
                    json={"q": query, "num": num_results},
                    headers={
                        "X-API-KEY": self.api_key,
                        "Content-Type": "application/json"
                    },
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    data = response.json()
                    results = []
                    
                    for item in data.get("organic", [])[:num_results]:
                        results.append({
                            "title": item.get("title"),
                            "snippet": item.get("snippet"),
                            "link": item.get("link")
                        })
                    
                    return {
                        "success": True,
                        "results": results,
                        "query": query
                    }
                else:
                    return {
                        "success": False,
                        "error": f"Search API returned {response.status_code}"
                    }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
```

4. **Calculator Tool** (`src/services/tools/builtin/calculator.py`):
```python
import math
import ast
import operator
from typing import Dict, Any
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter

class CalculatorTool(BaseTool):
    """Perform mathematical calculations"""
    
    # Safe operators
    OPERATORS = {
        ast.Add: operator.add,
        ast.Sub: operator.sub,
        ast.Mult: operator.mul,
        ast.Div: operator.truediv,
        ast.Pow: operator.pow,
        ast.USub: operator.neg,
    }
    
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="calculator",
            description="Perform mathematical calculations. Supports basic arithmetic, powers, and math functions.",
            parameters=[
                ToolParameter(
                    name="expression",
                    type="string",
                    description="Mathematical expression to evaluate (e.g., '2 + 2', 'sqrt(16)', 'sin(pi/2)')",
                    required=True
                )
            ]
        )
    
    async def execute(self, expression: str) -> Dict[str, Any]:
        """Safely evaluate mathematical expression"""
        try:
            # Add common math functions
            safe_dict = {
                'sqrt': math.sqrt,
                'sin': math.sin,
                'cos': math.cos,
                'tan': math.tan,
                'log': math.log,
                'exp': math.exp,
                'pi': math.pi,
                'e': math.e,
            }
            
            result = eval(expression, {"__builtins__": {}}, safe_dict)
            
            return {
                "success": True,
                "result": result,
                "expression": expression
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Calculation error: {str(e)}"
            }
```

5. **Code Executor Tool** (`src/services/tools/builtin/code_executor.py`):
```python
import asyncio
import tempfile
import os
from typing import Dict, Any
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter

class CodeExecutorTool(BaseTool):
    """Execute Python code in a sandboxed environment"""
    
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="execute_code",
            description="Execute Python code and return the output. Use for data analysis, calculations, or generating visualizations.",
            parameters=[
                ToolParameter(
                    name="code",
                    type="string",
                    description="Python code to execute",
                    required=True
                ),
                ToolParameter(
                    name="language",
                    type="string",
                    description="Programming language (default: python)",
                    required=False,
                    enum=["python", "javascript"]
                )
            ]
        )
    
    async def execute(self, code: str, language: str = "python") -> Dict[str, Any]:
        """Execute code in subprocess with timeout"""
        try:
            # Create temporary file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
                f.write(code)
                temp_file = f.name
            
            # Execute with timeout
            process = await asyncio.create_subprocess_exec(
                "python", temp_file,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            try:
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(),
                    timeout=30.0
                )
                
                os.unlink(temp_file)
                
                return {
                    "success": True,
                    "output": stdout.decode(),
                    "error": stderr.decode() if stderr else None,
                    "exit_code": process.returncode
                }
            except asyncio.TimeoutError:
                process.kill()
                os.unlink(temp_file)
                return {
                    "success": False,
                    "error": "Execution timed out after 30 seconds"
                }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
```

6. **Tool Executor Engine** (`src/services/tools/executor.py`):
```python
import json
from typing import List, Dict, Any, Optional
from src.services.tools.registry import tool_registry
from src.core.observability import tracer

class ToolExecutor:
    """Execute tools based on LLM function calls"""
    
    async def execute_tool_call(
        self,
        tool_name: str,
        arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute a single tool call"""
        span = tracer.start_span(f"tool_execution:{tool_name}")
        
        try:
            tool = tool_registry.get(tool_name)
            if not tool:
                return {
                    "success": False,
                    "error": f"Tool '{tool_name}' not found"
                }
            
            if not tool.validate_input(**arguments):
                return {
                    "success": False,
                    "error": "Invalid tool arguments"
                }
            
            result = await tool.execute(**arguments)
            tracer.end_span(span, metadata={"tool": tool_name, "success": result.get("success")})
            return result
            
        except Exception as e:
            tracer.end_span(span, metadata={"error": str(e)})
            return {
                "success": False,
                "error": str(e)
            }
    
    async def execute_parallel_tools(
        self,
        tool_calls: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Execute multiple tools in parallel"""
        import asyncio
        
        tasks = []
        for call in tool_calls:
            task = self.execute_tool_call(
                tool_name=call["function"]["name"],
                arguments=json.loads(call["function"]["arguments"])
            )
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        return [
            r if isinstance(r, dict) else {"success": False, "error": str(r)}
            for r in results
        ]

tool_executor = ToolExecutor()
```

7. **Integrate with Chat Handler** (`src/modules/apis/v1/chat/handlers.py`):
```python
# Add to imports
from src.services.tools.registry import tool_registry
from src.services.tools.executor import tool_executor

# Modify handle_chat_query to support tool calling:
async def handle_chat_query_with_tools(
    payload: ChatQueryRequest,
    user: User,
    db: AsyncSession,
) -> ChatQueryResponse:
    """Chat with tool/function calling support"""
    
    # ... existing retrieval code ...
    
    # Get available tools
    tools = tool_registry.get_openai_functions()
    
    # Call LLM with tools
    messages = [
        {"role": "system", "content": system_prompt},
        *conversation_history,
        {"role": "user", "content": payload.message}
    ]
    
    max_iterations = 5
    for iteration in range(max_iterations):
        response = await openai_client.chat.completions.create(
            model=payload.model or "gpt-4o",
            messages=messages,
            tools=tools,
            tool_choice="auto"
        )
        
        message = response.choices[0].message
        
        # If no tool calls, return response
        if not message.tool_calls:
            # Save and return
            await chat_service.append_message(
                db, session=session, role="assistant",
                content=message.content
            )
            return ChatQueryResponse(...)
        
        # Execute tool calls
        messages.append(message.dict())
        
        for tool_call in message.tool_calls:
            result = await tool_executor.execute_tool_call(
                tool_name=tool_call.function.name,
                arguments=json.loads(tool_call.function.arguments)
            )
            
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": json.dumps(result)
            })
        
        # Continue loop with tool results
    
    return {"error": "Max tool iterations reached"}
```

---

### 🌐 2. Real-Time Web Search Integration

**Implementation Options:**

**A. Serper API (Recommended - Google Search)**
```python
# src/core/settings/config.py
SERPER_API_KEY: str = ""  # Get from serper.dev ($50 for 5000 searches)

# src/services/search/web_search.py
class WebSearchService:
    async def search_google(self, query: str) -> List[Dict]:
        """Search Google via Serper API"""
        # Implementation in web_search tool above
```

**B. Tavily API (AI-optimized search)**
```python
# Better for RAG - extracts relevant content automatically
import tavily
client = tavily.Client(api_key="...")
results = client.search(query="...", search_depth="advanced")
```

**C. Brave Search API (Privacy-focused)**
```python
# Free tier: 2000 queries/month
async def brave_search(query: str):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.search.brave.com/res/v1/web/search",
            headers={"X-Subscription-Token": BRAVE_API_KEY},
            params={"q": query}
        )
```

**D. DuckDuckGo (Free, No API Key)**
```python
from duckduckgo_search import DDGS

async def ddg_search(query: str) -> List[Dict]:
    results = DDGS().text(query, max_results=5)
    return [{"title": r["title"], "body": r["body"], "url": r["href"]} for r in results]
```

**Integration Pattern:**
```python
# Add to system prompt
system_prompt = """
You are TEIA AI Assistant with access to:
1. Internal documents via RAG
2. Real-time web search for current information

When to use web search:
- Current events, news, dates after your training cutoff
- Live data (stock prices, weather, sports scores)
- Fact-checking or verification
- Information not in uploaded documents

Always cite sources from web search.
"""
```

---

### 🖼️ 3. Multimodal Capabilities (Images, Audio, Video)

**What GPT/Gemini Have:**
- Image understanding (GPT-4V, Gemini Pro Vision)
- Image generation (DALL-E 3)
- Audio transcription (Whisper)
- Text-to-speech
- Video understanding (Gemini)

**Implementation Plan:**

#### A. Image Understanding (Vision)

**File:** `src/services/multimodal/vision.py`
```python
import base64
from openai import AsyncOpenAI
from anthropic import AsyncAnthropic

class VisionService:
    def __init__(self):
        self.openai = AsyncOpenAI()
        self.anthropic = AsyncAnthropic()
    
    async def analyze_image_openai(
        self,
        image_url: str = None,
        image_base64: str = None,
        prompt: str = "Describe this image in detail"
    ) -> str:
        """Analyze image using GPT-4 Vision"""
        
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": image_url or f"data:image/jpeg;base64,{image_base64}"
                        }
                    }
                ]
            }
        ]
        
        response = await self.openai.chat.completions.create(
            model="gpt-4o",  # or gpt-4-vision-preview
            messages=messages,
            max_tokens=500
        )
        
        return response.choices[0].message.content
    
    async def analyze_image_anthropic(
        self,
        image_base64: str,
        media_type: str,
        prompt: str
    ) -> str:
        """Analyze image using Claude 3"""
        
        message = await self.anthropic.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1024,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_base64,
                            },
                        },
                        {
                            "type": "text",
                            "text": prompt
                        }
                    ],
                }
            ],
        )
        
        return message.content[0].text
```

**Update Frontend to Support Image Upload:**

`Front-End/src/components/ChatComposer.tsx`:
```tsx
import AttachFileIcon from '@mui/icons-material/AttachFile';
import ImageIcon from '@mui/icons-material/Image';

const [attachedImages, setAttachedImages] = useState<File[]>([]);

const handleImageUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
  if (event.target.files) {
    setAttachedImages(Array.from(event.target.files));
  }
};

// Add to UI:
<IconButton component="label">
  <ImageIcon />
  <input
    type="file"
    hidden
    accept="image/*"
    multiple
    onChange={handleImageUpload}
  />
</IconButton>

// Display attached images
{attachedImages.map((img, idx) => (
  <Chip
    key={idx}
    label={img.name}
    onDelete={() => setAttachedImages(prev => prev.filter((_, i) => i !== idx))}
  />
))}
```

#### B. Image Generation

**File:** `src/services/multimodal/image_generation.py`
```python
from openai import AsyncOpenAI

class ImageGenerationService:
    def __init__(self):
        self.client = AsyncOpenAI()
    
    async def generate_image(
        self,
        prompt: str,
        model: str = "dall-e-3",
        size: str = "1024x1024",
        quality: str = "standard",
        n: int = 1
    ) -> List[str]:
        """Generate images using DALL-E 3"""
        
        response = await self.client.images.generate(
            model=model,
            prompt=prompt,
            size=size,
            quality=quality,
            n=n
        )
        
        return [img.url for img in response.data]

# Add as a tool
class ImageGenerationTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="generate_image",
            description="Generate an image from a text description",
            parameters=[
                ToolParameter(
                    name="prompt",
                    type="string",
                    description="Detailed description of the image to generate",
                    required=True
                )
            ]
        )
```

#### C. Audio Transcription (Speech-to-Text)

**File:** `src/services/multimodal/audio.py`
```python
from openai import AsyncOpenAI

class AudioService:
    def __init__(self):
        self.client = AsyncOpenAI()
    
    async def transcribe_audio(
        self,
        audio_file_path: str,
        language: str = None
    ) -> str:
        """Transcribe audio using Whisper"""
        
        with open(audio_file_path, "rb") as audio_file:
            transcript = await self.client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language=language
            )
        
        return transcript.text
    
    async def text_to_speech(
        self,
        text: str,
        voice: str = "alloy",
        model: str = "tts-1"
    ) -> bytes:
        """Convert text to speech"""
        
        response = await self.client.audio.speech.create(
            model=model,
            voice=voice,
            input=text
        )
        
        return response.content

# Frontend: Add voice input button
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
const recognition = new SpeechRecognition();

recognition.onresult = (event) => {
  const transcript = event.results[0][0].transcript;
  setMessage(transcript);
};

<IconButton onClick={() => recognition.start()}>
  <MicIcon />
</IconButton>
```

---

### 💾 4. Advanced Context Management

**What GPT/Gemini Have:**
- Long context windows (128K+ tokens)
- Context compression
- Conversation memory
- File attachments in context

**What You Need:**

#### A. Conversation Summarization

**File:** `src/services/memory/conversation_summary.py`
```python
class ConversationSummarizer:
    """Compress long conversations"""
    
    async def summarize_conversation(
        self,
        messages: List[Dict],
        max_summary_tokens: int = 500
    ) -> str:
        """Summarize conversation history"""
        
        conversation_text = "\n".join([
            f"{msg['role']}: {msg['content']}"
            for msg in messages
        ])
        
        response = await openai_client.chat.completions.create(
            model="gpt-4o-mini",  # Cheaper model for summarization
            messages=[
                {
                    "role": "system",
                    "content": "Summarize this conversation, preserving key facts, decisions, and context."
                },
                {
                    "role": "user",
                    "content": conversation_text
                }
            ],
            max_tokens=max_summary_tokens
        )
        
        return response.choices[0].message.content
    
    async def maintain_context_window(
        self,
        messages: List[Dict],
        max_tokens: int = 100000
    ) -> List[Dict]:
        """Keep conversation within token limit"""
        
        total_tokens = sum(len(msg["content"]) / 4 for msg in messages)  # Rough estimate
        
        if total_tokens <= max_tokens:
            return messages
        
        # Summarize older messages
        cutoff = len(messages) // 2
        old_messages = messages[:cutoff]
        recent_messages = messages[cutoff:]
        
        summary = await self.summarize_conversation(old_messages)
        
        return [
            {"role": "system", "content": f"Previous conversation summary: {summary}"},
            *recent_messages
        ]
```

#### B. File Attachments in Chat

**Frontend Update** (`ChatComposer.tsx`):
```tsx
const [attachedFiles, setAttachedFiles] = useState<File[]>([]);

const handleFileAttach = async (files: File[]) => {
  // Upload and extract text
  for (const file of files) {
    const formData = new FormData();
    formData.append('file', file);
    
    const response = await uploadAndExtractText(formData);
    // Add extracted text to message context
  }
};

// In the send handler:
const contextFromFiles = attachedFiles.map(f => f.extractedText).join('\n');
const fullMessage = `${message}\n\nAttached files context:\n${contextFromFiles}`;
```

---

### 📊 5. Data Analysis & Visualization

**What GPT/Gemini Have:**
- Code Interpreter / Code Execution
- Data analysis
- Chart generation
- CSV/Excel analysis

**Implementation:**

**File:** `src/services/tools/builtin/data_analysis.py`
```python
import pandas as pd
import matplotlib.pyplot as plt
import io
import base64

class DataAnalysisTool(BaseTool):
    """Analyze data files and generate visualizations"""
    
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="analyze_data",
            description="Analyze CSV/Excel data and generate charts",
            parameters=[
                ToolParameter(
                    name="file_id",
                    type="string",
                    description="ID of uploaded data file",
                    required=True
                ),
                ToolParameter(
                    name="analysis_type",
                    type="string",
                    description="Type of analysis",
                    required=True,
                    enum=["summary", "correlation", "trend", "distribution"]
                ),
                ToolParameter(
                    name="columns",
                    type="array",
                    description="Columns to analyze",
                    required=False
                )
            ]
        )
    
    async def execute(
        self,
        file_id: str,
        analysis_type: str,
        columns: List[str] = None
    ) -> Dict[str, Any]:
        """Perform data analysis"""
        
        # Load file
        df = pd.read_csv(f"data/uploads/{file_id}.csv")
        
        if analysis_type == "summary":
            summary = df.describe().to_dict()
            return {"success": True, "summary": summary}
        
        elif analysis_type == "correlation":
            corr = df.corr().to_dict()
            
            # Generate heatmap
            plt.figure(figsize=(10, 8))
            plt.imshow(df.corr(), cmap='coolwarm')
            plt.colorbar()
            
            buffer = io.BytesIO()
            plt.savefig(buffer, format='png')
            img_base64 = base64.b64encode(buffer.getvalue()).decode()
            
            return {
                "success": True,
                "correlation": corr,
                "chart": f"data:image/png;base64,{img_base64}"
            }
```

---

### 🎨 6. Advanced UI Features

**What GPT/Gemini Have:**
- Regenerate responses
- Edit previous messages
- Branch conversations
- Share conversations
- Export chat history
- Dark/Light mode
- Keyboard shortcuts
- Suggested prompts
- Typing indicators
- Message reactions
- Code syntax highlighting

**Implementation Checklist:**

1. **Regenerate Response**
```tsx
// In ChatMessageList.tsx
<IconButton onClick={() => handleRegenerate(message.id)}>
  <RefreshIcon />
</IconButton>

const handleRegenerate = async (messageId: string) => {
  // Find message
  const msgIndex = messages.findIndex(m => m.id === messageId);
  const userMessage = messages[msgIndex - 1];
  
  // Remove assistant response
  setMessages(prev => prev.filter((_, i) => i !== msgIndex));
  
  // Resend user message
  await handleSend(userMessage.content);
};
```

2. **Edit Previous Messages**
```tsx
const [editingMessageId, setEditingMessageId] = useState<string | null>(null);
const [editText, setEditText] = useState("");

const handleEdit = async (messageId: string) => {
  const updatedMessages = messages.map(m =>
    m.id === messageId ? { ...m, content: editText } : m
  );
  setMessages(updatedMessages);
  
  // Resend from this point
  const msgIndex = updatedMessages.findIndex(m => m.id === messageId);
  setMessages(prev => prev.slice(0, msgIndex + 1));
  await handleSend(editText);
};
```

3. **Share Conversation**
```tsx
const handleShare = async () => {
  const shareData = {
    session_id: activeSessionId,
    messages: messages,
    shared_at: new Date().toISOString()
  };
  
  const response = await createShareLink(shareData);
  const shareUrl = `${window.location.origin}/shared/${response.share_id}`;
  
  navigator.clipboard.writeText(shareUrl);
  setSnackbar({ message: "Link copied!", severity: "success" });
};
```

4. **Code Syntax Highlighting**
```tsx
// Install: npm install react-syntax-highlighter
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';

// In ReactMarkdown components:
code: ({ node, inline, className, children, ...props }) => {
  const match = /language-(\w+)/.exec(className || '');
  return !inline && match ? (
    <SyntaxHighlighter
      style={vscDarkPlus}
      language={match[1]}
      PreTag="div"
      {...props}
    >
      {String(children).replace(/\n$/, '')}
    </SyntaxHighlighter>
  ) : (
    <code className={className} {...props}>
      {children}
    </code>
  );
}
```

5. **Suggested Prompts**
```tsx
const suggestedPrompts = [
  "Summarize the uploaded document",
  "What are the key findings?",
  "Search the web for recent news about [topic]",
  "Create a chart showing the data trends",
  "Translate this to Arabic"
];

<Stack spacing={1}>
  {messages.length === 0 && suggestedPrompts.map(prompt => (
    <Button
      key={prompt}
      variant="outlined"
      onClick={() => handleSend(prompt)}
    >
      {prompt}
    </Button>
  ))}
</Stack>
```

6. **Typing Indicator**
```tsx
const [isTyping, setIsTyping] = useState(false);

{isTyping && (
  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
    <Avatar sx={{ bgcolor: 'primary.main', width: 32, height: 32 }}>
      <AutoAwesomeIcon />
    </Avatar>
    <Typography variant="body2" color="text.secondary">
      TEIA is thinking
      <span className="typing-dots">...</span>
    </Typography>
  </Box>
)}

// CSS animation
@keyframes blink {
  0%, 20% { opacity: 0; }
  40% { opacity: 1; }
  60%, 100% { opacity: 0; }
}
```

---

### 🔌 7. Plugin/Extension System

**What GPT/Gemini Have:**
- Custom GPTs
- Plugin marketplace
- OAuth integrations
- Third-party tools

**Implementation:**

**File:** `src/services/plugins/plugin_manager.py`
```python
from typing import Dict, List, Optional
from pydantic import BaseModel

class PluginManifest(BaseModel):
    id: str
    name: str
    description: str
    version: str
    author: str
    tools: List[Dict]  # Tool definitions
    oauth_config: Optional[Dict] = None

class PluginManager:
    """Manage third-party plugins"""
    
    def __init__(self):
        self.plugins: Dict[str, PluginManifest] = {}
    
    def load_plugin(self, manifest_path: str):
        """Load plugin from manifest"""
        with open(manifest_path) as f:
            manifest = PluginManifest(**json.load(f))
        
        # Register plugin tools
        for tool_def in manifest.tools:
            tool = self._create_plugin_tool(manifest.id, tool_def)
            tool_registry.register(tool)
        
        self.plugins[manifest.id] = manifest
    
    def _create_plugin_tool(self, plugin_id: str, tool_def: Dict) -> BaseTool:
        """Create tool instance from plugin definition"""
        # Dynamic tool creation
        pass

# Example plugin manifest
{
  "id": "weather-plugin",
  "name": "Weather Plugin",
  "description": "Get current weather information",
  "version": "1.0.0",
  "author": "TEIA",
  "tools": [
    {
      "name": "get_weather",
      "description": "Get current weather for a location",
      "parameters": [
        {"name": "location", "type": "string", "required": true}
      ],
      "endpoint": "https://api.openweathermap.org/data/2.5/weather"
    }
  ]
}
```

---

### 🔒 8. Advanced Security & Privacy

**Features Needed:**

1. **Message Encryption**
```python
# src/core/security/encryption.py
from cryptography.fernet import Fernet

class MessageEncryption:
    def __init__(self, key: bytes):
        self.cipher = Fernet(key)
    
    def encrypt_message(self, content: str) -> str:
        return self.cipher.encrypt(content.encode()).decode()
    
    def decrypt_message(self, encrypted: str) -> str:
        return self.cipher.decrypt(encrypted.encode()).decode()

# Store encrypted messages in DB
message.content_encrypted = encryptor.encrypt_message(content)
```

2. **Data Retention Policies**
```python
# Auto-delete old conversations
@app.on_event("startup")
async def cleanup_old_data():
    scheduler = BackgroundScheduler()
    scheduler.add_job(
        delete_old_sessions,
        'cron',
        hour=2,  # Run at 2 AM daily
        kwargs={'days_old': 90}
    )
    scheduler.start()

async def delete_old_sessions(days_old: int):
    cutoff = datetime.now() - timedelta(days=days_old)
    await db.execute(
        delete(ChatSession).where(ChatSession.created_at < cutoff)
    )
```

3. **Content Moderation**
```python
from openai import AsyncOpenAI

async def moderate_content(text: str) -> Dict:
    """Check content for policy violations"""
    client = AsyncOpenAI()
    response = await client.moderations.create(input=text)
    
    result = response.results[0]
    if result.flagged:
        return {
            "allowed": False,
            "categories": result.categories.dict(),
            "reason": "Content violates policy"
        }
    
    return {"allowed": True}
```

---

### 📱 9. Mobile & Cross-Platform

**Features:**

1. **Progressive Web App (PWA)**
```json
// public/manifest.json
{
  "name": "TEIA AI Assistant",
  "short_name": "TEIA",
  "description": "Your intelligent AI assistant",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#4338ca",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

2. **Offline Support**
```typescript
// src/serviceWorker.ts
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
```

3. **Push Notifications**
```typescript
// Request notification permission
const permission = await Notification.requestPermission();

// Send notification
if ('serviceWorker' in navigator) {
  const registration = await navigator.serviceWorker.ready;
  registration.showNotification('New message', {
    body: 'TEIA has responded',
    icon: '/icon-192.png'
  });
}
```

---

### 🌍 10. Internationalization (i18n)

**Multi-language Support:**

```typescript
// Install: npm install react-i18next i18next
// src/i18n/config.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n.use(initReactI18next).init({
  resources: {
    en: {
      translation: {
        "welcome": "Welcome to TEIA",
        "send_message": "Send message",
        "upload_document": "Upload document"
      }
    },
    ar: {
      translation: {
        "welcome": "مرحبا بك في TEIA",
        "send_message": "إرسال رسالة",
        "upload_document": "تحميل مستند"
      }
    }
  },
  lng: "en",
  fallbackLng: "en"
});

// Usage in components
import { useTranslation } from 'react-i18next';

const { t, i18n } = useTranslation();
<Typography>{t('welcome')}</Typography>
<Button onClick={() => i18n.changeLanguage('ar')}>العربية</Button>
```

---

## IMPLEMENTATION PRIORITY

### 🔥 Phase 1: Core GPT Features (Week 1-2)
1. ✅ **Function/Tool Calling System** - Most critical
2. ✅ **Web Search Integration** - Essential for current info
3. ✅ **Code Syntax Highlighting** - Easy UX win
4. ✅ **Suggested Prompts** - Better onboarding

### 🚀 Phase 2: Enhanced UX (Week 3-4)
5. ✅ **Regenerate/Edit Messages**
6. ✅ **Share Conversations**
7. ✅ **Typing Indicators**
8. ✅ **Dark Mode**
9. ✅ **Keyboard Shortcuts**

### 🎯 Phase 3: Multimodal (Week 5-6)
10. ✅ **Image Understanding (Vision)**
11. ✅ **Image Generation (DALL-E)**
12. ✅ **Audio Transcription (Whisper)**
13. ✅ **Text-to-Speech**

### 🔧 Phase 4: Advanced Features (Week 7-8)
14. ✅ **Code Execution Tool**
15. ✅ **Data Analysis Tool**
16. ✅ **Plugin System**
17. ✅ **Conversation Branching**

### 🌐 Phase 5: Polish & Scale (Week 9-10)
18. ✅ **PWA Support**
19. ✅ **Push Notifications**
20. ✅ **i18n (Arabic + English)**
21. ✅ **Advanced Caching**
22. ✅ **Load Testing**

---

## DEPENDENCIES TO ADD

### Python Backend
```toml
# Add to pyproject.toml

[project.dependencies]
# Tools & Function Calling
"duckduckgo-search" = "^6.0.0"  # Free web search
"tavily-python" = "^0.3.0"  # AI-optimized search
"httpx" = "^0.26.0"  # For API calls

# Multimodal
"pillow" = "^10.1.0"  # Image processing
"opencv-python" = "^4.8.0"  # Computer vision
"moviepy" = "^1.0.3"  # Video processing
"pydub" = "^0.25.1"  # Audio processing

# Data Analysis
"pandas" = "^2.1.0"
"matplotlib" = "^3.8.0"
"seaborn" = "^0.13.0"
"plotly" = "^5.18.0"

# Plugin System
"pluggy" = "^1.3.0"  # Plugin framework
"importlib-metadata" = "^7.0.0"

# Enhanced Security
"python-multipart" = "^0.0.6"  # File uploads
"itsdangerous" = "^2.1.2"  # Secure signing
```

### Frontend
```json
// Add to package.json
{
  "dependencies": {
    "react-syntax-highlighter": "^15.5.0",
    "react-i18next": "^14.0.0",
    "i18next": "^23.7.0",
    "react-markdown": "^9.0.1",  // Already have
    "remark-gfm": "^4.0.0",  // Already have
    "workbox-webpack-plugin": "^7.0.0",  // PWA
    "@mui/icons-material": "^5.15.0",  // Already have
    "chart.js": "^4.4.0",  // Data viz
    "react-chartjs-2": "^5.2.0"
  }
}
```

---

## CONFIGURATION UPDATES

**Add to `src/core/settings/config.py`:**

```python
# Web Search
SERPER_API_KEY: str = ""  # serper.dev
TAVILY_API_KEY: str = ""  # tavily.com
BRAVE_API_KEY: str = ""   # brave.com/search/api

# Function Calling
ENABLE_FUNCTION_CALLING: bool = True
MAX_TOOL_ITERATIONS: int = 5
ALLOWED_TOOLS: List[str] = ["web_search", "calculator", "code_executor"]

# Multimodal
ENABLE_VISION: bool = True
ENABLE_IMAGE_GENERATION: bool = True
ENABLE_AUDIO_TRANSCRIPTION: bool = True
ENABLE_TEXT_TO_SPEECH: bool = True
MAX_IMAGE_SIZE_MB: int = 10
SUPPORTED_IMAGE_FORMATS: List[str] = ["jpg", "jpeg", "png", "webp"]

# Context Management
MAX_CONTEXT_TOKENS: int = 100000
ENABLE_CONVERSATION_SUMMARY: bool = True
SUMMARY_TRIGGER_TOKENS: int = 80000

# Code Execution
ENABLE_CODE_EXECUTION: bool = True
CODE_EXECUTION_TIMEOUT: int = 30
ALLOWED_LANGUAGES: List[str] = ["python", "javascript"]

# Data Analysis
ENABLE_DATA_ANALYSIS: bool = True
MAX_CSV_ROWS: int = 100000

# Plugins
ENABLE_PLUGINS: bool = True
PLUGIN_DIR: str = "plugins/"

# UI Features
ENABLE_MESSAGE_EDITING: bool = True
ENABLE_CONVERSATION_SHARING: bool = True
ENABLE_MESSAGE_REACTIONS: bool = True
```

---

## TESTING CHECKLIST

### Tool Calling Tests
- [ ] Test web search with various queries
- [ ] Test calculator with complex expressions  
- [ ] Test code execution with Python/JavaScript
- [ ] Test parallel tool execution
- [ ] Test tool error handling

### Multimodal Tests
- [ ] Upload and analyze images (JPG, PNG, WebP)
- [ ] Generate images with DALL-E
- [ ] Transcribe audio files
- [ ] Test text-to-speech output
- [ ] Test multimodal in conversations

### UX Tests
- [ ] Regenerate responses
- [ ] Edit and resend messages
- [ ] Share conversation links
- [ ] Test keyboard shortcuts
- [ ] Dark/light mode toggle
- [ ] Mobile responsiveness
- [ ] PWA installation

### Performance Tests
- [ ] Load test with 100 concurrent users
- [ ] Test with 100K+ token conversations
- [ ] Test large file uploads (images, data files)
- [ ] Test streaming with tool calls
- [ ] Test database query performance

---

## API COSTS ESTIMATION

### Per 1000 Requests

| Feature | Cost | Notes |
|---------|------|-------|
| GPT-4o Chat | $5-10 | $2.50 input + $10 output per 1M tokens |
| GPT-4o Vision | $10-20 | $10 per 1M tokens + $0.00765 per image |
| DALL-E 3 | $400 | $0.04 per standard image |
| Whisper | $6 | $0.006 per minute |
| Web Search (Serper) | $10 | $0.01 per search |
| Embeddings | $0.13 | text-embedding-3-small |

**Budget Recommendation**: Start with $100/month for testing, scale to $500-1000/month for production.

---

## MONITORING & OBSERVABILITY

**Add Metrics:**

```python
# src/core/observability/metrics.py
from prometheus_client import Counter, Histogram

# Tool usage metrics
tool_calls = Counter('tool_calls_total', 'Tool calls', ['tool_name', 'status'])
tool_duration = Histogram('tool_duration_seconds', 'Tool execution time', ['tool_name'])

# Multimodal metrics
image_uploads = Counter('image_uploads_total', 'Image uploads', ['format'])
audio_transcriptions = Counter('audio_transcriptions_total', 'Audio transcriptions')

# Usage metrics
tokens_used = Counter('tokens_used_total', 'Tokens consumed', ['model', 'type'])
api_costs = Counter('api_costs_total', 'API costs in USD', ['service'])
```

---

## SUCCESS METRICS

### Feature Parity Checklist

| Feature | ChatGPT | Gemini | TEIA | Priority |
|---------|---------|--------|------|----------|
| Function/Tool Calling | ✅ | ✅ | ❌ | 🔥 Critical |
| Web Search | ✅ | ✅ | ❌ | 🔥 Critical |
| Image Understanding | ✅ | ✅ | ❌ | 🚀 High |
| Image Generation | ✅ | ✅ | ❌ | 🚀 High |
| Code Execution | ✅ | ✅ | ❌ | 🚀 High |
| Audio Transcription | ✅ | ✅ | ❌ | 🎯 Medium |
| Text-to-Speech | ✅ | ✅ | ❌ | 🎯 Medium |
| Data Analysis | ✅ | ✅ | ❌ | 🎯 Medium |
| Plugins/Extensions | ✅ | ❌ | ❌ | 🌐 Low |
| Video Understanding | ❌ | ✅ | ❌ | 🌐 Low |
| Mobile App | ✅ | ✅ | ❌ (PWA) | 🌐 Low |
| RAG/Documents | ❌ | ❌ | ✅ | ✅ Advantage |
| Hybrid Search | ❌ | ❌ | ✅ | ✅ Advantage |
| Reranking | ❌ | ❌ | ✅ | ✅ Advantage |

### Competitive Advantages You Already Have
1. ✅ **Better document understanding** (multiple file types)
2. ✅ **Advanced retrieval** (hybrid search + reranking)
3. ✅ **Enterprise security** (RBAC, PII detection)
4. ✅ **Self-hosted option** (data privacy)
5. ✅ **Customizable** (white-label ready)

---

## NEXT STEPS

1. **Start with Tool Calling** - Implement base tool system and web search (1 week)
2. **Add Essential UI Features** - Regenerate, edit, syntax highlighting (3 days)
3. **Integrate Vision APIs** - Image understanding with GPT-4V (2 days)
4. **Add Code Execution** - Python/JS sandbox (3 days)
5. **Polish & Test** - End-to-end testing, performance tuning (1 week)

**Total Timeline**: 3-4 weeks for MVP feature parity with GPT/Gemini

---

## CONCLUSION

Your system has a **strong foundation** with advanced RAG capabilities that GPT/Gemini lack. The main gaps are:

1. **Tool/Function Calling** (most critical)
2. **Web Search** (essential for current info)
3. **Multimodal** (images, audio)
4. **UX Polish** (regenerate, edit, share)

Focus on Phase 1-2 first to achieve 80% feature parity in 2-3 weeks. The remaining features can be added iteratively based on user feedback.

**Your Competitive Edge**: While GPT/Gemini are general-purpose, you have superior document processing, hybrid search, and reranking. Position TEIA as the "ChatGPT for Enterprise Documents" with web search and tool calling.
