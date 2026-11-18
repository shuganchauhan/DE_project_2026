-- ============================================================
-- WhatsApp Messaging Database: Phase 4 Indexes
-- Schema: whatsapp, public
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
SET search_path TO whatsapp, public;

-- 1. MESSAGES: Chat lookup and recency sorting
-- Serves: R01, R02, R19, W01, W02
-- Why: Most queries filter messages by chat_id and sort by sent_at DESC.
-- B-Tree composite on (chat_id, sent_at DESC) allows instant index scan and eliminates sorting.
CREATE INDEX IF NOT EXISTS idx_messages_chat_sent 
ON messages (chat_id, sent_at DESC);

-- 2. MESSAGES: Sender and date range
-- Serves: R10, R12, R14
-- Why: Accelerates time-slice filtering (June 2026) and grouping by sender/chat.
CREATE INDEX IF NOT EXISTS idx_messages_sent_sender 
ON messages (sent_at, sender_id);

-- 3. MESSAGES: Trigram GIN index on text body
-- Serves: R04
-- Why: Accelerates ILIKE '%meeting%' arbitrary substring pattern matching via trigram tokenization.
CREATE INDEX IF NOT EXISTS idx_messages_body_trgm 
ON messages USING gin (body gin_trgm_ops);

-- 4. MESSAGES: Threaded replies lookup
-- Serves: R13, R25
-- Why: Partial index on reply_to_message_id for non-null replies allows instant check of which questions received replies.
CREATE INDEX IF NOT EXISTS idx_messages_reply_to 
ON messages (reply_to_message_id) 
WHERE reply_to_message_id IS NOT NULL;

-- 5. MESSAGES: Spam and forwarding monitor
-- Serves: R12
-- Why: Partial index indexing only forwarded messages for June 2026 spam detection.
CREATE INDEX IF NOT EXISTS idx_messages_forwarded_sender_sent 
ON messages (sender_id, sent_at) 
WHERE is_forwarded = TRUE;

-- 6. MESSAGE RECEIPTS: Unread receipts per user
-- Serves: R03, W02
-- Why: Partial index for read_at IS NULL avoids indexing 98% of receipts that are already read.
CREATE INDEX IF NOT EXISTS idx_receipts_user_unread 
ON message_receipts (user_id, message_id) 
WHERE read_at IS NULL;

-- 7. MESSAGE RECEIPTS: Pending delivery queue
-- Serves: R08
-- Why: Partial index for undelivered receipts avoids scanning 500k+ rows when only undelivered rows are needed.
CREATE INDEX IF NOT EXISTS idx_receipts_undelivered 
ON message_receipts (message_id, user_id) 
WHERE delivered_at IS NULL;

-- 8. MESSAGE RECEIPTS: Read latency metrics
-- Serves: R17
-- Why: Composite index on message_id and read timestamps for June 2026 messages.
CREATE INDEX IF NOT EXISTS idx_receipts_msg_read 
ON message_receipts (message_id, read_at, delivered_at);

-- 9. CALLS: Missed calls by chat and time
-- Serves: R11
-- Why: Partial index filtering only MISSED calls avoids scanning completed/rejected calls.
CREATE INDEX IF NOT EXISTS idx_calls_missed_chat_started 
ON calls (chat_id, started_at) 
WHERE status = 'MISSED';

-- 10. DEVICES: Inactive linked devices
-- Serves: R23
-- Why: Partial index on Web/Desktop companion sessions to immediately find stale tokens for logout.
CREATE INDEX IF NOT EXISTS idx_devices_web_desktop_last_active 
ON devices (last_active_at) 
WHERE device_type IN ('WEB', 'DESKTOP');

-- 11. CHAT MEMBERS: Active memberships by user
-- Serves: R01, R04, R06, R18, W05
-- Why: chat_members_pkey is (chat_id, user_id). Adding an index starting with user_id allows efficient lookups of a user's chats.
CREATE INDEX IF NOT EXISTS idx_chat_members_user_active 
ON chat_members (user_id, chat_id) 
WHERE left_at IS NULL;

-- 12. MEDIA: Deduplication and SHA256 grouping
-- Serves: R24
-- Why: Covering B-Tree index on (sha256) INCLUDE (size_bytes) enables Index Only Scan for finding duplicate uploads.
CREATE INDEX IF NOT EXISTS idx_media_sha256_size 
ON media (sha256) INCLUDE (size_bytes);

-- 13. MEDIA: Uploader quota tracking
-- Serves: R09
-- Why: B-Tree index on (uploader_id, size_bytes) enables Index Only Scan for aggregating upload volume per user.
CREATE INDEX IF NOT EXISTS idx_media_uploader_size 
ON media (uploader_id, size_bytes);

VACUUM ANALYZE;
