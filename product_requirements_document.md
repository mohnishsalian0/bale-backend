# Fabric Inventory Management System - PRD ## Technical Architecture & Stack
### Core Technology Stack

#### Backend
- **Framework**: Rust + Axum
- **Database**: Supabase (PostgreSQL with Row Level Security)
- **Authentication**: Supabase Auth (JWT-based)
- **File Storage**: Supabase Storage
- **Deployment**: Railway or Fly.io (decision pending)

#### Mobile Application
- **Framework**: React Native
- **Platform**: Android (primary focus)
- **Offline Support**: Phase 2 feature (not in MVP)

#### Public Sales Catalog
- **Framework**: TBD (React/Next.js decision pending)
- **Deployment**: Vercel/Netlify (static hosting)

#### Additional Services
- **PDF Generation**: For barcode printing
- **Barcode Generation**: QR codes for stock units
- **Image Processing**: Product image optimization
- **Monitoring**: Built-in Railway/Fly.io analytics
- **Real-time Updates**: Not in Phase 1 (future consideration)

### Architecture Decisions
- **Single App Approach**: Admins manage products/inventory through mobile app (no separate web dashboard)
- **Multi-tenant**: Company-based isolation with warehouse-level staff access
- **Role-based Access**: Admin (full access) + Staff (warehouse-specific)
- **Mobile-first**: Primary interface for all inventory operations

---

## Problem & Opportunity

India's textile industry (₹20.1 lakh crore/$240.8B market) has 96.66% unorganized production flowing through intermediary traders to reach the domestic market (70% of production). These fabric traders lack specialized inventory tools—existing solutions are either too generic (TallyPrime, Vyapar) or too complex (enterprise ERPs). With 2.5 crore traders now eligible for MSME registration, there's a clear digitization opportunity.

### Market Size

- **TAM:** ₹18.5 lakh crore/$222B textile market (growing 11.98% CAGR)
- **SAM:** Fabric trading intermediary layer (70% of domestic production)
- **SOM:** ₹14-70 crore (1-5% penetration of eligible MSME traders)

### Solution

**Vision:** Digitize India's fabric trading ecosystem with purpose-built tools

**Positioning:** "The only inventory management platform designed specifically for fabric - not too simple like generic software, not too complex like enterprise ERP, but just right for fabric"

**Core Value Props:**
- Fabric-specific inventory tracking (roll, color, weight, quality)
- Trading workflow optimization

**Competitive Advantage:**
- **vs Generic Software:** Built for fabric specifications
- **vs Enterprise ERP:** Right-sized complexity and cost
- **vs Textile Apps:** Comprehensive inventory beyond basic transactions

---

## User Research & Personas

### Primary Persona: Embroidery Fabric Trading Business Owner

**Demographics:**
- Role: Owner of embroidery fabric trading business
- Experience: Managing 250+ designs, 15 new designs weekly
- Technology comfort: Moderate (currently uses Excel, Tally, WhatsApp)

**Daily Workflow:**
- Check WhatsApp orders from clients
- Coordinate between fabric suppliers, embroidery masters, and customers
- Track design progress across multiple embroidery units
- Update Excel sheets manually with design codes, quantities, client details
- Physical visits/calls to embroidery masters for work updates

**Responsibilities:**
- Manage 250+ designs with custom design codes and client numbering systems
- Source base fabrics from multiple suppliers
- Coordinate embroidery work (currently: 20 designs total, 4 complete, 5 in pipeline, 10 pending)
- Handle sampling process and client approvals
- Track inventory by meters with fabric specifications (color, design, quantity)

**Pain Points:**
- **Time-consuming coordination:** Regular physical visits/calls to embroidery masters for updates
- **Manual tracking:** Excel-based design codes, color management, client details
- **Stock visibility:** Cannot instantly confirm fabric availability (e.g., "Black 100m, Blue 100m")
- **Work-in-progress tracking:** No real-time visibility of embroidery work status
- **Communication gaps:** Miscommunication with embroidery masters on designs and colors

**Technology Constraints:**
- Current budget range: ₹10-20K (₹1 lakh systems not affordable)
- Wants barcode system but needs it simple for less-educated staff
- Prefers mobile-friendly solutions for field coordination

