-- ═══════════════════════════════════════════════════════════════
-- UNIFIED VEHICLE REGISTRY – CURSOR DEMONSTRATIONS
-- ═══════════════════════════════════════════════════════════════
-- Run this file AFTER DDL.sql, Insert_data.sql, and Queries.sql
-- ═══════════════════════════════════════════════════════════════
--
-- This file demonstrates various cursor patterns in PL/pgSQL:
--   1. Explicit OPEN / FETCH / CLOSE pattern
--   2. Cursors with parameters (parameterised cursors)
--   3. FOR ... IN cursor shorthand
--   4. REF CURSOR (dynamic / unbound cursor)
--   5. SCROLL cursor (bidirectional navigation)
--
-- Each example is wrapped in a DO $$ ... $$ block or a
-- standalone function so it can be executed directly.
-- ═══════════════════════════════════════════════════════════════


-- ████████████████████████████████████████████████████████████████
-- CURSOR 1 : COMPLIANCE REPORT CURSOR
-- ████████████████████████████████████████████████████████████████
-- Pattern : Explicit DECLARE → OPEN → FETCH → CLOSE
-- Purpose : Iterate through ALL vehicles, check whether each
--           has an active insurance policy AND a valid PUC
--           certificate, then output a per-vehicle compliance
--           report via RAISE NOTICE.
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
    -- ── Cursor declaration ──────────────────────────────────
    -- An unbound cursor that selects every vehicle's core info
    -- along with insurance and PUC compliance flags computed
    -- as correlated sub-selects.
    cur_compliance CURSOR FOR
        SELECT
            v.vehicle_id,
            v.model_name,
            v.manufacturer,
            -- Insurance compliance: TRUE if at least one active policy exists
            EXISTS (
                SELECT 1 FROM insurance i
                WHERE i.vehicle_id = v.vehicle_id
                  AND i.expiry_date >= CURRENT_DATE
            ) AS has_active_insurance,
            -- PUC compliance: TRUE if at least one valid PUC exists
            EXISTS (
                SELECT 1 FROM puc p
                WHERE p.vehicle_id = v.vehicle_id
                  AND p.valid_until >= CURRENT_DATE
            ) AS has_active_puc
        FROM vehicle v
        ORDER BY v.vehicle_id;

    -- ── Record variable to hold each fetched row ────────────
    rec_vehicle RECORD;

    -- ── Counters for summary statistics ─────────────────────
    v_total         INT := 0;
    v_fully_compliant INT := 0;
    v_ins_missing   INT := 0;
    v_puc_missing   INT := 0;
    v_both_missing  INT := 0;

BEGIN
    -- ── Step 1: OPEN the cursor ─────────────────────────────
    -- This allocates server-side resources and positions the
    -- cursor before the first row.
    OPEN cur_compliance;

    -- ── Step 2: FETCH rows in a loop ────────────────────────
    LOOP
        FETCH cur_compliance INTO rec_vehicle;

        -- EXIT when no more rows are available
        EXIT WHEN NOT FOUND;

        v_total := v_total + 1;

        -- ── Evaluate compliance status ──────────────────────
        IF rec_vehicle.has_active_insurance AND rec_vehicle.has_active_puc THEN
            v_fully_compliant := v_fully_compliant + 1;
            RAISE NOTICE '[✓] % (%) — FULLY COMPLIANT',
                rec_vehicle.vehicle_id, rec_vehicle.model_name;

        ELSIF NOT rec_vehicle.has_active_insurance AND NOT rec_vehicle.has_active_puc THEN
            v_both_missing := v_both_missing + 1;
            RAISE NOTICE '[✗✗] % (%) — MISSING BOTH Insurance & PUC',
                rec_vehicle.vehicle_id, rec_vehicle.model_name;

        ELSIF NOT rec_vehicle.has_active_insurance THEN
            v_ins_missing := v_ins_missing + 1;
            RAISE NOTICE '[✗] % (%) — MISSING Insurance (PUC OK)',
                rec_vehicle.vehicle_id, rec_vehicle.model_name;

        ELSE
            v_puc_missing := v_puc_missing + 1;
            RAISE NOTICE '[✗] % (%) — MISSING PUC (Insurance OK)',
                rec_vehicle.vehicle_id, rec_vehicle.model_name;
        END IF;
    END LOOP;

    -- ── Step 3: CLOSE the cursor ────────────────────────────
    -- Releases server-side resources.  Always close explicitly
    -- when using the OPEN/FETCH/CLOSE pattern.
    CLOSE cur_compliance;

    -- ── Summary ─────────────────────────────────────────────
    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE 'COMPLIANCE SUMMARY';
    RAISE NOTICE '────────────────────────────────────────────';
    RAISE NOTICE 'Total vehicles scanned  : %', v_total;
    RAISE NOTICE 'Fully compliant         : %', v_fully_compliant;
    RAISE NOTICE 'Missing insurance only  : %', v_ins_missing;
    RAISE NOTICE 'Missing PUC only        : %', v_puc_missing;
    RAISE NOTICE 'Missing both            : %', v_both_missing;
    RAISE NOTICE '════════════════════════════════════════════';

