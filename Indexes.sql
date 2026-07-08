-- ════════════════════════════════════════════════════════════════
-- UNIFIED VEHICLE REGISTRY – INDEXES
-- ════════════════════════════════════════════════════════════════
-- Run this file AFTER DDL.sql (schema must exist).
--
-- PostgreSQL does NOT automatically index foreign key columns
-- (unlike MySQL/InnoDB). Without these indexes, every JOIN or
-- ON DELETE CASCADE check triggers a sequential scan on the
-- child table. This file creates:
--
--   §1  FK Indexes          – one B-tree per FK column
--   §2  Composite Indexes   – multi-column indexes for common
--                              query patterns (range scans, sorts)
--   §3  Partial Indexes     – filtered indexes for hot subsets
--                              (active ownerships, unpaid challans…)
--
-- All statements use CREATE INDEX IF NOT EXISTS so re-runs are
-- safe and idempotent.
-- ════════════════════════════════════════════════════════════════


-- ████████████████████████████████████████████████████████████████
-- §0 : DROP ALL INDEXES (clean slate)
-- ████████████████████████████████████████████████████████████████
-- Drop in reverse dependency order. IF EXISTS prevents errors
-- when running on a fresh database.

DROP INDEX IF EXISTS
    -- Partial indexes (§3)
    idx_ownership_active,
    idx_challan_unpaid,
    idx_vehicle_log_active,
    idx_license_active,

    -- Composite indexes (§2)
    idx_insurance_vehicle_expiry,
    idx_puc_vehicle_valid,
    idx_challan_vehicle_paid,
    idx_ownership_vehicle_todate,
    idx_wallet_txn_from_datetime,
    idx_wallet_txn_to_datetime,

    -- FK indexes (§1)
    idx_ownership_vehicle_id,
    idx_ownership_owner_id,
    idx_insurance_vehicle_id,
    idx_puc_vehicle_id,
    idx_license_user_id,
    idx_license_issuing_rto,
    idx_permit_vehicle_id,
    idx_permit_issuing_rto,
    idx_vehicle_log_vehicle_id,
    idx_challan_vehicle_id,
    idx_challan_officer_id,
    idx_officer_rto_code,
    idx_wallet_txn_from_wallet,
    idx_wallet_txn_to_wallet;


-- ████████████████████████████████████████████████████████████████
-- §1 : FOREIGN KEY INDEXES
-- ████████████████████████████████████████████████████████████████
-- PostgreSQL uses FK definitions only for constraint enforcement,
-- not for query planning. Without explicit indexes, JOINs on FK
-- columns fall back to sequential scans.
--
-- NOTE: Columns that are already covered by UNIQUE or PK
-- constraints are skipped (rc_book.vehicle_id, e_wallet.user_id,
-- permit_route.permit_id).


-- ──────────────────────────────────────────────────────────────
-- ownership(vehicle_id)
-- Speeds up: Q1 current owner lookup, Q2 all-vehicle owner list,
--            Q6 ownership count, Q15 ownership history, Q27 profile card,
--            any ON DELETE CASCADE check from vehicle table.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ownership_vehicle_id
    ON ownership (vehicle_id);

-- ──────────────────────────────────────────────────────────────
-- ownership(owner_id)
-- Speeds up: Q7 user vehicle count, Q24 multi-vehicle owners,
--            Q28 user profile card.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ownership_owner_id
    ON ownership (owner_id);

-- ──────────────────────────────────────────────────────────────
-- insurance(vehicle_id)
-- Speeds up: Q3 active insurance check, Q5A/Q5B insurance list,
--            Q9 compliance report, Q10 non-compliant vehicles,
--            Q19 expiring-soon, Q27 vehicle profile card.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_insurance_vehicle_id
    ON insurance (vehicle_id);

-- ──────────────────────────────────────────────────────────────
-- puc(vehicle_id)
-- Speeds up: Q4 active PUC check, Q9 compliance report,
--            Q10 non-compliant vehicles, Q20 expiring-soon,
--            Q27 vehicle profile card.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_puc_vehicle_id
    ON puc (vehicle_id);

