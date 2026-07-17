DROP VIEW IF EXISTS v_user_age, v_ownership_status, v_puc_status, v_permit_status, v_insurance_status, v_license_status, v_vehicle_condition, v_vehicle_age CASCADE;
DROP TABLE IF EXISTS challan, wallet_transaction, e_wallet, permit_route, permit, license, puc, rc_book, insurance, ownership, vehicle_log, officer, rto, vehicle, users CASCADE;

CREATE TABLE users (
    user_id char(12) PRIMARY KEY,
    password varchar(255) NOT NULL,
    fname varchar(50) NOT NULL,
    mname varchar(50),
    lname varchar(50),
    dob date NOT NULL,
    gender varchar(10) CHECK (gender IN ('Male','Female','Other')),
    blood_group varchar(3),
    email varchar(120) UNIQUE,
    phone_number varchar(15) UNIQUE NOT NULL,
    street varchar(100),
    city varchar(50),
    state varchar(50),
    pincode char(6)
);

CREATE TABLE vehicle (
    vehicle_id varchar(17) PRIMARY KEY,
    model_name varchar(60) NOT NULL,
    vehicle_weight int CHECK (vehicle_weight > 0),
    manufacturer varchar(60),
    manufactured_year int,
    registration_type varchar(15) CHECK (registration_type IN ('Transport','Non-transport','Electric')),
    body_type varchar(20),
    fuel_type varchar(10) CHECK (fuel_type IN ('Petrol','Diesel','Electric','CNG')),
    odometer_reading int,
    registration_date date
);

CREATE TABLE rto (
    rto_code varchar(10) PRIMARY KEY,
    rto_name varchar(100) NOT NULL,
    city varchar(50),
    district varchar(50),
    state varchar(50),
    pincode char(6) NOT NULL
);

CREATE TABLE officer (
    officer_id serial PRIMARY KEY,
    name varchar(100) NOT NULL,
    rto_code varchar(10) NOT NULL REFERENCES rto(rto_code)
);

CREATE TABLE e_wallet (
    wallet_id serial PRIMARY KEY,
    user_id char(12) NOT NULL UNIQUE REFERENCES users(user_id),
    balance numeric(12,2) NOT NULL DEFAULT 0,
    status varchar(10) NOT NULL DEFAULT 'Active' CHECK (status IN ('Active','Closed','Blocked'))
);

CREATE TABLE wallet_transaction (
    transaction_id serial PRIMARY KEY,
    from_wallet_id int NOT NULL REFERENCES e_wallet(wallet_id),
    to_wallet_id int REFERENCES e_wallet(wallet_id),
    amount numeric(12,2) NOT NULL CHECK (amount > 0),
    purpose varchar(10) CHECK (purpose IN ('toll','fuel','challan','refund')),
    tran_datetime timestamp NOT NULL DEFAULT now(),
    status varchar(10) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Success','Failed','Pending'))
);

CREATE TABLE ownership (
    ownership_id serial PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL REFERENCES vehicle(vehicle_id),
    owner_id char(12) NOT NULL REFERENCES users(user_id),
    from_date date NOT NULL,
    to_date date
);

CREATE TABLE insurance (
    policy_id varchar(30) PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL REFERENCES vehicle(vehicle_id),
    issue_date date NOT NULL,
    expiry_date date NOT NULL,
    coverage_amount numeric(12,2) NOT NULL,
    insurance_type varchar(15) CHECK (insurance_type IN ('Third-party','Comprehensive','Own-damage')),
    premium_amount numeric(10,2) NOT NULL,
    number_of_claims int NOT NULL DEFAULT 0,
    insurance_company varchar(100) NOT NULL,
    CHECK (expiry_date > issue_date)
);

CREATE TABLE rc_book (
    registration_no varchar(20) PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL UNIQUE REFERENCES vehicle(vehicle_id),
    plate_number varchar(15) UNIQUE NOT NULL,
    chassis_no varchar(30) UNIQUE NOT NULL,
    engine_no varchar(30) UNIQUE NOT NULL,
    color varchar(20) NOT NULL
);

CREATE TABLE puc (
    certificate_number varchar(30) PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL REFERENCES vehicle(vehicle_id),
    date_of_test date NOT NULL,
    valid_until date NOT NULL,
    centre_code varchar(15) NOT NULL,
    CHECK (valid_until >= date_of_test + INTERVAL '3 months')
);

CREATE TABLE license (
    license_no varchar(20) PRIMARY KEY,
    user_id char(12) NOT NULL REFERENCES users(user_id),
    issue_date date NOT NULL,
    expiry_date date NOT NULL,
    license_type varchar(15) NOT NULL CHECK (license_type IN ('Learner','Permanent','Commercial','International')),
    vehicle_class varchar(20) NOT NULL,
    issuing_rto_id varchar(10) NOT NULL REFERENCES rto(rto_code),
    status varchar(10) NOT NULL DEFAULT 'Active' CHECK (status IN ('Active','Suspended','Expired','Revoked'))
);

CREATE TABLE permit (
    permit_id serial PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL REFERENCES vehicle(vehicle_id),
    permit_type varchar(30) NOT NULL,
    issuing_rto_id varchar(10) NOT NULL REFERENCES rto(rto_code),
    issue_date date NOT NULL,
    expiry_date date NOT NULL,
    max_load_capacity numeric(8,2) NOT NULL,
    max_passengers int NOT NULL,
    CHECK (expiry_date >= issue_date + INTERVAL '3 months')
);
CREATE TABLE permit_route (
    permit_id int NOT NULL REFERENCES permit(permit_id),
    authorized_route varchar(100) NOT NULL,
    PRIMARY KEY (permit_id, authorized_route)
);

CREATE TABLE vehicle_log (
    status_id serial PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL REFERENCES vehicle(vehicle_id),
    vehicle_status varchar(20) NOT NULL CHECK (vehicle_status IN ('Seized_by_police','Stolen','Lost','Under_Repair','Scrapped')),
    start_date date NOT NULL,
    end_date date,
    CHECK (end_date IS NULL OR end_date > start_date)
);

CREATE TABLE challan (
    challan_id serial PRIMARY KEY,
    vehicle_id varchar(17) NOT NULL REFERENCES vehicle(vehicle_id),
    issuing_officer_id int NOT NULL REFERENCES officer(officer_id),
    amount numeric(10,2) NOT NULL CHECK (amount > 0),
    reason varchar(200) NOT NULL,
    challan_date date NOT NULL,
    location varchar(100) NOT NULL,
    is_paid boolean NOT NULL DEFAULT false,
    wallet_transaction_id int UNIQUE REFERENCES wallet_transaction(transaction_id)
);
