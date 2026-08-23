"""
Kora Messenger AI Server
=========================
Flask server that proxies AI requests from the Android app to OpenRouter.
The OpenRouter API key stays server-side — the app never sees it.

Endpoints:
  POST /api/ai/chat              — Kora AI (general assistant)
  POST /api/ai/support           — Kora AI Support (product support)
  POST /api/ai/writing           — Kora AI Writing Assistant
  POST /api/ai/reply-suggestions — Kora AI Reply Suggestions
  POST /api/ai/summarize-chat    — Kora AI Chat Summarizer
  POST /api/ai/transcribe        — Kora AI Voice Transcription/Translation
  POST /api/ai/analyze-image     — Kora AI Image Analysis
  POST /api/ai/analyze-file      — Kora AI Document Analysis
  GET  /api/ai/health            — Health check

All endpoints require Bearer token authentication.
Conversation history is stored in-memory (replace with Redis/DB for production).
"""

import os
import json
import time
from collections import defaultdict, deque
from pathlib import Path

from flask import Flask, request, jsonify
from dotenv import load_dotenv

from kora_ai import (
    execute_kora_ai,
    execute_kora_support,
    execute_writing_assistant,
    execute_reply_suggestions,
    execute_chat_summary,
    execute_transcribe_voice,
    execute_analyze_image,
    execute_analyze_file,
)

# ============================================================
# CONFIG
# ============================================================

load_dotenv()

app = Flask(__name__)

# Auth token — the app sends this in the Authorization header.
# Generate a strong random token and share it with the app.
KORA_AUTH_TOKEN = os.getenv("KORA_AUTH_TOKEN", "change-me-in-production")

# Rate limiting: max requests per window per user
RATE_LIMIT_MAX = 30
RATE_LIMIT_WINDOW = 60  # seconds

# Knowledge base path
KNOWLEDGE_DIR = Path(__file__).parent.parent / "knowledge"
SUPPORT_KNOWLEDGE_FILE = KNOWLEDGE_DIR / "kora_support.md"

# In-memory conversation store (replace with Redis/DB in production)
conversations = defaultdict(deque)

# Rate limiter: { user_id: deque of timestamps }
rate_limiter = defaultdict(deque)


# ============================================================
# AUTHENTICATION
# ============================================================

