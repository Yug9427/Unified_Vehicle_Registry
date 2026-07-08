-- ═══════════════════════════════════════════════════════════════
-- UNIFIED VEHICLE REGISTRY – TRANSACTION DEMONSTRATIONS
-- ═══════════════════════════════════════════════════════════════
-- Run this file AFTER DDL.sql and Insert_data.sql
-- ═══════════════════════════════════════════════════════════════
--
-- This file demonstrates PostgreSQL transaction concepts:
--   1. Basic COMMIT / ROLLBACK
--   2. Multi-statement ownership transfer
--   3. Challan payment workflow with wallet
--   4. SAVEPOINTs for partial rollback
--   5. Isolation levels (READ COMMITTED vs SERIALIZABLE)
--   6. Deadlock scenario and resolution
--   7. Batch insert performance with transactions
--
-- IMPORTANT: Each demo is self-contained.  Demos that modify
-- data use ROLLBACK at the end to leave the database unchanged,
-- unless explicitly noted.  To actually persist changes, replace
-- ROLLBACK with COMMIT.
-- ═══════════════════════════════════════════════════════════════


-- ████████████████████████████████████████████████████████████████
-- TXN 1 : BASIC COMMIT / ROLLBACK
-- ████████████████████████████████████████████████████████████████
-- Demonstrates the two possible outcomes of a transaction:
--   Path A: All statements succeed → COMMIT
--   Path B: Something goes wrong  → ROLLBACK
-- ──────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Path A: Successful Transaction (COMMIT)
-- ─────────────────────────────────────────────────────────────
-- This inserts a new user and a new vehicle, then commits both.
-- After COMMIT, both rows are permanently visible to all sessions.

BEGIN;

    -- Step 1: Insert a new user
    INSERT INTO users (user_id, password, fname, lname, dob, gender, phone_number, city, state, pincode)
    VALUES ('USR000000099', 'pbkdf2$demo_password_hash', 'Demo', 'User', '1995-06-15', 'Male', '9999999901', 'Mumbai', 'Maharashtra', '400001');

    -- Step 2: Insert a new vehicle
    INSERT INTO vehicle (vehicle_id, model_name, vehicle_weight, manufacturer, manufactured_year, registration_type, fuel_type, registration_date)
    VALUES ('DEMO00000000001AA', 'Demo Car', 1200, 'Tata', 2024, 'Non-transport', 'Petrol', '2024-01-15');

    -- Step 3: Verify — both rows exist within this transaction
    -- (Other sessions cannot see these until COMMIT)
    SELECT 'User created' AS status, user_id, fname FROM users WHERE user_id = 'USR000000099';
    SELECT 'Vehicle created' AS status, vehicle_id, model_name FROM vehicle WHERE vehicle_id = 'DEMO00000000001AA';

-- COMMIT;  -- Would make changes permanent
ROLLBACK;   -- Rolling back to keep demo data clean


-- ─────────────────────────────────────────────────────────────
-- Path B: Failed Transaction (ROLLBACK)
-- ─────────────────────────────────────────────────────────────
-- Same operations, but we intentionally ROLLBACK.
-- After ROLLBACK, neither the user nor the vehicle exists.

BEGIN;

    INSERT INTO users (user_id, password, fname, lname, dob, gender, phone_number, city, state, pincode)
    VALUES ('USR000000098', 'pbkdf2$another_hash', 'Rollback', 'Test', '1990-01-01', 'Female', '9999999902', 'Pune', 'Maharashtra', '411001');

    INSERT INTO vehicle (vehicle_id, model_name, vehicle_weight, manufacturer, manufactured_year, registration_type, fuel_type, registration_date)
    VALUES ('DEMO00000000002BB', 'Rollback Car', 1100, 'Honda', 2023, 'Non-transport', 'Petrol', '2023-06-01');

    -- Oops — we decide to abort the entire operation
    -- Perhaps validation failed, or user cancelled the request

ROLLBACK;   -- Both inserts are undone atomically

