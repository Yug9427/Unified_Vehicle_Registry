# Unified Vehicle Registry

A full-stack **Unified Vehicle Registry** system built as a DBMS course project. It provides a centralized platform to manage vehicle life cycles, ownership transfers, regulatory compliance (insurance, permits, PUC, licenses), traffic challans, and e-wallet transactions — integrating data across RTOs, insurance providers, and law enforcement.

---

##  Features

### Vehicle & Owner Management
- Register vehicles with full specifications (VIN, body type, fuel type, manufacturer, etc.)
- Manage users identified by Aadhaar ID with complete profile data
- Track ownership history with time-based transfers and single-active-owner enforcement

### Regulatory Compliance
- **Licenses** — Learner, Permanent, Commercial, and International license tracking per RTO
- **Insurance** — Multiple concurrent policy types (Third-party, Comprehensive, Own-damage)
- **Permits** — Transport permits with multi-valued authorized routes and load/passenger limits
- **PUC Certificates** — Pollution-under-control tracking with validity enforcement

### Finance & Enforcement
- **E-Wallet** system with balance management and transaction history
- **Traffic Challans** — Issuance by officers, linked to wallet payments
- Challan payment validation via wallet transactions

### Analytics & Reporting
- Dashboard with aggregate statistics
- Reports and analytics module for data-driven insights

---

##  Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | React 19, TypeScript, Vite, Tailwind CSS 4, Framer Motion, Recharts, Lucide Icons |
| **Backend** | Python, Flask, flask-cors |
| **Database** | PostgreSQL (psycopg 3 + connection pooling) |
| **Tooling** | Oxlint, dotenv |

---

## Project Structure

```
DBMS_Project/
├── app/                          # Flask backend
│   ├── __init__.py               # App factory & blueprint registration
│   ├── config.py                 # Environment-based configuration
│   ├── db.py                     # psycopg connection pool & query helpers
│   ├── routes/                   # API route blueprints
│   │   ├── dashboard.py          #   GET /api/dashboard
│   │   ├── vehicles.py           #   /api/vehicles
│   │   ├── owners.py             #   /api/owners
│   │   ├── ownership.py          #   /api/ownership
│   │   ├── licenses.py           #   /api/licenses
│   │   ├── insurance.py          #   /api/insurance
│   │   ├── permits.py            #   /api/permits
│   │   ├── challans.py           #   /api/challans
│   │   ├── wallets.py            #   /api/wallets
│   │   └── reports.py            #   /api/reports
│   └── services/                 # Business logic layer
│       ├── dashboard_service.py
│       ├── vehicle_service.py
│       ├── owner_service.py
│       ├── ownership_service.py
│       ├── license_service.py
│       ├── insurance_service.py
│       ├── permit_service.py
│       ├── challan_service.py
│       ├── wallet_service.py
│       └── report_service.py
│
├── frontend/                     # React + Vite + Tailwind frontend
│   └── src/
│       ├── App.tsx               # Routing & sidebar layout
│       └── pages/
│           ├── Dashboard.tsx
│           ├── Vehicles.tsx      # Vehicle list
│           ├── VehicleDetail.tsx  # Single vehicle view
│           ├── VehicleRegistration.tsx
│           ├── Users.tsx         # User list
│           ├── UserDetail.tsx    # Single user view
│           ├── OwnershipTransfer.tsx
│           ├── Licenses.tsx
│           ├── Insurance.tsx
│           ├── Permits.tsx
│           ├── Challans.tsx
│           ├── Wallets.tsx       # Wallet list
│           ├── WalletDetail.tsx  # Single wallet view
│           └── Reports.tsx
│
├── SQL/                          # Database scripts (execute in order)
│   ├── 01_DDL.sql                # Tables, constraints, views
│   ├── 02_Insert_data.sql        # Seed / sample data
│   ├── 03_Queries.sql            # Analytical queries
│   ├── 04_Indexes.sql            # Performance indexes
│   ├── 05_Triggers.sql           # Ownership & validation triggers
│   ├── 06_Procedures_Functions.sql
│   ├── 07_Materialized_Views.sql
│   ├── 08_Advanced_Queries.sql
│   ├── 09_Cursors.sql
│   └── 10_Transactions.sql
│
├── Diagrams/                     # ER & Relational diagrams
│   ├── ER_diagram.png
│   └── Relational_diagram.png
│
├── .env.example                  # Environment variable template
├── requirements.txt              # Python dependencies
├── run.py                        # Backend entry point
├── start.sh                      # One-command launcher (both servers)
├── setup_guide.md                # Detailed setup instructions
└── Unified_Vehicle_Registry_schema.md  # Full schema documentation
```