EXCEPTION
    WHEN OTHERS THEN
        -- Ensure cursor is closed even on error
        IF cur_compliance IS NOT NULL THEN
            CLOSE cur_compliance;
        END IF;
        RAISE NOTICE 'ERROR in compliance report: % — %', SQLSTATE, SQLERRM;
END;
$$;


-- ████████████████████████████████████████████████████████████████
-- CURSOR 2 : EXPIRED PUC NOTIFICATION CURSOR
-- ████████████████████████████████████████████████████████████████
-- Pattern : FOR ... IN cursor (implicit open/fetch/close)
-- Purpose : Find vehicles whose latest PUC has expired, look up
--           the current owner, and simulate sending an SMS/email
--           notification via RAISE NOTICE.
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
    -- ── Cursor using FOR...IN shorthand ─────────────────────
    -- When you use FOR rec IN cursor_query LOOP, PostgreSQL
    -- automatically handles OPEN, FETCH, and CLOSE.
    rec RECORD;

    v_notification_count INT := 0;

BEGIN
    RAISE NOTICE '╔══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║       EXPIRED PUC NOTIFICATION DISPATCH                ║';
    RAISE NOTICE '╚══════════════════════════════════════════════════════════╝';

    -- ── FOR ... IN cursor loop ──────────────────────────────
    -- This is the implicit cursor pattern: no explicit DECLARE
    -- CURSOR, OPEN, FETCH, or CLOSE is needed.
    FOR rec IN
        SELECT
            v.vehicle_id,
            v.model_name,
            p.certificate_number,
            p.valid_until                                       AS puc_expiry,
            CURRENT_DATE - p.valid_until                        AS days_expired,
            u.user_id                                           AS owner_id,
            u.fname || COALESCE(' ' || u.lname, '')             AS owner_name,
            u.phone_number,
            u.email
        FROM puc p
        JOIN vehicle v ON p.vehicle_id = v.vehicle_id
        -- Only the LATEST PUC per vehicle (DISTINCT ON)
        JOIN (
            SELECT DISTINCT ON (vehicle_id)
                vehicle_id, certificate_number
            FROM puc
            ORDER BY vehicle_id, valid_until DESC
        ) latest ON p.certificate_number = latest.certificate_number
        -- Current owner via ownership
        LEFT JOIN ownership o ON v.vehicle_id = o.vehicle_id AND o.to_date IS NULL
        LEFT JOIN users u ON o.owner_id = u.user_id
        WHERE p.valid_until < CURRENT_DATE
        ORDER BY p.valid_until ASC
    LOOP
        v_notification_count := v_notification_count + 1;

        RAISE NOTICE '────────────────────────────────────────────';
        RAISE NOTICE 'Notification #%', v_notification_count;
        RAISE NOTICE '  Vehicle   : % (%)', rec.vehicle_id, rec.model_name;
        RAISE NOTICE '  PUC Cert  : %', rec.certificate_number;
        RAISE NOTICE '  Expired   : % (% days ago)', rec.puc_expiry, rec.days_expired;

        IF rec.owner_id IS NOT NULL THEN
            RAISE NOTICE '  Owner     : % (%)', rec.owner_name, rec.owner_id;
            RAISE NOTICE '  Phone     : %', rec.phone_number;
            RAISE NOTICE '  Email     : %', rec.email;
            RAISE NOTICE '  → SMS sent to %: "Dear %, your PUC for % expired on %. Please renew."',
                rec.phone_number, rec.owner_name, rec.model_name, rec.puc_expiry;
        ELSE
            RAISE NOTICE '  Owner     : No current owner on record';
            RAISE NOTICE '  → Notification skipped (no owner)';
        END IF;
    END LOOP;

    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE 'Total notifications dispatched: %', v_notification_count;
    RAISE NOTICE '════════════════════════════════════════════';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in PUC notification dispatch: % — %', SQLSTATE, SQLERRM;
