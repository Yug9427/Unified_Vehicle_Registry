-- ============================================================
-- VEHICLE DATABASE MANAGEMENT – QUERIES & VIEWS
-- ============================================================
-- Run this file AFTER ddl.sql and insert_data.sql
-- ============================================================


-- ████████████████████████████████████████████████████████████
-- SECTION 1 : VIEWS FOR ALL DERIVED ATTRIBUTES
-- ████████████████████████████████████████████████████████████


-- ──────────────────────────────────────────────────────────────
-- 1A. User Age (derived from DOB)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_user_age AS
SELECT
    user_id,
    fname || COALESCE(' ' || mname, '') || COALESCE(' ' || lname, '') AS full_name,
    dob,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, dob))::int AS age
FROM users;


-- ──────────────────────────────────────────────────────────────
-- 1B. Ownership – is_current (derived: TRUE when to_date IS NULL)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_ownership_status AS
SELECT
    ownership_id,
    vehicle_id,
    owner_id,
    from_date,
    to_date,
    CASE WHEN to_date IS NULL THEN TRUE ELSE FALSE END AS is_current
FROM ownership;


-- ──────────────────────────────────────────────────────────────
-- 1C. PUC Certificate Status (derived from valid_until)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_puc_status AS
SELECT
    certificate_number,
    vehicle_id,
    date_of_test,
    valid_until,
    centre_code,
    CASE
        WHEN valid_until >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS certificate_status
FROM puc;


-- ──────────────────────────────────────────────────────────────
-- 1D. Permit Status (derived from expiry_date)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_permit_status AS
SELECT
    p.permit_id,
    p.vehicle_id,
    p.permit_type,
    p.issuing_rto_id,
    p.issue_date,
    p.expiry_date,
    CASE
        WHEN p.expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS permit_status,
    p.max_load_capacity,
    p.max_passengers,
    ARRAY_AGG(pr.authorized_route ORDER BY pr.authorized_route)
        FILTER (WHERE pr.authorized_route IS NOT NULL) AS authorized_routes
FROM permit p
LEFT JOIN permit_route pr ON p.permit_id = pr.permit_id
GROUP BY p.permit_id;


-- ──────────────────────────────────────────────────────────────
-- 1E. Insurance Status (derived from expiry_date)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_insurance_status AS
SELECT
    policy_id,
    vehicle_id,
    issue_date,
    expiry_date,
    coverage_amount,
    insurance_type,
    premium_amount,
    number_of_claims,
    insurance_company,
    CASE
        WHEN expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS policy_status
FROM insurance;


-- ──────────────────────────────────────────────────────────────
-- 1F. License Status (derived: Active only if not expired/revoked)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_license_status AS
SELECT
    license_no,
    user_id,
    issue_date,
    expiry_date,
    license_type,
    vehicle_class,
    issuing_rto_id,
    status AS stored_status,
    CASE
        WHEN status = 'Revoked' THEN 'Revoked'
        WHEN status = 'Suspended' THEN 'Suspended'
        WHEN expiry_date < CURRENT_DATE THEN 'Expired'
        ELSE 'Active'
    END AS effective_status
FROM license;


-- ──────────────────────────────────────────────────────────────
-- 1G. Vehicle Condition (derived from vehicle_log)
--     Shows the current condition of every vehicle.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_vehicle_condition AS
SELECT
    v.vehicle_id,
    v.model_name,
    COALESCE(
        (SELECT vl.vehicle_status
         FROM vehicle_log vl
         WHERE vl.vehicle_id = v.vehicle_id
           AND vl.end_date IS NULL
         ORDER BY vl.start_date DESC
         LIMIT 1),
        'Normal'
    ) AS current_condition
FROM vehicle v;


-- ──────────────────────────────────────────────────────────────
-- 1H. Vehicle Age (derived from manufactured_year)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_vehicle_age AS
SELECT
    vehicle_id,
    model_name,
    manufactured_year,
    EXTRACT(YEAR FROM CURRENT_DATE)::int - manufactured_year AS vehicle_age_years
FROM vehicle;


-- ████████████████████████████████████████████████████████████
-- SECTION 2 : ADDITIONAL USEFUL QUERIES
-- ████████████████████████████████████████████████████████████