---

##  Quick Start

### Prerequisites

- **Python** 3.10+
- **Node.js** 18+ & npm
- **PostgreSQL** 14+

### 1. Clone & configure

```bash
git clone <your-repo-url>
cd DBMS_Project
cp .env.example .env
# Edit .env with your PostgreSQL credentials
```

### 2. Set up the database

```bash
createdb unified_vehicle_registry

# Run all SQL scripts in order
for f in SQL/*.sql; do psql -d unified_vehicle_registry -f "$f"; done
```

### 3. Start both servers

```bash
# Backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Frontend
cd frontend && npm install && cd ..

# Launch everything
chmod +x start.sh
./start.sh
```

| Server | URL |
|--------|-----|
| Frontend (Vite) | http://localhost:5173 |
| Backend (Flask) | http://127.0.0.1:5001 |

> For detailed step-by-step instructions, see [`setup_guide.md`](setup_guide.md).

---

##  Database Design

The PostgreSQL schema models **15 tables** covering users, vehicles, ownership history, insurance, RC books, PUC certificates, RTOs, officers, licenses, permits, vehicle logs, challans, e-wallets, wallet transactions, and permit routes.

Key design highlights:
- **Aadhaar-based identity** — users keyed by 12-digit Aadhaar ID
- **Temporal ownership** — historical tracking with single-active-owner trigger enforcement
- **Derived attributes** — age, ownership status, PUC status, and permit status computed at query time
- **Audit logging** — JSONB snapshots of all ownership changes
- **Connection pooling** — `psycopg_pool` for efficient backend connections

### ER Diagram

See [`Diagrams/ER_diagram.png`](Diagrams/ER_diagram.png) for the full entity-relationship diagram.

### Relational Diagram

See [`Diagrams/Relational_diagram.png`](Diagrams/Relational_diagram.png) for the mapped relational schema.

For the complete schema documentation, refer to [`Unified_Vehicle_Registry_schema.md`](Unified_Vehicle_Registry_schema.md).

---

##  SQL Scripts Overview

| # | Script | Purpose |
|---|--------|---------|
| 01 | `DDL.sql` | Table creation, constraints, CHECK rules, views |
| 02 | `Insert_data.sql` | Seed data for all tables |
| 03 | `Queries.sql` | Analytical SELECT queries |
| 04 | `Indexes.sql` | B-Tree and performance indexes |
| 05 | `Triggers.sql` | Ownership, scrapped-vehicle, and payment validation triggers |
| 06 | `Procedures_Functions.sql` | Stored procedures and functions |
| 07 | `Materialized_Views.sql` | Pre-computed views for reporting |
| 08 | `Advanced_Queries.sql` | Complex joins, CTEs, window functions |
| 09 | `Cursors.sql` | Cursor-based processing examples |
| 10 | `Transactions.sql` | Transaction management and isolation |

---

##  API Endpoints

All routes are prefixed with `/api`:

| Endpoint | Description |
|----------|-------------|
| `GET /api/dashboard` | Aggregate statistics and counts |
| `/api/vehicles` | Vehicle CRUD operations |
| `/api/owners` | User/owner management |
| `/api/ownership` | Ownership transfer operations |
| `/api/licenses` | License management |
| `/api/insurance` | Insurance policy operations |
| `/api/permits` | Transport permit management |
| `/api/challans` | Challan issuance and payment |
| `/api/wallets` | E-Wallet and transaction management |
| `/api/reports` | Analytics and reporting queries |

---