**User Stories:**
1. "I want to track embroidery work progress without physical visits so I can save time and give accurate delivery dates"
2. "I want instant fabric stock visibility so I can confirm orders immediately when sales team asks"
3. "I want design code management with photos and color charts so embroidery masters don't make mistakes"

### Primary Persona: Sports Fabric Trading Business Owner

**Demographics:**
- Role: Owner of sports fabric trading business (jerseys, sportswear fabrics)
- Experience: Cotton yarn to finished fabric coordination with dyeing houses
- Technology comfort: Basic (uses physical files, TurboTax for billing, no Excel)

**Daily Workflow:**
- Check physical files for order status (ingoing/outgoing files)
- Coordinate dyeing work across 2-5 different dyeing houses
- Manage quality checks and handle damaged/re-dyeing processes
- Track 4000+ rolls (20-25kg each, total ~100 tons)
- Handle customer orders based on current stock availability

**Responsibilities:**
- Manage 4000+ fabric rolls across 20+ categories (Dry Fit, Polo Matte, etc.)
- Coordinate with multiple dyeing houses based on rates, quality, delivery times
- Handle peak season planning (3-4 week rush periods) vs off-season stock building
- Track orders by roll count but price by weight (kg)
- Manage damage, wastage, and re-dyeing processes
- Maintain customer relationships (direct customers, corporate clients)

**Pain Points:**
- **No stock visibility:** Cannot check current inventory during peak seasons
- **Manual file tracking:** Physical files for all inventory management (no digital records)
- **Weight vs roll confusion:** Orders by rolls, pricing by kg, leading to calculation errors
- **Quality issues:** Tracking damaged inventory, re-dyeing decisions, wastage management
- **Supplier coordination:** Managing multiple dyeing houses with different capabilities
- **Customer communication:** Cannot provide instant stock confirmation

**Current Process:**
- Uses WhatsApp and phone calls for all communication
- Creates PO only for high-value orders
- Handles returns through debit notes via accountant
- Uses Tally-like accounting software for basic billing (sales orders, dyeing orders, outstanding tracking)

**User Stories:**
1. "I want real-time stock visibility by weight and roll count so I can confirm orders instantly"
2. "I want to track dyeing house work progress so I can manage delivery commitments better"
3. "I want easy damage/wastage recording with date tracking so I can reduce losses"

### Secondary Persona: Dispatch Staff

**Demographics:**
- Role: Warehouse and dispatch handling
- Technology comfort: Basic smartphone usage
- Education: Limited formal education

**Daily Workflow:**
- Handle physical roll movements (50+ rolls daily)
- Update manual dispatch sheets
- Coordinate with sales team on stock availability
- Process returns and damaged inventory

**Responsibilities:**
- Physical inventory movement and dispatch
- Manual record keeping on paper
- Customer coordination for walk-in orders
- Basic quality checks during dispatch

**Pain Points:**
- **Paper-based systems:** Manual dispatch sheets lead to errors and time loss
- **No instant stock lookup:** Cannot check availability when customers call
- **End-of-day reconciliation:** Time-consuming manual updates to main records
- **Limited technology skills:** Needs very simple interface requiring minimal training

**Technology Requirements:**
- Simple mobile interface for basic operations
- Minimal training required (staff has limited education)
- Budget-friendly solution (not ₹1 lakh enterprise systems)

**User Stories:**
1. "I want simple barcode scanning so I can update stock without paperwork"
2. "I want to check stock quickly when customers ask so I can help them immediately"
3. "I want easy return processing so damaged items are tracked properly"

### Core User Requirements

- **Inventory tracking:** Roll-based with weight/meter options
- **Barcode support:** Essential for accurate stock management
- **Quality management:** Damage, wastage, re-work tracking
- **Supplier coordination:** Multiple dyeing houses/embroiderers
- **Customer updates:** Order status and delivery tracking
- **Pricing flexibility:** Per kg/meter/roll options

## Role-Based Permissions Matrix

### Feature/Module Access Control Matrix

#### Company Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ❌ | ❌ |
| **Read** | ✅ | ❌ |
| **Update** | ✅ | ❌ |
| **Delete** | ✅ | ❌ |

#### Staff Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ | ❌ |
| **Read** | ✅ | ❌ |
| **Update** | ✅ | ❌ |
| **Delete** | ✅ | ❌ |

