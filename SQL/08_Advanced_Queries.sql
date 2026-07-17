-- ═══════════════════════════════════════════════════════════════
-- UNIFIED VEHICLE REGISTRY – ADVANCED QUERIES
-- ═══════════════════════════════════════════════════════════════
-- Run this file AFTER DDL.sql, Insert_data.sql, and Queries.sql
-- ═══════════════════════════════════════════════════════════════
--
-- This file demonstrates advanced SQL features:
--   • Window Functions (RANK, DENSE_RANK, ROW_NUMBER, LAG,
--     PERCENT_RANK, NTILE, FIRST_VALUE, LAST_VALUE,
--     running SUM, moving AVG, cumulative COUNT)
--   • CTEs (Common Table Expressions) — chained & aggregated
--   • Recursive CTEs — ownership chains, transaction chains
--   • GROUPING SETS / ROLLUP / CUBE — multidimensional analysis
--
-- Each query is self-contained and well-commented.
-- ═══════════════════════════════════════════════════════════════


-- ████████████████████████████████████████████████████████████████
-- SECTION 1 : WINDOW FUNCTIONS
-- ████████████████████████████████████████████████████████████████


-- ============================================================
-- AQ1. Rank Owners by Total Challans
--      Feature: RANK() and DENSE_RANK()
-- ============================================================
-- RANK() leaves gaps after ties (1, 2, 2, 4).
-- DENSE_RANK() does not leave gaps (1, 2, 2, 3).
-- We rank vehicle owners by how many challans their vehicles
-- have accumulated.
-- ────────────────────────────────────────────────────────────
SELECT
    u.user_id,
    u.fname || COALESCE(' ' || u.lname, '')        AS owner_name,
    COUNT(c.challan_id)                            AS total_challans,
    SUM(c.amount)                                  AS total_fine,
    RANK()       OVER (ORDER BY COUNT(c.challan_id) DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY COUNT(c.challan_id) DESC) AS rank_no_gaps
FROM users u
JOIN ownership o ON u.user_id = o.owner_id AND o.to_date IS NULL
JOIN challan c   ON o.vehicle_id = c.vehicle_id
GROUP BY u.user_id, u.fname, u.lname
ORDER BY rank_no_gaps, u.user_id;


-- ============================================================
-- AQ2. Running Total of Wallet Transactions
--      Feature: SUM() OVER(ORDER BY ...)
-- ============================================================
-- Shows a chronological running balance of all transactions
-- (debits as negative, credits as positive) for wallet #9
-- (user USR000000009, Manish Bhai Rao).
-- ────────────────────────────────────────────────────────────
SELECT
    wt.transaction_id,
    wt.tran_datetime,
    wt.purpose,
    wt.status,
    CASE
        WHEN wt.from_wallet_id = 9 THEN -wt.amount   -- debit
        WHEN wt.to_wallet_id   = 9 THEN  wt.amount   -- credit
    END AS signed_amount,
    SUM(
        CASE
            WHEN wt.from_wallet_id = 9 THEN -wt.amount
            WHEN wt.to_wallet_id   = 9 THEN  wt.amount
            ELSE 0
        END
    ) OVER (ORDER BY wt.tran_datetime, wt.transaction_id) AS running_total
FROM wallet_transaction wt
WHERE wt.from_wallet_id = 9
   OR wt.to_wallet_id   = 9
ORDER BY wt.tran_datetime, wt.transaction_id;


