#!/bin/bash
set -e

echo "--- [START] Running custom initialization script (init-dbs-chat.sh) ---"
echo "Configuring 'chat_memory' database (STM schema with WA mapping) ..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
-- Create role and grant privileges
CREATE ROLE chat LOGIN PASSWORD '$POSTGRES_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO chat;

-- PostgreSQL Schema for Conversational AI Memory

-- This schema is designed to store and manage data for a conversational AI system,
-- focusing on structured information about users, groups, conversations, and messages.

-- Table: contacts
-- Stores information about individual users or contacts.
CREATE TABLE IF NOT EXISTS contacts (
contact_id TEXT PRIMARY KEY,
name TEXT NOT NULL,
metadata JSONB,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: channels
-- Represents the different platforms or channels where conversations take place.
CREATE TABLE IF NOT EXISTS channels (
channel_id TEXT PRIMARY KEY,
type TEXT NOT NULL,
name TEXT,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: groups
-- Stores information about chat groups or threads.
CREATE TABLE IF NOT EXISTS groups (
group_id TEXT PRIMARY KEY,
channel_id TEXT REFERENCES channels(channel_id),
name TEXT,
is_private BOOLEAN NOT NULL DEFAULT FALSE,
metadata JSONB,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: group_members
-- A join table to manage the many-to-many relationship between contacts and groups.
CREATE TABLE IF NOT EXISTS group_members (
group_id TEXT REFERENCES groups(group_id),
contact_id TEXT REFERENCES contacts(contact_id),
joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
PRIMARY KEY (group_id, contact_id)
);

-- Table: sessions
-- Represents a single, continuous conversation session.
CREATE TABLE IF NOT EXISTS sessions (
session_id TEXT PRIMARY KEY,
channel_id TEXT REFERENCES channels(channel_id),
group_id TEXT REFERENCES groups(group_id),
contact_id TEXT REFERENCES contacts(contact_id),
start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: messages
-- Stores each individual message, which is the core unit of a conversation.
CREATE TABLE IF NOT EXISTS messages (
message_id TEXT PRIMARY KEY,
session_id TEXT REFERENCES sessions(session_id),
contact_id TEXT REFERENCES contacts(contact_id),
timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
text TEXT NOT NULL,
embedding JSONB
);

-- Table: facts
-- Stores extracted facts about users or topics (Long-Term Memory).
CREATE TABLE IF NOT EXISTS facts (
fact_id UUID PRIMARY KEY,
contact_id TEXT REFERENCES contacts(contact_id),
source_message_id TEXT REFERENCES messages(message_id),
fact_type TEXT NOT NULL,
fact_value JSONB NOT NULL,
embedding JSONB,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for optimized performance
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members (group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_contact_id ON group_members (contact_id);
CREATE INDEX IF NOT EXISTS idx_sessions_group_id ON sessions (group_id);
CREATE INDEX IF NOT EXISTS idx_sessions_contact_id ON sessions (contact_id);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages (session_id);
CREATE INDEX IF NOT EXISTS idx_messages_contact_id ON messages (contact_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages (timestamp);
CREATE INDEX IF NOT EXISTS idx_facts_contact_id ON facts (contact_id);
CREATE INDEX IF NOT EXISTS idx_facts_source_message_id ON facts (source_message_id);
CREATE INDEX IF NOT EXISTS idx_facts_fact_type ON facts (fact_type);

-- Function and Trigger for new message notifications
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS \$\$
DECLARE
  payload JSON;
BEGIN
  payload = json_build_object(
    'table', TG_TABLE_NAME,
    'action', TG_OP,
    'message_id', NEW.message_id,
    'session_id', NEW.session_id,
    'contact_id', NEW.contact_id
  );

  PERFORM pg_notify('new_message_channel', payload::text);

  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER messages_insert_trigger
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION notify_new_message();

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO chat;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO chat;

EOSQL

echo "--- [SUCCESS] 'chat_memory' database configured with extended schema. ---"
echo "--- [COMPLETE] PostgreSQL initialization finished. ---"
