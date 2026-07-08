# Unified Vehicle Registry Schema

## Database Overview
The Unified Vehicle Registry is a centralized system designed to manage vehicle life cycles, ownership transfers, regulatory compliance, and related financial transactions. It integrates data across RTOs, insurance, and law enforcement for seamless access and monitoring.

## Design Assumptions

### Users & Identity
- A user is uniquely identified by a 12-digit Aadhaar ID (`user_id = char(12)`), which serves as the primary key.
- Each user must have a phone number and first name; middle name and last name are optional.
- A user's **age** is a derived attribute, computed from DOB at query time — it is not stored.
- Email and phone number must be unique across all users.

### Vehicles & Ownership
- A vehicle is uniquely identified by a 17-character **VIN** (Vehicle Identification Number).
- A vehicle can have **multiple owners over time**, but only **one active owner at any given point** (enforced by trigger `trg_prevent_double_ownership`).
- Active ownership is indicated by `to_date IS NULL`; a closed ownership has an explicit `to_date`.
- `is_current` (ownership) is a **derived boolean** — not stored, computed from `to_date IS NULL`.
- Scrapped vehicles cannot have new ownership, insurance, or permit records assigned to them (enforced by trigger `trg_prevent_scrapped_vehicle_ops`).

### Vehicle Documents
- Each vehicle has **exactly one RC Book** (`vehicle_id` is UNIQUE in `rc_book`), but can have multiple PUC certificates over time.
- Plate number, chassis number, and engine number are all unique across the entire registry.
- A PUC certificate's validity must be **at least 3 months** from the test date (enforced by CHECK constraint).
- **Certificate Status** (PUC) is a derived attribute, computed from `valid_until` vs current date.

### Insurance
- A vehicle can have **multiple insurance policies** over time (1:N), and can also have **more than one active policy simultaneously** — since different insurance types (Third-party, Comprehensive, Own-damage) are not mutually exclusive.
- Insurance `expiry_date` must always be after `issue_date` (enforced by CHECK constraint).
- A vehicle is considered **compliant** only if it has both an active insurance policy AND an active PUC certificate.

### Permits
- Permits are only applicable to transport-type vehicles.
- `Authorized_route` is a **multi-valued attribute**, stored in a separate `permit_route` table (composite PK: `permit_id + authorized_route`).
- Permit `expiry_date` must be at least 3 months after `issue_date` (enforced by CHECK constraint).
- **Permit Status** is a derived attribute, computed from `expiry_date` vs current date.

### Licenses
- Each user can hold multiple licenses of different types (Learner, Permanent, Commercial, International).
- A license is issued and tracked by a specific RTO.
- License status defaults to `'Active'`; it transitions to `'Expired'` via a scheduled refresh function (`fn_refresh_license_statuses`), not automatically on query.

### E-Wallet & Transactions
- Each user has **exactly one E-Wallet** (`user_id` is UNIQUE in `e_wallet`).
- Wallet balance starts at `0` by default and is updated automatically on successful transactions via trigger (`trg_wallet_balance_update`).
- `to_wallet_id` in a transaction can be NULL — this represents an **external payment** (e.g., toll, fuel, challan to a government body).
- A challan **cannot be marked as paid** without a linked `wallet_transaction_id` (enforced by trigger `trg_validate_challan_payment`).
- Only wallets with status `'Active'` can initiate transactions.

### Officers & Challans
- Officers belong to a specific RTO and can issue challans to any vehicle.
- A challan's `wallet_transaction_id` is nullable (unpaid state) and UNIQUE (one payment per challan).
- Challan amount must always be positive.

### Audit & Integrity
- All changes to the `ownership` table (INSERT, UPDATE, DELETE) are recorded in an `audit_log` table with JSONB snapshots of old and new data.
- Serial (`SERIAL`) primary keys are used for auto-incrementing IDs in tables like `officer`, `e_wallet`, `wallet_transaction`, `ownership`, `permit`, `vehicle_log`, and `challan`.

## Entities

**User**

* user\_id \-\>aadhaar\_id (unique)  
* Password  
* Name → (Fname, Mname, Lname)  
* DOB  
* (derived) age ← from DOB  
* Gender  
* Blood Group  
* Email  
* Phone Number  
* Address (composite → street, city, state, pincode)

