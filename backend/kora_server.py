"""
Kora Messenger AI Server
=========================
Flask server that proxies AI requests from the Android app to OpenRouter.
The OpenRouter API key stays server-side — the app never sees it.

Endpoints:
  POST /api/ai/chat     — Kora AI (general assistant)
  POST /api/ai/support  — Kora AI Support (product support)
  GET  /api/ai/health   — Health check

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
    """Validate Bearer token. Returns (success, error_response)."""
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


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
