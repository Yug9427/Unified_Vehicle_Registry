from app.db import execute_query, execute_one, execute_write

def search_vehicles(query):
    """Searches for vehicles by VIN, model, or manufacturer."""
    search_term = f"%{query}%"
    return execute_query("""
        SELECT v.vehicle_id, v.model_name, v.manufacturer, v.registration_date,
               rc.registration_no, rc.plate_number,
               o_info.owner_name,
               EXISTS(SELECT 1 FROM insurance i WHERE i.vehicle_id = v.vehicle_id AND i.expiry_date >= CURRENT_DATE) as has_insurance,
               EXISTS(SELECT 1 FROM puc p WHERE p.vehicle_id = v.vehicle_id AND p.valid_until >= CURRENT_DATE) as has_puc
        FROM vehicle v
        LEFT JOIN rc_book rc ON v.vehicle_id = rc.vehicle_id
        LEFT JOIN (
            SELECT o.vehicle_id, u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name
            FROM ownership o
            JOIN users u ON o.owner_id = u.user_id
            WHERE o.to_date IS NULL
        ) o_info ON v.vehicle_id = o_info.vehicle_id
        WHERE v.vehicle_id ILIKE %s
           OR v.model_name ILIKE %s
           OR v.manufacturer ILIKE %s
           OR rc.registration_no ILIKE %s
        ORDER BY v.registration_date DESC
        LIMIT 50
    """, (search_term, search_term, search_term, search_term))

def get_vehicle_profile(vehicle_id):
    """Gets complete vehicle profile (Q27)."""
    return execute_one("""
        SELECT
            v.vehicle_id, v.model_name, v.manufacturer, v.manufactured_year,
            EXTRACT(YEAR FROM CURRENT_DATE)::int - v.manufactured_year AS vehicle_age,
            v.fuel_type, v.body_type, v.registration_type, v.vehicle_weight, v.odometer_reading, v.registration_date,
            rc.registration_no, rc.plate_number, rc.chassis_no, rc.engine_no, rc.color,
            owner_u.user_id AS owner_id,
            owner_u.fname || COALESCE(' ' || owner_u.mname, '') || COALESCE(' ' || owner_u.lname, '') AS owner_name,
            owner_u.phone_number AS owner_phone,
            COALESCE(
                (SELECT vl.vehicle_status FROM vehicle_log vl
                 WHERE vl.vehicle_id = v.vehicle_id AND vl.end_date IS NULL
                 ORDER BY vl.start_date DESC LIMIT 1),
                'Normal'
            ) AS current_condition,
            COALESCE(latest_ins.expiry_date >= CURRENT_DATE, FALSE) AS insurance_active,
            COALESCE(latest_puc.valid_until >= CURRENT_DATE, FALSE) AS puc_active,
            latest_ins.policy_id AS latest_insurance_policy,
            latest_ins.expiry_date AS insurance_expiry,
            latest_ins.insurance_company,
            latest_puc.certificate_number AS latest_puc_certificate,
            latest_puc.valid_until AS puc_valid_until
        FROM vehicle v
        LEFT JOIN rc_book rc ON v.vehicle_id = rc.vehicle_id
        LEFT JOIN ownership o_curr ON v.vehicle_id = o_curr.vehicle_id AND o_curr.to_date IS NULL
        LEFT JOIN users owner_u ON o_curr.owner_id = owner_u.user_id
        LEFT JOIN (
            SELECT DISTINCT ON (vehicle_id) vehicle_id, policy_id, expiry_date, insurance_company
            FROM insurance ORDER BY vehicle_id, expiry_date DESC
        ) latest_ins ON v.vehicle_id = latest_ins.vehicle_id
        LEFT JOIN (
            SELECT DISTINCT ON (vehicle_id) vehicle_id, certificate_number, valid_until
            FROM puc ORDER BY vehicle_id, valid_until DESC
        ) latest_puc ON v.vehicle_id = latest_puc.vehicle_id
        WHERE v.vehicle_id = %s
    """, (vehicle_id,))

