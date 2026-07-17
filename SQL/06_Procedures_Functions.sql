-- ============================================================
-- UNIFIED VEHICLE REGISTRY — STORED PROCEDURES & FUNCTIONS
-- ============================================================
-- Database  : PostgreSQL 15+
-- Project   : Unified Vehicle Registry (DBMS Project)
-- Author    : Auto-generated
-- Created   : 2026-07-08
-- ============================================================

-- ############################################################
--                        FUNCTIONS
-- ############################################################

-- ============================================================
-- 1. fn_get_user_age(p_user_id)
--    Returns the age (in whole years) of a user based on DOB.
-- ============================================================
DROP FUNCTION IF EXISTS fn_get_user_age(char);

CREATE OR REPLACE FUNCTION fn_get_user_age(p_user_id char(12))
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    v_dob date;
BEGIN
    -- Fetch date-of-birth for the given user
    SELECT dob INTO v_dob
    FROM users
    WHERE user_id = p_user_id;

    -- Validate user exists
    IF v_dob IS NULL THEN
        RAISE EXCEPTION 'User with ID "%" does not exist.', p_user_id;
    END IF;

    -- AGE() returns an interval; EXTRACT(YEAR ...) gives whole years
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, v_dob))::int;
END;
$$;

-- EXAMPLE: SELECT fn_get_user_age('USR000000001');
-- EXAMPLE: SELECT user_id, fname, fn_get_user_age(user_id) AS age FROM users LIMIT 5;


-- ============================================================
-- 2. fn_calculate_wallet_balance(p_wallet_id)
--    Derives the wallet balance from all successful transactions.
--    Debits  = sum of amounts where this wallet is from_wallet_id
--    Credits = sum of amounts where this wallet is to_wallet_id
--    Useful for audit / reconciliation against stored balance.
-- ============================================================
DROP FUNCTION IF EXISTS fn_calculate_wallet_balance(int);

