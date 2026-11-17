# Database Normalization Report: Gamers'G Platform

**Course:** Advanced Programming (AP) / Database Management Systems (DBMS)  
**Project:** Gamers'G — Competitive Esports Platform  
**Component:** AP Database Architecture (`dbms/01_normalization.md`)  
**Target Normal Form:** 1NF → 2NF → 3NF → BCNF  

---

## 1. Executive Summary & Application Scope

**Gamers'G** is an end-to-end competitive esports networking and tournament management platform designed for gamers, teams, esports organizations, and tournament organizers across major competitive titles (*VALORANT*, *BGMI*, *Free Fire*, *Clash of Clans*, *Clash Royale*, and *Call of Duty*). 

The platform supports multiple interconnected subsystems:
1. **Identity & RBAC:** Multi-entity accounts representing Organizations (`org`), Tournament Organizers (`tournament_organizer`), Players (`player`), and System Administrators (`admin`).
2. **Team & Roster Management:** Teams owned by organizations or captains, managing structured roster slots (`team_member`) and official recruitment invitations (`team_invitation`).
3. **Recruitment Engine:** Public or team-specific vacancies (`role_posting`) and player candidacy submissions (`application`).
4. **Tournaments & Scrims:** Tournaments, competitive lobbies (`scrim`), and registrations (`registration`, `scrim_registration`).
5. **Social Networking:** Feed publishing (`post`), social interactions (`post_comment`, `post_like`), entity subscriptions (`follow`), and peer networking (`player_connection`).
6. **Tactical Communications:** Player direct messages (`message`) and real-time private squad comms (`team_message`).

This document presents the complete normalization progression of the Gamers'G relational schema, starting from an unnormalized universal dataset representation through **1NF**, **2NF**, **3NF**, and evaluating **BCNF**.

---

## 2. Unnormalized Form (UNF)

In its initial raw/unnormalized state, data across the platform exists as composite records containing nested entities, multi-valued attributes, and repeating groups. 

### Universal Unnormalized Relation Schema:
$$\text{UNF\_ESPORTS\_PLATFORM}(\underline{\text{AccountID}}, \text{Email}, \text{PasswordHash}, \text{AccountType}, \text{Name}, \text{Username}, \text{Bio}, \text{GameIGNs}, \{\text{TeamsOwned}\}, \{\text{RosterMembers}\}, \{\text{RolePostings}\}, \{\text{Applications}\}, \{\text{TournamentsCreated}\}, \{\text{TournamentRegistrations}\}, \{\text{ScrimLobbies}\}, \{\text{Posts}: \{\text{Comments}\}, \{\text{Likes}\}\}, \{\text{Connections}\}, \{\text{Messages}\})$$

### Anomalies in UNF:
- **Repeating Groups:** A single organization or player has multiple team memberships, applications, posts, and messages grouped inside their record.
- **Non-Atomic Attributes:** Attributes such as `GameIGNs` (in-game names across multiple titles) or `SocialLinks` store comma-separated or compound values.
- **Update Anomalies:** Updating a player's handle or team division requires updating multiple denormalized entries across tournament rosters, scrims, and chat logs.
- **Insertion Anomalies:** Cannot create a tournament slot or role vacancy without binding it immediately to an existing applicant or player.
- **Deletion Anomalies:** Deleting a disbanded team deletes all historical match registrations, player posts, and role applications tied to that record.

---

## 3. First Normal Form (1NF)

### 1NF Criteria:
1. All attributes must be **atomic** (indivisible single values; no repeating groups, arrays, or comma-separated lists).
2. Each row must be uniquely identifiable via a defined **Primary Key (PK)**.
3. Column names must be unique within each relation.

### Transformations Applied:
- Decomposed nested repeating groups into separate relations.
- Expanded compound arrays (such as game handles, roster members, and post comments) into dedicated atomic tuples.
- Assigned unique atomic surrogate/natural keys (UUIDs) as primary keys.

### 1NF Relations & Functional Dependencies:

#### 1. `org_1nf`
- **Schema:** $(\underline{\text{org\_id}}, \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at})$
- **Functional Dependencies ($FD$):**
  - $\text{org\_id} \to \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at}$
  - $\text{name} \to \text{org\_id}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at}$
  - $\text{email} \to \text{org\_id}, \text{name}, \text{password\_hash}, \text{verified}, \text{created\_at}$
- **Candidate Keys:** $\{\text{org\_id}\}, \{\text{name}\}, \{\text{email}\}$

#### 2. `tournament_organizer_1nf`
- **Schema:** $(\underline{\text{organizer\_id}}, \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at})$
- **Functional Dependencies ($FD$):**
  - $\text{organizer\_id} \to \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at}$
  - $\text{email} \to \text{organizer\_id}, \text{name}, \text{password\_hash}, \text{verified}, \text{created\_at}$
- **Candidate Keys:** $\{\text{organizer\_id}\}, \{\text{email}\}$

#### 3. `player_1nf`
- **Schema:** $(\underline{\text{player\_id}}, \text{username}, \text{email}, \text{password\_hash}, \text{game\_ign}, \text{team\_id}, \text{org\_id}, \text{tagline}, \text{bio}, \text{primary\_game}, \text{created\_at})$
- **Functional Dependencies ($FD$):**
  - $\text{player\_id} \to \text{username}, \text{email}, \text{password\_hash}, \text{game\_ign}, \text{team\_id}, \text{org\_id}, \text{tagline}, \text{bio}, \text{primary\_game}, \text{created\_at}$
  - $\text{username} \to \text{player\_id}, \text{email}, \dots$
  - $\text{email} \to \text{player\_id}, \text{username}, \dots$
- **Candidate Keys:** $\{\text{player\_id}\}, \{\text{username}\}, \{\text{email}\}$

#### 4. `team_1nf`
- **Schema:** $(\underline{\text{team\_id}}, \text{org\_id}, \text{name}, \text{game}, \text{status}, \text{captain\_id}, \text{tag}, \text{division}, \text{slots\_max}, \text{winrate}, \text{created\_at})$
- **Functional Dependencies ($FD$):**
  - $\text{team\_id} \to \text{org\_id}, \text{name}, \text{game}, \text{status}, \text{captain\_id}, \text{tag}, \text{division}, \text{slots\_max}, \text{winrate}, \text{created\_at}$
- **Candidate Keys:** $\{\text{team\_id}\}$

#### 5. `application_unsplit_1nf` *(Composite Key Candidate)*
- **Schema:** $(\underline{\text{player\_id}, \text{posting\_id}}, \text{application\_status}, \text{pitch}, \text{vod\_link}, \text{applied\_at}, \text{team\_id}, \text{role\_name}, \text{posting\_status})$
- **Functional Dependencies ($FD$):**
  - $\{\text{player\_id}, \text{posting\_id}\} \to \text{application\_status}, \text{pitch}, \text{vod\_link}, \text{applied\_at}$
  - $\text{posting\_id} \to \text{team\_id}, \text{role\_name}, \text{posting\_status}$ *(Partial Dependency)*

#### 6. `registration_unsplit_1nf` *(Composite Key Candidate)*
- **Schema:** $(\underline{\text{tournament\_id}, \text{team\_id}}, \text{registration\_status}, \text{registered\_at}, \text{tournament\_name}, \text{game}, \text{tournament\_status})$
- **Functional Dependencies ($FD$):**
  - $\{\text{tournament\_id}, \text{team\_id}\} \to \text{registration\_status}, \text{registered\_at}$
  - $\text{tournament\_id} \to \text{tournament\_name}, \text{game}, \text{tournament\_status}$ *(Partial Dependency)*

---

## 4. Second Normal Form (2NF)

### 2NF Criteria:
1. The relation must be in **1NF**.
2. **No partial functional dependencies:** No non-prime attribute may depend on a proper subset of any candidate key. Every non-prime attribute must be fully functionally dependent on the entire primary key.