-- Verify: neither row exists
SELECT COUNT(*) AS should_be_zero FROM users WHERE user_id = 'USR000000098';
SELECT COUNT(*) AS should_be_zero FROM vehicle WHERE vehicle_id = 'DEMO00000000002BB';


-- ████████████████████████████████████████████████████████████████
-- TXN 2 : OWNERSHIP TRANSFER TRANSACTION
-- ████████████████████████████████████████████████████████████████
-- Transfers vehicle '5HP8F95D6J936D6WB' from current owner
-- (USR000000008) to a new owner (USR000000039).
--
-- This must be ATOMIC: if we end the old ownership but fail
-- to create the new one, the vehicle ends up with no owner.
-- ──────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Success path: Complete ownership transfer
-- ─────────────────────────────────────────────────────────────
BEGIN;

    -- Step 1: Verify current ownership
    SELECT ownership_id, owner_id, from_date
    FROM ownership
    WHERE vehicle_id = '5HP8F95D6J936D6WB' AND to_date IS NULL;
    -- Expected: ownership_id=50, owner_id='USR000000008', from_date='2023-01-20'

    -- Step 2: End current ownership (set to_date = today)
    UPDATE ownership
    SET to_date = CURRENT_DATE
    WHERE vehicle_id = '5HP8F95D6J936D6WB'
      AND to_date IS NULL;
    -- Rows affected: 1

    -- Step 3: Create new ownership for the buyer
    INSERT INTO ownership (vehicle_id, owner_id, from_date, to_date)
    VALUES ('5HP8F95D6J936D6WB', 'USR000000039', CURRENT_DATE, NULL);

    -- Step 4: Verify the transfer
    SELECT ownership_id, owner_id, from_date, to_date,
           CASE WHEN to_date IS NULL THEN 'Current' ELSE 'Past' END AS status
    FROM ownership
    WHERE vehicle_id = '5HP8F95D6J936D6WB'
    ORDER BY from_date DESC;

-- COMMIT;  -- Would make the transfer permanent
ROLLBACK;   -- Rolling back for demo purposes


-- ─────────────────────────────────────────────────────────────
-- Failure path: What if the new ownership INSERT fails?
-- ─────────────────────────────────────────────────────────────
-- Without a transaction, the UPDATE would persist but the
-- INSERT would fail, leaving the vehicle without an owner.
-- With a transaction, the entire operation is rolled back.

BEGIN;

    -- Step 1: End current ownership
    UPDATE ownership
    SET to_date = CURRENT_DATE
    WHERE vehicle_id = '5HP8F95D6J936D6WB'
      AND to_date IS NULL;

    -- Step 2: Attempt to create new ownership with INVALID owner
    -- This will fail because 'USR_INVALID__' doesn't exist
    -- (violates FK constraint on users.user_id)
    INSERT INTO ownership (vehicle_id, owner_id, from_date, to_date)
    VALUES ('5HP8F95D6J936D6WB', 'USR_INVALID_', CURRENT_DATE, NULL);
    -- ERROR: insert or update on table "ownership" violates
    --        foreign key constraint "ownership_owner_id_fkey"

    -- This line is never reached due to the error above.
    -- PostgreSQL automatically marks the transaction as aborted.

ROLLBACK;   -- Roll back BOTH the UPDATE and the failed INSERT

-- Verify: original ownership is intact
SELECT owner_id, from_date, to_date
FROM ownership
WHERE vehicle_id = '5HP8F95D6J936D6WB' AND to_date IS NULL;
-- Still shows USR000000008 as the current owner


