# Chat Memory Storage Policy

This document defines how messages from Waha (WhatsApp Webhook) are handled in our chat memory pipeline.

---

## 1. Data Sources

From **Set Fields Node**, we extract:

- `meId` → our WhatsApp account JID
- `isGroupChat` → whether the chat is group or private
- `chatId` → unique chat/session ID (`xxx@c.us` or `xxx@g.us`)
- `actorId` → who sent the message (`fromMe ? meId : senderId`)
- `contactId` → counterparty (for private chats) or group participant (for group chats)
- `fromMeNormalized` → boolean, stringified (`true` / `false`)
- `messageId` → Waha message ID
- `body` → raw text
- `timestamp` → normalized timestamp
- `ltmId` → ID used for long-term grouping (user or group)

---

## 2. Workflow Diagram

```mermaid
flowchart TD
    A[Incoming Waha Payload] --> B[Set Fields Node]
    B --> C{fromMe?}
    C -->| false {User Message} --> D[Store in STM -Postgres]
    D --> E[Embed & Store in LTM - Qdrant]
    E --> F[Retrieve STM + LTM Context]
    F --> G[AI Agent Generates Response]
    G --> H[Store AI Response in STM]
    H --> I[Send to WhatsApp]

    C -->|true (AI Response)| D2[Store in STM Only]
    D2 --> J[No Response Generation]
```
---

## 3. Storage Targets

We maintain two memory layers:

### Short-Term Memory (STM) → PostgreSQL
- `sessions` → tracks one per chat (user or group)
- `messages` → full message history for the session

### Long-Term Memory (LTM) → Qdrant
- `longterm_memory` → general chat history vectors (semantic retrieval)
- `user_knowledge` → extracted facts / preferences from participants

---

## 3. Storage Policy

| Source                     | STM (sessions + messages) | LTM (longterm_memory) | LTM (user_knowledge) |
|----------------------------|---------------------------|-----------------------|-----------------------|
| **User message** (`fromMe = false`) | ✅ Always store             | ✅ Embed + store       | ✅ Extract knowledge   |
| **AI message** (`fromMe = true`)   | ✅ Always store             | ❌ Never               | ❌ Never               |
| **System/meta messages**           | ✅ Always store (optional)  | ❌ Never               | ❌ Never               |

---

## 4. Retrieval Policy

When generating a response:
1. **Retrieve STM** → recent messages (N last, e.g. 10–20) for conversation flow.
2. **Retrieve LTM** → relevant vectors from `longterm_memory` and `user_knowledge`.
3. **Compose context** → merge STM + LTM into prompt for AI agent.

---

## 5. Response Policy

- AI generates a draft response using STM + LTM context.
- Response is **stored into STM** before sending.
- When WhatsApp echoes the AI’s own message back (`fromMe = true`), it is only **stored in STM**, not reprocessed for response, nor embedded to LTM.

---

## 6. Schema Mappings

### PostgreSQL: STM

#### `sessions`
| Column      | Source field    | Notes |
|-------------|-----------------|-------|
| `id`        | (auto)          | Primary key |
| `user_id`   | `contactId`     | For private chats → user JID |
| `chat_id`   | `chatId`        | Group JID or private JID |
| `is_group`  | `isGroupChat`   | Boolean |
| `started_at`| `timestamp`     | First message timestamp |

#### `messages`
| Column      | Source field        | Notes |
|-------------|--------------------|-------|
| `id`        | (auto)             | Primary key |
| `session_id`| FK → sessions.id   | Link to session |
| `role`      | `fromMeNormalized` | `"user"` if false, `"assistant"` if true |
| `content`   | `body`             | Message text |
| `message_id`| `messageId`        | Unique per message |
| `actor_id`  | `actorId`          | Who sent it |
| `created_at`| `timestamp`        | Message time |

---

### Qdrant: LTM

#### `longterm_memory`
- **Vector** → embedding of `body`
- **Payload**
    - `chatId` → conversation
    - `actorId` → who said it
    - `timestamp` → when
    - `messageId` → source link
    - `isGroupChat` → flag

#### `user_knowledge`
- **Vector** → embedding of fact/summary
- **Payload**
    - `ltmId` → user or group anchor
    - `fact` → extracted knowledge
    - `sourceMessageId` → link to original
    - `timestamp` → when fact was learned

---

## 7. Safety Notes

- **Loop prevention:** Never run AI on `fromMe = true` payloads.
- **Knowledge hygiene:** Only human/user messages are candidates for LTM knowledge extraction.
- **Transcript fidelity:** STM is the single source of truth for the full conversation.

---