-- ──────────────────────────────────────────────────────────────
-- license(user_id)
-- Speeds up: Q13 expired/suspended licenses, Q28 user profile card,
--            any user → license joins.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_license_user_id
    ON license (user_id);

-- ──────────────────────────────────────────────────────────────
-- license(issuing_rto_id)
-- Speeds up: Q12 RTO-wise license count, any RTO → license joins.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_license_issuing_rto
    ON license (issuing_rto_id);

-- ──────────────────────────────────────────────────────────────
-- permit(vehicle_id)
-- Speeds up: Q9 compliance (active permit check), Q30 expiring permits,
--            any vehicle → permit joins.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_permit_vehicle_id
    ON permit (vehicle_id);

-- ──────────────────────────────────────────────────────────────
-- permit(issuing_rto_id)
-- Speeds up: Q12 RTO-wise permit count, any RTO → permit joins.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_permit_issuing_rto
    ON permit (issuing_rto_id);

-- ──────────────────────────────────────────────────────────────
-- vehicle_log(vehicle_id)
-- Speeds up: Q16 abnormal vehicle status, Q27 vehicle profile card
--            (current condition subquery), v_vehicle_condition view.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_vehicle_log_vehicle_id
    ON vehicle_log (vehicle_id);

-- ──────────────────────────────────────────────────────────────
-- challan(vehicle_id)
-- Speeds up: Q8 vehicle dashboard (challan summary), Q17 top challans,
--            Q26 wallet-paid challans, any vehicle → challan joins.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_challan_vehicle_id
    ON challan (vehicle_id);

-- ──────────────────────────────────────────────────────────────
-- challan(issuing_officer_id)
-- Speeds up: Q11 officer-wise challan report, Q31 state-wise
--            revenue (officer → rto join path).
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_challan_officer_id
    ON challan (issuing_officer_id);

-- ──────────────────────────────────────────────────────────────
-- officer(rto_code)
-- Speeds up: Q11 officer → rto join, Q31 state-wise revenue,
--            any rto → officer lookups.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_officer_rto_code
    ON officer (rto_code);

-- ──────────────────────────────────────────────────────────────
-- wallet_transaction(from_wallet_id)
-- Speeds up: Q14 wallet transaction summary (debit side),
--            Q25 user transaction history, Q26 challan payments.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wallet_txn_from_wallet
    ON wallet_transaction (from_wallet_id);

-- ──────────────────────────────────────────────────────────────
-- wallet_transaction(to_wallet_id)
-- Speeds up: Q14 wallet transaction summary (credit side),
--            Q25 user transaction history.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wallet_txn_to_wallet
    ON wallet_transaction (to_wallet_id);


-- ████████████████████████████████████████████████████████████████
-- §2 : COMPOSITE INDEXES
-- ████████████████████████████████████████████████████████████████
-- Multi-column indexes that support common query patterns
-- involving range scans, ORDER BY, and DISTINCT ON operations.
-- These provide index-only scans for the most frequent access
-- patterns, avoiding heap fetches entirely.


-- ──────────────────────────────────────────────────────────────
-- insurance(vehicle_id, expiry_date DESC)
-- Supports DISTINCT ON (vehicle_id) ORDER BY vehicle_id,
-- expiry_date DESC — used in Q10, Q27 to find the latest
-- insurance per vehicle in a single index-only pass.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_insurance_vehicle_expiry
    ON insurance (vehicle_id, expiry_date DESC);

-- ──────────────────────────────────────────────────────────────
-- puc(vehicle_id, valid_until DESC)
-- Supports DISTINCT ON (vehicle_id) ORDER BY vehicle_id,
-- valid_until DESC — used in Q10, Q27 to find the latest
-- PUC certificate per vehicle in a single index-only pass.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_puc_vehicle_valid
    ON puc (vehicle_id, valid_until DESC);

-- ──────────────────────────────────────────────────────────────
-- challan(vehicle_id, is_paid)
-- Supports Q8 vehicle dashboard where we GROUP BY vehicle_id
-- and FILTER (WHERE is_paid = FALSE). Also helps Q17
-- (top challan vehicles) with the paid/unpaid breakdown.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_challan_vehicle_paid
    ON challan (vehicle_id, is_paid);