-- ============================================================
-- Q1. Current owner of a PARTICULAR vehicle
--     PREPARED: $1 = vehicle_id
-- ============================================================
SELECT
    o.vehicle_id,
    v.model_name,
    u.user_id,
    u.fname || COALESCE(' ' || mname, '') || COALESCE(' ' || lname, '') AS owner_name,
    u.phone_number,
    o.from_date AS ownership_since
FROM ownership o
JOIN users   u ON o.owner_id   = u.user_id
JOIN vehicle v ON o.vehicle_id = v.vehicle_id
WHERE o.vehicle_id = $1
  AND o.to_date IS NULL;


-- ============================================================
-- Q2. Current owner for ALL vehicles
-- ============================================================
SELECT
    o.vehicle_id,
    v.model_name,
    u.user_id,
    u.fname || COALESCE(' ' || mname, '') || COALESCE(' ' || lname, '') AS owner_name,
    u.phone_number,
    o.from_date AS ownership_since
FROM ownership o
JOIN users   u ON o.owner_id   = u.user_id
JOIN vehicle v ON o.vehicle_id = v.vehicle_id
WHERE o.to_date IS NULL
ORDER BY o.vehicle_id;


-- ============================================================
-- Q3. Does a vehicle have any ACTIVE insurance? (Boolean)
--     PREPARED: $1 = vehicle_id
-- ============================================================
SELECT
    EXISTS (
        SELECT 1
        FROM insurance
        WHERE vehicle_id = $1
          AND expiry_date >= CURRENT_DATE
    ) AS has_active_insurance;


-- ============================================================
-- Q4. Does a vehicle have any ACTIVE PUC? (Boolean)
--     PREPARED: $1 = vehicle_id
-- ============================================================
SELECT
    EXISTS (
        SELECT 1
        FROM puc
        WHERE vehicle_id = $1
          AND valid_until >= CURRENT_DATE
    ) AS has_active_puc;


-- ============================================================
-- Q5A. All Active & Expired insurance of a PARTICULAR vehicle
--      PREPARED: $1 = vehicle_id
-- ============================================================
SELECT
    policy_id,
    vehicle_id,
    insurance_company,
    insurance_type,
    issue_date,
    expiry_date,
    coverage_amount,
    premium_amount,
    number_of_claims,
    CASE
        WHEN expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS policy_status
FROM insurance
WHERE vehicle_id = $1
ORDER BY issue_date DESC;


-- ============================================================
-- Q5B. All Active & Expired insurance for ALL vehicles
-- ============================================================
SELECT
    i.policy_id,
    i.vehicle_id,
    v.model_name,
    i.insurance_company,
    i.insurance_type,
    i.issue_date,
    i.expiry_date,
    i.coverage_amount,
    i.premium_amount,
    i.number_of_claims,
    CASE
        WHEN i.expiry_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Expired'
    END AS policy_status
FROM insurance i
JOIN vehicle v ON i.vehicle_id = v.vehicle_id
ORDER BY i.vehicle_id, i.issue_date DESC;


-- ============================================================
-- Q6. How many users has a vehicle had? (current + past)
--     PREPARED: $1 = vehicle_id
-- ============================================================
SELECT
    o.vehicle_id,
    v.model_name,
    COUNT(DISTINCT o.owner_id) AS total_owners
FROM ownership o
JOIN vehicle v ON o.vehicle_id = v.vehicle_id
WHERE o.vehicle_id = $1
GROUP BY o.vehicle_id, v.model_name;


-- ============================================================
-- Q7. How many vehicles does a user own / has owned?
--     PREPARED: $1 = user_id
-- ============================================================
SELECT
    o.owner_id AS user_id,
    u.fname || COALESCE(' ' || mname, '') || COALESCE(' ' || lname, '') AS user_name,
    COUNT(DISTINCT o.vehicle_id) AS total_vehicles,
    COUNT(DISTINCT o.vehicle_id) FILTER (WHERE o.to_date IS NULL) AS currently_owned,
    COUNT(DISTINCT o.vehicle_id) FILTER (WHERE o.to_date IS NOT NULL) AS previously_owned
FROM ownership o
JOIN users u ON o.owner_id = u.user_id
WHERE o.owner_id = $1
GROUP BY o.owner_id, u.fname, u.mname, u.lname;


