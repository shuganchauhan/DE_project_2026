# Phase 1: Problem Understanding & Requirements Analysis

**Course:** Database Management Systems (DBMS)  
**Project:** WhatsApp Messaging Database  
**Author:** Team 14  
**Scope:** Message Store for India Region  

---

## 1. Executive Overview

WhatsApp processes hundreds of millions of conversational transactions daily across India. The database supports one-to-one direct conversations, multi-participant groups, media exchanges, voice/video calling, and real-time delivery/read receipt synchronization. 

Due to rapid initial growth without structured indexing, partitioning, or query tuning, several mission-critical workloads suffer from degraded latency, timeouts, or logical inaccuracies. Below is the systematic analysis of reported issues (P1–P10), their operational stakeholders, classification, and business impact.

---

## 2. Problem Statements Analysis (P1 – P10)

| ID | Problem Description & Business Need | Affected Stakeholder | Workload Classification | Related Queries | SLA Target |
|:---|:---|:---|:---|:---|:---|
| **P1** | **Slow Chats Screen Rendering:** When active users open WhatsApp, computing the most recent message per conversation and unread badges requires scanning millions of message rows. The app needs sub-50ms conversational previews. | Mobile App / End User | **Customer-Facing / Real-Time** | `R01`, `R03` | < 30 ms |
| **P2** | **Chat History & Group Scrolling Latency:** Opening high-volume groups (e.g. group 22556) incurs sequential scans across all sent messages instead of retrieving the latest 50 messages instantaneously. | Mobile App / End User | **Customer-Facing / Real-Time** | `R02`, `R07`, `W01` | < 10 ms |
| **P3** | **Message Text Search & Read Receipts Lag:** Substring text filtering (`ILIKE '%meeting%'`) and per-recipient status lookups (who read message $X$) stall due to lack of trigram indexes and receipt lookups. | End User / Privacy | **Customer-Facing / Real-Time** | `R04`, `R16`, `R25` | < 25 ms |
| **P4** | **Phone Registration & Presence Checking:** Account setup, phone number verification, contact synchronization, and mutual blocking status verification require immediate point lookups. | Identity / Privacy Service | **Customer-Facing / Real-Time** | `R05`, `R06`, `R15` | < 5 ms |
| **P5** | **Delivery Service Backlog:** The offline messaging queue scanning for unacknowledged receipts (`delivered_at IS NULL`) and updating read timestamps causes lock contention and slow updates. | Delivery Infrastructure | **Real-Time Backend Service** | `R08`, `W02`, `W04` | < 15 ms |
| **P6** | **Unanswered Questions Report Empty Bug:** Group administrators querying unanswered questions receive an empty result set due to an SQL three-valued logic bug (`NOT IN` on a subquery containing `NULL`). | Group Administrators | **Reporting / Operational** | `R13` | Correctness & < 20 ms |
| **P7** | **Trust & Safety Forwarding & Spam Console:** Trust & Safety teams monitoring bulk forwarding (>5 forwards in a period) and paginating through message logs experience slow scans and inefficient `OFFSET` pagination. | Trust & Safety Operations | **Reporting / Console** | `R12`, `R22`, `W03` | < 50 ms |
| **P8** | **Rising Storage Footprint & Deduplication:** Infrastructure teams require identification of top storage consumers and duplicate media files sharing identical SHA-256 hashes to reclaim object storage costs. | Storage Engineering | **Batch / Analytics** | `R09`, `R24` | < 100 ms |
| **P9** | **Product Analytics & Growth Metric Timeouts:** Computing daily active senders (DAU), read receipt latency, edit/delete rates, and group health metrics times out as message volume scales 20×. | Growth / Product Analytics | **Analytical / Reporting** | `R10`, `R14`, `R17`, `R19`, `R20`, `R21` | < 200 ms |
| **P10** | **Security Audits & Stale Session Garbage Collection:** Periodic background jobs that invalidate inactive linked web/desktop sessions, clean up inactive users, and monitor call logs execute table-wide scans. | Security / Platform Operations | **Batch / Scheduled Maintenance** | `R11`, `R18`, `R23`, `W05` | < 50 ms |

---

## 3. Workload Classification & Latency Objectives

Workloads are segregated into two distinct performance tiers:

1. **Customer-Facing / Real-Time Tier (P1–P5, P10 writes):**
   - Direct impact on user perception, messaging latency, and delivery guarantees.
   - **Optimization Target:** Latency $\le 10$–$30\text{ ms}$, zero sequential scans on `messages` or `message_receipts`, utilizing B-Tree and GIN indexes with covering attributes.

2. **Reporting & Analytics Tier (P6–P10):**
   - High data-volume aggregations, cohort tracking, and audit sweeps.
   - **Optimization Target:** Execution within hundreds of milliseconds instead of 30+ seconds, sargable query rewrites, eliminating correlated subqueries, and leveraging covering scans.

---

## 4. Key Architectural Assumptions

1. **Database Platform:** PostgreSQL 15+ (tested on PostgreSQL 18.x with 8KB page size, standard memory parameters).
2. **Schema Separation:** All production operational tables reside in the dedicated `whatsapp` schema.
3. **Data Integrity:** Primary keys, foreign keys, and business integrity constraints are enforced at the database level.
4. **Timezone Uniformity:** All transactional timestamps use `TIMESTAMPTZ` with standard Indian Standard Time offset (`+05:30`).
5. **Scale Profile:** Seed data consists of 120,000 messages and 501,590 receipts; Phase 5 projects a 20× scaling factor (approx. 2.4 million messages and 10 million receipts).