Sub-modules:
- Staff Accounts
- Warehouse Assignment

#### Warehouse Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ | ❌ |
| **Read** | ✅ | ❌ |
| **Update** | ✅ | ❌ |
| **Delete** | ✅ | ❌ |

#### Product Master

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ | ❌ |
| **Read** | ✅ | ✅ |
| **Update** | ✅ | ❌ |
| **Delete** | ✅ | ❌ |

#### Stock Units

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Read** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Update** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Delete** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |

#### Sales Order Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ (All Warehouses) | ❌ |
| **Read** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only & List view) |
| **Update** | ✅ (All Warehouses) | ❌ |
| **Delete** | ✅ (All Warehouses) | ❌ |

#### Partner Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ | ❌ |
| **Read** | ✅ | ✅ (Assigned Warehouse Only & List view) |
| **Update** | ✅ | ❌ |
| **Delete** | ✅ | ❌ |

#### Job Work Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Read** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Update** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Delete** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |

#### Goods Dispatch

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Read** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Update** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Delete** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |

Sub-modules:
- Barcode Scanning

#### Goods Receipt

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Read** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Update** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Delete** | ❌ | ❌ |

#### Barcode Management

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Read** | ✅ (All Warehouses) | ✅ (Assigned Warehouse Only) |
| **Update** | ✅ | ✅ |
| **Delete** | ❌ | ❌ |

Sub-modules:
- Barcode Generation (Create & Read & Update only)
- Barcode Field Selection (Full CRUD for both roles)
- Barcode Print/Export (Read-only for both roles)

#### Catalog Configuration

| Operation | Admin | Staff |
|-----------|-------|-------|
| **Create** | ❌ | ❌ |
| **Read** | ✅ | ❌ |
| **Update** | ✅ | ❌ |
| **Delete** | ❌ | ❌ |

Sub-modules:
- Branding
- Product Info Config
- Group product into variants

**Legend:**
- ✅ = Permitted
- ❌ = Not Permitted

---

## Feature Specifications

### 1. Company & User Management

#### 1.1 Company Setup

**Feature Description:** Multi-tenant company management with hierarchical access control

**Specifications:**

**Company Registration**
- **Company Details:**
  - Company Name (required, 100 chars)
  - Complete Address (structured fields)
  - Business type (optional)
  - Logo (optional) max 1 image, 2MB)
  - GST number (optional) - under more information
  - PAN number (optional) - under more information

**Audit information:**
- Unique ID (unique and auto-generated in backend)
- Created on (date, time and generated in backend)
- Updated on (date, time and generated in backend)
- Created by (id of user who created the record)
- Modified by (id of user who last modified the record)
- Deleted at (date, time and generated in backend)

**Business Rules**
- One company = One tenant with multi tenant strategy
- Company admin has full system access
- All other entities (staff, warehouse, partners) belong to company

#### 1.2 Staff Management

**Feature Description:** Role-based staff management with single warehouse assignment and company admin control

**Staff Creation (Company Admin Only)**
- **Personal Information:**
  - First & Last Name (required)
  - Phone Number (required, unique within company)
  - Profile image
  - Additional note
- **Access Control:**
  - Single Warehouse Assignment (selected by Company Admin)
  - Set of features will be pre-determined as per role
- **Audit information**
  - Unique ID (unique and auto-generated in backend)
  - Created on (date, time and generated in backend)
  - Updated on (date, time and generated in backend)
  - Created by (id of user who created the record)
  - Modified by (id of user who last modified the record)
  - Deleted at (date, time and generated in backend)

**Warehouse Assignment Rules**
- Staff is assigned to exactly one warehouse by Company Admin
- Staff cannot create or switch warehouses
- Staff can only access their assigned warehouse
- Warehouse reassignment requires Company Admin intervention
- All staff operations are limited to their assigned warehouse scope

**Role-Based Permissions**
- **Company Admin:** Full system access, warehouse creation, staff management
- **Staff:** Basic warehouse operations like goods dispatch, goods receipt and job work within assigned warehouse

### 2. Warehouse Management

#### 2.1 Warehouse Configuration

**Feature Description:** Single-location inventory management with basic location tracking

**Specifications:**

**Warehouse Setup (Company Admin Only)**
- **Basic Information:**
  - Warehouse Name (required)
  - Complete Address (structured fields)
  - Staff Assignment (from staff list - must be assigned to this warehouse)