### Identifying Partial Dependencies:
- In `application_unsplit_1nf`, candidate key is $\{\text{player\_id}, \text{posting\_id}\}$. However, $\text{posting\_id} \to \text{team\_id}, \text{role\_name}, \text{posting\_status}$. The posting attributes depend only on part of the composite primary key.
- In `registration_unsplit_1nf`, candidate key is $\{\text{tournament\_id}, \text{team\_id}\}$. However, $\text{tournament\_id} \to \text{tournament\_name}, \text{game}, \text{tournament\_status}$, violating 2NF.
- In `post_like_unsplit_1nf`, composite key $\{\text{post\_id}, \text{user\_id}\}$ was initially bundled with post author details ($\text{post\_id} \to \text{author\_id}, \text{content}$).

### Decompositions into 2NF:

#### Decomposition of `application`:
1. **`role_posting`**
   - **Schema:** $(\underline{\text{id}}, \text{team\_id}, \text{role}, \text{description}, \text{status}, \text{created\_at})$
   - **FD:** $\text{id} \to \text{team\_id}, \text{role}, \text{description}, \text{status}, \text{created\_at}$
   - **Full Functional Dependency:** All non-prime attributes depend strictly on `id`.
2. **`application`**
   - **Schema:** $(\underline{\text{id}}, \text{player\_id}, \text{posting\_id}, \text{pitch}, \text{vod\_link}, \text{status}, \text{created\_at}, \text{updated\_at})$
   - **Candidate Keys:** $\{\text{id}\}, \{\text{player\_id}, \text{posting\_id}\}$
   - **FDs:** 
     - $\text{id} \to \text{player\_id}, \text{posting\_id}, \text{pitch}, \text{vod\_link}, \text{status}, \text{created\_at}, \text{updated\_at}$
     - $\{\text{player\_id}, \text{posting\_id}\} \to \text{id}, \text{pitch}, \text{vod\_link}, \text{status}, \text{created\_at}, \text{updated\_at}$
   - **Result:** No partial dependencies; fully dependent on candidate keys.

#### Decomposition of `registration`:
1. **`tournament`**
   - **Schema:** $(\underline{\text{id}}, \text{organizer\_id}, \text{name}, \text{game}, \text{start\_date}, \text{status}, \text{created\_at})$
   - **FD:** $\text{id} \to \text{organizer\_id}, \text{name}, \text{game}, \text{start\_date}, \text{status}, \text{created\_at}$
2. **`registration`**
   - **Schema:** $(\underline{\text{id}}, \text{tournament\_id}, \text{team\_id}, \text{status}, \text{registered\_at})$
   - **Candidate Keys:** $\{\text{id}\}, \{\text{tournament\_id}, \text{team\_id}\}$
   - **FD:** $\{\text{tournament\_id}, \text{team\_id}\} \to \text{id}, \text{status}, \text{registered\_at}$
   - **Result:** Fully functionally dependent.

#### Decomposition of `scrim_registration`:
1. **`scrim`**
   - **Schema:** $(\underline{\text{id}}, \text{organizer\_id}, \text{name}, \text{game}, \text{scheduled\_at}, \text{slots\_max}, \text{room\_id}, \text{room\_password}, \text{status}, \text{created\_at})$
   - **FD:** $\text{id} \to \text{organizer\_id}, \text{name}, \text{game}, \text{scheduled\_at}, \text{slots\_max}, \text{room\_id}, \text{room\_password}, \text{status}, \text{created\_at}$
2. **`scrim_registration`**
   - **Schema:** $(\underline{\text{id}}, \text{scrim\_id}, \text{team\_id}, \text{check\_in\_status}, \text{created\_at})$
   - **Candidate Keys:** $\{\text{id}\}, \{\text{scrim\_id}, \text{team\_id}\}$
   - **FD:** $\{\text{scrim\_id}, \text{team\_id}\} \to \text{id}, \text{check\_in\_status}, \text{created\_at}$

---

## 5. Third Normal Form (3NF)

