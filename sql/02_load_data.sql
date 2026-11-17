-- ============================================================
-- WhatsApp Messaging Database: Phase 2 Data Loading Script
-- Schema: whatsapp
-- ============================================================

SET search_path TO whatsapp;

\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true);
\copy devices FROM 'seed_data/devices.csv' WITH (FORMAT csv, HEADER true);
\copy chats FROM 'seed_data/chats.csv' WITH (FORMAT csv, HEADER true);
\copy chat_members FROM 'seed_data/chat_members.csv' WITH (FORMAT csv, HEADER true);
\copy media FROM 'seed_data/media.csv' WITH (FORMAT csv, HEADER true);
\copy messages FROM 'seed_data/messages.csv' WITH (FORMAT csv, HEADER true);
\copy message_receipts FROM 'seed_data/message_receipts.csv' WITH (FORMAT csv, HEADER true);
\copy calls FROM 'seed_data/calls.csv' WITH (FORMAT csv, HEADER true);
\copy blocked_users FROM 'seed_data/blocked_users.csv' WITH (FORMAT csv, HEADER true);

VACUUM ANALYZE;
