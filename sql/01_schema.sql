-- ============================================================
-- WhatsApp Messaging Database: Phase 2 Schema Definition
-- Schema: whatsapp
-- ============================================================

CREATE SCHEMA IF NOT EXISTS whatsapp;
SET search_path TO whatsapp;

DROP TABLE IF EXISTS blocked_users CASCADE;
DROP TABLE IF EXISTS calls CASCADE;
DROP TABLE IF EXISTS message_receipts CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS media CASCADE;
DROP TABLE IF EXISTS chat_members CASCADE;
DROP TABLE IF EXISTS chats CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 1. USERS
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    phone_e164 VARCHAR(20) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    about TEXT,
    is_business BOOLEAN NOT NULL DEFAULT FALSE,
    joined_on DATE NOT NULL,
    last_seen_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE', 'BANNED', 'DELETED')),
    CONSTRAINT chk_phone_e164_format CHECK (phone_e164 ~ '^\+[1-9][0-9]{1,14}$')
);

-- 2. DEVICES
CREATE TABLE devices (
    device_id INT PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    device_type VARCHAR(20) NOT NULL CHECK (device_type IN ('ANDROID', 'IOS', 'WEB', 'DESKTOP')),
    app_version VARCHAR(20) NOT NULL,
    registered_at TIMESTAMPTZ NOT NULL,
    last_active_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_device_activity_time CHECK (last_active_at >= registered_at)
);

-- 3. CHATS
CREATE TABLE chats (
    chat_id INT PRIMARY KEY,
    chat_type VARCHAR(20) NOT NULL CHECK (chat_type IN ('DIRECT', 'GROUP')),
    group_name VARCHAR(100),
    created_by INT REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_chat_group_name CHECK (
        (chat_type = 'DIRECT' AND group_name IS NULL) OR
        (chat_type = 'GROUP' AND group_name IS NOT NULL)
    )
);

-- 4. CHAT MEMBERS
CREATE TABLE chat_members (
    chat_id INT NOT NULL REFERENCES chats(chat_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('ADMIN', 'MEMBER')),
    joined_at TIMESTAMPTZ NOT NULL,
    left_at TIMESTAMPTZ,
    is_muted BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (chat_id, user_id),
    CONSTRAINT chk_member_left_after_joined CHECK (left_at IS NULL OR left_at >= joined_at)
);

-- 5. MEDIA
CREATE TABLE media (
    media_id INT PRIMARY KEY,
    uploader_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('IMAGE', 'VIDEO', 'AUDIO', 'DOCUMENT')),
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
    sha256 CHAR(64) NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_sha256_format CHECK (sha256 ~ '^[0-9a-f]{64}$')
);

-- 6. MESSAGES
CREATE TABLE messages (
    message_id INT PRIMARY KEY,
    chat_id INT NOT NULL REFERENCES chats(chat_id) ON DELETE CASCADE,
    sender_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    sent_at TIMESTAMPTZ NOT NULL,
    message_type VARCHAR(20) NOT NULL CHECK (message_type IN ('TEXT', 'IMAGE', 'AUDIO', 'DOCUMENT', 'LOCATION', 'VIDEO')),
    body TEXT,
    media_id INT REFERENCES media(media_id) ON DELETE SET NULL,
    reply_to_message_id INT REFERENCES messages(message_id) ON DELETE SET NULL,
    is_forwarded BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    CONSTRAINT chk_message_edit_after_sent CHECK (edited_at IS NULL OR edited_at >= sent_at)
);

-- 7. MESSAGE RECEIPTS
CREATE TABLE message_receipts (
    message_id INT NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id),
    CONSTRAINT chk_receipt_read_after_delivered CHECK (read_at IS NULL OR delivered_at IS NULL OR read_at >= delivered_at)
);

-- 8. CALLS
CREATE TABLE calls (
    call_id INT PRIMARY KEY,
    chat_id INT NOT NULL REFERENCES chats(chat_id) ON DELETE CASCADE,
    caller_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    call_type VARCHAR(20) NOT NULL CHECK (call_type IN ('VOICE', 'VIDEO')),
    started_at TIMESTAMPTZ NOT NULL,
    answered_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL CHECK (status IN ('COMPLETED', 'MISSED', 'REJECTED', 'FAILED')),
    CONSTRAINT chk_call_timing CHECK (
        (answered_at IS NULL OR answered_at >= started_at) AND
        (ended_at IS NULL OR ended_at >= started_at) AND
        (ended_at IS NULL OR answered_at IS NULL OR ended_at >= answered_at)
    )
);

-- 9. BLOCKED USERS
CREATE TABLE blocked_users (
    blocker_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    blocked_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    blocked_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT chk_cannot_block_self CHECK (blocker_id <> blocked_id)
);