END;
$$;


-- ████████████████████████████████████████████████████████████████
-- CURSOR 3 : BULK CHALLAN PROCESSING CURSOR (WITH PARAMETERS)
-- ████████████████████████████████████████████████████████████████
-- Pattern : Parameterised cursor + FOR UPDATE (row-level lock)
-- Purpose : For a specific vehicle, iterate through all unpaid
--           challans, attempt to pay each from the owner's wallet
--           (check balance, deduct, create transaction, mark paid).
--
-- The cursor takes vehicle_id as a parameter, and uses
-- FOR UPDATE to lock challan rows during processing.
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
    -- ── Input parameter (change this to test with other vehicles) ──
    p_vehicle_id CONSTANT varchar(17) := '0TBZEZSGYJCZYM67M';

    -- ── Parameterised cursor with FOR UPDATE ────────────────
    -- The parameter v_id is bound when the cursor is OPENed.
    -- FOR UPDATE locks each fetched challan row to prevent
    -- concurrent modification during payment processing.
    cur_unpaid_challans CURSOR (v_id varchar(17)) FOR
        SELECT
            c.challan_id,
            c.amount,
            c.reason,
            c.challan_date,
            c.location
        FROM challan c
        WHERE c.vehicle_id = v_id
          AND c.is_paid = FALSE
        ORDER BY c.challan_date ASC
        FOR UPDATE OF c;

    rec_challan     RECORD;

    -- ── Owner & wallet variables ────────────────────────────
    v_owner_id      char(12);
    v_wallet_id     INT;
    v_balance       numeric(12,2);
    v_new_txn_id    INT;
    v_paid_count    INT := 0;
    v_failed_count  INT := 0;
    v_total_paid    numeric(12,2) := 0;

BEGIN
    RAISE NOTICE '╔══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  BULK CHALLAN PAYMENT PROCESSING                       ║';
    RAISE NOTICE '║  Vehicle: %                              ║', p_vehicle_id;
    RAISE NOTICE '╚══════════════════════════════════════════════════════════╝';

    -- ── Resolve current owner and their wallet ──────────────
    SELECT o.owner_id INTO v_owner_id
    FROM ownership o
    WHERE o.vehicle_id = p_vehicle_id
      AND o.to_date IS NULL;

    IF v_owner_id IS NULL THEN
        RAISE NOTICE 'ERROR: No current owner found for vehicle %', p_vehicle_id;
        RETURN;
    END IF;

    SELECT ew.wallet_id, ew.balance INTO v_wallet_id, v_balance
    FROM e_wallet ew
    WHERE ew.user_id = v_owner_id
      AND ew.status = 'Active';

    IF v_wallet_id IS NULL THEN
        RAISE NOTICE 'ERROR: No active wallet found for owner %', v_owner_id;
        RETURN;
    END IF;

    RAISE NOTICE 'Owner: %  |  Wallet #%  |  Balance: ₹%',
        v_owner_id, v_wallet_id, v_balance;
    RAISE NOTICE '────────────────────────────────────────────';

    -- ── Step 1: OPEN the parameterised cursor ───────────────
    -- The parameter p_vehicle_id is bound here at OPEN time.
    OPEN cur_unpaid_challans(p_vehicle_id);

    -- ── Step 2: FETCH and process each unpaid challan ───────
    LOOP
        FETCH cur_unpaid_challans INTO rec_challan;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Processing Challan #% — ₹% for "%" on %',
            rec_challan.challan_id, rec_challan.amount,
            rec_challan.reason, rec_challan.challan_date;

        -- ── Check sufficient balance ────────────────────────
        IF v_balance >= rec_challan.amount THEN
            -- Create wallet transaction
            INSERT INTO wallet_transaction (from_wallet_id, amount, purpose, tran_datetime, status)
            VALUES (v_wallet_id, rec_challan.amount, 'challan', NOW(), 'Success')
            RETURNING transaction_id INTO v_new_txn_id;

            -- Deduct from wallet
            UPDATE e_wallet
            SET balance = balance - rec_challan.amount
            WHERE wallet_id = v_wallet_id;

            -- Mark challan as paid (uses WHERE CURRENT OF for cursor row)
            UPDATE challan
            SET is_paid = TRUE,
                wallet_transaction_id = v_new_txn_id
            WHERE CURRENT OF cur_unpaid_challans;

            -- Update local balance tracker
            v_balance := v_balance - rec_challan.amount;
            v_paid_count := v_paid_count + 1;
            v_total_paid := v_total_paid + rec_challan.amount;

            RAISE NOTICE '  → PAID (Txn #%).  Remaining balance: ₹%',
                v_new_txn_id, v_balance;
        ELSE
            -- Insufficient balance — log failure
            v_failed_count := v_failed_count + 1;

            RAISE NOTICE '  → SKIPPED: Insufficient balance (need ₹%, have ₹%)',
                rec_challan.amount, v_balance;
        END IF;
    END LOOP;

    -- ── Step 3: CLOSE the cursor ────────────────────────────
    CLOSE cur_unpaid_challans;

    -- ── Summary ─────────────────────────────────────────────
    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE 'PAYMENT SUMMARY for %', p_vehicle_id;
    RAISE NOTICE '────────────────────────────────────────────';
    RAISE NOTICE 'Challans paid     : %', v_paid_count;
    RAISE NOTICE 'Challans skipped  : %', v_failed_count;
    RAISE NOTICE 'Total amount paid : ₹%', v_total_paid;
    RAISE NOTICE 'Final balance     : ₹%', v_balance;
    RAISE NOTICE '════════════════════════════════════════════';