CREATE OR REPLACE FUNCTION fn_calculate_wallet_balance(p_wallet_id int)
RETURNS numeric(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_debits  numeric(12,2);
    v_credits numeric(12,2);
    v_exists  boolean;
BEGIN
    -- Validate wallet exists
    SELECT EXISTS(SELECT 1 FROM e_wallet WHERE wallet_id = p_wallet_id) INTO v_exists;
    IF NOT v_exists THEN
        RAISE EXCEPTION 'Wallet with ID % does not exist.', p_wallet_id;
    END IF;

    -- Sum all successful debits (money going OUT of this wallet)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_debits
    FROM wallet_transaction
    WHERE from_wallet_id = p_wallet_id
      AND status = 'Success';

    -- Sum all successful credits (money coming IN to this wallet)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_credits
    FROM wallet_transaction
    WHERE to_wallet_id = p_wallet_id
      AND status = 'Success';

    -- Derived balance = credits received minus debits sent
    -- Note: This is a derived view; actual starting balance is not tracked
    -- in transactions, so this shows net transaction flow.
    RETURN (v_credits - v_debits);
END;
$$;

-- EXAMPLE: SELECT fn_calculate_wallet_balance(3);
-- EXAMPLE: SELECT w.wallet_id, w.balance AS stored_balance, fn_calculate_wallet_balance(w.wallet_id) AS derived_balance FROM e_wallet w LIMIT 10;


-- ============================================================
-- 3. fn_is_vehicle_compliant(p_vehicle_id)
--    Returns TRUE if the vehicle has BOTH:
--      (a) An active insurance policy (expiry_date >= CURRENT_DATE)
--      (b) An active PUC certificate   (valid_until >= CURRENT_DATE)
-- ============================================================
DROP FUNCTION IF EXISTS fn_is_vehicle_compliant(varchar);

CREATE OR REPLACE FUNCTION fn_is_vehicle_compliant(p_vehicle_id varchar(17))
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_vehicle_exists boolean;
    v_has_insurance  boolean;
    v_has_puc        boolean;
BEGIN
    -- Validate vehicle exists
    SELECT EXISTS(SELECT 1 FROM vehicle WHERE vehicle_id = p_vehicle_id)
    INTO v_vehicle_exists;

    IF NOT v_vehicle_exists THEN
        RAISE EXCEPTION 'Vehicle with ID "%" does not exist.', p_vehicle_id;
    END IF;

    -- Check for at least one active (non-expired) insurance policy
    SELECT EXISTS(
        SELECT 1 FROM insurance
        WHERE vehicle_id = p_vehicle_id
          AND expiry_date >= CURRENT_DATE
    ) INTO v_has_insurance;

    -- Check for at least one active (non-expired) PUC certificate
    SELECT EXISTS(
        SELECT 1 FROM puc
        WHERE vehicle_id = p_vehicle_id
          AND valid_until >= CURRENT_DATE
    ) INTO v_has_puc;

    RETURN v_has_insurance AND v_has_puc;
END;
$$;

-- EXAMPLE: SELECT fn_is_vehicle_compliant('T10GR7BXRE6W3HJCC');
-- EXAMPLE: SELECT v.vehicle_id, v.model_name, fn_is_vehicle_compliant(v.vehicle_id) AS compliant FROM vehicle v LIMIT 10;


-- ============================================================
-- 4. fn_get_ownership_duration(p_ownership_id)
--    Returns an INTERVAL representing how long the ownership
--    lasted (if ended) or has lasted so far (if ongoing).
-- ============================================================
DROP FUNCTION IF EXISTS fn_get_ownership_duration(int);

CREATE OR REPLACE FUNCTION fn_get_ownership_duration(p_ownership_id int)
RETURNS interval
LANGUAGE plpgsql
AS $$
DECLARE
    v_from   date;
    v_to     date;
BEGIN
    -- Fetch ownership dates
    SELECT from_date, to_date
    INTO v_from, v_to
    FROM ownership
    WHERE ownership_id = p_ownership_id;

    -- Validate ownership record exists
    IF v_from IS NULL THEN
        RAISE EXCEPTION 'Ownership with ID % does not exist.', p_ownership_id;
    END IF;

    -- If ownership is still active (to_date IS NULL), measure until today
    IF v_to IS NULL THEN
        RETURN AGE(CURRENT_DATE, v_from);
    ELSE
        RETURN AGE(v_to, v_from);
    END IF;
END;
$$;

-- EXAMPLE: SELECT fn_get_ownership_duration(1);
-- EXAMPLE: SELECT ownership_id, vehicle_id, owner_id, fn_get_ownership_duration(ownership_id) AS duration FROM ownership LIMIT 10;


-- ============================================================
-- 5. fn_count_active_challans(p_vehicle_id)
--    Returns the count of unpaid challans for a vehicle.
-- ============================================================
DROP FUNCTION IF EXISTS fn_count_active_challans(varchar);

CREATE OR REPLACE FUNCTION fn_count_active_challans(p_vehicle_id varchar(17))
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    v_count          int;
    v_vehicle_exists boolean;
BEGIN
    -- Validate vehicle exists
    SELECT EXISTS(SELECT 1 FROM vehicle WHERE vehicle_id = p_vehicle_id)
    INTO v_vehicle_exists;

    IF NOT v_vehicle_exists THEN
        RAISE EXCEPTION 'Vehicle with ID "%" does not exist.', p_vehicle_id;
    END IF;

    -- Count challans that have not been paid
    SELECT COUNT(*)
    INTO v_count
    FROM challan
    WHERE vehicle_id = p_vehicle_id
      AND is_paid = false;

    RETURN v_count;
END;
$$;

-- EXAMPLE: SELECT fn_count_active_challans('T10GR7BXRE6W3HJCC');
-- EXAMPLE: SELECT DISTINCT c.vehicle_id, fn_count_active_challans(c.vehicle_id) AS unpaid FROM challan c WHERE c.is_paid = false;


-- ############################################################
--                       PROCEDURES
-- ############################################################

-- ============================================================
-- 6. sp_transfer_vehicle_ownership
--    Atomically transfers ownership of a vehicle:
--      1. Validates the old owner currently owns the vehicle
--         (active ownership with to_date IS NULL).
--      2. Ends the old ownership (sets to_date = today).
--      3. Creates a new ownership record for the new owner.
--    Uses EXCEPTION block to roll back on any failure.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_transfer_vehicle_ownership(varchar, char, char);

CREATE OR REPLACE PROCEDURE sp_transfer_vehicle_ownership(
    p_vehicle_id   varchar(17),
    p_old_owner_id char(12),
    p_new_owner_id char(12)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ownership_id int;
BEGIN
    -- Validate: old owner and new owner must be different
    IF p_old_owner_id = p_new_owner_id THEN
        RAISE EXCEPTION 'Old owner and new owner cannot be the same (%).', p_old_owner_id;
    END IF;

    -- Validate: vehicle exists
    IF NOT EXISTS(SELECT 1 FROM vehicle WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle "%" does not exist.', p_vehicle_id;
    END IF;

    -- Validate: new owner exists
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id = p_new_owner_id) THEN
        RAISE EXCEPTION 'New owner "%" does not exist in users table.', p_new_owner_id;
    END IF;

    -- Validate: old owner currently owns this vehicle (active ownership)
    SELECT ownership_id INTO v_ownership_id
    FROM ownership
    WHERE vehicle_id = p_vehicle_id
      AND owner_id   = p_old_owner_id
      AND to_date IS NULL;

    IF v_ownership_id IS NULL THEN
        RAISE EXCEPTION 'User "%" does not have an active ownership of vehicle "%".',
            p_old_owner_id, p_vehicle_id;
    END IF;

    -- Step 1: End the old ownership
    UPDATE ownership
    SET to_date = CURRENT_DATE
    WHERE ownership_id = v_ownership_id;

    -- Step 2: Create new ownership record
    INSERT INTO ownership (vehicle_id, owner_id, from_date, to_date)
    VALUES (p_vehicle_id, p_new_owner_id, CURRENT_DATE, NULL);

    RAISE NOTICE 'Ownership of vehicle "%" transferred from "%" to "%" successfully.',
        p_vehicle_id, p_old_owner_id, p_new_owner_id;

EXCEPTION
    WHEN OTHERS THEN
        -- Re-raise the exception so the calling transaction is aware
        RAISE EXCEPTION 'Ownership transfer failed: %', SQLERRM;
END;
$$;

-- EXAMPLE: CALL sp_transfer_vehicle_ownership('T10GR7BXRE6W3HJCC', 'USR000000048', 'USR000000003');


-- ============================================================
-- 7. sp_pay_challan_via_wallet
--    Pays an outstanding challan using a wallet:
--      1. Validates challan exists and is unpaid.
--      2. Validates wallet exists, is Active, and has
--         sufficient balance.
--      3. Creates a wallet_transaction (purpose = 'challan').
--      4. Updates challan: sets is_paid = TRUE and links
--         the wallet_transaction_id.
--    All within a single transaction with EXCEPTION handling.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_pay_challan_via_wallet(int, int);

CREATE OR REPLACE PROCEDURE sp_pay_challan_via_wallet(
    p_challan_id int,
    p_wallet_id  int
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_challan_amount  numeric(10,2);
    v_wallet_balance  numeric(12,2);
    v_wallet_status   varchar(10);
    v_is_paid         boolean;
    v_transaction_id  int;
BEGIN
    -- Step 1: Validate challan exists and fetch details
    SELECT amount, is_paid INTO v_challan_amount, v_is_paid
    FROM challan
    WHERE challan_id = p_challan_id;

    IF v_challan_amount IS NULL THEN
        RAISE EXCEPTION 'Challan with ID % does not exist.', p_challan_id;
    END IF;

    IF v_is_paid THEN
        RAISE EXCEPTION 'Challan % is already paid.', p_challan_id;
    END IF;

    -- Step 2: Validate wallet exists, is active, and has funds
    SELECT balance, status INTO v_wallet_balance, v_wallet_status
    FROM e_wallet
    WHERE wallet_id = p_wallet_id;

    IF v_wallet_status IS NULL THEN
        RAISE EXCEPTION 'Wallet with ID % does not exist.', p_wallet_id;
    END IF;

    IF v_wallet_status <> 'Active' THEN
        RAISE EXCEPTION 'Wallet % is not active (current status: %).', p_wallet_id, v_wallet_status;
    END IF;

    IF v_wallet_balance < v_challan_amount THEN
        RAISE EXCEPTION 'Insufficient wallet balance. Required: %, Available: %.',
            v_challan_amount, v_wallet_balance;
    END IF;

    -- Step 3: Create wallet transaction (challan payments go to NULL to_wallet)
    INSERT INTO wallet_transaction (from_wallet_id, to_wallet_id, amount, purpose, tran_datetime, status)
    VALUES (p_wallet_id, NULL, v_challan_amount, 'challan', NOW(), 'Success')
    RETURNING transaction_id INTO v_transaction_id;

    -- Step 4: Mark challan as paid and link the transaction
    UPDATE challan
    SET is_paid = true,
        wallet_transaction_id = v_transaction_id
    WHERE challan_id = p_challan_id;

    RAISE NOTICE 'Challan % paid successfully via wallet %. Transaction ID: %. Amount: %.',
        p_challan_id, p_wallet_id, v_transaction_id, v_challan_amount;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Challan payment failed: %', SQLERRM;
END;
$$;

-- EXAMPLE: CALL sp_pay_challan_via_wallet(1, 3);


-- ============================================================
-- 8. sp_renew_insurance
--    Creates a new insurance policy for a vehicle.
--    The expiry date is calculated from the issue date (today)
--    plus the specified duration in months.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_renew_insurance(varchar, varchar, varchar, varchar, numeric, numeric, int);

CREATE OR REPLACE PROCEDURE sp_renew_insurance(
    p_vehicle_id        varchar(17),
    p_new_policy_id     varchar(30),
    p_insurance_company varchar(100),
    p_insurance_type    varchar(15),
    p_coverage_amount   numeric(12,2),
    p_premium_amount    numeric(10,2),
    p_duration_months   int
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_issue_date  date := CURRENT_DATE;
    v_expiry_date date;
BEGIN
    -- Validate vehicle exists
    IF NOT EXISTS(SELECT 1 FROM vehicle WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle "%" does not exist.', p_vehicle_id;
    END IF;

    -- Validate insurance type
    IF p_insurance_type NOT IN ('Third-party', 'Comprehensive', 'Own-damage') THEN
        RAISE EXCEPTION 'Invalid insurance type "%". Must be Third-party, Comprehensive, or Own-damage.',
            p_insurance_type;
    END IF;

    -- Validate duration
    IF p_duration_months <= 0 THEN
        RAISE EXCEPTION 'Duration must be a positive number of months. Got: %.', p_duration_months;
    END IF;

    -- Validate amounts
    IF p_coverage_amount <= 0 THEN
        RAISE EXCEPTION 'Coverage amount must be positive. Got: %.', p_coverage_amount;
    END IF;
    IF p_premium_amount <= 0 THEN
        RAISE EXCEPTION 'Premium amount must be positive. Got: %.', p_premium_amount;
    END IF;

    -- Validate policy ID is not already in use
    IF EXISTS(SELECT 1 FROM insurance WHERE policy_id = p_new_policy_id) THEN
        RAISE EXCEPTION 'Policy ID "%" already exists.', p_new_policy_id;
    END IF;

    -- Calculate expiry date
    v_expiry_date := v_issue_date + (p_duration_months || ' months')::interval;

    -- Insert the new insurance policy
    INSERT INTO insurance (
        policy_id, vehicle_id, issue_date, expiry_date,
        coverage_amount, insurance_type, premium_amount,
        number_of_claims, insurance_company
    ) VALUES (
        p_new_policy_id, p_vehicle_id, v_issue_date, v_expiry_date,
        p_coverage_amount, p_insurance_type, p_premium_amount,
        0, p_insurance_company
    );

    RAISE NOTICE 'Insurance policy "%" created for vehicle "%". Valid: % to %.',
        p_new_policy_id, p_vehicle_id, v_issue_date, v_expiry_date;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Insurance renewal failed: %', SQLERRM;
END;
$$;

-- EXAMPLE: CALL sp_renew_insurance('T10GR7BXRE6W3HJCC', 'INS-NEW-2026-001', 'ICICI Lombard', 'Comprehensive', 500000.00, 12000.00, 12);


-- ============================================================
-- 9. sp_issue_challan
--    Issues a new traffic challan against a vehicle.
--    Validates the vehicle and officer exist before creation.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_issue_challan(varchar, int, numeric, varchar, varchar);

CREATE OR REPLACE PROCEDURE sp_issue_challan(
    p_vehicle_id  varchar(17),
    p_officer_id  int,
    p_amount      numeric(10,2),
    p_reason      varchar(200),
    p_location    varchar(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_challan_id int;
BEGIN
    -- Validate vehicle exists
    IF NOT EXISTS(SELECT 1 FROM vehicle WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle "%" does not exist.', p_vehicle_id;
    END IF;

    -- Validate officer exists
    IF NOT EXISTS(SELECT 1 FROM officer WHERE officer_id = p_officer_id) THEN
        RAISE EXCEPTION 'Officer with ID % does not exist.', p_officer_id;
    END IF;

    -- Validate amount
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Challan amount must be positive. Got: %.', p_amount;
    END IF;

    -- Validate reason is not empty
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'Challan reason cannot be empty.';
    END IF;

    -- Validate location is not empty
    IF p_location IS NULL OR TRIM(p_location) = '' THEN
        RAISE EXCEPTION 'Challan location cannot be empty.';
    END IF;

    -- Insert the new challan (unpaid by default)
    INSERT INTO challan (vehicle_id, issuing_officer_id, amount, reason, challan_date, location, is_paid)
    VALUES (p_vehicle_id, p_officer_id, p_amount, p_reason, CURRENT_DATE, p_location, false)
    RETURNING challan_id INTO v_challan_id;

    RAISE NOTICE 'Challan #% issued to vehicle "%" for %. Reason: %. Location: %.',
        v_challan_id, p_vehicle_id, p_amount, p_reason, p_location;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Challan issuance failed: %', SQLERRM;
END;
$$;

-- EXAMPLE: CALL sp_issue_challan('T10GR7BXRE6W3HJCC', 1, 2000.00, 'Over-speeding on highway', 'SG Highway, Ahmedabad');


-- ============================================================
-- 10. sp_block_wallet
--     Blocks a wallet by changing its status to 'Blocked'.
--     Validates the wallet exists and is currently Active.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_block_wallet(int, varchar);

CREATE OR REPLACE PROCEDURE sp_block_wallet(
    p_wallet_id int,
    p_reason    varchar(200)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_status varchar(10);
    v_user_id        char(12);
BEGIN
    -- Fetch current wallet details
    SELECT status, user_id INTO v_current_status, v_user_id
    FROM e_wallet
    WHERE wallet_id = p_wallet_id;

    -- Validate wallet exists
    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'Wallet with ID % does not exist.', p_wallet_id;
    END IF;

    -- Validate wallet is currently Active
    IF v_current_status = 'Blocked' THEN
        RAISE EXCEPTION 'Wallet % is already blocked.', p_wallet_id;
    END IF;

    IF v_current_status = 'Closed' THEN
        RAISE EXCEPTION 'Wallet % is closed and cannot be blocked.', p_wallet_id;
    END IF;

    -- Block the wallet
    UPDATE e_wallet
    SET status = 'Blocked'
    WHERE wallet_id = p_wallet_id;

    RAISE NOTICE 'Wallet % (user: %) has been blocked. Reason: %.',
        p_wallet_id, v_user_id, p_reason;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Wallet blocking failed: %', SQLERRM;
END;
$$;

-- EXAMPLE: CALL sp_block_wallet(3, 'Suspicious transaction activity detected');


-- ============================================================
-- END OF FILE
-- ============================================================
