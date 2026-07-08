-- ════════════════════════════════════════════════════════════════
-- UNIFIED VEHICLE REGISTRY – MATERIALIZED VIEWS
-- ════════════════════════════════════════════════════════════════
-- Run this file AFTER DDL.sql, Insert_data.sql, and Indexes.sql.
--
-- Materialized views pre-compute expensive aggregation queries
-- and store the result as a physical table. Reads become instant;
-- the trade-off is that data must be refreshed periodically.
--
-- Each MV below includes:
--   • DROP MATERIALIZED VIEW IF EXISTS  — safe re-runs
--   • CREATE MATERIALIZED VIEW          — the pre-computed query
--   • CREATE UNIQUE INDEX               — required for
--       REFRESH MATERIALIZED VIEW … CONCURRENTLY (allows reads
--       during refresh without locking)
--   • COMMENT ON                        — documents purpose
--
-- §5 at the end contains REFRESH commands and scheduling notes.
-- ════════════════════════════════════════════════════════════════


-- ████████████████████████████████████████████████████████████████
-- §1 : mv_vehicle_compliance_summary
--      Pre-computed compliance status for every vehicle.
--      Replaces Q9 (Vehicle Compliance Report).
-- ████████████████████████████████████████████████████████████████

DROP MATERIALIZED VIEW IF EXISTS mv_vehicle_compliance_summary CASCADE;

-- ──────────────────────────────────────────────────────────────
-- What it pre-computes:
--   For each vehicle: whether it has an active insurance policy,
--   an active PUC certificate, an active permit, and who the
--   current owner is. Without this MV, Q9 runs three correlated
--   EXISTS subqueries per vehicle row — O(n × m) in the worst
--   case. The MV reduces this to a single sequential scan of
--   pre-computed booleans.
-- ──────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_vehicle_compliance_summary AS
SELECT
    v.vehicle_id,
    v.model_name,
    v.registration_type,
    v.fuel_type,
    -- Current owner (from active ownership)
    owner_info.owner_id,
    owner_info.owner_name,
    -- Insurance compliance
    EXISTS (
        SELECT 1 FROM insurance i
        WHERE i.vehicle_id = v.vehicle_id
          AND i.expiry_date >= CURRENT_DATE
    ) AS has_active_insurance,
    -- PUC compliance
    EXISTS (
        SELECT 1 FROM puc p
        WHERE p.vehicle_id = v.vehicle_id
          AND p.valid_until >= CURRENT_DATE
    ) AS has_active_puc,
    -- Permit compliance
    EXISTS (
        SELECT 1 FROM permit pm
        WHERE pm.vehicle_id = v.vehicle_id
          AND pm.expiry_date >= CURRENT_DATE
    ) AS has_active_permit,
    -- Overall compliance flag (all three must be active)
    (
        EXISTS (SELECT 1 FROM insurance i WHERE i.vehicle_id = v.vehicle_id AND i.expiry_date >= CURRENT_DATE)
        AND
        EXISTS (SELECT 1 FROM puc p WHERE p.vehicle_id = v.vehicle_id AND p.valid_until >= CURRENT_DATE)
        AND
        EXISTS (SELECT 1 FROM permit pm WHERE pm.vehicle_id = v.vehicle_id AND pm.expiry_date >= CURRENT_DATE)
    ) AS is_fully_compliant,
    -- Snapshot timestamp
    CURRENT_TIMESTAMP AS refreshed_at
FROM vehicle v
LEFT JOIN (
    SELECT
        o.vehicle_id,
        o.owner_id,
        u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name
    FROM ownership o
    JOIN users u ON o.owner_id = u.user_id
    WHERE o.to_date IS NULL
) owner_info ON v.vehicle_id = owner_info.vehicle_id
WITH DATA;

-- Unique index required for REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_compliance_vehicle
    ON mv_vehicle_compliance_summary (vehicle_id);

