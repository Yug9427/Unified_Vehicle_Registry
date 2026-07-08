-- ============================================================
-- UNIFIED VEHICLE REGISTRY — TRIGGERS
-- ============================================================
-- Database  : PostgreSQL 15+
-- Project   : Unified Vehicle Registry (DBMS Project)
-- Author    : Auto-generated
-- Created   : 2026-07-08
-- ============================================================


-- ############################################################
-- 1. trg_wallet_balance_update
--    AFTER INSERT on wallet_transaction
--    When a new transaction with status = 'Success' is inserted:
--      • Deduct the amount from the from_wallet balance
--      • Credit the amount to the to_wallet balance (if not NULL)
--    If to_wallet_id IS NULL (e.g., toll/fuel/challan payments
--    to external entities), only the debit side is applied.
-- ############################################################
DROP TRIGGER IF EXISTS trg_wallet_balance_update ON wallet_transaction;
DROP FUNCTION IF EXISTS fn_trg_wallet_balance_update();

CREATE OR REPLACE FUNCTION fn_trg_wallet_balance_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only process successful transactions
    IF NEW.status = 'Success' THEN

        -- Deduct from the sender's wallet
        UPDATE e_wallet
        SET balance = balance - NEW.amount
        WHERE wallet_id = NEW.from_wallet_id;

        -- Credit to the receiver's wallet (if applicable)
        -- NULL to_wallet_id indicates external payment (toll, fuel, challan)
        IF NEW.to_wallet_id IS NOT NULL THEN
            UPDATE e_wallet
            SET balance = balance + NEW.amount
            WHERE wallet_id = NEW.to_wallet_id;
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_wallet_balance_update
    AFTER INSERT ON wallet_transaction
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_wallet_balance_update();

-- TEST SCENARIOS:
-- 1. Successful wallet-to-wallet refund (both wallets updated):
--    INSERT INTO wallet_transaction (from_wallet_id, to_wallet_id, amount, purpose, status)
--    VALUES (3, 5, 500.00, 'refund', 'Success');
--    -- Verify: wallet 3 balance decreased by 500, wallet 5 balance increased by 500

-- 2. Successful toll payment to external (only debit):
--    INSERT INTO wallet_transaction (from_wallet_id, to_wallet_id, amount, purpose, status)
--    VALUES (3, NULL, 120.00, 'toll', 'Success');
--    -- Verify: wallet 3 balance decreased by 120, no credit anywhere

-- 3. Failed transaction (no balance change):
--    INSERT INTO wallet_transaction (from_wallet_id, to_wallet_id, amount, purpose, status)
--    VALUES (3, 5, 1000.00, 'refund', 'Failed');
--    -- Verify: no balance changes on either wallet


-- ############################################################
-- 2. trg_prevent_double_ownership
--    BEFORE INSERT on ownership
--    Prevents creating a new active ownership for a vehicle
--    that already has an active owner (to_date IS NULL).
--    This enforces the business rule that a vehicle can have
--    only one active owner at any time.
-- ############################################################
DROP TRIGGER IF EXISTS trg_prevent_double_ownership ON ownership;
DROP FUNCTION IF EXISTS fn_trg_prevent_double_ownership();

CREATE OR REPLACE FUNCTION fn_trg_prevent_double_ownership()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_owner char(12);
BEGIN
    -- Only check if the new record is an active ownership (no end date)
    IF NEW.to_date IS NULL THEN
        SELECT owner_id INTO v_existing_owner
        FROM ownership
        WHERE vehicle_id = NEW.vehicle_id
          AND to_date IS NULL
        LIMIT 1;

        IF v_existing_owner IS NOT NULL THEN
            RAISE EXCEPTION 'Vehicle "%" already has an active owner (%). '
                'End the existing ownership before assigning a new one.',
                NEW.vehicle_id, v_existing_owner;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_double_ownership
    BEFORE INSERT ON ownership
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_prevent_double_ownership();