-- ============================================================
-- Q8. Vehicle Dashboard – Full summary per vehicle
--     (vehicle_id, model_name, current_owner, total_challan,
--      unpaid_challan, total_amount, outstanding_amount)
-- ============================================================
SELECT
    v.vehicle_id,
    v.model_name,
    COALESCE(
        owner_info.owner_name,
        'No Current Owner'
    ) AS current_owner_name,
    COALESCE(ch.total_challans, 0) AS total_challans,
    COALESCE(ch.unpaid_challans, 0) AS unpaid_challans,
    COALESCE(ch.total_amount, 0) AS total_amount,
    COALESCE(ch.outstanding_amount, 0) AS outstanding_amount
FROM vehicle v
-- current owner
LEFT JOIN (
    SELECT
        o.vehicle_id,
        u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name
    FROM ownership o
    JOIN users u ON o.owner_id = u.user_id
    WHERE o.to_date IS NULL
) owner_info ON v.vehicle_id = owner_info.vehicle_id
-- challan summary
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
ORDER BY v.vehicle_id;


-- ============================================================
-- Q9. Vehicle Compliance Report
--     (Insurance + PUC + Permit active status at a glance)
-- ============================================================
SELECT
    v.vehicle_id,
    v.model_name,
    EXISTS (
        SELECT 1 FROM insurance
        WHERE vehicle_id = v.vehicle_id
          AND expiry_date >= CURRENT_DATE
    ) AS has_active_insurance,
    EXISTS (
        SELECT 1 FROM puc
        WHERE vehicle_id = v.vehicle_id
          AND valid_until >= CURRENT_DATE
    ) AS has_active_puc,
    EXISTS (
        SELECT 1 FROM permit
        WHERE vehicle_id = v.vehicle_id
          AND expiry_date >= CURRENT_DATE
    ) AS has_active_permit
FROM vehicle v
ORDER BY v.vehicle_id;


-- ============================================================
-- Q10. Non-Compliant Vehicles
--      (vehicles missing EITHER active insurance OR active PUC)
--      Uses DISTINCT ON to extract the latest record per vehicle
--      in a single index-backed pass — avoids correlated subqueries.
-- ============================================================
SELECT
    v.vehicle_id,
    v.model_name,
    CASE
        WHEN latest_ins.expiry_date IS NULL OR latest_ins.expiry_date < CURRENT_DATE
        THEN 'NO' ELSE 'YES'
    END AS insurance_valid,
    CASE
        WHEN latest_puc.valid_until IS NULL OR latest_puc.valid_until < CURRENT_DATE
        THEN 'NO' ELSE 'YES'
    END AS puc_valid
FROM vehicle v
-- Latest insurance per vehicle (single-pass via DISTINCT ON)
LEFT JOIN (
    SELECT DISTINCT ON (vehicle_id)
        vehicle_id, expiry_date
    FROM insurance
    ORDER BY vehicle_id, expiry_date DESC
) latest_ins ON v.vehicle_id = latest_ins.vehicle_id
-- Latest PUC per vehicle (single-pass via DISTINCT ON)
LEFT JOIN (
    SELECT DISTINCT ON (vehicle_id)
        vehicle_id, valid_until
    FROM puc
    ORDER BY vehicle_id, valid_until DESC
) latest_puc ON v.vehicle_id = latest_puc.vehicle_id
WHERE (latest_ins.expiry_date IS NULL OR latest_ins.expiry_date < CURRENT_DATE)
   OR (latest_puc.valid_until IS NULL OR latest_puc.valid_until < CURRENT_DATE)
ORDER BY v.vehicle_id;


-- ============================================================
-- Q11. Officer-wise Challan Report
--      (how many challans each officer has issued & total amount)
-- ============================================================
SELECT
    of.officer_id,
    of.name AS officer_name,
    r.rto_name,
    r.city AS rto_city,
    COUNT(c.challan_id) AS challans_issued,
    SUM(c.amount) AS total_amount_fined,
    SUM(c.amount) FILTER (WHERE c.is_paid = FALSE) AS amount_still_unpaid
FROM officer of
JOIN rto r ON of.rto_code = r.rto_code
LEFT JOIN challan c ON of.officer_id = c.issuing_officer_id
GROUP BY of.officer_id, of.name, r.rto_name, r.city
ORDER BY challans_issued DESC;


-- ============================================================
-- Q12. RTO-wise Vehicle Registration Count
-- ============================================================
SELECT
    r.rto_code,
    r.rto_name,
    r.city,
    r.state,
    COUNT(DISTINCT p.vehicle_id) AS vehicles_with_permits,
    COUNT(DISTINCT l.user_id) AS licenses_issued