def authenticate():
    """Validate Bearer token. Returns (success, error_response, status_code)."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return False, jsonify({"error": "Missing or invalid Authorization header"}), 401

    token = auth_header[7:]
    if token != KORA_AUTH_TOKEN:
        return False, jsonify({"error": "Invalid auth token"}), 401

    return True, None, None


# ============================================================
# RATE LIMITING
# ============================================================

def check_rate_limit(user_id):
    """Returns True if within limit, False otherwise."""
    now = time.time()
    window = rate_limiter[user_id]

    # Remove old timestamps
    while window and window[0] < now - RATE_LIMIT_WINDOW:
        window.popleft()

    if len(window) >= RATE_LIMIT_MAX:
        return False

    window.append(now)
    return True


# ============================================================
# KNOWLEDGE BASE LOADER
# ============================================================

def load_support_knowledge():
    """Load the Kora support knowledge base."""
    try:
        if SUPPORT_KNOWLEDGE_FILE.exists():
            return SUPPORT_KNOWLEDGE_FILE.read_text(encoding="utf-8")
    except Exception as e:
        app.logger.warning(f"Could not load knowledge base: {e}")
    return ""


# ============================================================
# CONVERSATION MANAGEMENT
# ============================================================

def get_history(conversation_id):
    """Get conversation history for a given ID."""
    return list(conversations[conversation_id])


def save_to_history(conversation_id, role, content):
    """Save a message to conversation history."""
    conversations[conversation_id].append({
        "role": role,
        "content": content
    })
    # Keep only last 50 messages
    while len(conversations[conversation_id]) > 50:
        conversations[conversation_id].popleft()


# ============================================================
# ENDPOINTS
# ============================================================

@app.route("/api/ai/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "Kora AI Server"})


@app.route("/api/ai/chat", methods=["POST"])
def ai_chat():
    """Kora AI — general-purpose assistant."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    message = data.get("message", "").strip()
    conversation_id = data.get("conversationId", "default")
    web_url = data.get("webUrl")
    image_base64 = data.get("imageBase64")  # base64-encoded image
    user_id = data.get("userId", "anonymous")

    if not message:
        return jsonify({"error": "Message is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    # Get conversation history
    history = get_history(conversation_id)

    # Handle image if provided
    image_path = None
    if image_base64:
        try:
            import base64 as b64
            image_bytes = b64.b64decode(image_base64)
            temp_dir = Path("/tmp/kora_ai_images")
            temp_dir.mkdir(parents=True, exist_ok=True)
            image_path = temp_dir / f"{conversation_id}_{int(time.time())}.jpg"
            image_path.write_bytes(image_bytes)
        except Exception:
            pass  # Skip image on error

    try:
        response = execute_kora_ai(
            user_query=message,
            history=history,
            web_url=web_url,
            direct_image_path=image_path,
        )

        # Save to conversation history
        save_to_history(conversation_id, "user", message)
        save_to_history(conversation_id, "assistant", response)

        # Clean up temp image
        if image_path and image_path.exists():
            image_path.unlink()

        return jsonify({
            "response": response,
            "conversationId": conversation_id
        })

    except Exception as e:
        return jsonify({"error": f"AI request failed: {str(e)}"}), 500


@app.route("/api/ai/support", methods=["POST"])
def ai_support():
    """Kora AI Support — product support assistant."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    message = data.get("message", "").strip()
    conversation_id = data.get("conversationId", "support-default")
    user_id = data.get("userId", "anonymous")

    if not message:
        return jsonify({"error": "Message is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    # Get conversation history and knowledge base
    history = get_history(conversation_id)
    knowledge = load_support_knowledge()

    try:
        response = execute_kora_support(
            user_query=message,
            history=history,
            knowledge_text=knowledge,
        )

        # Save to conversation history
        save_to_history(conversation_id, "user", message)
        save_to_history(conversation_id, "assistant", response)

        return jsonify({
            "response": response,
            "conversationId": conversation_id
        })

    except Exception as e:
        return jsonify({"error": f"Support request failed: {str(e)}"}), 500


@app.route("/api/ai/writing", methods=["POST"])
def ai_writing():
    """Kora AI Writing Assistant — rewrite, translate, adjust tone/length."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    text = data.get("text", "").strip()
    mode = data.get("mode", "").strip()
    target_language = data.get("targetLanguage") or data.get("target_language")
    user_id = data.get("userId", "anonymous")

    if not text:
        return jsonify({"error": "text is required"}), 400
    if not mode:
        return jsonify({"error": "mode is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    try:
        response = execute_writing_assistant(
            text=text,
            mode=mode,
            target_language=target_language
        )
        return jsonify({"response": response})
    except Exception as e:
        return jsonify({"error": f"Writing assistant request failed: {str(e)}"}), 500


@app.route("/api/ai/reply-suggestions", methods=["POST"])
def ai_reply_suggestions():
    """Kora AI Reply Suggestions — generate 3 quick reply options."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    message = data.get("message") or data.get("received_message", "")
    if isinstance(message, str):
        message = message.strip()
    context_messages = data.get("contextMessages") or data.get("context_messages")
    user_id = data.get("userId", "anonymous")

    if not message:
        return jsonify({"error": "message is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    try:
        suggestions = execute_reply_suggestions(
            received_message=message,
            context_messages=context_messages
        )
        return jsonify({"suggestions": suggestions})
    except Exception as e:
        return jsonify({"error": f"Reply suggestions request failed: {str(e)}"}), 500


@app.route("/api/ai/summarize-chat", methods=["POST"])
def ai_summarize_chat():
    """Kora AI Chat Summarizer — full, brief, or catch_me_up summary."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    messages = data.get("messages")
    summary_type = data.get("summaryType") or data.get("summary_type", "full")
    user_id = data.get("userId", "anonymous")

    if not messages or not isinstance(messages, list):
        return jsonify({"error": "messages (list) is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    try:
        summary = execute_chat_summary(
            messages=messages,
            summary_type=summary_type
        )
        return jsonify({"summary": summary})
    except Exception as e:
        return jsonify({"error": f"Summarize chat request failed: {str(e)}"}), 500


@app.route("/api/ai/transcribe", methods=["POST"])
def ai_transcribe():
    """Kora AI Transcribe & Translate — voice transcript handling."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    voice_text = data.get("voiceText") or data.get("voice_text")
    file_path = data.get("filePath") or data.get("file_path")
    target_language = data.get("targetLanguage") or data.get("target_language")
    user_id = data.get("userId", "anonymous")

    voice_text_or_path = voice_text or file_path
    if not voice_text_or_path:
        return jsonify({"error": "voiceText or filePath is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    try:
        res = execute_transcribe_voice(
            voice_text_or_path=voice_text_or_path,
            target_language=target_language
        )
        return jsonify({
            "transcript": res.get("transcript", ""),
            "translated": res.get("translated"),
            "detectedLanguage": res.get("detected_language")
        })
    except Exception as e:
        return jsonify({"error": f"Transcribe request failed: {str(e)}"}), 500


@app.route("/api/ai/analyze-image", methods=["POST"])
def ai_analyze_image():
    """Kora AI Image Analysis — answer questions about image."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    image_base64 = data.get("imageBase64") or data.get("image_base64")
    question = data.get("question", "").strip()
    user_id = data.get("userId", "anonymous")

    if not image_base64:
        return jsonify({"error": "imageBase64 is required"}), 400
    if not question:
        return jsonify({"error": "question is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    temp_dir = Path("/tmp/kora_ai_images")
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_file = temp_dir / f"img_{int(time.time() * 1000)}.jpg"

    try:
        import base64 as b64
        image_bytes = b64.b64decode(image_base64)
        temp_file.write_bytes(image_bytes)

        response = execute_analyze_image(
            image_path=temp_file,
            question=question
        )
        return jsonify({"response": response})
    except Exception as e:
        return jsonify({"error": f"Analyze image request failed: {str(e)}"}), 500
    finally:
        if temp_file.exists():
            try:
                temp_file.unlink()
            except Exception:
                pass


@app.route("/api/ai/analyze-file", methods=["POST"])
def ai_analyze_file():
    """Kora AI File Analysis — answer questions about file content."""
    ok, err, code = authenticate()
    if not ok:
        return err, code

    data = request.get_json(silent=True) or {}

    file_content = data.get("fileContent") or data.get("file_content")
    file_name = data.get("fileName") or data.get("file_name", "document.txt")
    question = data.get("question", "").strip()
    user_id = data.get("userId", "anonymous")

    if not file_content:
        return jsonify({"error": "fileContent is required"}), 400
    if not question:
        return jsonify({"error": "question is required"}), 400

    if not check_rate_limit(user_id):
        return jsonify({"error": "Rate limit exceeded. Please wait a moment."}), 429

    try:
        response = execute_analyze_file(
            file_content=file_content,
            file_name=file_name,
            question=question
        )
        return jsonify({"response": response})
    except Exception as e:
        return jsonify({"error": f"Analyze file request failed: {str(e)}"}), 500


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