COMMENT ON MATERIALIZED VIEW mv_vehicle_compliance_summary IS
    'Pre-computed vehicle compliance status (insurance, PUC, permit) '
    'with current owner. Replaces Q9 and parts of Q10. '
    'Refresh daily or after bulk insurance/PUC/permit updates.';


-- ████████████████████████████████████████████████████████████████
-- §2 : mv_challan_revenue_by_state
--      State-wise challan revenue with collected/pending breakdown.
--      Replaces Q31 (State-wise Challan Revenue Report).
-- ████████████████████████████████████████████████████████████████

DROP MATERIALIZED VIEW IF EXISTS mv_challan_revenue_by_state CASCADE;

-- ──────────────────────────────────────────────────────────────
-- What it pre-computes:
--   For each state: total challans, total revenue, collected
--   (paid) revenue, pending (unpaid) revenue, and collection
--   rate percentage. The base query requires a 3-table join
--   (challan → officer → rto) plus aggregation with FILTER
--   clauses. The MV eliminates this overhead for dashboards.
-- ──────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_challan_revenue_by_state AS
SELECT
    r.state,
    COUNT(c.challan_id)                                          AS total_challans,
    SUM(c.amount)                                                AS total_revenue,
    COALESCE(SUM(c.amount) FILTER (WHERE c.is_paid = TRUE), 0)  AS collected_revenue,
    COALESCE(SUM(c.amount) FILTER (WHERE c.is_paid = FALSE), 0) AS pending_revenue,
    ROUND(
        100.0 * COALESCE(SUM(c.amount) FILTER (WHERE c.is_paid = TRUE), 0)
        / NULLIF(SUM(c.amount), 0),
        2
    ) AS collection_rate_pct,
    COUNT(c.challan_id) FILTER (WHERE c.is_paid = TRUE)  AS paid_challans,
    COUNT(c.challan_id) FILTER (WHERE c.is_paid = FALSE) AS unpaid_challans,
    CURRENT_TIMESTAMP AS refreshed_at
FROM challan c
JOIN officer o ON c.issuing_officer_id = o.officer_id
JOIN rto r     ON o.rto_code = r.rto_code
GROUP BY r.state
WITH DATA;

-- Unique index required for REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_challan_revenue_state
    ON mv_challan_revenue_by_state (state);

COMMENT ON MATERIALIZED VIEW mv_challan_revenue_by_state IS
    'State-wise challan revenue with collected/pending breakdown. '
    'Replaces Q31. Refresh after challan payments or new challans.';


-- ████████████████████████████████████████████████████████████████
-- §3 : mv_insurance_market_share
--      Insurance company market share with policy count, total
--      coverage, avg premium, and total claims.
--      Replaces Q32 (Insurance Company Market Share).
-- ████████████████████████████████████████████████████████████████

DROP MATERIALIZED VIEW IF EXISTS mv_insurance_market_share CASCADE;

-- ──────────────────────────────────────────────────────────────
-- What it pre-computes:
--   For each insurance company: number of policies, market share
--   percentage, total coverage, average premium, and total claims.
--   The base query includes a scalar subquery (SELECT COUNT(*)
--   FROM insurance) to compute percentages — this runs once per
--   refresh instead of once per query execution.
-- ──────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_insurance_market_share AS
SELECT
    insurance_company,
    COUNT(*)                                                      AS policies_issued,
    ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM insurance), 0), 2)
                                                                  AS market_share_pct,
    SUM(coverage_amount)                                          AS total_coverage,
    ROUND(AVG(premium_amount), 2)                                 AS avg_premium,
    SUM(number_of_claims)                                         AS total_claims,
    MIN(issue_date)                                               AS earliest_policy,
    MAX(issue_date)                                               AS latest_policy,
    CURRENT_TIMESTAMP AS refreshed_at
FROM insurance
GROUP BY insurance_company
WITH DATA;

-- Unique index required for REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_insurance_market_company
    ON mv_insurance_market_share (insurance_company);

