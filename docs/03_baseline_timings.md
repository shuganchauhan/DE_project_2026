# Baseline Performance Timings: WhatsApp Messaging Database

**Phase:** Phase 3 — Baseline Workload Benchmarking  
**Course:** Database Management Systems (DBMS)  
**Database:** PostgreSQL 18.x (localhost:5432, schema `whatsapp`)  
**Workload File:** `queries/workload_30.sql` (30 Queries: R01–R25 Reads, W01–W05 Writes)  
**Results Directory:** `benchmarks/results/baseline/`  
**Summary CSV:** `benchmarks/results/baseline/summary.csv`  

---

## 1. Benchmark Environment & Methodology

- **Measurement Protocol:** Every query was executed using `EXPLAIN (ANALYZE, BUFFERS)` in PostgreSQL.
- **Repetitions:** Exactly **3 independent runs** per query. The reported average is the arithmetic mean of the three execution times.
- **Write Safety:** Write operations (`W01`–`W05`) executed strictly within isolated `BEGIN; ... ROLLBACK;` blocks to prevent mutating the seed data between runs.
- **Schema State:** Baseline unoptimized configuration (only Primary Key, Unique, and Foreign Key constraints; zero auxiliary secondary indexes or materialized views).
- **Dataset Scale:** 
  - `users`: 30,000 rows
  - `devices`: 42,000 rows
  - `chats`: 23,000 rows
  - `chat_members`: 104,514 rows
  - `media`: 27,634 rows
  - `messages`: 120,000 rows
  - `message_receipts`: 501,590 rows
  - `calls`: 25,000 rows
  - `blocked_users`: 4,000 rows

---

## 2. Baseline Timing Table (30 Queries)

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| **R01**: Chats screen: user 965's chats with latest message | READ | 25.976 | 25.130 | 24.619 | **25.242** |
| **R02**: Open a chat: latest 50 messages of group 22556 | READ | 6.161 | 6.445 | 6.543 | **6.383** |
| **R03**: Badge counts: unread messages per chat for user 965 | READ | 15.542 | 14.123 | 13.217 | **14.294** |
| **R04**: Search: messages containing "meeting" in user 965's chats | READ | 68.955 | 69.907 | 69.776 | **69.546** |
| **R05**: Registration: phone number existence lookup | READ | 0.051 | 0.046 | 0.045 | **0.047** |
| **R06**: Contact info: last seen of direct chat partners | READ | 2.191 | 2.112 | 2.028 | **2.110** |
| **R07**: Group info screen: members of group 22556 with role | READ | 0.716 | 0.334 | 0.291 | **0.447** |
| **R08**: Delivery service: pending undelivered receipts | READ | 25.830 | 25.697 | 25.420 | **25.649** |
| **R09**: Storage team: top 20 users by total media uploaded | READ | 18.481 | 18.200 | 18.321 | **18.334** |
| **R10**: Growth: daily active senders in June 2026 | READ | 15.218 | 15.089 | 14.972 | **15.093** |
| **R11**: Calls tab: missed calls received by user 965 | READ | 10.523 | 10.469 | 10.625 | **10.539** |
| **R12**: Spam detection: users forwarding > 5 messages in June | READ | 10.699 | 10.768 | 10.744 | **10.737** |
| **R13**: Unanswered questions: group questions with no replies | READ | 39.393 | 38.140 | 39.329 | **38.954** |
| **R14**: Media heavy chats: groups with highest media ratio | READ | 11.104 | 11.195 | 12.061 | **11.453** |
| **R15**: Privacy check: has user A blocked user B | READ | 0.045 | 0.046 | 0.047 | **0.046** |
| **R16**: Message info: status breakdown for message 12000 | READ | 0.123 | 0.140 | 0.130 | **0.131** |
| **R17**: Message latency: median time from sent to read | READ | 29.674 | 33.753 | 30.019 | **31.149** |
| **R18**: Inactive users in active groups: users inactive > 90d | READ | 29.310 | 29.459 | 29.139 | **29.303** |
| **R19**: Group health report: last message time & June count | READ | 30915.896 | 30046.583 | 29580.009 | **30180.829** |
| **R20**: Capacity planning: hourly message load by type | READ | 84.952 | 84.998 | 88.895 | **86.282** |
| **R21**: Analytics: percentage of messages edited or deleted | READ | 24.117 | 23.625 | 23.705 | **23.816** |
| **R22**: Trust & safety: message audit page 4,001 | READ | 17.114 | 16.827 | 17.650 | **17.197** |
| **R23**: Security audit: stale linked Web/Desktop devices | READ | 6.885 | 6.672 | 6.980 | **6.846** |
| **R24**: Deduplication: duplicate media files (matching SHA256) | READ | 13.803 | 13.933 | 13.941 | **13.892** |
| **R25**: Reply thread: recursive CTE traversing reply hierarchy | READ | 0.116 | 0.127 | 0.132 | **0.125** |
| **W01**: Send text message in group 22556 | WRITE | 1.637 | 1.059 | 1.028 | **1.241** |
| **W02**: Mark group messages as read for user 965 | WRITE | 6.675 | 7.334 | 7.757 | **7.255** |
| **W03**: Delete message for everyone (message 119989) | WRITE | 0.269 | 0.247 | 0.271 | **0.262** |
| **W04**: Broadcast: generate receipts for 5,000 recipients | WRITE | 49.331 | 52.296 | 58.935 | **53.521** |
| **W05**: Member leaves group 20898 | WRITE | 0.340 | 0.278 | 0.263 | **0.294** |