-- ──────────────────────────────────────────────────────────────
-- ownership(vehicle_id, to_date)
-- Supports Q1/Q2 current-owner lookups (WHERE to_date IS NULL),
-- Q15 ownership timeline, Q33 vehicles with no current owner.
-- The to_date column lets Postgres skip non-matching rows
-- without touching the heap.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ownership_vehicle_todate
    ON ownership (vehicle_id, to_date);

-- ──────────────────────────────────────────────────────────────
-- wallet_transaction(from_wallet_id, tran_datetime DESC)
-- Supports Q25 user transaction history ordered by time,
-- recent-transaction lookups, and time-range queries on
-- a user's outgoing transactions.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wallet_txn_from_datetime
    ON wallet_transaction (from_wallet_id, tran_datetime DESC);

-- ──────────────────────────────────────────────────────────────
-- wallet_transaction(to_wallet_id, tran_datetime DESC)
-- Supports Q25 user transaction history for incoming
-- transactions, ordered by time.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wallet_txn_to_datetime
    ON wallet_transaction (to_wallet_id, tran_datetime DESC);


-- ████████████████████████████████████████████████████████████████
-- §3 : PARTIAL INDEXES
-- ████████████████████████████████████████████████████████████████
-- Partial (filtered) indexes only store rows matching a WHERE
-- predicate. They are dramatically smaller than full indexes and
-- provide faster lookups for queries that always include the
-- same filter condition.


-- ──────────────────────────────────────────────────────────────
-- ownership WHERE to_date IS NULL  (active / current ownerships)
-- This partial index stores only the rows representing the
-- CURRENT owner of each vehicle. Since the vast majority of
-- ownership rows are historical (to_date IS NOT NULL), this
-- index is much smaller than a full index.
-- Benefits: Q1, Q2, Q8, Q16, Q19, Q20, Q24, Q27, Q33 —
--           any query with WHERE o.to_date IS NULL.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ownership_active
    ON ownership (vehicle_id, owner_id)
    WHERE to_date IS NULL;

-- ──────────────────────────────────────────────────────────────
-- challan WHERE is_paid = FALSE  (unpaid challans)
-- Stores only unpaid challans. As challans get paid over time,
-- this index naturally shrinks, keeping queries like "show all
-- unpaid challans" extremely fast.
-- Benefits: Q8 outstanding amount, Q17 unpaid fine filter,
--           Q29 unpaid count, any unpaid-challan dashboard.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_challan_unpaid
    ON challan (vehicle_id, amount)
    WHERE is_paid = FALSE;

-- ──────────────────────────────────────────────────────────────
-- vehicle_log WHERE end_date IS NULL  (active vehicle statuses)
-- Only stores rows for vehicles currently in an abnormal state
-- (Seized, Stolen, Lost, Under_Repair, Scrapped). This is
-- typically a tiny fraction of all log entries.
-- Benefits: Q16 abnormal vehicles, Q27 current_condition
--           subquery, v_vehicle_condition view.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_vehicle_log_active
    ON vehicle_log (vehicle_id, vehicle_status)
    WHERE end_date IS NULL;

-- ──────────────────────────────────────────────────────────────
-- license WHERE status = 'Active'  (active licenses)
-- Only stores currently active licenses. Useful for quickly
-- answering "does this user have a valid license?" without
-- scanning expired/revoked/suspended rows.
-- Benefits: Q13 (inverse – finding non-active is faster when
--           active set is known), Q28 user profile card,
--           v_license_status view, license verification checks.
-- ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_license_active
    ON license (user_id, license_type)
    WHERE status = 'Active';


-- ════════════════════════════════════════════════════════════════
-- END OF INDEXES
-- ════════════════════════════════════════════════════════════════
-- Total indexes created:  14 FK  +  6 Composite  +  4 Partial = 24
--
-- To verify all indexes:
--   SELECT indexname, indexdef
--   FROM pg_indexes
--   WHERE schemaname = 'public'
--   ORDER BY tablename, indexname;
-- ════════════════════════════════════════════════════════════════