-- TEST SCENARIOS:
-- 1. Attempt double active ownership (should FAIL):
--    INSERT INTO ownership (vehicle_id, owner_id, from_date, to_date)
--    VALUES ('T10GR7BXRE6W3HJCC', 'USR000000003', CURRENT_DATE, NULL);
--    -- Should raise: "Vehicle already has an active owner"

-- 2. Insert historical (closed) ownership (should SUCCEED):
--    INSERT INTO ownership (vehicle_id, owner_id, from_date, to_date)
--    VALUES ('T10GR7BXRE6W3HJCC', 'USR000000003', '2020-01-01', '2020-06-01');
--    -- Should succeed since to_date is set


-- ############################################################
-- 3. fn_refresh_license_statuses
--    Callable function (not a trigger — PostgreSQL does not
--    support BEFORE SELECT triggers).
--    Updates all licenses where expiry_date < CURRENT_DATE
--    AND status = 'Active' → sets status to 'Expired'.
--    Designed to be called periodically (e.g., via pg_cron
--    or application-level scheduler).
-- ############################################################
DROP FUNCTION IF EXISTS fn_refresh_license_statuses();

CREATE OR REPLACE FUNCTION fn_refresh_license_statuses()
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated_count int;
BEGIN
    -- Find all active licenses past their expiry date and mark them expired
    UPDATE license
    SET status = 'Expired'
    WHERE expiry_date < CURRENT_DATE
      AND status = 'Active';

    -- Get count of affected rows
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    IF v_updated_count > 0 THEN
        RAISE NOTICE '% license(s) marked as Expired.', v_updated_count;
    ELSE
        RAISE NOTICE 'No licenses needed status update.';
    END IF;

    RETURN v_updated_count;
END;
$$;

-- TEST SCENARIOS:
-- 1. Run the refresh:
--    SELECT fn_refresh_license_statuses();
--    -- Check updated count in NOTICE output

-- 2. Verify results:
--    SELECT license_no, expiry_date, status FROM license
--    WHERE expiry_date < CURRENT_DATE;
--    -- All should show status = 'Expired'


-- ############################################################
-- 4. trg_audit_ownership_changes
--    Audit trail for all changes to the ownership table.
--    First creates the audit_log table, then attaches a trigger
--    that fires AFTER INSERT, UPDATE, or DELETE on ownership.
--    Stores old/new row data as JSONB for complete traceability.
-- ############################################################

-- Create the audit log table (idempotent)
CREATE TABLE IF NOT EXISTS audit_log (
    id          serial       PRIMARY KEY,
    table_name  varchar(100) NOT NULL,
    operation   varchar(10)  NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    old_data    jsonb,
    new_data    jsonb,
    changed_at  timestamp    NOT NULL DEFAULT NOW(),
    changed_by  text         NOT NULL DEFAULT current_user
);

DROP TRIGGER IF EXISTS trg_audit_ownership_changes ON ownership;
DROP FUNCTION IF EXISTS fn_trg_audit_ownership_changes();

CREATE OR REPLACE FUNCTION fn_trg_audit_ownership_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, old_data, new_data)
        VALUES ('ownership', 'INSERT', NULL, to_jsonb(NEW));

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, old_data, new_data)
        VALUES ('ownership', 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, old_data, new_data)
        VALUES ('ownership', 'DELETE', to_jsonb(OLD), NULL);

    END IF;

    -- Return appropriate row depending on operation
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

CREATE TRIGGER trg_audit_ownership_changes
    AFTER INSERT OR UPDATE OR DELETE ON ownership
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_audit_ownership_changes();

-- TEST SCENARIOS:
-- 1. Insert a new ownership and check audit:
--    INSERT INTO ownership (vehicle_id, owner_id, from_date)
--    VALUES ('998W7B0YH3WB7TRD7', 'USR000000003', CURRENT_DATE);
--    SELECT * FROM audit_log WHERE table_name = 'ownership' ORDER BY id DESC LIMIT 1;

