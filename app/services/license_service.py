from app.db import execute_query, execute_one, execute_write

def get_all_licenses():
    """Gets all licenses, refreshing their statuses first."""
    # First, refresh statuses by calling the function (non-critical)
    try:
        execute_write("SELECT fn_refresh_license_statuses()")
    except Exception:
        pass  # Function may not exist; view still works
    
    # Then query the view
    return execute_query("""
        SELECT l.license_no, l.user_id, u.fname || ' ' || u.lname as owner_name, 
               l.license_type, l.vehicle_class, l.issue_date, l.expiry_date,
               l.effective_status AS status
        FROM v_license_status l
        JOIN users u ON l.user_id = u.user_id
        ORDER BY l.issue_date DESC
    """)

def search_licenses(query):
    search_term = f"%{query}%"
    return execute_query("""
        SELECT l.license_no, l.user_id, u.fname || ' ' || u.lname as owner_name, 
               l.license_type, l.vehicle_class, l.issue_date, l.expiry_date,
               l.effective_status AS status
        FROM v_license_status l
        JOIN users u ON l.user_id = u.user_id
        WHERE l.license_no ILIKE %s OR u.user_id ILIKE %s OR (u.fname || ' ' || u.lname) ILIKE %s
        ORDER BY l.issue_date DESC
    """, (search_term, search_term, search_term))

def issue_license(data):
    """Issues a new license."""
    try:
        # Check if user exists
        if not execute_one("SELECT 1 FROM users WHERE user_id = %s", (data['user_id'],)):
            return False, "User ID not found."
            
        if not execute_one("SELECT 1 FROM rto WHERE rto_code = %s", (data['issuing_rto_id'],)):
            return False, "Issuing RTO code not found."
            
        execute_write("""
            INSERT INTO license (license_no, user_id, license_type, vehicle_class,
                                issue_date, expiry_date, issuing_rto_id, status)
            VALUES (%s, %s, %s, %s, CURRENT_DATE, CURRENT_DATE + INTERVAL '10 years', %s, 'Active')
        """, (
            data['license_no'], data['user_id'], data['license_type'],
            data['vehicle_class'], data['issuing_rto_id']
        ))
        return True, "License issued successfully."
    except Exception as e:
        return False, f"Failed to issue license: {str(e)}"