**Vehicle**

* vehicle\_id (VIN) (PK)  
* Model Name  
* Vehicle Weight  
* Manufacturer  
* Manufactured Year  
* Registration Type (Transport / Non-transport / Electric)  
* Body Type (Sedan, Hatchback, SUV, Truck, Tempo…)  
* Fuel Type (Petrol, Diesel, Electric, CNG)  
* Odometer Reading  
* Registration Date

**Ownership** (handles owner changes over time — User ↔ Vehicle)

* ownership\_id (PK)  
* vehicle\_id (FK → Vehicle)  
* owner\_id (FK → User.aadhaar\_id)  
* from\_date  
* to\_date  
* (derived)is\_current (boolean)

**Insurance** (weak entity of Vehicle)

* policy\_id (PK)  
* vehicle\_id (FK → Vehicle)  
* Issue\_date  
* Expiry\_date  
* Coverage\_Amount  
* Insurance Type (Third-party, Comprehensive, Own-damage)  
* Premium\_Amount  
* Number of Claims  
* Insurance Company

**Vehicle Documents – RC Book**

* registration\_no (PK)  
* vehicle\_id (FK → Vehicle)  
* Plate Number  
* Chassis No.  
* Engine No.  
* Color

**Vehicle Documents – PUC**

* certificate\_number (PK)  
* vehicle\_id (FK → Vehicle)  
* Date of Test  
* Valid Until  
* (derived) Certificate Status ← from Valid Until  
* Centre Code

**RTO**

* RTO\_code (PK)  
* RTO\_name  
* Address (composite → city, district, state, pincode)

**Officer**

* officer\_id (PK)  
* Name  
* rto\_code (FK → RTO)

**License**

* license\_no (PK)  
* user\_id (FK → User.aadhaar\_id)  
* Issue\_Date  
* Expiry\_Date  
* License\_Type (Learner, Permanent, Commercial, International)  
* Vehicle\_Class  
* issuing\_rto\_id (FK → RTO.RTO\_code)  
* Status (Active, Suspended, Expired, Revoked)

**Permit**

* permit\_id (PK)  
* vehicle\_id (FK → Vehicle)  
* Permit\_type  
* issuing\_rto\_id (FK → RTO)  
* Issue\_date  
* Expiry\_date  
* (derived)Status   
* Authorized\_route (multi value)  
* Max\_load\_capacity  
* max\_passengers

**Vehicle Log**

* status\_id (PK)  
* vehicle\_id (FK → Vehicle)  
* Vehicle\_status (Seized\_by\_police, Stolen, Lost, Under Repair, Scrapped…)  
* Start\_date  
* End\_date

**Challan**

* challan\_id (PK)  
* vehicle\_id (FK → Vehicle)  
* issuing\_officer\_id (FK → Officer)  
* Amount  
* Reason  
* challan\_date  
* location  
* Is\_Paid (boolean)  
* wallet\_transaction\_id (FK → Wallet Transaction, nullable)

**E-Wallet**

* wallet\_id (PK)  
* user\_id (FK → User)  
* Balance  
* Status (Active, Closed, Blocked)

**Wallet Transaction (it is self reference relation table)**

* transaction\_id (PK)  
* From\_wallet\_id (FK → E-Wallet)  
* To\_wallet\_id (FK → E-Wallet)  
* Purpose (toll, fuel, challan, refund)  
* tran\_datetime  
* Status (Success, Failed, Pending)  
* Amount

## Relationship Notes
- **User to Vehicle:** M:N relationship, resolved by the `Ownership` table which tracks historical and current ownership.
- **Vehicle to Insurance:** 1:N relationship. A vehicle can have multiple insurance policies over time.
- **Vehicle to Challan:** 1:N relationship. A vehicle can accumulate multiple challans issued by officers.
- **Wallet to Transactions:** 1:N relationship. The self-referencing `Wallet Transaction` table links sender and receiver wallets.
- **RTO to Officer / License / Permit:** 1:N relationships. RTOs issue multiple licenses and permits, and manage multiple officers.