FROM rto r
LEFT JOIN permit  p ON r.rto_code = p.issuing_rto_id
LEFT JOIN license l ON r.rto_code = l.issuing_rto_id
GROUP BY r.rto_code, r.rto_name, r.city, r.state
ORDER BY vehicles_with_permits DESC;


-- ============================================================
-- Q13. Users with Expired / Suspended / Revoked Licenses
-- ============================================================
SELECT
    u.user_id,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS full_name,
    l.license_no,
    l.license_type,
    l.vehicle_class,
    l.expiry_date,
    l.status,
    CASE
        WHEN l.status = 'Revoked' THEN 'Revoked'
        WHEN l.status = 'Suspended' THEN 'Suspended'
        WHEN l.expiry_date < CURRENT_DATE THEN 'Expired'
        ELSE 'Active'
    END AS effective_status
FROM license l
JOIN users u ON l.user_id = u.user_id
WHERE l.status IN ('Suspended','Revoked')
   OR l.expiry_date < CURRENT_DATE
ORDER BY l.expiry_date;


-- ============================================================
-- Q14. Wallet Balance & Transaction Summary per User
-- ============================================================
SELECT
    u.user_id,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS full_name,
    ew.wallet_id,
    ew.balance AS current_balance,
    ew.status  AS wallet_status,
    COALESCE(ts.total_transactions, 0) AS total_transactions,
    COALESCE(ts.total_debited, 0) AS total_debited,
    COALESCE(ts.total_credited, 0) AS total_credited
FROM users u
JOIN e_wallet ew ON u.user_id = ew.user_id
LEFT JOIN (
    SELECT
        w.wallet_id,
        COUNT(t.transaction_id) AS total_transactions,
        COALESCE(SUM(t.amount) FILTER (WHERE t.from_wallet_id = w.wallet_id AND t.status = 'Success'), 0) AS total_debited,
        COALESCE(SUM(t.amount) FILTER (WHERE t.to_wallet_id   = w.wallet_id AND t.status = 'Success'), 0) AS total_credited
    FROM e_wallet w
    LEFT JOIN wallet_transaction t
        ON w.wallet_id = t.from_wallet_id OR w.wallet_id = t.to_wallet_id
    GROUP BY w.wallet_id
) ts ON ew.wallet_id = ts.wallet_id
ORDER BY u.user_id;


-- ============================================================
-- Q15. Ownership History of a Vehicle (Full Timeline)
--      PREPARED: $1 = vehicle_id
-- ============================================================
SELECT
    o.ownership_id,
    o.vehicle_id,
    v.model_name,
    u.user_id,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name,
    o.from_date,
    o.to_date,
    CASE WHEN o.to_date IS NULL THEN 'Current Owner' ELSE 'Past Owner' END AS status,
    COALESCE(o.to_date, CURRENT_DATE) - o.from_date AS days_owned
FROM ownership o
JOIN users   u ON o.owner_id   = u.user_id
JOIN vehicle v ON o.vehicle_id = v.vehicle_id
WHERE o.vehicle_id = $1
ORDER BY o.from_date;


-- ============================================================
-- Q16. Vehicles Currently in Abnormal Status
--      (Seized, Stolen, Lost, Under Repair, Scrapped)
-- ============================================================
SELECT
    vl.status_id,
    vl.vehicle_id,
    v.model_name,
    vl.vehicle_status,
    vl.start_date,
    u.user_id AS current_owner_id,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS current_owner_name
FROM vehicle_log vl
JOIN vehicle v ON vl.vehicle_id = v.vehicle_id
LEFT JOIN ownership o ON vl.vehicle_id = o.vehicle_id AND o.to_date IS NULL
LEFT JOIN users u ON o.owner_id = u.user_id
WHERE vl.end_date IS NULL
ORDER BY vl.start_date DESC;


-- ============================================================
-- Q17. Vehicles with Most Challans (Top 10)
-- ============================================================
SELECT
    c.vehicle_id,
    v.model_name,
    COUNT(c.challan_id)                             AS total_challans,
    SUM(c.amount)                                   AS total_fine,
    SUM(c.amount) FILTER (WHERE c.is_paid = FALSE)  AS unpaid_fine,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE c.is_paid = TRUE) / COUNT(*), 2
    ) AS paid_percentage