-- ████████████████████████████████████████████████████████████████
-- TXN 3 : CHALLAN PAYMENT WITH WALLET
-- ████████████████████████████████████████████████████████████████
-- Full payment flow for challan #48 (₹2000, unpaid):
--   1. Check wallet balance
--   2. Create wallet transaction
--   3. Deduct from wallet
--   4. Mark challan as paid
--
-- Demonstrates ROLLBACK on insufficient balance.
-- ──────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Success path: Sufficient balance
-- ─────────────────────────────────────────────────────────────
BEGIN;

    -- Step 1: Identify the challan and current owner's wallet
    -- Challan #48: vehicle '3EJXE56ZJMJ49DHKW', owner USR000000020, wallet #20
    SELECT c.challan_id, c.amount, c.reason, c.is_paid,
           ew.wallet_id, ew.balance
    FROM challan c
    JOIN ownership o ON c.vehicle_id = o.vehicle_id AND o.to_date IS NULL
    JOIN e_wallet ew ON o.owner_id = ew.user_id
    WHERE c.challan_id = 48;
    -- Expected: amount=2000, is_paid=false, wallet_id=20, balance=13343.80

    -- Step 2: Check balance (programmatic — in real app this is in code)
    -- balance 13343.80 >= 2000 → proceed

    -- Step 3: Create wallet transaction record
    INSERT INTO wallet_transaction (from_wallet_id, amount, purpose, tran_datetime, status)
    VALUES (20, 2000, 'challan', NOW(), 'Success')
    RETURNING transaction_id;
    -- Suppose this returns transaction_id = 101

    -- Step 4: Deduct from wallet
    UPDATE e_wallet
    SET balance = balance - 2000
    WHERE wallet_id = 20;

    -- Step 5: Mark challan as paid and link the transaction
    UPDATE challan
    SET is_paid = TRUE,
        wallet_transaction_id = currval('wallet_transaction_transaction_id_seq')
    WHERE challan_id = 48;

    -- Step 6: Verify
    SELECT c.challan_id, c.is_paid, c.wallet_transaction_id, ew.balance AS new_balance
    FROM challan c
    JOIN ownership o ON c.vehicle_id = o.vehicle_id AND o.to_date IS NULL
    JOIN e_wallet ew ON o.owner_id = ew.user_id
    WHERE c.challan_id = 48;
    -- Expected: is_paid=true, new_balance=11343.80

-- COMMIT;  -- Would finalize the payment
ROLLBACK;   -- Rolling back for demo purposes


-- ─────────────────────────────────────────────────────────────
-- Failure path: Insufficient balance
-- ─────────────────────────────────────────────────────────────
-- Demonstrates how the application layer would detect
-- insufficient funds and ROLLBACK before any damage is done.

DO $$
DECLARE
    v_challan_amount numeric(10,2);
    v_wallet_balance numeric(12,2);
    v_wallet_id      INT;
BEGIN
    -- Look up challan #63 (₹5000) and owner's wallet
    SELECT c.amount, ew.wallet_id, ew.balance
    INTO v_challan_amount, v_wallet_id, v_wallet_balance
    FROM challan c
    JOIN ownership o ON c.vehicle_id = o.vehicle_id AND o.to_date IS NULL
    JOIN e_wallet ew ON o.owner_id = ew.user_id
    WHERE c.challan_id = 63;

    RAISE NOTICE 'Challan #63: ₹%  |  Wallet #%: ₹%',
        v_challan_amount, v_wallet_id, v_wallet_balance;

    -- Check balance
    IF v_wallet_balance < v_challan_amount THEN
        RAISE NOTICE 'INSUFFICIENT BALANCE: Need ₹%, have ₹%',
            v_challan_amount, v_wallet_balance;
        RAISE NOTICE 'Transaction will be rolled back.';
        -- In a real app, RAISE EXCEPTION would trigger automatic rollback
        RAISE EXCEPTION 'Insufficient wallet balance for challan payment';
    END IF;

    -- This code would only be reached if balance is sufficient
    RAISE NOTICE 'Payment would proceed here...';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Payment aborted: %', SQLERRM;
        -- The DO block's implicit transaction is rolled back
END;
$$;


-- ████████████████████████████████████████████████████████████████
-- TXN 4 : SAVEPOINT DEMONSTRATION
-- ████████████████████████████████████████████████████████████████
-- SAVEPOINTs allow partial rollback within a transaction.
-- You can undo work back to a savepoint without aborting
-- the entire transaction.
--
-- Scenario: Processing three operations in a batch.  If
-- operation 2 fails, roll back only that operation and
-- continue with operation 3.
-- ──────────────────────────────────────────────────────────────

