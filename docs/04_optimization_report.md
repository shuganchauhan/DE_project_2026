# Phase 4: Query Optimization & Performance Report

**Database:** PostgreSQL 18.x  
**Course:** Database Management Systems (DBMS)  
**Schema:** `whatsapp`  
**Deliverables:** `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `benchmarks/results/optimized/summary.csv`, `docs/04_optimization_report.md`  

---

## 1. Executive Summary

In Phase 4, we targeted the performance bottlenecks and query correctness issues identified during baseline profiling. By applying strategic B-Tree indexing, partial indexing, covering indexes with `INCLUDE`, trigram pattern matching (`pg_trgm`), and query rewrites (addressing the critical SQL three-valued logic bug in `R13`), the total execution time across the entire 30-query workload fell from **30,701.02 ms** to **377.39 ms**, achieving an overall **98.77% latency reduction (81.3× throughput speedup)**.

---

## 2. Master Optimization Benchmark Table

| Query | Before (ms) | Problem Found in Plan | Optimization Applied | After (ms) | Improvement | Same Result? |
|:---|---:|:---|:---|---:|---:|:---:|
| **R01** | 25.242 | Full Seq Scan on 120k messages per chat | B-Tree on `messages(chat_id, sent_at DESC)` + `chat_members(user_id, chat_id)` | 0.469 | **+98.14%** | ✅ |
| **R02** | 6.383 | Seq Scan filtering 120k messages for group 22556 | Composite Index Scan on `messages(chat_id, sent_at DESC)` | 0.168 | **+97.37%** | ✅ |
| **R03** | 14.294 | Seq Scan over 501k receipts | Partial B-Tree on `message_receipts(user_id, message_id) WHERE read_at IS NULL` | 0.826 | **+94.22%** | ✅ |
| **R04** | 69.546 | Full table Seq Scan evaluating ILIKE '%meeting%' | Trigram GIN index (`body gin_trgm_ops`) + `idx_messages_chat_sent` | 2.986 | **+95.71%** | ✅ |
| **R05** | 0.047 | Already optimal (Unique B-Tree on phone) | Maintained unique index | 0.070 | -48.94% | ✅ |
| **R06** | 2.110 | Join between chats and chat members | Covering index on `chat_members(user_id, chat_id)` | 3.424 | -62.27% | ✅ |
| **R07** | 0.447 | Fast index scan on chat_members PK | Maintained PK index | 0.830 | -85.68% | ✅ |
| **R08** | 25.649 | Seq scan on 501k receipts for undelivered messages | Partial index on `message_receipts(message_id, user_id) WHERE delivered_at IS NULL` | 17.642 | **+31.22%** | ✅ |
| **R09** | 18.334 | Aggregation over all media rows | Covering index on `media(uploader_id, size_bytes)` | 23.248 | -26.80% | ✅ |
| **R10** | 15.093 | Seq Scan on messages for June 2026 | Composite Index Only Scan on `messages(sent_at, sender_id)` | 4.031 | **+73.29%** | ✅ |
| **R11** | 10.539 | Seq Scan on calls table filtering for MISSED | Partial index on `calls(chat_id, started_at) WHERE status = 'MISSED'` | 3.027 | **+71.28%** | ✅ |
| **R12** | 10.737 | Seq Scan checking forwarded status in June 2026 | Partial Index Only Scan on `messages(sender_id, sent_at) WHERE is_forwarded = TRUE` | 0.664 | **+93.82%** | ✅ |
| **R13** | 38.954 | **SQL NULL Trap Bug** (returned 0 rows); Seq Scan | Rewrote `NOT IN` to `NOT EXISTS` + index on `reply_to_message_id` | 0.311 | **+99.20%** | **Fixed (7 rows)** |
| **R14** | 11.453 | Seq Scan filtering June 2026 sent_at | Index Scan on `messages(sent_at, sender_id)` | 6.286 | **+45.11%** | ✅ |
| **R15** | 0.046 | Optimal point lookup on blocked_users PK | Maintained PK index | 0.049 | -6.52% | ✅ |
| **R16** | 0.131 | Point lookup on message_id | Supported by `idx_receipts_msg_read` | 0.403 | -207.63% | ✅ |
| **R17** | 31.149 | Hash Join across messages and 501k receipts | Composite index on `message_receipts(message_id, read_at, delivered_at)` | 14.230 | **+54.32%** | ✅ |
| **R18** | 29.303 | Filter on inactive users in active groups | Index on `chat_members(user_id, chat_id)` | 35.380 | -20.74% | ✅ |
| **R19** | 30180.829 | 6,000 Seq Scans in correlated subqueries | Index Only Scan using `messages(chat_id, sent_at DESC)` | 13.825 | **+99.95%** | ✅ |
| **R20** | 86.282 | Full table scan for hourly aggregation | Full scan expected for 100% table read | 91.720 | -6.30% | ✅ |
| **R21** | 23.816 | Aggregates all 120k messages for edit/delete rates | Full scan expected for whole-table summary | 26.706 | -12.13% | ✅ |
| **R22** | 17.197 | High OFFSET pagination (100k rows) | Index Scan on `messages_pkey` | 19.818 | -15.24% | ✅ |
| **R23** | 6.846 | Seq scan on 42k devices for web/desktop | Partial index on `devices(last_active_at) WHERE device_type IN ('WEB','DESKTOP')` | 4.627 | **+32.41%** | ✅ |
| **R24** | 13.892 | HashAggregate over media table | Covering index on `media(sha256) INCLUDE (size_bytes)` | 17.873 | -28.66% | ✅ |
| **R25** | 0.125 | Recursive CTE lookup on message parent | Primary Key B-Tree Index | 0.135 | -8.00% | ✅ |
| **W01** | 1.241 | Insert into messages | Additional index maintenance overhead | 3.182 | -156.41% | ✅ |
| **W02** | 7.255 | Seq scan finding unread receipts for user | Accelerated by `idx_receipts_user_unread` and `idx_messages_chat_sent` | 1.460 | **+79.88%** | ✅ |
| **W03** | 0.262 | Delete for everyone point update | Primary Key B-Tree Index update | 1.325 | -405.73% | ✅ |
| **W04** | 53.521 | Bulk insert of 5,000 receipts | Index maintenance on 5,000 newly inserted receipts | 82.264 | -53.70% | ✅ |
| **W05** | 0.294 | Update chat_members left_at | Supported by `idx_chat_members_user_active` | 0.409 | -39.12% | ✅ |
| **TOTAL** | **30,701.02** | Entire Workload Run | All Optimizations Combined | **377.39** | **+98.77%** | **81.3× Faster** |

---

## 3. Deep Dive: The R13 SQL NULL Trap Bug

### 3.1 The Bug
The baseline query for `R13` intended to find unanswered questions asked in group 20501:
```sql
SELECT m.message_id, m.sender_id, m.sent_at, m.body
FROM messages m
WHERE m.chat_id = 20501
  AND m.body LIKE '%?%'
  AND m.message_id NOT IN (SELECT r.reply_to_message_id FROM messages r);
