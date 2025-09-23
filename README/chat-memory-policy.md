# Chat Memory Policy (STM + LTM)

This document defines how messages are handled between STM (Postgres) and LTM (Qdrant).

---

## 1. Message Flow Overview

Incoming WhatsApp message → Processed by workflow → Stored/retrieved according to policy.

### ASCII Flow

                          +----------------+
                          | WhatsApp Event |
                          +----------------+
                                   |
                                   v
                          +----------------+
                          | Set Fields     |
                          | (normalize)    |
                          +----------------+
                                   |
                                   v
                          +----------------+
                          | Ingestion Step |
                          +----------------+
                                   |
              +--------------------+--------------------+
              |                                         |
[User Message]                              [Bot/FromMe Message]
|                                         |
v                                         v
+------------------+                       +------------------+
| Retrieve STM+LTM |                       | Store in STM only|
| (context)        |                       | (no LTM)         |
+------------------+                       +------------------+
|                                         |
v                                         |
+------------------+                       +------------------+
| AI Agent (reply) | <---------------------+   Outgoing Msg   |
+------------------+                       +------------------+
|
v
+------------------+
| Store in STM     |
| (and in LTM if   |
| relevant)        |
+------------------+
|
v
+------------------+
| Send via Waha    |
+------------------+

---

## 2. STM Policy (Short-Term Memory, Postgres)

- **Always store** every message (both user and bot).
- Tables:
    - `sessions`: conversation metadata.
    - `messages`: per-message log.

---

## 3. LTM Policy (Long-Term Memory, Qdrant)

- **Only store user messages** (not bot responses).
- Reason: user input = ground truth of knowledge. Bot output = synthetic, not reliable knowledge.
- Collections:
    - `longterm_memory` → general embeddings of conversations.
    - `user_knowledge` → extracted facts about the user (profile, preferences, etc.).

---

## 4. Retrieval Policy

- **Before generating a response**:
    1. Retrieve last N messages from STM (conversation context).
    2. Retrieve top-k semantic matches from LTM.
    3. Merge both into AI Agent’s prompt.

---

## 5. Response Policy

- AI Agent generates a response.
- Workflow:
    1. Store response in STM.
    2. Do **not** store response in LTM.
    3. Send response via Waha.

---