- **Audit information**
  - Unique ID (unique and auto-generated in backend)
  - Created on (date, time and generated in backend)
  - Updated on (date, time and generated in backend)
  - Created by (id of user who created the record)
  - Modified by (id of user who last modified the record)
  - Deleted at (date, time and generated in backend)

**Business Rules**
- Only Company Admin can create/modify warehouses
- Staff operations automatically restricted to their assigned warehouse
- All stock movements auto-tagged with staff's assigned warehouse
- Inter-warehouse transfers require dispatch to yourself which you from the list of options in dispatch form (If self is selected, then an option to select warehouse appears)

### 3. Product Master & Inventory Hierarchy

#### 3.1 Product Master

**Feature Description:** Central product catalog with fabric-specific attributes (Company-wide, warehouse-neutral)

**Specifications:**

**Product Creation (Company Admin Only)**
- **Identity Fields:**
  - Product Name (required, design name)
  - Product Number (auto-generated: PROD-{SEQUENCE})
  - Show on Catalog (toggle, default: true)
- **Fabric Specifications:**
  - Material (optional, dropdown: Cotton, Polyester, Silk, Blend, Custom)
  - Color (optional, predefined colors + custom RGB picker)
  - GSM (optional, numeric 50-500)
  - Thread count (optional, in cms)
  - Tags (multi-select for categorization)
- **Stock Information:**
  - Measuring Unit (required: Meters, Yards, KG, Pieces)
  - Cost Price Per Unit (optional, for margin calculation)
  - Selling Price Per Unit (optional, for quotations)
  - Product Images (max 5 images, 2MB each)
  - Min Stock Alert (toggle + threshold value)
- **Additional Information:**
  - HSN Code (optional, GST compliance)
  - Notes
- **Audit information**
  - Unique ID (unique and auto-generated in backend)
  - Created on (date, time and generated in backend)
  - Updated on (date, time and generated in backend)
  - Created by (id of user who created the record)
  - Modified by (id of user who last modified the record)
  - Deleted at (date, time and generated in backend)

**Access Restrictions:**
- Staff: View-only access to product master
- Cannot create, edit, or delete products
- Can view product details for operational purposes only

**Business Rules**
- Product Number unique across company (all warehouses)
- Color validation: Standard names + hex codes for custom colors
- Cannot delete product if stock units exist in any warehouse
- Product modifications don't affect existing stock units

#### 3.2 Stock Units

**Feature Description:** Individual unit tracking with barcode management (Warehouse-specific)

**Specifications:**

**Inventory Control Business Rules**
- **Stock Entry**: Stock units can ONLY be added to inventory via Goods Receipt process
- **Stock Removal**: Stock units can ONLY be removed from inventory via Goods Dispatch process
- **Traceability**: Every stock unit must be linked to its originating goods receipt (created_from_receipt_id)
- **Special Case Receipts**: For opening stock, adjustments, and manual additions, use link_type = 'other' with descriptive other_reference (e.g., "Opening Stock - System Setup", "Stock Adjustment - Found Inventory")

**Unit Creation Methods**
- Automatic Creation: From goods receipt items (creates individual stock units equal to quantity_received)
- System-assigned to receiving warehouse

**Unit Information**
- **Identity:**
  - Unit Number (auto: {PRODUCT_NUMBER}-SU{SEQUENCE})
  - QR Code (auto-generated by Unit number)
  - Date of Creation/Receipt
  - Assigned Warehouse (auto-filled from staff assignment)
  - Status (In inventory, dispatched, is auto filled based on goods receipt/dispatch created)
- **Physical Specifications:**
  - Size/Quantity (in product measuring unit)
  - Wastage (optional, same unit as size)
- **Location Tracking:**
  - Location Description (free-form text field, e.g., "Section A Rack 5", "Left Corner")
- **Additional Information:**
  - Barcode generated (boolean, default false, auto updates when barcode is generated for this stock unit)
  - Barcode generated at (time, auto updates when barcode is generated for this stock unit)
  - Quality Grade (custom text field with auto-suggestions from previously used values)
  - Notes
- **Audit information**
  - Unique ID (unique and auto-generated in backend)
  - Created on (date, time and generated in backend)
  - Updated on (date, time and generated in backend)
  - Created by (id of user who created the record)
  - Modified by (id of user who last modified the record)
  - Deleted at (date, time and generated in backend)