EXCEPTION
    WHEN OTHERS THEN
        -- Ensure cursor is closed on error before re-raising
        BEGIN
            CLOSE cur_unpaid_challans;
        EXCEPTION WHEN OTHERS THEN
            NULL;  -- cursor may already be closed
        END;
        RAISE NOTICE 'ERROR in challan processing: % — %', SQLSTATE, SQLERRM;
        RAISE;  -- re-raise to trigger transaction rollback
END;
$$;


-- ████████████████████████████████████████████████████████████████
-- CURSOR 4 : MONTHLY REVENUE REPORT CURSOR (REF CURSOR)
-- ████████████████████████████████████████████████████████████████
-- Pattern : REF CURSOR (SYS_REFCURSOR / dynamic cursor)
-- Purpose : A function that accepts a date range and returns a
--           refcursor pointing to monthly challan revenue data.
--           The caller can then FETCH from the cursor.
--
-- REF CURSORs are "unbound" at declaration time — their query
-- is assigned dynamically at OPEN time, making them flexible
-- for building generic reporting functions.
-- ──────────────────────────────────────────────────────────────

-- ── Function: returns a REF CURSOR ──────────────────────────
CREATE OR REPLACE FUNCTION fn_monthly_revenue_report(
    p_start_date DATE,
    p_end_date   DATE
)
RETURNS REFCURSOR
LANGUAGE plpgsql
AS $$
DECLARE
    -- ── REF CURSOR declaration ──────────────────────────────
    -- A refcursor is an unbound cursor variable.  We give it
    -- a portal name so the caller can reference it.
    ref_revenue REFCURSOR := 'revenue_portal';
BEGIN
    -- ── Validate parameters ─────────────────────────────────
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Start date (%) must be <= End date (%)', p_start_date, p_end_date;
    END IF;

    -- ── OPEN the refcursor with a dynamic query ─────────────
    -- The query is bound here, not at declaration time.
    -- This is what makes refcursors "dynamic".
    OPEN ref_revenue FOR
        SELECT
            TO_CHAR(c.challan_date, 'YYYY-MM')      AS report_month,
            COUNT(*)                                 AS total_challans,
            SUM(c.amount)                            AS total_revenue,
            SUM(c.amount) FILTER (WHERE c.is_paid)   AS collected_revenue,
            SUM(c.amount) FILTER (WHERE NOT c.is_paid) AS pending_revenue,
            ROUND(AVG(c.amount), 2)                  AS avg_challan_amount,
            COUNT(*) FILTER (WHERE c.is_paid)         AS paid_count,
            COUNT(*) FILTER (WHERE NOT c.is_paid)     AS unpaid_count
        FROM challan c
        WHERE c.challan_date BETWEEN p_start_date AND p_end_date
        GROUP BY TO_CHAR(c.challan_date, 'YYYY-MM')
        ORDER BY report_month;

    -- ── Return the cursor to the caller ─────────────────────
    -- The caller will FETCH from 'revenue_portal'.
    RETURN ref_revenue;