FROM challan c
JOIN vehicle v ON c.vehicle_id = v.vehicle_id
GROUP BY c.vehicle_id, v.model_name
ORDER BY total_challans DESC
LIMIT 10;


-- ============================================================
-- Q18. Most Common Challan Reasons
-- ============================================================
SELECT
    reason,
    COUNT(*) AS times_issued,
    SUM(amount) AS total_fine_amount,
    ROUND(AVG(amount), 2) AS avg_fine_amount,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_paid = TRUE) / COUNT(*), 2) AS payment_rate_pct
FROM challan
GROUP BY reason
ORDER BY times_issued DESC;


-- ============================================================
-- Q19. Insurance Expiring Soon (within next 30 days)
-- ============================================================
SELECT
    i.policy_id,
    i.vehicle_id,
    v.model_name,
    i.insurance_company,
    i.insurance_type,
    i.expiry_date,
    i.expiry_date - CURRENT_DATE AS days_remaining,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name,
    u.phone_number
FROM insurance i
JOIN vehicle v ON i.vehicle_id = v.vehicle_id
LEFT JOIN ownership o ON i.vehicle_id = o.vehicle_id AND o.to_date IS NULL
LEFT JOIN users u ON o.owner_id = u.user_id
WHERE i.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
ORDER BY i.expiry_date;


-- ============================================================
-- Q20. PUC Expiring Soon (within next 30 days)
-- ============================================================
SELECT
    p.certificate_number,
    p.vehicle_id,
    v.model_name,
    p.valid_until,
    p.valid_until - CURRENT_DATE AS days_remaining,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name,
    u.phone_number
FROM puc p
JOIN vehicle v ON p.vehicle_id = v.vehicle_id
LEFT JOIN ownership o ON p.vehicle_id = o.vehicle_id AND o.to_date IS NULL
LEFT JOIN users u ON o.owner_id = u.user_id
WHERE p.valid_until BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
ORDER BY p.valid_until;


-- ============================================================
-- Q21. Fuel Type Distribution (Vehicle Statistics)
-- ============================================================
SELECT
    fuel_type,
    COUNT(*) AS vehicle_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM vehicle), 2) AS percentage
FROM vehicle
GROUP BY fuel_type
ORDER BY vehicle_count DESC;


-- ============================================================
-- Q22. City-wise User Distribution
-- ============================================================
SELECT
    city,
    state,
    COUNT(*) AS user_count,
    COUNT(DISTINCT ew.wallet_id) FILTER (WHERE ew.status = 'Active') AS active_wallets
FROM users u
LEFT JOIN e_wallet ew ON u.user_id = ew.user_id
GROUP BY city, state
ORDER BY user_count DESC;


-- ============================================================
-- Q23. Manufacturer-wise Vehicle Count & Average Age
-- ============================================================
SELECT
    manufacturer,
    COUNT(*) AS total_vehicles,
    MIN(manufactured_year) AS oldest_year,
    MAX(manufactured_year) AS newest_year,
    ROUND(AVG(EXTRACT(YEAR FROM CURRENT_DATE)::int - manufactured_year), 1) AS avg_age_years
FROM vehicle
GROUP BY manufacturer
ORDER BY total_vehicles DESC;


-- ============================================================
-- Q24. Users Who Own Multiple Vehicles Currently
-- ============================================================
SELECT
    u.user_id,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS full_name,
    u.city,
    COUNT(o.vehicle_id) AS vehicles_currently_owned,
    ARRAY_AGG(v.model_name ORDER BY v.model_name) AS vehicle_models
FROM users u
JOIN ownership o ON u.user_id = o.owner_id AND o.to_date IS NULL
JOIN vehicle v ON o.vehicle_id = v.vehicle_id
GROUP BY u.user_id, u.fname, u.mname, u.lname, u.city
HAVING COUNT(o.vehicle_id) > 1
ORDER BY vehicles_currently_owned DESC;


-- ============================================================
-- Q25. Transaction History for a User's Wallet
--      PREPARED: $1 = user_id
-- ============================================================
SELECT
    wt.transaction_id,
    wt.tran_datetime,
    wt.amount,
    wt.purpose,
    wt.status,
    CASE
        WHEN wt.from_wallet_id = ew.wallet_id THEN 'DEBIT'
        WHEN wt.to_wallet_id   = ew.wallet_id THEN 'CREDIT'
    END AS direction,
    CASE
        WHEN wt.from_wallet_id = ew.wallet_id THEN wt.to_wallet_id
        ELSE wt.from_wallet_id
    END AS counterparty_wallet_id