-- 2. Update an ownership and check audit:
--    UPDATE ownership SET to_date = CURRENT_DATE WHERE ownership_id = 1;
--    SELECT * FROM audit_log WHERE table_name = 'ownership' AND operation = 'UPDATE' ORDER BY id DESC LIMIT 1;

-- 3. Delete an ownership and check audit:
--    DELETE FROM ownership WHERE ownership_id = 999;  -- use a test ID
--    SELECT * FROM audit_log WHERE table_name = 'ownership' AND operation = 'DELETE' ORDER BY id DESC LIMIT 1;


-- ############################################################
-- 5. trg_validate_challan_payment
--    BEFORE UPDATE on challan
--    When is_paid changes from FALSE to TRUE, ensures that
--    wallet_transaction_id is NOT NULL. This enforces the rule
--    that a challan cannot be marked as paid without a
--    corresponding payment transaction.
-- ############################################################
DROP TRIGGER IF EXISTS trg_validate_challan_payment ON challan;
DROP FUNCTION IF EXISTS fn_trg_validate_challan_payment();

CREATE OR REPLACE FUNCTION fn_trg_validate_challan_payment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only validate when is_paid transitions from false to true
    IF OLD.is_paid = false AND NEW.is_paid = true THEN
        IF NEW.wallet_transaction_id IS NULL THEN
            RAISE EXCEPTION 'Cannot mark challan #% as paid without a wallet_transaction_id. '
                'A valid payment transaction must be linked.',
                NEW.challan_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_challan_payment
    BEFORE UPDATE ON challan
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_validate_challan_payment();

-- TEST SCENARIOS:
-- 1. Try to mark challan paid without transaction (should FAIL):
--    UPDATE challan SET is_paid = true WHERE challan_id = 1;
--    -- Should raise: "Cannot mark challan as paid without a wallet_transaction_id"

-- 2. Mark challan paid WITH transaction (should SUCCEED):
--    UPDATE challan SET is_paid = true, wallet_transaction_id = 1 WHERE challan_id = 1;
--    -- Should succeed if transaction_id 1 exists and challan has no linked transaction yet


-- ############################################################
-- 6. trg_update_timestamp
--    A generic 'updated_at' trigger pattern.
--    Demonstrates how to automatically set an updated_at
--    column to the current timestamp on every UPDATE.
--
--    Usage pattern: add an `updated_at` column to any table,
--    then attach this trigger. Example shown with `e_wallet`.
-- ############################################################

-- Step 1: Add the updated_at column to e_wallet (if not present)
ALTER TABLE e_wallet
    ADD COLUMN IF NOT EXISTS updated_at timestamp DEFAULT NOW();

DROP TRIGGER IF EXISTS trg_update_timestamp_ewallet ON e_wallet;
DROP FUNCTION IF EXISTS fn_trg_update_timestamp();

CREATE OR REPLACE FUNCTION fn_trg_update_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Automatically set updated_at to current timestamp on every UPDATE
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- Attach to e_wallet as a demonstration
CREATE TRIGGER trg_update_timestamp_ewallet
    BEFORE UPDATE ON e_wallet
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_update_timestamp();

-- This generic function can be reused on any table with an updated_at column.
-- Simply create a new trigger pointing to fn_trg_update_timestamp():
--
--   ALTER TABLE vehicle ADD COLUMN IF NOT EXISTS updated_at timestamp DEFAULT NOW();
--   CREATE TRIGGER trg_update_timestamp_vehicle
--       BEFORE UPDATE ON vehicle
--       FOR EACH ROW
--       EXECUTE FUNCTION fn_trg_update_timestamp();