-- ============================================================
-- AQ3. Insurance Premium Trend per Vehicle
--      Feature: LAG() — compare with previous row
-- ============================================================
-- For vehicles with multiple insurance policies, shows how
-- the premium changed between consecutive policies.
-- LAG() accesses the previous row's value without a self-join.
-- ────────────────────────────────────────────────────────────
SELECT
    i.vehicle_id,
    v.model_name,
    i.policy_id,
    i.issue_date,
    i.insurance_company,
    i.insurance_type,
    i.premium_amount                                          AS current_premium,
    LAG(i.premium_amount) OVER (
        PARTITION BY i.vehicle_id
        ORDER BY i.issue_date
    )                                                         AS previous_premium,
    i.premium_amount - COALESCE(
        LAG(i.premium_amount) OVER (
            PARTITION BY i.vehicle_id
            ORDER BY i.issue_date
        ), i.premium_amount
    )                                                         AS premium_change,
    CASE
        WHEN LAG(i.premium_amount) OVER (
            PARTITION BY i.vehicle_id ORDER BY i.issue_date
        ) IS NULL THEN 'First Policy'
        WHEN i.premium_amount > LAG(i.premium_amount) OVER (
            PARTITION BY i.vehicle_id ORDER BY i.issue_date
        ) THEN '↑ Increased'
        WHEN i.premium_amount < LAG(i.premium_amount) OVER (
            PARTITION BY i.vehicle_id ORDER BY i.issue_date
        ) THEN '↓ Decreased'
        ELSE '= Unchanged'
    END AS trend
FROM insurance i
JOIN vehicle v ON i.vehicle_id = v.vehicle_id
ORDER BY i.vehicle_id, i.issue_date;


-- ============================================================
-- AQ4. Percentile Ranking of Challan Amounts
--      Feature: PERCENT_RANK() and NTILE(4)
-- ============================================================
-- PERCENT_RANK(): relative rank as a fraction (0.0 to 1.0).
-- NTILE(4): divides rows into 4 equal-sized buckets (quartiles).
-- This helps identify whether a challan amount is low, medium,
-- high, or extreme relative to all challans.
-- ────────────────────────────────────────────────────────────
SELECT
    c.challan_id,
    c.vehicle_id,
    c.reason,
    c.amount,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY c.amount)::numeric, 4
    )                                              AS percentile_rank,
    NTILE(4) OVER (ORDER BY c.amount)              AS quartile,
    CASE NTILE(4) OVER (ORDER BY c.amount)
        WHEN 1 THEN 'Q1 — Low'
        WHEN 2 THEN 'Q2 — Below Median'
        WHEN 3 THEN 'Q3 — Above Median'
        WHEN 4 THEN 'Q4 — High'
    END                                            AS quartile_label
FROM challan c
ORDER BY c.amount, c.challan_id;