FROM wallet_transaction wt
JOIN e_wallet ew ON ew.user_id = $1
WHERE wt.from_wallet_id = ew.wallet_id
   OR wt.to_wallet_id = ew.wallet_id
ORDER BY wt.tran_datetime DESC;


-- ============================================================
-- Q26. Challans Paid via Wallet (with transaction details)
-- ============================================================
SELECT
    c.challan_id,
    c.vehicle_id,
    v.model_name,
    c.reason,
    c.amount,
    c.challan_date,
    c.location,
    wt.transaction_id,
    wt.tran_datetime AS payment_datetime,
    wt.status AS payment_status
FROM challan c
JOIN vehicle v ON c.vehicle_id = v.vehicle_id
JOIN wallet_transaction wt ON c.wallet_transaction_id = wt.transaction_id
WHERE c.is_paid = TRUE
ORDER BY wt.tran_datetime DESC;


-- ============================================================
-- Q27. Vehicle Complete Profile Card
--      (All details about a vehicle in one query)
--      PREPARED: $1 = vehicle_id
--      Uses DISTINCT ON for single-pass latest PUC & Insurance.
-- ============================================================
SELECT
    v.vehicle_id,
    v.model_name,
    v.manufacturer,
    v.manufactured_year,
    EXTRACT(YEAR FROM CURRENT_DATE)::int - v.manufactured_year AS vehicle_age,
    v.fuel_type,
    v.body_type,
    v.registration_type,
    v.vehicle_weight,
    v.odometer_reading,
    v.registration_date,
    -- RC Book details
    rc.registration_no,
    rc.plate_number,
    rc.chassis_no,
    rc.engine_no,
    rc.color,
    -- Current owner
    owner_u.user_id AS owner_id,
    owner_u.fname || COALESCE(' ' || owner_u.mname, '') || COALESCE(' ' || owner_u.lname, '') AS owner_name,
    owner_u.phone_number AS owner_phone,
    -- Current condition
    COALESCE(
        (SELECT vl.vehicle_status FROM vehicle_log vl
         WHERE vl.vehicle_id = v.vehicle_id AND vl.end_date IS NULL
         ORDER BY vl.start_date DESC LIMIT 1),
        'Normal'
    ) AS current_condition,
    -- Compliance via DISTINCT ON (latest record per vehicle)
    COALESCE(latest_ins.expiry_date >= CURRENT_DATE, FALSE) AS insurance_active,
    COALESCE(latest_puc.valid_until >= CURRENT_DATE, FALSE) AS puc_active,
    latest_ins.policy_id       AS latest_insurance_policy,
    latest_ins.expiry_date     AS insurance_expiry,
    latest_ins.insurance_company,
    latest_puc.certificate_number AS latest_puc_certificate,
    latest_puc.valid_until     AS puc_valid_until
FROM vehicle v
LEFT JOIN rc_book rc ON v.vehicle_id = rc.vehicle_id
LEFT JOIN ownership o_curr ON v.vehicle_id = o_curr.vehicle_id AND o_curr.to_date IS NULL
LEFT JOIN users owner_u ON o_curr.owner_id = owner_u.user_id
-- Latest insurance (DISTINCT ON — single-pass)
LEFT JOIN (
    SELECT DISTINCT ON (vehicle_id)
        vehicle_id, policy_id, expiry_date, insurance_company
    FROM insurance
    ORDER BY vehicle_id, expiry_date DESC
) latest_ins ON v.vehicle_id = latest_ins.vehicle_id
-- Latest PUC (DISTINCT ON — single-pass)
LEFT JOIN (
    SELECT DISTINCT ON (vehicle_id)
        vehicle_id, certificate_number, valid_until
    FROM puc
    ORDER BY vehicle_id, valid_until DESC
) latest_puc ON v.vehicle_id = latest_puc.vehicle_id
WHERE v.vehicle_id = $1;


