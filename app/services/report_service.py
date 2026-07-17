from app.db import execute_query, execute_write

def refresh_materialized_views():
    """Refreshes all materialized views used in the application."""
    views = [
        'mv_vehicle_dashboard',
        'mv_vehicle_compliance_summary',
        'mv_challan_revenue_by_state',
        'mv_insurance_market_share',
        'mv_rto_statistics'
    ]
    for view in views:
        execute_write(f"REFRESH MATERIALIZED VIEW CONCURRENTLY {view}")
    return True

def get_compliance_summary():
    """Aggregates compliance data from mv_vehicle_compliance_summary by registration_type."""
    return execute_query("""
        SELECT registration_type,
               COUNT(*) AS total_vehicles,
               COUNT(*) FILTER (WHERE has_active_insurance) AS insured_vehicles,
               COUNT(*) FILTER (WHERE NOT has_active_insurance) AS uninsured_vehicles,
               ROUND(100.0 * COUNT(*) FILTER (WHERE has_active_insurance) / NULLIF(COUNT(*), 0), 1) AS insurance_compliance_pct,
               COUNT(*) FILTER (WHERE is_fully_compliant) AS fully_compliant
        FROM mv_vehicle_compliance_summary
        GROUP BY registration_type
        ORDER BY registration_type
    """)

def get_revenue_by_state():
    return execute_query("SELECT * FROM mv_challan_revenue_by_state ORDER BY total_revenue DESC")

def get_insurance_market_share():
    return execute_query("SELECT * FROM mv_insurance_market_share ORDER BY policies_issued DESC")

def get_rto_statistics():
    return execute_query("SELECT * FROM mv_rto_statistics ORDER BY total_challans DESC")

def get_top_defaulters():
    """AQ10: Top 10 Defaulters (Users with most unpaid challans)."""
    return execute_query("""
        WITH UserChallans AS (
            SELECT u.user_id, u.fname || ' ' || u.lname as owner_name, 
                   COUNT(c.challan_id) as total_unpaid_challans,
                   SUM(c.amount) as total_unpaid_amount
            FROM users u
            JOIN ownership o ON u.user_id = o.owner_id AND o.to_date IS NULL
            JOIN vehicle v ON o.vehicle_id = v.vehicle_id
            JOIN challan c ON v.vehicle_id = c.vehicle_id
            WHERE c.is_paid = FALSE
            GROUP BY u.user_id, owner_name
        )
        SELECT * FROM UserChallans
        ORDER BY total_unpaid_amount DESC NULLS LAST
        LIMIT 10
    """)

def get_monthly_challan_trend():
    """Q29: Monthly Challan Trend."""
    return execute_query("""
        SELECT TO_CHAR(challan_date, 'YYYY-MM') AS month,
               COUNT(*) AS challans_issued, SUM(amount) AS total_fine,
               COUNT(*) FILTER (WHERE is_paid = TRUE) AS paid_count,
               COUNT(*) FILTER (WHERE is_paid = FALSE) AS unpaid_count
        FROM challan
        GROUP BY TO_CHAR(challan_date, 'YYYY-MM')
        ORDER BY month DESC
        LIMIT 12
    """)