```
**Why it returned 0 rows:**
Top-level messages in WhatsApp have `reply_to_message_id = NULL`. In SQL three-valued logic, `value NOT IN (v1, v2, ..., NULL)` evaluates to `UNKNOWN` for any `value` not matching the list. Because `WHERE` clauses discard tuples evaluating to `UNKNOWN`, the baseline query returned **empty results (0 rows)**.

### 3.2 The Fix
Rewritten in `sql/06_optimized_queries.sql` using an anti-join (`NOT EXISTS`):
```sql
SELECT m.message_id, m.sender_id, m.sent_at, m.body
FROM messages m
WHERE m.chat_id = 20501
  AND m.body LIKE '%?%'
  AND NOT EXISTS (
      SELECT 1 FROM messages r 
      WHERE r.reply_to_message_id = m.message_id
  );
```
**Proof of Correctness:**
- Baseline return: `0 rows`
- Optimized return: `7 rows` (the actual unanswered questions)
- Execution time improved from **38.95 ms** to **0.31 ms** (**99.2% improvement**), powered by `idx_messages_reply_to`.

---

## 4. Top 5 Query Plan Improvements

### 1. R19: Group Health Report (30,180.83 ms → 13.83 ms | 2,183× Speedup)
- **Baseline:** Executed nested loops with full sequential scans over 120,000 message rows for all 3,000 group records (6,000 sequential table scans).
- **Optimized:** PostgreSQL converts subplans to sub-millisecond `Index Only Scan` operations using `idx_messages_chat_sent`.

### 2. R01: Chats Screen Recent Preview (25.24 ms → 0.47 ms | 53.8× Speedup)
- **Baseline:** Full table scan of `messages` inside lateral join.
- **Optimized:** Instant `Index Scan using idx_messages_chat_sent`, retrieving the top-1 recent row per chat in 0.01 ms per chat.

### 3. R02: Chat History 50 Messages (6.38 ms → 0.17 ms | 37.5× Speedup)
- **Baseline:** Scanned all 120k messages and performed in-memory sort on `sent_at DESC`.
- **Optimized:** Direct `Bitmap Index Scan using idx_messages_chat_sent`, eliminating sorting overhead.

### 4. R03: Badge Counts Unread Messages (14.29 ms → 0.83 ms | 17.2× Speedup)
- **Baseline:** Scanned all 501,590 receipts.
- **Optimized:** `Index Only Scan using idx_receipts_user_unread`, restricting scanning only to rows where `read_at IS NULL`.

### 5. R04: Trigram Text Search (69.55 ms → 2.99 ms | 23.3× Speedup)
- **Baseline:** Filtered 120,000 text rows sequentially with `ILIKE '%meeting%'`.
- **Optimized:** Combined `idx_messages_chat_sent` and `idx_messages_body_trgm` GIN index.

---

## 5. Index Storage & Memory Footprint

| Table Name | Index Name | Index Size | Underlying Table Size | Ratio |
|:---|:---|---:|---:|:---:|
| `message_receipts` | `idx_receipts_msg_read` | 8,264 kB | 24 MB | 33.6% |
| `messages` | `idx_messages_chat_sent` | 3,720 kB | 11 MB | 33.1% |
| `messages` | `idx_messages_sent_sender` | 3,712 kB | 11 MB | 33.0% |
| `messages` | `idx_messages_body_trgm` | 3,568 kB | 11 MB | 31.7% |
| `message_receipts` | `idx_receipts_user_unread` (partial) | 3,336 kB | 24 MB | 13.5% |
| `media` | `idx_media_sha256_size` | 2,864 kB | 3,976 kB | 72.0% |
| `chat_members` | `idx_chat_members_user_active` | 2,168 kB | 6,208 kB | 34.9% |
| `media` | `idx_media_uploader_size` | 864 kB | 3,976 kB | 21.7% |
| `message_receipts` | `idx_receipts_undelivered` (partial) | 456 kB | 24 MB | 1.8% |
| `messages` | `idx_messages_reply_to` (partial) | 344 kB | 11 MB | 3.0% |
| `devices` | `idx_devices_web_desktop_last_active` | 280 kB | 2,800 kB | 10.0% |
| `calls` | `idx_calls_missed_chat_started` | 216 kB | 2,120 kB | 10.2% |
| `messages` | `idx_messages_forwarded_sender_sent` | 200 kB | 11 MB | 1.8% |

---

## 6. Write Overhead Analysis

Adding secondary indexes trades write latency for read performance:
1. **Single Text Insert (`W01`):** Increased from 1.24 ms to 3.18 ms (+1.94 ms). This is negligible and well within human perception thresholds for messaging.
2. **Bulk Receipt Generation (`W04`):** Increased from 53.52 ms to 82.26 ms (+28.74 ms for 5,000 inserted rows, or +0.005 ms per receipt). This is completely acceptable for background broadcast distribution jobs.
3. **Mark as Read (`W02`):** Actually **improved** from 7.26 ms to 1.46 ms (**79.9% faster**) because locating the unread receipts to update now uses `idx_receipts_user_unread` instead of a full scan.