### 3NF Criteria:
1. The relation must be in **2NF**.
2. **No transitive dependencies:** No non-prime attribute is transitively dependent on any candidate key. That is, for every functional dependency $X \to Y$:
   - $X$ is a superkey, **OR**
   - $Y$ is a prime attribute (part of a candidate key).

### Identifying Transitive Dependencies:
- In the initial organization and organizer entities, organization verification legalities and reviews were mixed:
  - $\text{org\_id} \to \text{verification\_status} \to \text{legal\_name}, \text{gst\_number}, \text{reviewed\_by}, \text{review\_notes}$.
  - Here, $\text{verification\_status} \to \{\text{legal\_name}, \text{gst\_number}\}$ is a transitive dependency where neither determinant is a superkey for the entire organization profile.
- In team membership:
  - Storing player in-game names and captain flags directly inside `team` creates:
    $\text{team\_id} \to \text{captain\_id} \to \text{captain\_ign}, \text{captain\_email}$.
  - This is resolved by keeping only $\text{captain\_id}$ as a foreign key referencing `player` or isolating roster members into `team_member`.
- In social interactions:
  - Keeping post comments inside post relations created $\text{post\_id} \to \text{comment\_id} \to \text{author\_name}, \text{comment\_text}$.

### Decompositions into 3NF:

#### 1. Organization Legal Verification (`org_verification`)
Separated from `org` to eliminate transitive dependencies between organization credentials and administrative review metadata:
- **`org`:** $(\underline{\text{id}}, \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at})$
  - $FD$: $\text{id} \to \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at}$
- **`org_verification`:** $(\underline{\text{id}}, \text{org\_id}, \text{legal\_name}, \text{gst\_number}, \text{website}, \text{twitter}, \text{rep\_name}, \text{rep\_email}, \text{documents\_url}, \text{status}, \text{reviewed\_by}, \text{review\_notes}, \text{created\_at}, \text{updated\_at})$
  - $FD$: $\text{id} \to \text{org\_id}, \text{legal\_name}, \text{gst\_number}, \dots$
  - $\text{org\_id} \to \text{id}, \text{legal\_name}, \dots$ *(One-to-one verification profile)*
  - Eliminates transitive dependency on `org`.

#### 2. Organizer Verification (`organizer_verification`)
- **`tournament_organizer`:** $(\underline{\text{id}}, \text{name}, \text{email}, \text{password\_hash}, \text{verified}, \text{created\_at})$
- **`organizer_verification`:** $(\underline{\text{id}}, \text{organizer\_id}, \text{org\_name}, \text{experience\_summary}, \text{website}, \text{twitter}, \text{status}, \text{reviewed\_by}, \text{review\_notes}, \text{created\_at}, \text{updated\_at})$
  - $FD$: $\text{id} \to \text{organizer\_id}, \text{org\_name}, \dots$

#### 3. Team Roster Members (`team_member`)
Decomposed roster slots from `team` and `player` to prevent transitive data corruption when player profile attributes change:
- **`team_member`:** $(\underline{\text{id}}, \text{team\_id}, \text{player\_id}, \text{name}, \text{ign}, \text{role}, \text{is\_captain}, \text{created\_at})$
  - $FD$: $\text{id} \to \text{team\_id}, \text{player\_id}, \text{name}, \text{ign}, \text{role}, \text{is\_captain}, \text{created\_at}$

#### 4. Team Invitations (`team_invitation`)
- **`team_invitation`:** $(\underline{\text{id}}, \text{team\_id}, \text{player\_id}, \text{invited\_by}, \text{role}, \text{message}, \text{status}, \text{created\_at}, \text{updated\_at})$
  - Candidate Keys: $\{\text{id}\}, \{\text{team\_id}, \text{player\_id}\}$
  - $FD$: $\{\text{team\_id}, \text{player\_id}\} \to \text{id}, \text{invited\_by}, \text{role}, \text{message}, \text{status}, \text{created\_at}, \text{updated\_at}$