BEGIN;

    -- ── Operation 1: Insert a new user ──────────────────────
    SAVEPOINT sp_user;

    INSERT INTO users (user_id, password, fname, lname, dob, gender, phone_number, city, state, pincode)
    VALUES ('USR000000097', 'pbkdf2$sp_demo_hash', 'Savepoint', 'Demo', '1992-03-20', 'Male', '9999999903', 'Jaipur', 'Rajasthan', '302001');

    -- Operation 1 succeeded
    -- (If it failed, we would: ROLLBACK TO sp_user;)

    -- ── Operation 2: Insert a vehicle (intentional issue) ───
    SAVEPOINT sp_vehicle;

    -- This insert uses a duplicate vehicle_id that already exists
    -- causing a PRIMARY KEY violation
    DO $$
    BEGIN
        INSERT INTO vehicle (vehicle_id, model_name, vehicle_weight, manufacturer, manufactured_year, registration_type, fuel_type, registration_date)
        VALUES ('T10GR7BXRE6W3HJCC', 'Duplicate Vehicle', 1500, 'Test', 2024, 'Non-transport', 'Petrol', '2024-01-01');
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Operation 2 FAILED: Duplicate vehicle_id detected';
            RAISE NOTICE 'Rolling back to savepoint sp_vehicle...';
    END;
    $$;

    -- Roll back ONLY operation 2; operation 1's user insert survives
    ROLLBACK TO sp_vehicle;

    -- ── Operation 3: Create a wallet for the new user ───────
    SAVEPOINT sp_wallet;

    INSERT INTO e_wallet (user_id, balance, status)
    VALUES ('USR000000097', 5000.00, 'Active');

    -- Operation 3 succeeded

    -- ── Verify: user and wallet exist, but no duplicate vehicle ──
    SELECT u.user_id, u.fname, ew.wallet_id, ew.balance
    FROM users u
    JOIN e_wallet ew ON u.user_id = ew.user_id
    WHERE u.user_id = 'USR000000097';
    -- Expected: 1 row with user_id='USR000000097', balance=5000.00

    SELECT COUNT(*) AS duplicate_check
    FROM vehicle WHERE vehicle_id = 'T10GR7BXRE6W3HJCC';
    -- Expected: 1 (only the original, no duplicate)

-- COMMIT;  -- Would keep the user + wallet, without the duplicate vehicle
ROLLBACK;   -- Rolling back everything for demo purposes