-- TEST SCENARIOS:
-- 1. Update wallet balance and check timestamp:
--    UPDATE e_wallet SET balance = balance + 100 WHERE wallet_id = 3;
--    SELECT wallet_id, balance, updated_at FROM e_wallet WHERE wallet_id = 3;
--    -- updated_at should reflect current timestamp

-- 2. Multiple rapid updates:
--    UPDATE e_wallet SET balance = balance - 50 WHERE wallet_id = 3;
--    UPDATE e_wallet SET balance = balance + 25 WHERE wallet_id = 3;
--    SELECT wallet_id, balance, updated_at FROM e_wallet WHERE wallet_id = 3;
--    -- updated_at should match the last update time


-- ############################################################
-- 7. trg_prevent_scrapped_vehicle_ops
--    BEFORE INSERT on ownership, insurance, and permit
--    Checks if the vehicle has an active 'Scrapped' status in
--    vehicle_log (vehicle_status = 'Scrapped' AND end_date IS NULL).
--    Prevents new ownership, insurance, or permit records for
--    scrapped vehicles.
-- ############################################################
DROP TRIGGER IF EXISTS trg_prevent_scrapped_vehicle_ownership ON ownership;
DROP TRIGGER IF EXISTS trg_prevent_scrapped_vehicle_insurance ON insurance;
DROP TRIGGER IF EXISTS trg_prevent_scrapped_vehicle_permit ON permit;
DROP FUNCTION IF EXISTS fn_trg_prevent_scrapped_vehicle_ops();

CREATE OR REPLACE FUNCTION fn_trg_prevent_scrapped_vehicle_ops()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_scrapped boolean;
BEGIN
    -- Check if the vehicle has an active 'Scrapped' status
    SELECT EXISTS(
        SELECT 1 FROM vehicle_log
        WHERE vehicle_id = NEW.vehicle_id
          AND vehicle_status = 'Scrapped'
          AND end_date IS NULL
    ) INTO v_is_scrapped;

    IF v_is_scrapped THEN
        RAISE EXCEPTION 'Vehicle "%" is scrapped. Cannot create new % records for scrapped vehicles.',
            NEW.vehicle_id, TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$;

-- Attach to ownership table
CREATE TRIGGER trg_prevent_scrapped_vehicle_ownership
    BEFORE INSERT ON ownership
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_prevent_scrapped_vehicle_ops();

-- Attach to insurance table
CREATE TRIGGER trg_prevent_scrapped_vehicle_insurance
    BEFORE INSERT ON insurance
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_prevent_scrapped_vehicle_ops();

-- Attach to permit table
CREATE TRIGGER trg_prevent_scrapped_vehicle_permit
    BEFORE INSERT ON permit
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_prevent_scrapped_vehicle_ops();

-- TEST SCENARIOS:
-- 1. First, scrap a vehicle:
--    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date)
--    VALUES ('5HP8F95D6J936D6WB', 'Scrapped', CURRENT_DATE);

-- 2. Attempt new ownership for scrapped vehicle (should FAIL):
--    INSERT INTO ownership (vehicle_id, owner_id, from_date)
--    VALUES ('5HP8F95D6J936D6WB', 'USR000000003', CURRENT_DATE);
--    -- Should raise: "Vehicle is scrapped. Cannot create new ownership records"

-- 3. Attempt new insurance for scrapped vehicle (should FAIL):
--    INSERT INTO insurance (policy_id, vehicle_id, issue_date, expiry_date,
--        coverage_amount, insurance_type, premium_amount, insurance_company)
--    VALUES ('INS-TEST-001', '5HP8F95D6J936D6WB', CURRENT_DATE,
--        CURRENT_DATE + INTERVAL '1 year', 500000, 'Comprehensive', 12000, 'Test Co');
--    -- Should raise: "Vehicle is scrapped. Cannot create new insurance records"

-- 4. Non-scrapped vehicle operations should succeed normally.


-- ============================================================
-- END OF FILE
-- ============================================================