END;
$$;

-- ── Demo: Call the function and iterate the REF CURSOR ──────
DO $$
DECLARE
    v_cursor    REFCURSOR;
    rec         RECORD;
    v_row_count INT := 0;
BEGIN
    RAISE NOTICE '╔══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  MONTHLY REVENUE REPORT (REF CURSOR)                   ║';
    RAISE NOTICE '║  Period: 2024-01-01 to 2026-12-31                      ║';
    RAISE NOTICE '╚══════════════════════════════════════════════════════════╝';

    -- ── Call the function to get the REF CURSOR ─────────────
    -- The function opens the cursor and returns a reference.
    v_cursor := fn_monthly_revenue_report('2024-01-01'::DATE, '2026-12-31'::DATE);

    -- ── FETCH from the REF CURSOR ───────────────────────────
    LOOP
        FETCH v_cursor INTO rec;
        EXIT WHEN NOT FOUND;

        v_row_count := v_row_count + 1;

        RAISE NOTICE '────────────────────────────────────────────';
        RAISE NOTICE 'Month: %', rec.report_month;
        RAISE NOTICE '  Challans   : % total (% paid, % unpaid)',
            rec.total_challans, rec.paid_count, rec.unpaid_count;
        RAISE NOTICE '  Revenue    : ₹% total (₹% collected, ₹% pending)',
            rec.total_revenue, rec.collected_revenue, rec.pending_revenue;
        RAISE NOTICE '  Avg Amount : ₹%', rec.avg_challan_amount;
    END LOOP;

    -- ── CLOSE the REF CURSOR ────────────────────────────────
    CLOSE v_cursor;

    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE 'Total months reported: %', v_row_count;
    RAISE NOTICE '════════════════════════════════════════════';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in revenue report: % — %', SQLSTATE, SQLERRM;
END;
$$;


-- ████████████████████████████████████████████████████████████████
-- CURSOR 5 : VEHICLE TRANSFER HISTORY — SCROLLABLE CURSOR
-- ████████████████████████████████████████████████████████████████
-- Pattern : SCROLL cursor with bidirectional navigation
-- Purpose : Demonstrate FETCH NEXT, FETCH PRIOR, FETCH FIRST,
--           and FETCH LAST on a vehicle's ownership history.
--
-- A SCROLL cursor allows movement in any direction, unlike a
-- regular (NO SCROLL) cursor which only moves forward.
-- ──────────────────────────────────────────────────────────────

DO $$
DECLARE
    -- ── Input parameter ─────────────────────────────────────
    p_vehicle_id CONSTANT varchar(17) := 'XT0K7EFFF4G0JDYH3';
    -- This vehicle has multiple owners (ownership IDs 7 and 8)

    -- ── SCROLL cursor declaration ───────────────────────────
    -- The SCROLL keyword enables bidirectional movement.
    cur_history SCROLL CURSOR FOR
        SELECT
            o.ownership_id,
            o.vehicle_id,
            v.model_name,
            u.user_id,
            u.fname || COALESCE(' ' || u.lname, '') AS owner_name,
            o.from_date,
            o.to_date,
            CASE WHEN o.to_date IS NULL
                 THEN 'Current Owner'
                 ELSE 'Past Owner'
            END AS status,
            COALESCE(o.to_date, CURRENT_DATE) - o.from_date AS days_owned
        FROM ownership o
        JOIN users   u ON o.owner_id   = u.user_id
        JOIN vehicle v ON o.vehicle_id = v.vehicle_id
        WHERE o.vehicle_id = p_vehicle_id
        ORDER BY o.from_date ASC;

    rec RECORD;