-- ============================================================
-- Q28. User Complete Profile Card
--      (All details about a user in one query)
--      PREPARED: $1 = user_id
-- ============================================================
SELECT
    u.user_id,
    u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS full_name,
    u.dob,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, u.dob))::int AS age,
    u.gender,
    u.blood_group,
    u.email,
    u.phone_number,
    u.street || ', ' || u.city || ', ' || u.state || ' - ' || u.pincode AS full_address,
    -- Wallet
    ew.wallet_id,
    ew.balance AS wallet_balance,
    ew.status AS wallet_status,
    -- License
    l.license_no,
    l.license_type,
    l.vehicle_class,
    l.expiry_date AS license_expiry,
    l.status AS license_status,
    -- Vehicle count
    (SELECT COUNT(DISTINCT vehicle_id) FROM ownership WHERE owner_id = u.user_id AND to_date IS NULL) AS current_vehicles,
    (SELECT COUNT(DISTINCT vehicle_id) FROM ownership WHERE owner_id = u.user_id) AS total_vehicles_ever
FROM users u
LEFT JOIN e_wallet ew ON u.user_id = ew.user_id
LEFT JOIN license l ON u.user_id = l.user_id
WHERE u.user_id = $1;


-- ============================================================
-- Q29. Monthly Challan Trend (analytics)
-- ============================================================
SELECT
    TO_CHAR(challan_date, 'YYYY-MM') AS month,
    COUNT(*) AS challans_issued,
    SUM(amount) AS total_fine,
    ROUND(AVG(amount), 2) AS avg_fine,
    COUNT(*) FILTER (WHERE is_paid = TRUE) AS paid_count,
    COUNT(*) FILTER (WHERE is_paid = FALSE) AS unpaid_count
FROM challan
GROUP BY TO_CHAR(challan_date, 'YYYY-MM')
ORDER BY month;


-- ============================================================
-- Q30. Permit Expiring Soon (within next 30 days)
-- ============================================================
SELECT
    p.permit_id,
    p.vehicle_id,
    v.model_name,
    p.permit_type,
    p.expiry_date,
    p.expiry_date - CURRENT_DATE AS days_remaining,
    ARRAY_AGG(pr.authorized_route) FILTER (WHERE pr.authorized_route IS NOT NULL) AS routes
FROM permit p
JOIN vehicle v ON p.vehicle_id = v.vehicle_id
LEFT JOIN permit_route pr ON p.permit_id = pr.permit_id
WHERE p.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
GROUP BY p.permit_id, p.vehicle_id, v.model_name, p.permit_type, p.expiry_date
ORDER BY p.expiry_date;


-- ============================================================
-- Q31. State-wise Challan Revenue Report
-- ============================================================
SELECT
    r.state,
    COUNT(c.challan_id) AS total_challans,
    SUM(c.amount) AS total_revenue,
    SUM(c.amount) FILTER (WHERE c.is_paid = TRUE) AS collected_revenue,
    SUM(c.amount) FILTER (WHERE c.is_paid = FALSE) AS pending_revenue,
    ROUND(100.0 * SUM(c.amount) FILTER (WHERE c.is_paid = TRUE) / NULLIF(SUM(c.amount), 0), 2) AS collection_rate_pct
FROM challan c
JOIN officer o ON c.issuing_officer_id = o.officer_id
JOIN rto r ON o.rto_code = r.rto_code
GROUP BY r.state
ORDER BY total_revenue DESC;


-- ============================================================
-- Q32. Insurance Company Market Share
-- ============================================================
SELECT
    insurance_company,
    COUNT(*) AS policies_issued,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM insurance), 2) AS market_share_pct,
    SUM(coverage_amount) AS total_coverage,
    ROUND(AVG(premium_amount), 2) AS avg_premium,
    SUM(number_of_claims) AS total_claims
FROM insurance
GROUP BY insurance_company
ORDER BY policies_issued DESC;


-- ============================================================
-- Q33. Vehicles with No Current Owner (unregistered / transferred)
-- ============================================================
SELECT
    v.vehicle_id,
    v.model_name,
    v.manufacturer,
    v.registration_date,
    MAX(o.to_date) AS last_ownership_ended
FROM vehicle v
LEFT JOIN ownership o ON v.vehicle_id = o.vehicle_id
GROUP BY v.vehicle_id, v.model_name, v.manufacturer, v.registration_date
HAVING BOOL_AND(o.to_date IS NOT NULL)        -- all ownerships have ended
    OR COUNT(o.ownership_id) = 0              -- never had any ownership
ORDER BY last_ownership_ended DESC NULLS LAST;