**Business Rules**
- All units automatically tagged with creating staff's assigned warehouse
- **Inventory Control**: Stock units can only be added via Goods Receipt and removed via Goods Dispatch
- **Complete Traceability**: Every stock unit must reference its creating goods receipt for audit trail
- **No Direct Stock Manipulation**: Users cannot manually add/remove stock units outside of receipt/dispatch workflows

### 4. Sales Order Management with Real-time Linking

#### 4.1 Sales Order Creation & Management

**Feature Description:** Customer order management with real-time fulfillment tracking (Warehouse-specific operations)

**Specifications:**

**Sales Order Creation Access:**
- **Owner:** Can create sales orders via both Sales Catalog (public interface) and Inventory App (internal system)
- **Sales Staff/Customers:** Can create sales orders only via Sales Catalog (public interface)
- Both methods link to same underlying sales order system

**Order Header**
- **Order Information:**
  - Order Number (auto: SO-{SEQUENCE})
  - Customer (required, from Partners with type=Customer)
  - Agent (optional, from Partners with type=Agent)
  - Order Date (required, default: today)
  - Expected Delivery Date (optional, can be set during order processing)
  - Fulfillment Warehouse:
    - **Sales Catalog orders:** No warehouse assignment (owner can assign later if needed)
    - **Inventory App orders:** Auto-assigned from owner's warehouse

**Order Line Items**
- **Product Selection:**
  - Product (searchable dropdown from product master)
  - Required Quantity (in product measuring unit)
  - Unit Rate (optional, from product master)
  - Line Total (auto-calculated)
- **Additional Information:**
  - Advance amount
  - Discount (percentage value 0-100%)
  - Notes
  - Attachments
- **Fulfillment Tracking:**
  - **For Inventory App orders (with warehouse assignment):**
    - Order Request Quantity (from assigned warehouse stock only)
    - Dispatched Quantity (from this warehouse)
    - Pending Quantity (auto-calculated: Order Request Quantity - Dispatched Quantity)
    - Total Completion in % (auto-calculated: (Dispatched Quantity/ Order Request Quantity) *100)
  - **For Sales Catalog orders (no warehouse assignment):**
    - Shows aggregate stock across all warehouses
    - No automatic reservation until warehouse is assigned by owner
- **Audit information**
  - Unique ID (unique and auto-generated in backend)
  - Created on (date, time and generated in backend)
  - Updated on (date, time and generated in backend)
  - Created by (id of user who created the record)
  - Modified by (id of user who last modified the record)
  - Deleted at (date, time and generated in backend)

**Staff Access Controls:**
- **Sales Staff (Sales Catalog):** Can create orders without warehouse restrictions, no stock reservation capability
- **Owner (Inventory App):** Can create orders for their assigned warehouse with full stock management
- **Owner (Sales Catalog):** Can create orders without warehouse restrictions (same as sales staff)

**Business Rules**
- Cannot confirm order without customer details
- Expected delivery date is optional during order creation, can be updated during processing
- **For Sales Catalog orders:** No automatic stock reservation until warehouse assigned
- Order completion requires 100% dispatch from assigned warehouse or manual override
- Cancellation releases all reservations within warehouse
- Owner can contact customer if fulfillment issues arise with Sales Catalog orders

#### 4.2 Sales Order Dashboard & Tracking

**Specifications:**

**Order Management Interface List View (Warehouse-Filtered):**
- Auto-filtered to show only orders for the warehouse admin is logged into and auto assigned for staff
- Filter by status (approval_pending, in_progress, completed, cancelled), customer, product, agent
- Sort by order date

**Order Status Workflow:**
- **approval_pending** - Initial status for all new orders, awaiting owner approval
- **in_progress** - Order approved and being fulfilled
- **completed** - Order fully dispatched and delivered (requires completion notes)
- **cancelled** - Order cancelled by customer or owner (requires cancellation reason)

**Status Change Tracking:**
- **status_changed_at** - Timestamp when status was changed to completed/cancelled
- **status_changed_by** - User who changed the status
- **status_notes** - Completion notes (for completed) or cancellation reason (for cancelled)
- Full audit trail of status changes with efficient single-field design