def get_ownership_history(vehicle_id):
    """Gets ownership history (Q15)."""
    return execute_query("""
        SELECT
            o.ownership_id, o.vehicle_id, v.model_name, u.user_id,
            u.fname || COALESCE(' ' || u.mname, '') || COALESCE(' ' || u.lname, '') AS owner_name,
            o.from_date, o.to_date,
            CASE WHEN o.to_date IS NULL THEN 'Current Owner' ELSE 'Past Owner' END AS status,
            COALESCE(o.to_date, CURRENT_DATE) - o.from_date AS days_owned
        FROM ownership o
        JOIN users u ON o.owner_id = u.user_id
        JOIN vehicle v ON o.vehicle_id = v.vehicle_id
        WHERE o.vehicle_id = %s
        ORDER BY o.from_date DESC
    """, (vehicle_id,))

def get_insurance_history(vehicle_id):
    """Gets insurance history (Q5A)."""
    return execute_query("""
        SELECT
            policy_id, insurance_company, insurance_type, issue_date, expiry_date,
            coverage_amount, premium_amount, number_of_claims,
            CASE WHEN expiry_date >= CURRENT_DATE THEN 'Active' ELSE 'Expired' END AS policy_status
        FROM insurance
        WHERE vehicle_id = %s
        ORDER BY issue_date DESC
    """, (vehicle_id,))

def get_challans(vehicle_id):
    """Gets all challans for a vehicle."""
    return execute_query("""
        SELECT c.challan_id, c.reason, c.amount, c.challan_date, c.location, c.is_paid, o.name as officer_name
        FROM challan c
        JOIN officer o ON c.issuing_officer_id = o.officer_id
        WHERE c.vehicle_id = %s
        ORDER BY c.challan_date DESC
    """, (vehicle_id,))

def get_puc_history(vehicle_id):
    return execute_query("""
        SELECT certificate_number, date_of_test, valid_until, centre_code,
               CASE WHEN valid_until >= CURRENT_DATE THEN 'Active' ELSE 'Expired' END AS status
        FROM puc
        WHERE vehicle_id = %s
        ORDER BY date_of_test DESC
    """, (vehicle_id,))

def get_permit_history(vehicle_id):
    return execute_query("""
        SELECT p.permit_id, p.permit_type, r.rto_name, p.issue_date, p.expiry_date,
               CASE WHEN p.expiry_date >= CURRENT_DATE THEN 'Active' ELSE 'Expired' END AS status
        FROM permit p
        JOIN rto r ON p.issuing_rto_id = r.rto_code
        WHERE p.vehicle_id = %s
        ORDER BY p.issue_date DESC
    """, (vehicle_id,))

def register_vehicle(data):
    """Registers a new vehicle along with RC Book and initial ownership."""
    try:
        # Check if user exists
        user_exists = execute_one("SELECT 1 FROM users WHERE user_id = %s", (data['owner_id'],))
        if not user_exists:
            return False, "Owner ID does not exist in the system."
            
        # Start implicit transaction via execute_write (which commits at end, but we need multiple writes)
        # We will use raw connection here to ensure transaction atomicity
        from app.db import pool
        with pool.connection() as conn:
            with conn.cursor() as cur:
                # 1. Insert Vehicle
                cur.execute("""
                    INSERT INTO vehicle (vehicle_id, model_name, vehicle_weight, manufacturer, 
                                        manufactured_year, registration_type, body_type, fuel_type, 
                                        odometer_reading, registration_date)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_DATE)
                """, (
                    data['vehicle_id'], data['model_name'], data['vehicle_weight'], 
                    data['manufacturer'], data['manufactured_year'], data['registration_type'],
                    data['body_type'], data['fuel_type'], data['odometer_reading']
                ))
                
                # 2. Insert RC Book
                cur.execute("""
                    INSERT INTO rc_book (registration_no, vehicle_id, plate_number, chassis_no, engine_no, color)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    data['registration_no'], data['vehicle_id'], data['plate_number'],
                    data['chassis_no'], data['engine_no'], data['color']
                ))
                
                # 3. Insert initial ownership
                cur.execute("""
                    INSERT INTO ownership (vehicle_id, owner_id, from_date, to_date)
                    VALUES (%s, %s, CURRENT_DATE, NULL)
                """, (data['vehicle_id'], data['owner_id']))
                
            conn.commit()
        return True, "Vehicle registered successfully."
    except Exception as e:
        return False, f"Registration failed: {str(e)}"