-- ████████████████████████████████████████████████████████████████
-- TXN 5 : ISOLATION LEVEL DEMONSTRATION
-- ████████████████████████████████████████████████████████████████
-- PostgreSQL supports four isolation levels:
--   • READ UNCOMMITTED (treated as READ COMMITTED in PostgreSQL)
--   • READ COMMITTED   (default)
--   • REPEATABLE READ
--   • SERIALIZABLE
--
-- This demo shows the difference between READ COMMITTED and
-- SERIALIZABLE through comments explaining the behavior.
-- ──────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Demo A: READ COMMITTED (default)
-- ─────────────────────────────────────────────────────────────
-- In READ COMMITTED, each statement sees the latest committed
-- data.  If another session commits between two SELECT
-- statements in our transaction, the second SELECT will see
-- the new data ("non-repeatable read").

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    -- Statement 1: Count unpaid challans
    SELECT COUNT(*) AS unpaid_count FROM challan WHERE is_paid = FALSE;
    -- Suppose this returns 40

    -- *** Meanwhile, another session pays a challan and COMMITs ***
    -- (simulated — we can't run two sessions in one script)

    -- Statement 2: Count again
    SELECT COUNT(*) AS unpaid_count FROM challan WHERE is_paid = FALSE;
    -- In READ COMMITTED: might return 39 (sees the other session's commit)
    -- This is a "non-repeatable read" — same query, different results

    -- Characteristics of READ COMMITTED:
    -- ✓ No dirty reads    (only sees committed data)
    -- ✗ Non-repeatable reads possible
    -- ✗ Phantom reads possible (new rows may appear)

ROLLBACK;


-- ─────────────────────────────────────────────────────────────
-- Demo B: SERIALIZABLE (strictest level)
-- ─────────────────────────────────────────────────────────────
-- In SERIALIZABLE, the transaction sees a snapshot of the
-- database taken at the start of the transaction.  It behaves
-- as if transactions execute one after another (serially).

BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    -- Statement 1: Count unpaid challans
    SELECT COUNT(*) AS unpaid_count FROM challan WHERE is_paid = FALSE;
    -- Returns 40

    -- *** Meanwhile, another session pays a challan and COMMITs ***

    -- Statement 2: Count again
    SELECT COUNT(*) AS unpaid_count FROM challan WHERE is_paid = FALSE;
    -- In SERIALIZABLE: still returns 40!
    -- The transaction sees the same snapshot throughout.

    -- If this transaction tries to modify a row that was
    -- changed by the other session, PostgreSQL will raise:
    -- ERROR: could not serialize access due to concurrent update
    -- The application must then retry the transaction.

    -- Characteristics of SERIALIZABLE:
    -- ✓ No dirty reads
    -- ✓ No non-repeatable reads
    -- ✓ No phantom reads
    -- ✗ Higher overhead, possible serialization failures

ROLLBACK;


-- ─────────────────────────────────────────────────────────────
-- Demo C: REPEATABLE READ — Phantom Read Protection
-- ─────────────────────────────────────────────────────────────

BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- First read: get all challans for a vehicle
    SELECT challan_id, amount, is_paid
    FROM challan
    WHERE vehicle_id = '0TBZEZSGYJCZYM67M';

    -- *** Meanwhile, another session inserts a NEW challan for this
    --     vehicle and COMMITs ***

    -- Second read: same query
    SELECT challan_id, amount, is_paid
    FROM challan
    WHERE vehicle_id = '0TBZEZSGYJCZYM67M';

    -- In REPEATABLE READ: the new challan does NOT appear
    -- (PostgreSQL's REPEATABLE READ prevents phantom reads)
    --
    -- In READ COMMITTED: the new challan WOULD appear
    -- (phantom read occurs)

ROLLBACK;


-- ████████████████████████████████████████████████████████████████
-- TXN 6 : DEADLOCK SCENARIO
-- ████████████████████████████████████████████████████████████████
-- A deadlock occurs when two sessions each hold a lock that
-- the other needs.  PostgreSQL detects this and aborts one
-- of the transactions (the "victim").
--
-- Scenario: Two sessions update wallet balances, but in
-- opposite order.
--
-- Session 1: Updates wallet #3, then wallet #4
-- Session 2: Updates wallet #4, then wallet #3
-- ──────────────────────────────────────────────────────────────

-- NOTE: This cannot be fully executed in a single session.
-- The interleaved steps below show what would happen if you
-- opened two psql terminals and ran the steps alternately.

-- ┌─────────────────────────────────────────────────────────────┐
-- │                    DEADLOCK TIMELINE                        │
-- ├─────────┬──────────────────────┬────────────────────────────┤
-- │  Time   │  Session 1           │  Session 2                 │
-- ├─────────┼──────────────────────┼────────────────────────────┤
-- │  T1     │  BEGIN;              │                            │
-- │  T2     │                      │  BEGIN;                    │
-- │  T3     │  UPDATE e_wallet     │                            │
-- │         │  SET balance =       │                            │
-- │         │    balance + 100     │                            │
-- │         │  WHERE wallet_id = 3;│                            │
-- │         │  -- Acquires lock    │                            │
-- │         │  -- on wallet #3     │                            │
-- │  T4     │                      │  UPDATE e_wallet           │
-- │         │                      │  SET balance =             │
-- │         │                      │    balance + 200           │
-- │         │                      │  WHERE wallet_id = 4;      │
-- │         │                      │  -- Acquires lock          │
-- │         │                      │  -- on wallet #4           │
-- │  T5     │  UPDATE e_wallet     │                            │
-- │         │  SET balance =       │                            │
-- │         │    balance - 100     │                            │
-- │         │  WHERE wallet_id = 4;│                            │
-- │         │  -- BLOCKS! Session 2│                            │
-- │         │  -- holds lock on #4 │                            │
-- │  T6     │                      │  UPDATE e_wallet           │
-- │         │                      │  SET balance =             │
-- │         │                      │    balance - 200           │
-- │         │                      │  WHERE wallet_id = 3;      │
-- │         │                      │  -- BLOCKS! Session 1      │
-- │         │                      │  -- holds lock on #3       │
-- │         │                      │                            │
-- │  !!     │  *** DEADLOCK DETECTED ***                        │
-- │         │  PostgreSQL aborts one session (the "victim"):    │
-- │         │  ERROR: deadlock detected                         │
-- │         │  DETAIL: Process X waits for ShareLock on         │
-- │         │    transaction Y; blocked by process Z.           │
-- │         │  Process Z waits for ShareLock on                 │
-- │         │    transaction W; blocked by process X.           │
-- │         │                                                   │
-- │  T7     │  -- Session 1 aborted │  -- Session 2 proceeds   │
-- │         │  -- (ROLLBACK)        │  -- (can now COMMIT)      │
-- │  T8     │                       │  COMMIT;                  │
-- └─────────┴──────────────────────┴────────────────────────────┘

-- ── How to PREVENT deadlocks ────────────────────────────────
-- Always acquire locks in the same order across all sessions.
-- For example, always update wallets in ascending wallet_id order:

-- Session 1 (correct):
BEGIN;
    UPDATE e_wallet SET balance = balance + 100 WHERE wallet_id = 3;  -- lock #3 first
    UPDATE e_wallet SET balance = balance - 100 WHERE wallet_id = 4;  -- then #4
ROLLBACK;

-- Session 2 (correct — same order):
BEGIN;
    UPDATE e_wallet SET balance = balance - 200 WHERE wallet_id = 3;  -- lock #3 first
    UPDATE e_wallet SET balance = balance + 200 WHERE wallet_id = 4;  -- then #4
ROLLBACK;

-- By always locking in wallet_id ASC order, deadlocks are impossible.


-- ████████████████████████████████████████████████████████████████
-- TXN 7 : BATCH INSERT WITH TRANSACTION
-- ████████████████████████████████████████████████████████████████
-- Wrapping many INSERTs in a single transaction is both:
--   • FASTER: only one COMMIT (fsync) instead of N
--   • ATOMIC: all-or-nothing — partial inserts don't occur
--
-- This demo inserts multiple vehicle_log records as a batch.
-- ──────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- BAD PRACTICE: Individual transactions per insert
-- ─────────────────────────────────────────────────────────────
-- If auto-commit is ON (the default in psql), each INSERT
-- is its own transaction with its own COMMIT+fsync.
--
-- INSERT INTO vehicle_log (...) VALUES (...);  -- txn 1: commit + fsync
-- INSERT INTO vehicle_log (...) VALUES (...);  -- txn 2: commit + fsync
-- INSERT INTO vehicle_log (...) VALUES (...);  -- txn 3: commit + fsync
--
-- This is SLOW because fsync is expensive (≈5ms per commit).
-- For 1000 inserts: ≈5 seconds of pure fsync overhead.


-- ─────────────────────────────────────────────────────────────
-- GOOD PRACTICE: Single transaction for the entire batch
-- ─────────────────────────────────────────────────────────────
-- One BEGIN + many INSERTs + one COMMIT = one fsync.
-- For 1000 inserts: ≈5ms of fsync overhead.

BEGIN;

    -- ── Batch of vehicle_log entries ────────────────────────
    -- All inserts share a single transaction.

    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date, end_date) VALUES
        ('DE209LBK5CJES001C', 'Under_Repair', '2026-01-10', '2026-02-10');

    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date, end_date) VALUES
        ('3EJXE56ZJMJ49DHKW', 'Seized_by_police', '2026-02-15', '2026-04-15');

    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date, end_date) VALUES
        ('S36EH8B9SKV4AZS3M', 'Under_Repair', '2026-03-01', '2026-03-20');

    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date, end_date) VALUES
        ('7VAG4JT020C2DN0VE', 'Lost', '2026-04-05', '2026-05-05');

    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date, end_date) VALUES
        ('HNB5X3K3P397DJPX7', 'Stolen', '2026-05-10', '2026-07-10');

    -- Verify: all 5 rows exist within this transaction
    SELECT COUNT(*) AS batch_inserted
    FROM vehicle_log
    WHERE start_date >= '2026-01-01';

    -- ── Atomicity guarantee ─────────────────────────────────
    -- If any INSERT above had failed (e.g., invalid vehicle_id
    -- or CHECK constraint violation), ALL five inserts would
    -- be rolled back.  The database would remain in its
    -- pre-transaction state with no partial batch.