**Detail View:**
- Complete order information
- Real-time fulfillment status (warehouse-specific)
- Linked job works and dispatches (from assigned warehouse)

**Audit Information**
- Unique ID (auto-generated in backend)
- Created on (date, time, auto-generated)
- Updated on (date, time, auto-generated)
- Created by (user ID)
- Modified by (user ID)
- Deleted at (soft delete timestamp)

### 5. Partner Management

#### 5.1 Partner Master

**Feature Description**: Comprehensive partner management for customers, suppliers, vendors, and agents

**Specifications:**

**Primary Information**
- Partner ID (auto-generated unique identifier)
- First & Last Name (required)
- Company Name (optional)
- Phone Number (required, unique within company)
- Partner Type (required: Customer, Supplier, Vendor, Agent)
- GST Number (optional, tax identification)
- PAN Number (optional, tax identification)

**Address Information**
- Address Line 1 (optional, warehouse number, street)
- Address Line 2 (optional, locality, area)
- City (optional)
- State (optional)
- Country (optional)
- Pin Code (optional)

**Additional Information**
- Notes (additional information)

**Audit Information**
- Unique ID (auto-generated in backend)
- Created on (date, time, auto-generated)
- Updated on (date, time, auto-generated)
- Created by (user ID)
- Modified by (user ID)
- Deleted at (soft delete timestamp)

**Business Rules**
- Partner types can only have one selection
- Phone number must be unique within company
- GST and PAN basic validation for Indian businesses

### 6. Job Work Management

#### 6.1 Job Work Order Processing

**Feature Description**: Job work coordination with goods dispatch and receipt integration but without sales order integration

**Specifications:**

**Job Work Header**
- Job Work Number (auto-generated) (auto: JW-{SEQUENCE}))
- Job Type (required, custom text field with auto-suggestions from previously used values - e.g., "Dyeing", "Embroidery", "Printing", "Stitching", "Block Printing", "Digital Printing", etc.)
- Vendor (required, from Partners with type=Vendor as filter and free to choose other partners by changing filter)
- Agent (optional, from Partners with type=Agent)
- Start Date (required)
- Due Date (optional, can be set during job work processing)
- Sales Order (optional link, for reference only)
- Notes (additional information)
- Add files (attachments for job work documents)

**Raw Material Specification**
- Raw material is NOT reserved from inventory but highlighted in inventory
- Raw material Required Quantity (from assigned warehouse stock only)
- Raw material Dispatched Quantity (from this warehouse)
- Raw Pending Quantity (auto-calculated: Raw material Required Quantity - Dispatched Quantity)

**Finished Goods Specification**
- Finished Goods Request Quantity (from assigned warehouse stock only)
- Finished Goods Received Quantity (from this warehouse)
- Finished Goods Pending Quantity (updated via linked goods receipt)
- Finished Goods Pending Quantity (auto-calculated: Finished goods Request Quantity - Received Quantity)
- Total Completion in % (auto-calculated: (Finished Goods Received Quantity/ Finished Goods Request Quantity) *100)

**Linked Transactions**
- Goods Dispatch List (raw materials sent to vendor)
- Goods Receipt List (finished goods received from vendor)

**Job Work Status Workflow**
- **in_progress** - Default status, work is active with vendor
- **completed** - Job work finished, goods received back (requires completion notes)
- **cancelled** - Job work cancelled before completion (requires cancellation reason)

**Status Change Tracking:**
- **status_changed_at** - Timestamp when status was changed to completed/cancelled
- **status_changed_by** - User who changed the status
- **status_notes** - Completion notes (for completed) or cancellation reason (for cancelled)
- Full audit trail of status changes with efficient single-field design

**Communication Features**
- Option to call/message vendor directly from job work
- Share job work status with vendor/team
- Mark job work as complete
- Cancel job work if needed

**Audit Information**
- Unique ID (auto-generated in backend)
- Created on (date, time, auto-generated)
- Updated on (date, time, auto-generated)
- Created by (user ID)
- Modified by (user ID)
- Deleted at (soft delete timestamp)

**Staff Access Controls**
- Job works created within assigned warehouse scope
- Raw materials and finished goods linked to assigned warehouse
- Cannot access job works from other warehouses