---

## 3. Bottleneck Analysis & Query Plan Findings

### 3.1 The Extreme Outlier: R19 (30.18 seconds)
- **Problem:** `R19` computes the latest message timestamp and the total June 2026 messages for all groups in `chats`.
- **Query Plan Cause:** The query evaluates two correlated scalar subqueries (`SELECT max(m.sent_at) ...` and `SELECT count(*) ...`) for **every group row** returned by `chats`.
- **Impact:** Since `messages` does not have an index on `(chat_id, sent_at)`, PostgreSQL executes **two full sequential scans of 120,000 rows** for each of the ~3,000 groups, accumulating over 6,000 sequential table scans in a single query execution.
- **Phase 4 Target:** Rewrite into a single aggregated `GROUP BY` with `LEFT JOIN`, complemented by a composite B-Tree index on `messages(chat_id, sent_at)`.

### 3.2 Full Table Scans on High-Volume Tables
1. **`messages` (120,000 rows):**
   - Queries `R01`, `R02`, `R04`, `R08`, `R10`, `R12`, `R13`, `R14`, `R17`, `R20`, `R21`, and write `W02` perform full sequential table scans.
   - For `R04` (text search `%meeting%`), sequential scans take ~69.5 ms. A trigram GIN index on `messages(body)` will dramatically accelerate substring filtering.
   - For `R02` (fetch recent 50 messages of a chat), scanning 120,000 rows takes 6.38 ms. An index on `(chat_id, sent_at DESC)` will enable instant backward index scans.
2. **`message_receipts` (501,590 rows):**
   - Queries `R03`, `R08`, and `R17` perform full table scans across 500,000+ receipts.
   - `R08` filters on `delivered_at IS NULL`. A partial index `WHERE delivered_at IS NULL` will reduce scanned rows from 501,590 to only undelivered rows.
3. **`chat_members` (104,514 rows):**
   - `R18` scans all chat members to detect inactive users, taking ~29.3 ms.

### 3.3 Fast Point Lookups
- Queries utilizing primary keys or unique constraints (`R05` on `phone_e164`, `R15` on `blocked_users_pkey`, `R16` on `message_receipts_pkey`, `W03` on `messages_pkey`, and `W05` on `chat_members_pkey`) executed in **under 0.5 ms**, verifying the efficacy of default B-Tree indexing on primary key constraints.

---

## 4. Phase 4 Optimization Roadmap

Based on the baseline execution plans and buffer statistics, the following indexes and query rewrites are prioritized for Phase 4:
1. `CREATE INDEX idx_messages_chat_sent ON messages (chat_id, sent_at DESC);`
2. `CREATE INDEX idx_messages_sender_sent ON messages (sender_id, sent_at);`
3. `CREATE INDEX idx_receipts_undelivered ON message_receipts (message_id, user_id) WHERE delivered_at IS NULL;`
4. `CREATE INDEX idx_receipts_unread ON message_receipts (user_id, read_at) WHERE read_at IS NULL;`
5. `CREATE EXTENSION IF NOT EXISTS pg_trgm; CREATE INDEX idx_messages_body_trgm ON messages USING gin (body gin_trgm_ops);`
6. `CREATE INDEX idx_calls_chat_caller ON calls (chat_id, caller_id, started_at);`
7. Rewrite correlated subqueries in `R19` into set-based joins.
