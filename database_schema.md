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