**Business Rules**
- Raw material quantities are not allocated from inventory only highlighted
- Pending quantities update based on actual goods dispatch/receipt transactions
- Job work can exist independently without sales order linkage

### 7. Inventory Movement System

#### 7.1 Goods Dispatch

**Feature Description**: Comprehensive outward inventory management with flexible linking

**Specifications:**

**Dispatch Header**

**Dispatch Type Selection (required)**
- Dispatch Type (radio buttons: "Dispatch to Partner" or "Transfer to Warehouse")

**Recipient Configuration (based on dispatch type)**
- **For Partner Dispatch:**
  - Partner (required dropdown from partners list - customers, vendors, suppliers)
  - Agent (optional dropdown from partners with type=Agent)
- **For Warehouse Transfer:**
  - Destination Warehouse (required dropdown excluding current warehouse)
  - Agent field not applicable (hidden/disabled)

**Transaction Linking**
- Link to (radio options: sales order, job work, other)
- Sales Order (optional link to system sales order)
- Job Work (optional link to system job work)
- Other (custom reference with text field for description - e.g., "Sample dispatch", "Return goods", "Emergency stock")

**Dispatch Details**
- Date (required, date of dispatch)
- Due Date (expected delivery date)
- Invoice Number (optional, sales invoice reference)
- Amount (optional, total invoice amount)
- Transport (transport method details like LR number, vehicle details)
- Notes (additional information)
- Add files (attachments for invoices and documents)

**Items List**
- Stock Units (either barcode scanned or selected from list)
- Real-time stock validation (assigned warehouse only)
- Unit status updates upon dispatch

**PWA Barcode Scanning**
- Camera-based barcode scanning (PWA capability)
- Continuous scanning with running totals

**Staff Access Controls**
- Can only dispatch from assigned warehouse inventory
- Barcode scanning limited to assigned warehouse units
- All dispatch documentation auto-tagged with warehouse

**Audit Information**
- Unique ID (auto-generated in backend)
- Created on (date, time, auto-generated)
- Updated on (date, time, auto-generated)
- Created by (user ID)
- Modified by (user ID)
- Deleted at (soft delete timestamp)

**Business Rules**
- Stock units automatically marked as dispatched
- Inventory levels updated in real-time
- Linked job work raw material pending quantities updated
- Cannot dispatch units not in assigned warehouse
- **Dispatch Type Validation:**
  - Partner dispatch requires valid partner selection, warehouse field must be null
  - Warehouse transfer requires valid destination warehouse, partner field must be null
  - Agent can only be assigned for partner dispatch type
  - Cannot transfer to the same warehouse (system validation)
- **Database Integrity:**
  - Mutually exclusive recipient fields enforced by database constraints
  - All dispatch records must specify dispatch_type ('partner' or 'warehouse')
  - Real-time validation prevents invalid field combinations

**Dispatch Cancellation/Reversal Process:**
- Dispatch records remain as permanent historical records
- Cancellation marks dispatch as `is_cancelled = true` with timestamp and reason
- Automatic reversal of stock unit status (back to available)
- Real-time inventory level restoration
- Linked job work pending quantities adjustment
- Linked sales order pending quantities adjustment
- Audit trail: cancelled_by, cancelled_at, cancellation_reason
- Notification to relevant parties (owners/customer/vendor)

#### 7.2 Goods Receipt

**Feature Description**: Comprehensive inward inventory management with automatic unit creation

**Specifications:**

**Receipt Header**
- Issued By (required, sender of goods)
- Agent (optional, broker for this deal)
- Link to (radio options: sales order, job work, other)
- Sales Order (optional link to system sales order)
- Job Work (optional link to system job work)
- Other (custom reference with text field for description - e.g., "Inter-warehouse transfer", "Purchase return", "Damaged goods replacement")
- Date (required, date of arrival)
- Amount (optional, total invoice amount)
- Invoice Number (optional, purchase bill reference)
- Transport (transport method details)
- Notes (additional information)
- Add files (attachments for invoices and documents)

**Received product list**
- Received products and their stock unit quantity
- Individual stock units created with sequential numbering and added to inventory automatically
- Stock unit created with status as Received
- Auto update product quantity in the inventory of assigned warehouse

**Staff Access Controls**
- All receipts automatically assigned to staff's warehouse
- Cannot create receipts for other warehouses
- Unit creation limited to assigned warehouse scope

