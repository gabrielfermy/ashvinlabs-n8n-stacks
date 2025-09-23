# Message Flow Documentation (STM → LTM)

This document explains the mapping and flow of messages between **Short-Term Memory (STM)** and **Long-Term Memory (LTM)** in our n8n workflow.

---

## 1. Identifiers Extracted from Incoming Message

From `waha` webhook payload:

- `waha.isGroupChat` → `boolean` = `{{ $json.payload.participant.isNotEmpty() }}`
- `waha.fromMe` → `boolean` = `{{ $json.payload.fromMe }}`
- `waha.chatId` → `string` = Conversation ID (private or group)
- `waha.sender` → `string` = `{{ $json.payload.sender.id }}`
- `waha.senderName` → `string` = `{{ $json.payload.sender.name }}`
- `waha.message` → `string` = `{{ $json.payload.message.text }}`
- `waha.timestamp` → `number` = Unix timestamp

---

## 2. Routing Logic (Switch)

1. **Private Chat (`isGroupChat = false`)**
    - Messages are between a **single user and the AI agent/human**.
    - `fromMe = false` → user message (true source of knowledge).
    - `fromMe = true` → message from agent (AI or operator).

2. **Group Chat (`isGroupChat = true`)**
    - Must differentiate:
        - `fromMe = false` → other participant’s message.
        - `fromMe = true` → bot/agent response (not stored in LTM).

---

## 3. Memory Storage Rules

### Short-Term Memory (STM)
- Every message (user or agent) is stored in STM.
- Used for immediate context (conversation window).
- Retention is **limited** (e.g., last 20 messages).

### Long-Term Memory (LTM)
- **Store only user-originated messages**:
    - Condition: `fromMe = false`
    - Rationale: Only user content reflects real-world knowledge/state.
- **Do not store AI/agent responses**:
    - Avoid polluting knowledge base with assumptions or generated text.

---

## 4. Mapping Examples

### Example A: Private Chat
    fromMe = false, isGroupChat = false
    message = "I moved to Jakarta last week."
    → STM ✅
    → LTM ✅ (fact about user)

    fromMe = true, isGroupChat = false
    message = "That’s great! How do you like it there?"
    → STM ✅
    → LTM ❌ (AI generated)

### Example B: Group Chat
    fromMe = false, isGroupChat = true
    sender = "User123"
    message = "Can we schedule a call tomorrow?"
    → STM ✅
    → LTM ✅ (fact from participant)

    fromMe = true, isGroupChat = true
    sender = "AI Agent"
    message = "Sure, I’ll set it up."
    → STM ✅
    → LTM ❌

---

## 5. Summary

- **STM = full transcript (short horizon).**
- **LTM = user knowledge only.**
- AI/agent messages are **never stored in LTM**.
- Group and private chats follow the same logic, only differing in `isGroupChat` handling.

---