COMMENT ON MATERIALIZED VIEW mv_insurance_market_share IS
    'Insurance company market share with policy count, total coverage, '
    'avg premium, and total claims. Replaces Q32. '
    'Refresh after new insurance policies are recorded.';


-- ████████████████████████████████████████████████████████████████
-- §4 : mv_vehicle_dashboard
--      Pre-computed vehicle dashboard with current owner,
--      challan summary, and compliance status.
--      Replaces Q8 (Vehicle Dashboard).
-- ████████████████████████████████████████████████████████████████

DROP MATERIALIZED VIEW IF EXISTS mv_vehicle_dashboard CASCADE;

-- ──────────────────────────────────────────────────────────────
-- What it pre-computes:
--   For each vehicle: model name, current owner, total challans,
--   unpaid challans, total fine amount, outstanding fine amount,
--   and compliance flags (insurance, PUC, permit active).
--   The base query (Q8) joins vehicle with two subqueries
--   (ownership + challan aggregation). This MV adds compliance
--   data on top, giving a single-row-per-vehicle dashboard.
-- ──────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_vehicle_dashboard AS
SELECT
    v.vehicle_id,
    v.model_name,
    v.manufacturer,
    v.fuel_type,
    v.registration_type,
    -- Current owner
    COALESCE(
        owner_info.owner_name,
        'No Current Owner'
    ) AS current_owner_name,
    owner_info.owner_id AS current_owner_id,
    -- Challan summary
    COALESCE(ch.total_challans, 0)       AS total_challans,
    COALESCE(ch.unpaid_challans, 0)      AS unpaid_challans,
    COALESCE(ch.total_amount, 0)         AS total_fine_amount,
    COALESCE(ch.outstanding_amount, 0)   AS outstanding_amount,
    -- Compliance flags
    EXISTS (
        SELECT 1 FROM insurance i
        WHERE i.vehicle_id = v.vehicle_id AND i.expiry_date >= CURRENT_DATE
    ) AS has_active_insurance,
    EXISTS (
        SELECT 1 FROM puc p
        WHERE p.vehicle_id = v.vehicle_id AND p.valid_until >= CURRENT_DATE
    ) AS has_active_puc,
    EXISTS (
        SELECT 1 FROM permit pm
        WHERE pm.vehicle_id = v.vehicle_id AND pm.expiry_date >= CURRENT_DATE
    ) AS has_active_permit,
    -- Vehicle condition
    COALESCE(
        (SELECT vl.vehicle_status
         FROM vehicle_log vl
         WHERE vl.vehicle_id = v.vehicle_id AND vl.end_date IS NULL
         ORDER BY vl.start_date DESC LIMIT 1),
        'Normal'
    ) AS current_condition,
    -- Snapshot timestamp
    CURRENT_TIMESTAMP AS refreshed_at
FROM vehicle v
-- Current owner subquery
LEFT JOIN (
    SELECT
        o.vehicle_id,
        o.owner_id,
        u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name
    FROM ownership o
    JOIN users u ON o.owner_id = u.user_id
    WHERE o.to_date IS NULL
) owner_info ON v.vehicle_id = owner_info.vehicle_id
-- Challan aggregation subquery
LEFT JOIN (
    SELECT
        vehicle_id,
        COUNT(*)                                     AS total_challans,
        COUNT(*) FILTER (WHERE is_paid = FALSE)      AS unpaid_challans,
        SUM(amount)                                  AS total_amount,
        SUM(amount) FILTER (WHERE is_paid = FALSE)   AS outstanding_amount
    FROM challan
    GROUP BY vehicle_id
) ch ON v.vehicle_id = ch.vehicle_id
WITH DATA;

-- Unique index required for REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_dashboard_vehicle
    ON mv_vehicle_dashboard (vehicle_id);