-- COMMIT;  -- Would persist all 5 rows at once (1 fsync)
ROLLBACK;   -- Rolling back for demo purposes


-- ─────────────────────────────────────────────────────────────
-- EVEN BETTER: Multi-row VALUES for maximum performance
-- ─────────────────────────────────────────────────────────────
-- For large batches, use a single INSERT with multi-row VALUES.
-- This reduces both SQL parsing overhead and network round-trips.

BEGIN;

    INSERT INTO vehicle_log (vehicle_id, vehicle_status, start_date, end_date) VALUES
        ('DE209LBK5CJES001C', 'Under_Repair',     '2026-01-10', '2026-02-10'),
        ('3EJXE56ZJMJ49DHKW', 'Seized_by_police', '2026-02-15', '2026-04-15'),
        ('S36EH8B9SKV4AZS3M', 'Under_Repair',     '2026-03-01', '2026-03-20'),
        ('7VAG4JT020C2DN0VE', 'Lost',             '2026-04-05', '2026-05-05'),
        ('HNB5X3K3P397DJPX7', 'Stolen',           '2026-05-10', '2026-07-10');

    -- This is the fastest approach:
    -- ✓ One SQL statement    (minimal parse overhead)
    -- ✓ One transaction      (one fsync)
    -- ✓ One network round-trip
    -- ✓ Fully atomic

    SELECT COUNT(*) AS batch_inserted FROM vehicle_log WHERE start_date >= '2026-01-01';

