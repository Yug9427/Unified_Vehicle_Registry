from app.db import execute_query, execute_one, execute_write

def get_all_permits():
    """Gets all permits using the v_permit_status view."""
    return execute_query("""
        SELECT p.permit_id, p.vehicle_id, v.model_name, p.permit_type, 
               p.issue_date, p.expiry_date, p.issuing_rto_id, p.permit_status
        FROM v_permit_status p
        JOIN vehicle v ON p.vehicle_id = v.vehicle_id
        ORDER BY p.issue_date DESC
    """)

def search_permits(query):
    search_term = f"%{query}%"
    return execute_query("""
        SELECT p.permit_id, p.vehicle_id, v.model_name, p.permit_type, 
               p.issue_date, p.expiry_date, p.issuing_rto_id, p.permit_status
        FROM v_permit_status p
        JOIN vehicle v ON p.vehicle_id = v.vehicle_id
        WHERE p.permit_id::text ILIKE %s OR p.vehicle_id ILIKE %s OR v.model_name ILIKE %s
        ORDER BY p.issue_date DESC
    """, (search_term, search_term, search_term))

def issue_permit(data):
    """Issues a new permit and adds routes if provided."""
    try:
        if not execute_one("SELECT 1 FROM vehicle WHERE vehicle_id = %s", (data['vehicle_id'],)):
            return False, "Vehicle ID not found."
            
        from app.db import pool
        with pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO permit (vehicle_id, permit_type, issue_date, expiry_date, 
                                       issuing_rto_id, max_load_capacity, max_passengers)
                    VALUES (%s, %s, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', %s, %s, %s)
                    RETURNING permit_id
                """, (
                    data['vehicle_id'], data['permit_type'], data['rto_code'],
                    data.get('max_load_capacity', 0), data.get('max_passengers', 0)
                ))
                new_permit_id = cur.fetchone()[0]
                
                # Add routes if provided
                if data.get('routes'):
                    routes = [r.strip() for r in data['routes'].split(',') if r.strip()]
                    for route in routes:
                        cur.execute("""
                            INSERT INTO permit_route (permit_id, authorized_route)
                            VALUES (%s, %s)
                        """, (new_permit_id, route))
                        
            conn.commit()
        return True, "Permit issued successfully."
    except Exception as e:
        return False, f"Failed to issue permit: {str(e)}"