**Update stock units in case of discrepancy**
- Add stock units. Creates new units with unique number and status 'Received'
- Remove stock units. The removed unit status will be updated to 'Removed'

**Audit Information**
- Unique ID (auto-generated in backend)
- Created on (date, time, auto-generated)
- Updated on (date, time, auto-generated)
- Created by (user ID)
- Modified by (user ID)
- Deleted at (soft delete timestamp)

**Business Rules**
- All received units auto-assigned to staff's warehouse
- Linked job work finished goods pending quantities updated
- Real-time inventory updates within warehouse scope
- Stock units created ONLY for physically received items
- Barcode generation limited to actual received units
- Real-time inventory updates reflect only actual received stock

### 8. Barcode Generation System

#### 8.1 Barcode Generation Workflow

**Feature Description**: Comprehensive barcode generation with customization and batch printing

**Specifications:**

**Unit Selection Interface** 

**Selection Criteria:**
- Bulk select all units without barcodes generated
- Search for product by name or number
- Filter by material, color, tags
- Select product to see stock units grouped by goods receipt
- Individual/bulk unit selection from list

**Selection Methods:**
- Units grouped by Goods receipt and sorted by latest to earliest
- Select All Units Without Barcodes (warehouse-filtered)
- Goods receipt wise bulk selection
- Manual individual selection

**Fields Selection and Preview** 

**Field Selection Options:**
- Select which fields to display on barcode (product name, unit number, size, etc.)
- Preview barcode with selected fields for single item

**Print Format** 

**Print Layout:**
- Fixed format with 10-20 barcodes per A4 sheet
- Dashed reference lines for cutting guidance
- Optimized for sticky paper printing
- Professional formatting for easy application

**Output Options:**
- Save as PDF for printing
- Email PDF directly to specified address
- WhatsApp sharing capability

**Post-Generation Workflow** 

**Physical Application:**
- Print barcodes on sticky paper
- Cut along dashed reference lines
- Attach to individual fabric rolls/units

**Digital Updates:**
- Scan barcode to open stock unit information
- Edit unit details (size, wastage, manufacturing date, notes)
- Real-time updates to inventory system
- Mobile-optimized scanning interface

**Staff Access Controls**
- Warehouse filter automatically applied to assigned warehouse
- Cannot generate barcodes for other warehouse units
- All generation activities logged per warehouse

**Audit Information**
- Unique ID (auto-generated in backend)
- Created on (date, time, auto-generated)
- Updated on (date, time, auto-generated)
- Created by (user ID)
- Modified by (user ID)
- Deleted at (soft delete timestamp)

**Business Rules**
- Barcode generation limited to assigned warehouse units
- Generated barcodes immediately marked in system
- Templates can be saved for consistent formatting
- Batch tracking for generation history

### 9. Public Sales Catalog

Based on the specifications provided, here's how I would divide this into 2 distinct features:

#### 9.1 Catalog Management System

**Feature Description**: Admin-controlled catalog creation and content management system

**Admin Functions:**
- **Catalog Setup & Configuration**
  - Branding setup- font, logo & color & fav icon
  - Product information configuration- which fields to show
- **Product Selection & Organization**
  - Users can group related products into a set (e.g., by variant type such as color, material, custom property) and assign a specific value to each product within that group
- **Search & Filter**
  - Filter options (material, color, price range)
  - Search (name & product number)
  - Sort (alphabetical, price)

#### 9.2 Public Sales Catalog Interface

**Feature Description**: Customer-facing product catalog with complete ordering capabilities

**Customer Functions:**
- **Product Browsing & Discovery**
  - Browse products without login requirement
  - Search functionality for product names/codes
  - Filter by material, color
  - View real-time stock availability across warehouses
  - Product comparison capabilities
- **Shopping Experience**
  - Add products to cart with quantity selection
  - Cart management (modify quantities, remove items)
- **Order Creation & Checkout**
  - Customer information capture (name, phone, address)
  - Required legal agreements (terms, return policy, privacy policy)
- **Order Processing & Communication**
  - Automatic Sales Order creation in backend system with approval_pending status
  - Order Number generation (SO-{SEQUENCE})
  - Notification to owner

**Integration Features:**
- Automatic sales order generation in backend
- Public domain accessibility with shareable links