#### 5. Social Interactions (`post_comment`, `post_like`, `follow`, `player_connection`)
- **`post`:** $(\underline{\text{id}}, \text{author\_type}, \text{author\_id}, \text{content}, \text{category}, \text{game}, \text{likes\_count}, \text{created\_at})$
- **`post_comment`:** $(\underline{\text{id}}, \text{post\_id}, \text{author\_id}, \text{author\_name}, \text{content}, \text{created\_at})$
- **`post_like`:** $(\underline{\text{id}}, \text{post\_id}, \text{user\_id}, \text{created\_at})$
  - Candidate Keys: $\{\text{id}\}, \{\text{post\_id}, \text{user\_id}\}$
- **`follow`:** $(\underline{\text{id}}, \text{player\_id}, \text{target\_type}, \text{target\_id}, \text{created\_at})$
  - Candidate Keys: $\{\text{id}\}, \{\text{player\_id}, \text{target\_type}, \text{target\_id}\}$
- **`player_connection`:** $(\underline{\text{id}}, \text{requester\_id}, \text{receiver\_id}, \text{status}, \text{created\_at})$
  - Candidate Keys: $\{\text{id}\}, \{\text{requester\_id}, \text{receiver\_id}\}$

#### 6. Tactical Comms & Direct Messaging
- **`message` (1-on-1 Direct Chat):** $(\underline{\text{id}}, \text{sender\_id}, \text{receiver\_id}, \text{content}, \text{read}, \text{created\_at})$
  - $FD$: $\text{id} \to \text{sender\_id}, \text{receiver\_id}, \text{content}, \text{read}, \text{created\_at}$
- **`team_message` (Squad Tactical Comms):** $(\underline{\text{id}}, \text{team\_id}, \text{sender\_id}, \text{sender\_role}, \text{sender\_name}, \text{content}, \text{created\_at})$
  - $FD$: $\text{id} \to \text{team\_id}, \text{sender\_id}, \text{sender\_role}, \text{sender\_name}, \text{content}, \text{created\_at}$

---

## 6. Boyce-Codd Normal Form (BCNF) Evaluation

### BCNF Definition:
A relation $R$ is in **BCNF** if and only if, for every non-trivial functional dependency $X \to Y$, the determinant $X$ is a **superkey** of $R$.

### Evaluation of Relations:

| Table | Candidate Keys | Non-trivial FDs ($X \to Y$) | Is $X$ a Superkey? | In BCNF? |
|---|---|---|---|:---:|
| `org` | $\{\text{id}\}, \{\text{name}\}, \{\text{email}\}$ | $\text{id} \to \text{All}$<br>$\text{name} \to \text{All}$<br>$\text{email} \to \text{All}$ | Yes (All determinants are candidate keys) | **YES** |
| `tournament_organizer` | $\{\text{id}\}, \{\text{email}\}$ | $\text{id} \to \text{All}$<br>$\text{email} \to \text{All}$ | Yes | **YES** |
| `player` | $\{\text{id}\}, \{\text{username}\}, \{\text{email}\}$ | $\text{id} \to \text{All}$<br>$\text{username} \to \text{All}$<br>$\text{email} \to \text{All}$ | Yes | **YES** |
| `team` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `role_posting` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `application` | $\{\text{id}\}, \{\text{player\_id}, \text{posting\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{player\_id}, \text{posting\_id}\} \to \text{All}$ | Yes (Both determinants are candidate keys) | **YES** |
| `tournament` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `registration` | $\{\text{id}\}, \{\text{tournament\_id}, \text{team\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{tournament\_id}, \text{team\_id}\} \to \text{All}$ | Yes | **YES** |
| `scrim` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `scrim_registration` | $\{\text{id}\}, \{\text{scrim\_id}, \text{team\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{scrim\_id}, \text{team\_id}\} \to \text{All}$ | Yes | **YES** |
| `post` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `post_like` | $\{\text{id}\}, \{\text{post\_id}, \text{user\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{post\_id}, \text{user\_id}\} \to \text{All}$ | Yes | **YES** |
| `post_comment` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `follow` | $\{\text{id}\}, \{\text{player\_id}, \text{target\_type}, \text{target\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{player\_id}, \text{target\_type}, \text{target\_id}\} \to \text{All}$ | Yes | **YES** |
| `player_connection` | $\{\text{id}\}, \{\text{requester\_id}, \text{receiver\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{requester\_id}, \text{receiver\_id}\} \to \text{All}$ | Yes | **YES** |
| `team_invitation` | $\{\text{id}\}, \{\text{team\_id}, \text{player\_id}\}$ | $\text{id} \to \text{All}$<br>$\{\text{team\_id}, \text{player\_id}\} \to \text{All}$ | Yes | **YES** |
| `message` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |
| `team_message` | $\{\text{id}\}$ | $\text{id} \to \text{All}$ | Yes | **YES** |

### Conclusion on BCNF:
Every non-trivial functional dependency has a determinant that is a **superkey** (either the surrogate UUID or the alternate natural candidate key guarded by a `UNIQUE` constraint). Consequently, the entire relational schema satisfies **Boyce-Codd Normal Form (BCNF)** without loss of functional dependencies or information.

---

## 7. Master Data Dictionary & Integrity Constraints

Below is the definitive catalog of normalized tables implemented in PostgreSQL:

| Table Name | Primary Key | Alternate / Unique Keys | Foreign Keys | Normal Form |
|---|---|---|---|:---:|
| `org` | `id` | `name`, `email` | — | BCNF |
| `org_verification` | `id` | — | `org_id` $\to$ `org(id)`, `reviewed_by` $\to$ `admin(id)` | BCNF |
| `tournament_organizer` | `id` | `email` | — | BCNF |
| `organizer_verification` | `id` | — | `organizer_id` $\to$ `tournament_organizer(id)`, `reviewed_by` $\to$ `admin(id)` | BCNF |
| `admin` | `id` | `email` | — | BCNF |
| `player` | `id` | `username`, `email` | `team_id` $\to$ `team(id)`, `org_id` $\to$ `org(id)` | BCNF |
| `player_connection` | `id` | `(requester_id, receiver_id)` | `requester_id` $\to$ `player(id)`, `receiver_id` $\to$ `player(id)` | BCNF |
| `team` | `id` | — | `org_id` $\to$ `org(id)`, `captain_id` $\to$ `player(id)` | BCNF |
| `team_member` | `id` | — | `team_id` $\to$ `team(id)`, `player_id` $\to$ `player(id)` | BCNF |
| `team_invitation` | `id` | `(team_id, player_id)` | `team_id` $\to$ `team(id)`, `player_id` $\to$ `player(id)`, `invited_by` $\to$ `player(id)` | BCNF |
| `role_posting` | `id` | — | `team_id` $\to$ `team(id)` | BCNF |
| `application` | `id` | `(player_id, posting_id)` | `player_id` $\to$ `player(id)`, `posting_id` $\to$ `role_posting(id)` | BCNF |
| `tournament` | `id` | — | `organizer_id` $\to$ `tournament_organizer(id)` | BCNF |
| `registration` | `id` | `(tournament_id, team_id)` | `tournament_id` $\to$ `tournament(id)`, `team_id` $\to$ `team(id)` | BCNF |
| `scrim` | `id` | — | `organizer_id` $\to$ `tournament_organizer(id)` | BCNF |
| `scrim_registration` | `id` | `(scrim_id, team_id)` | `scrim_id` $\to$ `scrim(id)`, `team_id` $\to$ `team(id)` | BCNF |
| `post` | `id` | — | — *(Polymorphic: author_id references player/org/team/organizer)* | BCNF |
| `post_like` | `id` | `(post_id, user_id)` | `post_id` $\to$ `post(id)` | BCNF |
| `post_comment` | `id` | — | `post_id` $\to$ `post(id)` | BCNF |
| `follow` | `id` | `(player_id, target_type, target_id)` | `player_id` $\to$ `player(id)` | BCNF |
| `message` | `id` | — | `sender_id` $\to$ `player(id)`, `receiver_id` $\to$ `player(id)` | BCNF |
| `team_message` | `id` | — | `team_id` $\to$ `team(id)` | BCNF |