ROLLBACK;   -- Rolling back for demo purposes


-- ═══════════════════════════════════════════════════════════════
-- SUMMARY OF TRANSACTION CONCEPTS
-- ═══════════════════════════════════════════════════════════════
--
-- ┌──────────────────┬──────────────────────────────────────────┐
-- │ Concept          │ Key Takeaway                             │
-- ├──────────────────┼──────────────────────────────────────────┤
-- │ COMMIT           │ Makes all changes permanent & visible    │
-- │ ROLLBACK         │ Undoes all changes since BEGIN           │
-- │ SAVEPOINT        │ Creates a "bookmark" for partial rollback│
-- │ ROLLBACK TO      │ Undoes back to savepoint, txn continues  │
-- │ READ COMMITTED   │ Each statement sees latest committed data│
-- │ REPEATABLE READ  │ Snapshot at first statement; no phantoms │
-- │ SERIALIZABLE     │ Full snapshot; may fail with serialization│
-- │ Deadlock         │ Circular lock wait → one session aborted │
-- │ Batch INSERT     │ Wrap in txn for atomicity & performance  │
-- └──────────────────┴──────────────────────────────────────────┘
--
-- ═══════════════════════════════════════════════════════════════
-- END OF TRANSACTION DEMONSTRATIONS
-- ═══════════════════════════════════════════════════════════════
