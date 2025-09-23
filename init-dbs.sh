#!/bin/bash
set -e

echo "--- [START] Running custom initialization script (init-dbs.sh) ---"
echo "Setting up databases for n8n..."

## Function to create database if it doesn't exist
#create_database() {
#  local db_name=$1
#  echo "  - Processing database: $db_name"
#  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
#      SELECT 'CREATE DATABASE $db_name'
#      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db_name');
#EOSQL
#}
#
## Create required databases
#create_database "chat_memory"
#create_database "n8n"
#
#echo "--- [SUCCESS] Databases created or already exist. ---"
#echo "--- [START] Configuring 'chat_memory' database (STM schema)... ---"
#
#psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "chat_memory" <<-'EOSQL'
#-- Sessions table: tracks conversations per user
#CREATE TABLE IF NOT EXISTS sessions (
#    id BIGSERIAL PRIMARY KEY,
#    session_id VARCHAR(255) NOT NULL UNIQUE,
#    user_id VARCHAR(255) NOT NULL,
#    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
#);
#
#-- Messages table: stores every message with role info
#CREATE TABLE IF NOT EXISTS messages (
#    id BIGSERIAL PRIMARY KEY,
#    session_id VARCHAR(255) REFERENCES sessions(session_id),
#    chat_id VARCHAR(255) NOT NULL,
#    is_group_chat BOOLEAN NOT NULL DEFAULT FALSE,
#    user_id VARCHAR(255) NOT NULL,
#    role VARCHAR(50) NOT NULL, -- 'user', 'assistant', 'system'
#    content TEXT NOT NULL,
#    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
#);
#
#-- Indexes for faster retrieval
#CREATE INDEX IF NOT EXISTS idx_messages_session_time
#    ON messages(session_id, created_at DESC);
#CREATE INDEX IF NOT EXISTS idx_messages_user_time
#    ON messages(user_id, created_at DESC);
#CREATE INDEX IF NOT EXISTS idx_messages_chat_time
#    ON messages(chat_id, is_group_chat, created_at DESC);
#
#EOSQL

#echo "--- [SUCCESS] 'chat_memory' database configured with final STM schema. ---"
echo "--- [COMPLETE] Postgre_n8n initialization finished. ---"