COMMENT ON MATERIALIZED VIEW mv_vehicle_dashboard IS
    'Pre-computed vehicle dashboard with current owner, challan summary, '
    'compliance flags, and vehicle condition. Replaces Q8. '
    'Refresh after ownership changes, new challans, or compliance updates.';


-- ████████████████████████████████████████████████████████████████
-- §5 : mv_rto_statistics
--      RTO-wise statistics: vehicles with permits, licenses
--      issued, challans in jurisdiction, and total revenue.
-- ████████████████████████████████████████████████████████████████

DROP MATERIALIZED VIEW IF EXISTS mv_rto_statistics CASCADE;

-- ──────────────────────────────────────────────────────────────
-- What it pre-computes:
--   For each RTO: name, location, count of vehicles with permits,
--   licenses issued, challans issued by officers in that RTO,
--   total challan revenue, and collection rate. This combines
--   data from Q12 (RTO-wise registrations) with challan revenue
--   data, requiring joins across permit, license, officer, and
--   challan tables — expensive when run ad hoc.
-- ──────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_rto_statistics AS
SELECT
    r.rto_code,
    r.rto_name,
    r.city,
    r.district,
    r.state,
    -- Permit statistics
    COALESCE(pm.vehicles_with_permits, 0)   AS vehicles_with_permits,
    COALESCE(pm.total_permits, 0)           AS total_permits,
    COALESCE(pm.active_permits, 0)          AS active_permits,
    -- License statistics
    COALESCE(lc.licenses_issued, 0)         AS licenses_issued,
    COALESCE(lc.active_licenses, 0)         AS active_licenses,
    -- Challan statistics (via officers assigned to this RTO)
    COALESCE(ch.total_challans, 0)          AS total_challans,
    COALESCE(ch.total_revenue, 0)           AS total_revenue,
    COALESCE(ch.collected_revenue, 0)       AS collected_revenue,
    COALESCE(ch.pending_revenue, 0)         AS pending_revenue,
    COALESCE(ch.collection_rate_pct, 0)     AS collection_rate_pct,
    -- Officer count
    COALESCE(ofc.officer_count, 0)          AS officer_count,
    -- Snapshot timestamp
    CURRENT_TIMESTAMP AS refreshed_at
FROM rto r
-- Permit statistics per RTO
LEFT JOIN (
    SELECT
        issuing_rto_id,
        COUNT(DISTINCT vehicle_id) AS vehicles_with_permits,
        COUNT(*)                   AS total_permits,
        COUNT(*) FILTER (WHERE expiry_date >= CURRENT_DATE) AS active_permits
    FROM permit
    GROUP BY issuing_rto_id
) pm ON r.rto_code = pm.issuing_rto_id
-- License statistics per RTO
LEFT JOIN (
    SELECT
        issuing_rto_id,
        COUNT(*)                                            AS licenses_issued,
        COUNT(*) FILTER (WHERE status = 'Active'
                         AND expiry_date >= CURRENT_DATE)   AS active_licenses
    FROM license
    GROUP BY issuing_rto_id
) lc ON r.rto_code = lc.issuing_rto_id
-- Challan statistics per RTO (via officers)
LEFT JOIN (
    SELECT
        o.rto_code,
        COUNT(c.challan_id)                                          AS total_challans,
        COALESCE(SUM(c.amount), 0)                                   AS total_revenue,
        COALESCE(SUM(c.amount) FILTER (WHERE c.is_paid = TRUE), 0)   AS collected_revenue,
        COALESCE(SUM(c.amount) FILTER (WHERE c.is_paid = FALSE), 0)  AS pending_revenue,
        ROUND(
            100.0 * COALESCE(SUM(c.amount) FILTER (WHERE c.is_paid = TRUE), 0)
            / NULLIF(SUM(c.amount), 0),
            2
        ) AS collection_rate_pct
    FROM officer o
    LEFT JOIN challan c ON o.officer_id = c.issuing_officer_id
    GROUP BY o.rto_code
) ch ON r.rto_code = ch.rto_code
-- Officer count per RTO
LEFT JOIN (
    SELECT rto_code, COUNT(*) AS officer_count
    FROM officer
    GROUP BY rto_code
) ofc ON r.rto_code = ofc.rto_code
WITH DATA;