-- ============================================================
-- AQ5. Moving Average of Monthly Challan Revenue
--      Feature: AVG() OVER(ORDER BY ... ROWS BETWEEN)
-- ============================================================
-- Computes a 3-month moving average (current month plus the
-- two preceding months) to smooth out seasonal fluctuations
-- in challan revenue.
-- ────────────────────────────────────────────────────────────
SELECT
    report_month,
    monthly_challans,
    monthly_revenue,
    ROUND(
        AVG(monthly_revenue) OVER (
            ORDER BY report_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_3m_revenue,
    ROUND(
        AVG(monthly_challans) OVER (
            ORDER BY report_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 1
    ) AS moving_avg_3m_count
FROM (
    SELECT
        TO_CHAR(challan_date, 'YYYY-MM') AS report_month,
        COUNT(*)                         AS monthly_challans,
        SUM(amount)                      AS monthly_revenue
    FROM challan
    GROUP BY TO_CHAR(challan_date, 'YYYY-MM')
) monthly_stats
ORDER BY report_month;


-- ============================================================
-- AQ6. Row Numbering for Pagination
--      Feature: ROW_NUMBER()
-- ============================================================
-- Assigns a unique sequential number to each vehicle for
-- cursor-based pagination.  Example: page 2, 10 per page.
-- ────────────────────────────────────────────────────────────
SELECT *
FROM (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY v.registration_date DESC, v.vehicle_id
        ) AS row_num,
        v.vehicle_id,
        v.model_name,
        v.manufacturer,
        v.fuel_type,
        v.registration_type,
        v.registration_date
    FROM vehicle v
) numbered
WHERE row_num BETWEEN 11 AND 20   -- page 2 (rows 11–20)
ORDER BY row_num;


-- ============================================================
-- AQ7. First and Last Challan per Vehicle
--      Feature: FIRST_VALUE() and LAST_VALUE()
-- ============================================================
-- For every challan, show the first and last challan details
-- for that vehicle's entire challan history.
-- NOTE: LAST_VALUE requires ROWS BETWEEN ... to see the full
-- partition; by default the frame ends at the current row.
-- ────────────────────────────────────────────────────────────
SELECT
    c.challan_id,
    c.vehicle_id,
    v.model_name,
    c.challan_date,
    c.amount,
    c.reason,
    FIRST_VALUE(c.challan_id) OVER w              AS first_challan_id,
    FIRST_VALUE(c.challan_date) OVER w             AS first_challan_date,
    FIRST_VALUE(c.reason) OVER w                   AS first_challan_reason,
    LAST_VALUE(c.challan_id) OVER w                AS last_challan_id,
    LAST_VALUE(c.challan_date) OVER w              AS last_challan_date,
    LAST_VALUE(c.reason) OVER w                    AS last_challan_reason
FROM challan c
JOIN vehicle v ON c.vehicle_id = v.vehicle_id
WINDOW w AS (
    PARTITION BY c.vehicle_id
    ORDER BY c.challan_date, c.challan_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY c.vehicle_id, c.challan_date;


-- ============================================================
-- AQ8. Cumulative Vehicle Registrations Over Time
--      Feature: COUNT() OVER(ORDER BY ...)
-- ============================================================
-- Shows how the fleet grew over time by computing a running
-- count of vehicles registered up to each date.
-- ────────────────────────────────────────────────────────────
SELECT
    v.registration_date,
    v.vehicle_id,
    v.model_name,
    v.manufacturer,
    COUNT(*) OVER (
        ORDER BY v.registration_date, v.vehicle_id
    ) AS cumulative_registrations,
    COUNT(*) OVER () AS total_fleet_size
FROM vehicle v
ORDER BY v.registration_date, v.vehicle_id;


-- ████████████████████████████████████████████████████████████████
-- SECTION 2 : COMMON TABLE EXPRESSIONS (CTEs)
-- ████████████████████████████████████████████████████████████████


-- ============================================================
-- AQ9. Multi-level CTE: Vehicle Risk Score
--      Feature: Chained CTEs combining multiple data sources
-- ============================================================
-- Risk score = weighted sum of:
--   • Challan count            (weight: 3 per challan)
--   • Unpaid challan count     (weight: 5 per unpaid)
--   • No active insurance      (weight: 20)
--   • No active PUC            (weight: 15)
--   • Abnormal vehicle status  (weight: 10)
-- ────────────────────────────────────────────────────────────
WITH
-- CTE 1: Challan statistics per vehicle
challan_stats AS (
    SELECT
        vehicle_id,
        COUNT(*)                                  AS total_challans,
        COUNT(*) FILTER (WHERE is_paid = FALSE)   AS unpaid_challans,
        SUM(amount) FILTER (WHERE is_paid = FALSE) AS unpaid_amount
    FROM challan
    GROUP BY vehicle_id
),

-- CTE 2: Insurance compliance per vehicle
insurance_check AS (
    SELECT
        v.vehicle_id,
        CASE WHEN EXISTS (
            SELECT 1 FROM insurance i
            WHERE i.vehicle_id = v.vehicle_id
              AND i.expiry_date >= CURRENT_DATE
        ) THEN 0 ELSE 20 END AS insurance_penalty
    FROM vehicle v
),

-- CTE 3: PUC compliance per vehicle
puc_check AS (
    SELECT
        v.vehicle_id,
        CASE WHEN EXISTS (
            SELECT 1 FROM puc p
            WHERE p.vehicle_id = v.vehicle_id
              AND p.valid_until >= CURRENT_DATE
        ) THEN 0 ELSE 15 END AS puc_penalty
    FROM vehicle v
),

-- CTE 4: Abnormal status check
status_check AS (
    SELECT
        v.vehicle_id,
        CASE WHEN EXISTS (
            SELECT 1 FROM vehicle_log vl
            WHERE vl.vehicle_id = v.vehicle_id
              AND vl.end_date IS NULL
        ) THEN 10 ELSE 0 END AS status_penalty
    FROM vehicle v
)

-- Final SELECT: combine all CTEs into a risk score
SELECT
    v.vehicle_id,
    v.model_name,
    v.manufacturer,
    COALESCE(cs.total_challans, 0)   AS total_challans,
    COALESCE(cs.unpaid_challans, 0)  AS unpaid_challans,
    COALESCE(cs.unpaid_amount, 0)    AS unpaid_amount,
    ic.insurance_penalty,
    pc.puc_penalty,
    sc.status_penalty,
    -- Composite risk score
    COALESCE(cs.total_challans, 0) * 3
        + COALESCE(cs.unpaid_challans, 0) * 5
        + ic.insurance_penalty
        + pc.puc_penalty
        + sc.status_penalty            AS risk_score,
    CASE
        WHEN COALESCE(cs.total_challans, 0) * 3
             + COALESCE(cs.unpaid_challans, 0) * 5
             + ic.insurance_penalty + pc.puc_penalty + sc.status_penalty >= 50
        THEN 'HIGH RISK'
        WHEN COALESCE(cs.total_challans, 0) * 3
             + COALESCE(cs.unpaid_challans, 0) * 5
             + ic.insurance_penalty + pc.puc_penalty + sc.status_penalty >= 25
        THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS risk_category
FROM vehicle v
LEFT JOIN challan_stats  cs ON v.vehicle_id = cs.vehicle_id
JOIN      insurance_check ic ON v.vehicle_id = ic.vehicle_id
JOIN      puc_check       pc ON v.vehicle_id = pc.vehicle_id
JOIN      status_check    sc ON v.vehicle_id = sc.vehicle_id
ORDER BY risk_score DESC;


-- ============================================================
-- AQ10. CTE with Aggregation: Top Defaulters
--       Feature: CTE for pre-aggregation + final ranking
-- ============================================================
-- Users with the most unpaid challans, showing total amount
-- owed, number of vehicles involved, and ranking.
-- ────────────────────────────────────────────────────────────
WITH unpaid_summary AS (
    SELECT
        o.owner_id                                     AS user_id,
        COUNT(DISTINCT c.challan_id)                   AS unpaid_challan_count,
        SUM(c.amount)                                  AS total_amount_owed,
        COUNT(DISTINCT c.vehicle_id)                   AS vehicles_involved,
        ARRAY_AGG(DISTINCT v.model_name ORDER BY v.model_name) AS vehicle_models
    FROM challan c
    JOIN ownership o ON c.vehicle_id = o.vehicle_id AND o.to_date IS NULL
    JOIN vehicle v   ON c.vehicle_id = v.vehicle_id
    WHERE c.is_paid = FALSE
    GROUP BY o.owner_id
)
SELECT
    us.user_id,
    u.fname || COALESCE(' ' || u.lname, '')            AS full_name,
    u.phone_number,
    u.city,
    us.unpaid_challan_count,
    us.total_amount_owed,
    us.vehicles_involved,
    us.vehicle_models,
    RANK() OVER (ORDER BY us.total_amount_owed DESC)    AS defaulter_rank
FROM unpaid_summary us
JOIN users u ON us.user_id = u.user_id
ORDER BY defaulter_rank;


-- ============================================================
-- AQ11. CTE for Data Cleanup Analysis
--       Feature: CTE to find duplicate / inconsistent records
-- ============================================================
-- Identifies potential data quality issues:
--   • Vehicles with overlapping ownership periods
--   • Vehicles with multiple "current" owners
--   • Users with wallets but no ownership history
-- ────────────────────────────────────────────────────────────

-- Part A: Vehicles with multiple current owners
WITH multiple_current_owners AS (
    SELECT
        vehicle_id,
        COUNT(*) AS current_owner_count,
        ARRAY_AGG(owner_id ORDER BY from_date) AS owner_ids
    FROM ownership
    WHERE to_date IS NULL
    GROUP BY vehicle_id
    HAVING COUNT(*) > 1
)
SELECT
    mco.vehicle_id,
    v.model_name,
    mco.current_owner_count,
    mco.owner_ids
FROM multiple_current_owners mco
JOIN vehicle v ON mco.vehicle_id = v.vehicle_id
ORDER BY mco.current_owner_count DESC;

-- Part B: Overlapping ownership periods for the same vehicle
WITH ownership_pairs AS (
    SELECT
        o1.vehicle_id,
        o1.ownership_id AS owner1_id,
        o1.owner_id     AS user1_id,
        o1.from_date    AS from1,
        o1.to_date      AS to1,
        o2.ownership_id AS owner2_id,
        o2.owner_id     AS user2_id,
        o2.from_date    AS from2,
        o2.to_date      AS to2
    FROM ownership o1
    JOIN ownership o2
        ON o1.vehicle_id = o2.vehicle_id
       AND o1.ownership_id < o2.ownership_id
    WHERE (o1.from_date, COALESCE(o1.to_date, '9999-12-31'))
        OVERLAPS
          (o2.from_date, COALESCE(o2.to_date, '9999-12-31'))
)
SELECT
    op.vehicle_id,
    v.model_name,
    op.owner1_id, op.user1_id, op.from1, op.to1,
    op.owner2_id, op.user2_id, op.from2, op.to2,
    'Overlapping ownership periods detected' AS issue
FROM ownership_pairs op
JOIN vehicle v ON op.vehicle_id = v.vehicle_id
ORDER BY op.vehicle_id;

-- Part C: Users with wallets but no vehicle ownership
WITH orphan_wallets AS (
    SELECT
        ew.wallet_id,
        ew.user_id,
        ew.balance,
        ew.status
    FROM e_wallet ew
    WHERE NOT EXISTS (
        SELECT 1 FROM ownership o
        WHERE o.owner_id = ew.user_id
    )
)
SELECT
    ow.wallet_id,
    ow.user_id,
    u.fname || COALESCE(' ' || u.lname, '') AS full_name,
    ow.balance,
    ow.status AS wallet_status,
    'User has wallet but never owned a vehicle' AS note
FROM orphan_wallets ow
JOIN users u ON ow.user_id = u.user_id
ORDER BY ow.balance DESC;


-- ████████████████████████████████████████████████████████████████
-- SECTION 3 : RECURSIVE CTEs
-- ████████████████████████████████████████████████████████████████


-- ============================================================
-- AQ12. Wallet Transaction Chain (Recursive CTE)
--       Feature: Recursive CTE tracing related transactions
-- ============================================================
-- Traces a chain of related transactions: a challan payment
-- may trigger a refund, which may connect to another payment.
-- We trace connections through the wallet_transaction table
-- where refund transactions link payer and receiver wallets.
--
-- Chain logic: from a starting "challan" payment transaction,
-- find refund transactions involving the same wallet, then
-- trace forward to any subsequent challan payments by the
-- refund receiver.
-- ────────────────────────────────────────────────────────────
WITH RECURSIVE txn_chain AS (
    -- Base case: start with a specific challan payment transaction
    -- (Transaction #1: wallet 32 paid ₹3000 for challan)
    SELECT
        wt.transaction_id,
        wt.from_wallet_id,
        wt.to_wallet_id,
        wt.amount,
        wt.purpose,
        wt.tran_datetime,
        wt.status,
        1 AS chain_depth,
        ARRAY[wt.transaction_id] AS chain_path
    FROM wallet_transaction wt
    WHERE wt.transaction_id = 1   -- starting transaction

    UNION ALL

    -- Recursive case: find transactions connected through wallet IDs
    -- A transaction is "connected" if:
    --   • Its from_wallet matches the previous to_wallet (forward chain)
    --   • Its to_wallet matches the previous from_wallet (refund chain)
    -- We limit depth to prevent infinite recursion.
    SELECT
        wt.transaction_id,
        wt.from_wallet_id,
        wt.to_wallet_id,
        wt.amount,
        wt.purpose,
        wt.tran_datetime,
        wt.status,
        tc.chain_depth + 1,
        tc.chain_path || wt.transaction_id
    FROM wallet_transaction wt
    JOIN txn_chain tc ON (
        -- Forward chain: next transaction from receiver's wallet
        (wt.from_wallet_id = tc.to_wallet_id AND tc.to_wallet_id IS NOT NULL)
        OR
        -- Backward chain: refund back to the payer's wallet
        (wt.to_wallet_id = tc.from_wallet_id AND wt.purpose = 'refund')
    )
    WHERE wt.transaction_id != ALL(tc.chain_path)  -- prevent cycles
      AND tc.chain_depth < 5                       -- depth limit
      AND wt.tran_datetime >= tc.tran_datetime     -- chronological order
)
SELECT
    chain_depth,
    transaction_id,
    purpose,
    amount,
    from_wallet_id,
    to_wallet_id,
    status,
    tran_datetime,
    chain_path
FROM txn_chain
ORDER BY chain_depth, tran_datetime;


-- ============================================================
-- AQ13. Ownership Chain of a Vehicle (Recursive CTE)
--       Feature: Recursive CTE showing full owner chain
-- ============================================================
-- Reconstructs the ownership chain of a vehicle from the
-- first owner to the current owner, treating each transfer
-- as a parent-child relationship.
--
-- Chain: owner N's to_date ≈ owner N+1's from_date.
-- ────────────────────────────────────────────────────────────
WITH RECURSIVE owner_chain AS (
    -- Base case: the FIRST owner (no previous ownership ends
    -- near this owner's from_date for the same vehicle)
    SELECT
        o.ownership_id,
        o.vehicle_id,
        o.owner_id,
        o.from_date,
        o.to_date,
        1 AS chain_position,
        ARRAY[o.owner_id::text] AS chain_path
    FROM ownership o
    WHERE o.vehicle_id = 'XT0K7EFFF4G0JDYH3'  -- vehicle with transfers
      AND NOT EXISTS (
          SELECT 1 FROM ownership prev
          WHERE prev.vehicle_id = o.vehicle_id
            AND prev.to_date IS NOT NULL
            AND prev.to_date <= o.from_date
            AND prev.ownership_id != o.ownership_id
      )

    UNION ALL

    -- Recursive case: the next owner started after the
    -- previous owner's to_date
    SELECT
        o.ownership_id,
        o.vehicle_id,
        o.owner_id,
        o.from_date,
        o.to_date,
        oc.chain_position + 1,
        oc.chain_path || o.owner_id::text
    FROM ownership o
    JOIN owner_chain oc ON o.vehicle_id = oc.vehicle_id
                       AND o.from_date > oc.from_date
                       AND oc.to_date IS NOT NULL           -- previous owner transferred
                       AND o.owner_id::text != ALL(oc.chain_path) -- prevent cycles
    WHERE oc.chain_position < 10  -- safety limit
)
SELECT
    oc.chain_position                                        AS transfer_number,
    oc.ownership_id,
    u.user_id,
    u.fname || COALESCE(' ' || u.lname, '')                  AS owner_name,
    u.city,
    oc.from_date,
    oc.to_date,
    CASE WHEN oc.to_date IS NULL
         THEN 'Current Owner ★'
         ELSE 'Transferred on ' || oc.to_date::text
    END                                                      AS status,
    COALESCE(oc.to_date, CURRENT_DATE) - oc.from_date        AS days_owned
FROM owner_chain oc
JOIN users u ON oc.owner_id = u.user_id
ORDER BY oc.chain_position;


-- ████████████████████████████████████████████████████████████████
-- SECTION 4 : GROUPING SETS / ROLLUP / CUBE
-- ████████████████████████████████████████████████████████████████


-- ============================================================
-- AQ14. Multi-dimensional Challan Analysis
--       Feature: GROUPING SETS
-- ============================================================
-- Produces multiple levels of aggregation in a single query:
--   • By challan reason
--   • By RTO state
--   • By (reason, state) combination
--   • Grand total
--
-- GROUPING() function identifies which grouping level each
-- row belongs to.
-- ────────────────────────────────────────────────────────────
SELECT
    CASE WHEN GROUPING(c.reason) = 1
         THEN '── ALL REASONS ──'
         ELSE c.reason
    END                                                      AS challan_reason,
    CASE WHEN GROUPING(r.state) = 1
         THEN '── ALL STATES ──'
         ELSE r.state
    END                                                      AS rto_state,
    COUNT(*)                                                 AS total_challans,
    SUM(c.amount)                                            AS total_fine,
    SUM(c.amount) FILTER (WHERE c.is_paid = TRUE)            AS collected,
    SUM(c.amount) FILTER (WHERE c.is_paid = FALSE)           AS pending,
    ROUND(AVG(c.amount), 2)                                  AS avg_fine,
    CASE
        WHEN GROUPING(c.reason) = 0 AND GROUPING(r.state) = 0
            THEN 'Reason × State'
        WHEN GROUPING(c.reason) = 0 AND GROUPING(r.state) = 1
            THEN 'By Reason'
        WHEN GROUPING(c.reason) = 1 AND GROUPING(r.state) = 0
            THEN 'By State'
        ELSE 'Grand Total'
    END                                                      AS grouping_level
FROM challan c
JOIN officer o ON c.issuing_officer_id = o.officer_id
JOIN rto r     ON o.rto_code = r.rto_code
GROUP BY GROUPING SETS (
    (c.reason),              -- subtotal by reason
    (r.state),               -- subtotal by state
    (c.reason, r.state),     -- detail level
    ()                       -- grand total
)
ORDER BY
    GROUPING(c.reason),
    GROUPING(r.state),
    challan_reason,
    rto_state;


-- ============================================================
-- AQ15. ROLLUP for Hierarchical Revenue
--       Feature: ROLLUP (state → city → rto_code)
-- ============================================================
-- ROLLUP creates a hierarchy of subtotals:
--   Level 0: State + City + RTO     (detail)
--   Level 1: State + City           (city subtotal)
--   Level 2: State                  (state subtotal)
--   Level 3: ()                     (grand total)
--
-- This is commonly used for hierarchical financial reports.
-- ────────────────────────────────────────────────────────────
SELECT
    COALESCE(r.state,    '══ GRAND TOTAL ══')                AS state,
    COALESCE(r.city,     '── State Total ──')                AS city,
    COALESCE(r.rto_code, '── City Total ──')                 AS rto_code,
    COUNT(c.challan_id)                                      AS total_challans,
    SUM(c.amount)                                            AS total_revenue,
    SUM(c.amount) FILTER (WHERE c.is_paid = TRUE)            AS collected_revenue,
    SUM(c.amount) FILTER (WHERE c.is_paid = FALSE)           AS outstanding_revenue,
    ROUND(
        100.0 * COALESCE(
            SUM(c.amount) FILTER (WHERE c.is_paid = TRUE), 0
        ) / NULLIF(SUM(c.amount), 0), 2
    )                                                        AS collection_rate_pct,
    GROUPING(r.state, r.city, r.rto_code)                    AS grouping_id
FROM challan c
JOIN officer o ON c.issuing_officer_id = o.officer_id
JOIN rto r     ON o.rto_code = r.rto_code
GROUP BY ROLLUP (r.state, r.city, r.rto_code)
ORDER BY
    GROUPING(r.state) DESC,   -- grand total first
    r.state NULLS FIRST,
    GROUPING(r.city) DESC,    -- state subtotals before city detail
    r.city NULLS FIRST,
    GROUPING(r.rto_code) DESC,
    r.rto_code NULLS FIRST;


-- ═══════════════════════════════════════════════════════════════
-- END OF ADVANCED QUERIES
-- ═══════════════════════════════════════════════════════════════