BEGIN
    RAISE NOTICE '╔══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  SCROLLABLE CURSOR — OWNERSHIP HISTORY                 ║';
    RAISE NOTICE '║  Vehicle: %                          ║', p_vehicle_id;
    RAISE NOTICE '╚══════════════════════════════════════════════════════════╝';

    -- ── OPEN the scroll cursor ──────────────────────────────
    OPEN cur_history;

    -- ─────────────────────────────────────────────────────────
    -- Demo 1: FETCH FIRST — jump to the very first row
    -- ─────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '>>> FETCH FIRST (Original / First Owner)';
    FETCH FIRST FROM cur_history INTO rec;
    IF FOUND THEN
        RAISE NOTICE '  Ownership #% : % (%)',
            rec.ownership_id, rec.owner_name, rec.user_id;
        RAISE NOTICE '  Period: % to %  |  Status: %  |  Days: %',
            rec.from_date, COALESCE(rec.to_date::text, 'present'),
            rec.status, rec.days_owned;
    ELSE
        RAISE NOTICE '  No ownership records found.';
    END IF;

    -- ─────────────────────────────────────────────────────────
    -- Demo 2: FETCH LAST — jump to the very last row
    -- ─────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '>>> FETCH LAST (Most Recent / Current Owner)';
    FETCH LAST FROM cur_history INTO rec;
    IF FOUND THEN
        RAISE NOTICE '  Ownership #% : % (%)',
            rec.ownership_id, rec.owner_name, rec.user_id;
        RAISE NOTICE '  Period: % to %  |  Status: %  |  Days: %',
            rec.from_date, COALESCE(rec.to_date::text, 'present'),
            rec.status, rec.days_owned;
    END IF;

    -- ─────────────────────────────────────────────────────────
    -- Demo 3: FETCH PRIOR — move backward from current position
    -- ─────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '>>> FETCH PRIOR (Previous Owner from current position)';
    FETCH PRIOR FROM cur_history INTO rec;
    IF FOUND THEN
        RAISE NOTICE '  Ownership #% : % (%)',
            rec.ownership_id, rec.owner_name, rec.user_id;
        RAISE NOTICE '  Period: % to %  |  Status: %  |  Days: %',
            rec.from_date, COALESCE(rec.to_date::text, 'present'),
            rec.status, rec.days_owned;
    ELSE
        RAISE NOTICE '  Already at the beginning — no prior row.';
    END IF;

    -- ─────────────────────────────────────────────────────────
    -- Demo 4: FETCH NEXT — move forward again
    -- ─────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '>>> FETCH NEXT (Move forward from current position)';
    FETCH NEXT FROM cur_history INTO rec;
    IF FOUND THEN
        RAISE NOTICE '  Ownership #% : % (%)',
            rec.ownership_id, rec.owner_name, rec.user_id;
        RAISE NOTICE '  Period: % to %  |  Status: %  |  Days: %',
            rec.from_date, COALESCE(rec.to_date::text, 'present'),
            rec.status, rec.days_owned;
    ELSE
        RAISE NOTICE '  Already at the end — no next row.';
    END IF;

    -- ─────────────────────────────────────────────────────────
    -- Demo 5: Full forward traversal from FIRST
    -- ─────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '>>> FULL FORWARD TRAVERSAL (FIRST → each NEXT)';
    RAISE NOTICE '────────────────────────────────────────────';

    -- Reposition to before the first row
    FETCH FIRST FROM cur_history INTO rec;
    -- We already have the first row, so print it and continue
    IF FOUND THEN
        RAISE NOTICE '  [1] % (%) — % to % [%]',
            rec.owner_name, rec.user_id,
            rec.from_date, COALESCE(rec.to_date::text, 'present'),
            rec.status;

        -- Now fetch each subsequent row
        LOOP
            FETCH NEXT FROM cur_history INTO rec;
            EXIT WHEN NOT FOUND;
            RAISE NOTICE '  [+] % (%) — % to % [%]',
                rec.owner_name, rec.user_id,
                rec.from_date, COALESCE(rec.to_date::text, 'present'),
                rec.status;
        END LOOP;
    END IF;

    -- ── CLOSE the scroll cursor ─────────────────────────────
    CLOSE cur_history;

    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE 'Scrollable cursor demonstration complete.';
    RAISE NOTICE '════════════════════════════════════════════';

EXCEPTION
    WHEN OTHERS THEN
        BEGIN
            CLOSE cur_history;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
        RAISE NOTICE 'ERROR in scroll cursor demo: % — %', SQLSTATE, SQLERRM;
END;
$$;


-- ═══════════════════════════════════════════════════════════════
-- END OF CURSOR DEMONSTRATIONS
-- ═══════════════════════════════════════════════════════════════
