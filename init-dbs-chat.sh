#!/bin/bash
set -e

echo "--- [START] Running custom initialization script (init-dbs-chat.sh) ---"
echo "Configuring 'chat_memory' database (STM schema with WA mapping) ..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-'EOSQL'
-- PostgreSQL Schema for Conversational AI Memory

-- This schema is designed to store and manage data for a conversational AI system,
-- focusing on structured information about users, groups, conversations, and messages.

-- Table: contacts
-- Stores information about individual users or contacts.
-- contact_id: A unique identifier for the contact.
-- name: The human-readable name of the contact.
-- metadata: A JSONB field for flexible storage of additional, non-relational data
--           like user preferences, a summary of their persona, or other details.
-- created_at: Timestamp for when the contact record was created.
CREATE TABLE IF NOT EXISTS contacts (
contact_id TEXT PRIMARY KEY,
name TEXT NOT NULL,
metadata JSONB,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: channels
-- Represents the different platforms or channels where conversations take place (e.g., Slack, Discord).
-- channel_id: A unique identifier for the channel.
-- type: The type of channel (e.g., 'slack', 'discord', 'telegram').
-- name: A display name for the channel.
-- created_at: Timestamp for when the channel record was created.
CREATE TABLE IF NOT EXISTS channels (
channel_id TEXT PRIMARY KEY,
type TEXT NOT NULL,
name TEXT,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: groups
-- Stores information about chat groups or threads.
-- group_id: A unique identifier for the group.
-- channel_id: A foreign key referencing the 'channels' table, linking the group to its parent channel.
-- name: The name of the group.
-- is_private: A boolean flag indicating if the group is private.
-- metadata: A JSONB field for storing additional group-specific data.
-- created_at: Timestamp for when the group record was created.
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
-- group_id: A foreign key referencing the 'groups' table.
-- contact_id: A foreign key referencing the 'contacts' table.
-- joined_at: The timestamp when the contact joined the group.
-- PRIMARY KEY: A composite primary key to ensure that each contact can only be in a group once.
CREATE TABLE IF NOT EXISTS group_members (
group_id TEXT REFERENCES groups(group_id),
contact_id TEXT REFERENCES contacts(contact_id),
joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
PRIMARY KEY (group_id, contact_id)
);

-- Table: sessions
-- Represents a single, continuous conversation session. A session could be a direct message (DM)
-- or a group chat. It links messages to a specific time frame and context.
-- session_id: A unique identifier for the session.
-- channel_id: A foreign key linking the session to its channel.
-- group_id: A foreign key linking the session to a specific group (optional for DMs).
-- contact_id: A foreign key to the primary contact in the session (e.g., the other person in a DM).
-- start_time: The start time of the session.
-- end_time: The end time of the session.
CREATE TABLE IF NOT EXISTS sessions (
session_id TEXT PRIMARY KEY,
channel_id TEXT REFERENCES channels(channel_id),
group_id TEXT REFERENCES groups(group_id),
contact_id TEXT REFERENCES contacts(contact_id),
start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: messages
-- Stores each individual message, which is the core unit of a conversation.
-- message_id: A unique identifier for the message.
-- session_id: A foreign key referencing the 'sessions' table, linking the message to a conversation.
-- contact_id: A foreign key referencing the 'contacts' table, identifying the message sender.
-- timestamp: The time the message was sent.
-- text: The content of the message.
-- embedding: A JSONB field to store the vector embedding of the message for semantic search.
-- status: A field to track the status of the message (e.g., 'sent', 'delivered', 'read').
CREATE TABLE IF NOT EXISTS messages (
message_id TEXT PRIMARY KEY,
session_id TEXT REFERENCES sessions(session_id),
contact_id TEXT REFERENCES contacts(contact_id),
timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
text TEXT NOT NULL,
embedding JSONB
);

-- Indexes for optimized performance
-- These indexes help speed up common database queries, especially for lookups based on foreign keys.
-- They are crucial for improving the efficiency of searching for specific groups, contacts, and sessions.
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members (group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_contact_id ON group_members (contact_id);
CREATE INDEX IF NOT EXISTS idx_sessions_group_id ON sessions (group_id);
CREATE INDEX IF NOT EXISTS idx_sessions_contact_id ON sessions (contact_id);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages (session_id);
CREATE INDEX IF NOT EXISTS idx_messages_contact_id ON messages (contact_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages (timestamp);
EOSQL

echo "--- [SUCCESS] 'chat_memory' database configured with extended schema. ---"
echo "--- [COMPLETE] PostgreSQL initialization finished. ---"