-- Unique index required for REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uidx_mv_rto_stats_code
    ON mv_rto_statistics (rto_code);

COMMENT ON MATERIALIZED VIEW mv_rto_statistics IS
    'RTO-wise statistics: permits, licenses, challans, revenue, and '
    'officer count. Combines Q12 with challan revenue data. '
    'Refresh after permit/license issuance or challan updates.';


-- ████████████████████████████████████████████████████████████████
-- §6 : REFRESH COMMANDS & SCHEDULING NOTES
-- ████████████████████████████████████████████████████████████████

-- ──────────────────────────────────────────────────────────────
-- Manual refresh (use CONCURRENTLY to avoid locking reads):
-- ──────────────────────────────────────────────────────────────
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_compliance_summary;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_challan_revenue_by_state;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_insurance_market_share;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_dashboard;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rto_statistics;

-- ──────────────────────────────────────────────────────────────
-- Refresh all MVs in one transaction:
-- ──────────────────────────────────────────────────────────────
-- BEGIN;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_compliance_summary;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_challan_revenue_by_state;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_insurance_market_share;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_dashboard;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rto_statistics;
-- COMMIT;

-- ──────────────────────────────────────────────────────────────
-- SCHEDULING NOTES:
-- ──────────────────────────────────────────────────────────────
-- Option A — pg_cron (PostgreSQL extension):
--   SELECT cron.schedule(
--       'refresh_mvs_daily',
--       '0 2 * * *',    -- Every day at 2:00 AM
--       $$
--         REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_compliance_summary;
--         REFRESH MATERIALIZED VIEW CONCURRENTLY mv_challan_revenue_by_state;
--         REFRESH MATERIALIZED VIEW CONCURRENTLY mv_insurance_market_share;
--         REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_dashboard;
--         REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rto_statistics;
--       $$
--   );
--
-- Option B — OS-level cron (Linux/macOS):
--   Add to crontab (crontab -e):
--   0 2 * * * psql -U your_user -d your_db -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_compliance_summary; REFRESH MATERIALIZED VIEW CONCURRENTLY mv_challan_revenue_by_state; REFRESH MATERIALIZED VIEW CONCURRENTLY mv_insurance_market_share; REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_dashboard; REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rto_statistics;"
--
-- Option C — Application-level trigger:
--   Call REFRESH after bulk INSERT/UPDATE operations on source
--   tables (e.g., after an insurance batch upload or challan
--   payment processing run).
--
-- CONCURRENTLY requires a UNIQUE INDEX on the MV (created above
-- for each view). It allows SELECT queries to continue reading
-- the old snapshot while the refresh builds the new one.
-- ──────────────────────────────────────────────────────────────


-- ════════════════════════════════════════════════════════════════
-- END OF MATERIALIZED VIEWS
-- ════════════════════════════════════════════════════════════════
-- Summary of materialized views:
--   1. mv_vehicle_compliance_summary  — replaces Q9
--   2. mv_challan_revenue_by_state    — replaces Q31
--   3. mv_insurance_market_share      — replaces Q32
--   4. mv_vehicle_dashboard           — replaces Q8
--   5. mv_rto_statistics              — replaces Q12 + revenue
--
-- To check MV sizes and last refresh:
--   SELECT
--       relname AS mv_name,
--       pg_size_pretty(pg_relation_size(oid)) AS size,
--       (SELECT MAX(refreshed_at)
--        FROM mv_vehicle_compliance_summary) AS last_refresh
--   FROM pg_class
--   WHERE relkind = 'm' AND relnamespace = 'public'::regnamespace;
-- ════════════════════════════════════════════════════════════════
