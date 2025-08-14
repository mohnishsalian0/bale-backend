-- Sukh Fabric Inventory Management System - Database Schema (Fixed Version)
-- Multi-tenant architecture with Row Level Security (RLS)

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- CORE ENTITIES - MULTI-TENANT FOUNDATION
-- =====================================================

-- Companies table (tenant isolation)
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'India',
    pin_code VARCHAR(10),
    business_type VARCHAR(50),
    gst_number VARCHAR(15),
    pan_number VARCHAR(10),
    logo_url TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    modified_by UUID,
    deleted_at TIMESTAMPTZ
);

-- Users/Staff table with role-based access
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Personal information
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    profile_image_url TEXT,
    additional_notes TEXT,
    
    -- Role and access
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'staff')),
    warehouse_id UUID, -- Single warehouse assignment for staff
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Authentication (handled by Supabase Auth)
    auth_user_id UUID UNIQUE,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    modified_by UUID,
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, phone_number)
);

-- Warehouses table
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    name VARCHAR(100) NOT NULL,
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'India',
    pin_code VARCHAR(10),
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, name)
);

-- Add foreign key constraint for warehouse assignment
ALTER TABLE users ADD CONSTRAINT fk_user_warehouse 
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id);


-- =====================================================
-- PRODUCT CATALOG & INVENTORY
-- =====================================================

-- Products master table (company-wide catalog)
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Identity
    product_number VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    show_on_catalog BOOLEAN DEFAULT TRUE,
    
    -- Fabric specifications
    material VARCHAR(50) CHECK (material IN (
        -- Natural Fibers
        'Cotton', 'Silk', 'Wool', 'Linen', 'Jute', 'Hemp', 'Cashmere', 'Mohair', 'Alpaca',
        -- Synthetic Fibers  
        'Polyester', 'Nylon', 'Acrylic', 'Spandex', 'Lycra', 'Rayon', 'Viscose', 'Modal',
        -- Semi-Synthetic
        'Bamboo', 'Tencel', 'Cupro',
        -- Specialty/Technical
        'Microfiber', 'Fleece', 'Denim', 'Canvas', 'Twill', 'Satin', 'Chiffon', 'Georgette', 
        'Organza', 'Taffeta', 'Velvet', 'Corduroy', 'Jacquard', 'Brocade',
        -- Blends & Custom
        'Cotton-Polyester', 'Cotton-Spandex', 'Cotton-Linen', 'Poly-Cotton', 'Wool-Silk', 
        'Silk-Cotton', 'Blend', 'Custom'
    )),
    color VARCHAR(50),
    color_hex VARCHAR(7), -- RGB hex code
    gsm INTEGER CHECK (gsm BETWEEN 50 AND 500),
    thread_count_cm INTEGER,
    tags TEXT[], -- Array for categorization
    
    -- Stock information
    measuring_unit VARCHAR(20) NOT NULL CHECK (measuring_unit IN ('Meters', 'Yards', 'Kg', 'Pieces')),
    cost_price_per_unit DECIMAL(10,2),
    selling_price_per_unit DECIMAL(10,2),
    min_stock_alert BOOLEAN DEFAULT FALSE,
    min_stock_threshold INTEGER DEFAULT 0,
    
    -- Additional information
    hsn_code VARCHAR(20),
    notes TEXT,
    product_images TEXT[], -- Array of image URLs
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, product_number)
);

-- Stock Units table (individual fabric rolls/pieces)
CREATE TABLE stock_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    
    -- Identity
    unit_number VARCHAR(100) NOT NULL,
    qr_code TEXT, -- Generated from unit_number
    
    -- Physical specifications
    size_quantity DECIMAL(10,3) NOT NULL,
    wastage DECIMAL(10,3) DEFAULT 0,
    quality_grade TEXT, -- Custom quality grade with auto-suggestions from previously used values
    location_description TEXT,
    
    -- Status tracking
    status VARCHAR(20) NOT NULL DEFAULT 'pending_details' 
        CHECK (status IN ('pending_details', 'in_stock', 'dispatched', 'removed')),
    
    -- Dates
    manufacturing_date DATE,
    
    -- Receipt tracking (links back to goods receipt that created this unit)
    created_from_receipt_id UUID NOT NULL REFERENCES goods_receipts(id),
    
    notes TEXT,
    
    -- Barcode tracking
    barcode_generated BOOLEAN DEFAULT FALSE,
    barcode_generated_at TIMESTAMPTZ,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, unit_number)
);

-- =====================================================
-- PARTNER MANAGEMENT
-- =====================================================

-- Partners table (customers, suppliers, vendors, agents)
CREATE TABLE partners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Identity
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    company_name VARCHAR(200),
    phone_number VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    
    -- Partner type
    partner_type VARCHAR(20) NOT NULL 
        CHECK (partner_type IN ('Customer', 'Supplier', 'Vendor', 'Agent')),
    
    -- Tax information
    gst_number VARCHAR(15),
    pan_number VARCHAR(10),
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'India',
    pin_code VARCHAR(10),
    
    notes TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, phone_number)
);

-- =====================================================
-- SALES ORDER MANAGEMENT
-- =====================================================

-- Sales Orders table
CREATE TABLE sales_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Order identification
    order_number VARCHAR(50) NOT NULL,
    
    -- Customer information
    customer_id UUID NOT NULL REFERENCES partners(id),
    agent_id UUID REFERENCES partners(id),
    
    -- Order details
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE, -- Optional, can be set later during order processing
    fulfillment_warehouse_id UUID REFERENCES warehouses(id),
    
    -- Financial
    advance_amount DECIMAL(10,2) DEFAULT 0,
    discount_percentage DECIMAL(5,2) DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100), -- Percentage value (0-100)
    total_amount DECIMAL(10,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'approval_pending' 
        CHECK (status IN ('approval_pending', 'in_progress', 'completed', 'cancelled')),
    
    -- Status change tracking
    status_changed_at TIMESTAMPTZ,
    status_changed_by UUID REFERENCES users(id),
    status_notes TEXT, -- Completion notes or cancellation reason
    
    notes TEXT,
    attachments TEXT[], -- Array of file URLs
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, order_number)
);

-- Sales Order Line Items
CREATE TABLE sales_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    sales_order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    -- Quantities
    required_quantity DECIMAL(10,3) NOT NULL,
    dispatched_quantity DECIMAL(10,3) DEFAULT 0,
    pending_quantity DECIMAL(10,3) GENERATED ALWAYS AS (required_quantity - dispatched_quantity) STORED,
    
    -- Pricing
    unit_rate DECIMAL(10,2),
    line_total DECIMAL(10,2) GENERATED ALWAYS AS (required_quantity * COALESCE(unit_rate, 0)) STORED,
    
    notes TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- JOB WORK MANAGEMENT
-- =====================================================

-- Job Works table
CREATE TABLE job_works (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    
    -- Job identification
    job_number VARCHAR(50) NOT NULL,
    job_type TEXT NOT NULL, -- Custom job type with auto-suggestions from previously used values
    
    -- Partners
    vendor_id UUID NOT NULL REFERENCES partners(id),
    agent_id UUID REFERENCES partners(id),
    
    -- Dates
    start_date DATE NOT NULL,
    due_date DATE, -- Optional, can be set during job work processing
    
    -- Optional sales order reference
    sales_order_id UUID REFERENCES sales_orders(id),
    
    -- Status tracking
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress' 
        CHECK (status IN ('in_progress', 'completed', 'cancelled')),
    
    -- Status change tracking
    status_changed_at TIMESTAMPTZ,
    status_changed_by UUID REFERENCES users(id),
    status_notes TEXT, -- Completion notes or cancellation reason
    
    notes TEXT,
    attachments TEXT[], -- Array of file URLs
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, job_number)
);

-- Job Work Raw Materials (what we send to vendor)
CREATE TABLE job_work_raw_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    job_work_id UUID NOT NULL REFERENCES job_works(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    required_quantity DECIMAL(10,3) NOT NULL,
    dispatched_quantity DECIMAL(10,3) DEFAULT 0,
    pending_quantity DECIMAL(10,3) GENERATED ALWAYS AS (required_quantity - dispatched_quantity) STORED,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Job Work Finished Goods (what we receive from vendor)
CREATE TABLE job_work_finished_goods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    job_work_id UUID NOT NULL REFERENCES job_works(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    expected_quantity DECIMAL(10,3) NOT NULL,
    received_quantity DECIMAL(10,3) DEFAULT 0,
    pending_quantity DECIMAL(10,3) GENERATED ALWAYS AS (expected_quantity - received_quantity) STORED,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- INVENTORY MOVEMENT (DISPATCH & RECEIPT)
-- =====================================================

-- Goods Dispatch table
CREATE TABLE goods_dispatches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    
    -- Dispatch identification
    dispatch_number VARCHAR(50) NOT NULL,
    
    -- Dispatch type (mutually exclusive)
    dispatch_type VARCHAR(20) NOT NULL CHECK (dispatch_type IN ('partner', 'warehouse')),
    
    -- Recipients (mutually exclusive based on dispatch_type)
    dispatch_to_partner_id UUID REFERENCES partners(id),
    dispatch_to_warehouse_id UUID REFERENCES warehouses(id), -- For inter-warehouse transfer
    agent_id UUID REFERENCES partners(id), -- Only valid when dispatch_type = 'partner'
    
    -- Linking
    link_type VARCHAR(20) CHECK (link_type IN ('sales_order', 'job_work', 'other')),
    sales_order_id UUID REFERENCES sales_orders(id),
    job_work_id UUID REFERENCES job_works(id),
    other_reference TEXT, -- Custom reference when link_type = 'other'
    
    -- Details
    dispatch_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    invoice_number VARCHAR(50),
    invoice_amount DECIMAL(10,2),
    transport_details TEXT,
    
    -- Cancellation/Reversal tracking
    is_cancelled BOOLEAN DEFAULT FALSE,
    cancelled_at TIMESTAMPTZ,
    cancelled_by UUID REFERENCES users(id),
    cancellation_reason TEXT,
    
    notes TEXT,
    attachments TEXT[], -- Array of file URLs
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    -- Business logic constraints
    CONSTRAINT check_dispatch_type_consistency 
        CHECK (
            (dispatch_type = 'partner' AND dispatch_to_partner_id IS NOT NULL AND dispatch_to_warehouse_id IS NULL) OR
            (dispatch_type = 'warehouse' AND dispatch_to_warehouse_id IS NOT NULL AND dispatch_to_partner_id IS NULL)
        ),
    
    -- Agent only valid for partner dispatch
    CONSTRAINT check_agent_for_partner_only 
        CHECK (
            (agent_id IS NULL) OR 
            (agent_id IS NOT NULL AND dispatch_type = 'partner')
        ),
    
    -- Cannot dispatch to same warehouse
    CONSTRAINT check_different_warehouse
        CHECK (
            dispatch_type != 'warehouse' OR 
            dispatch_to_warehouse_id != warehouse_id
        ),
    
    UNIQUE(company_id, dispatch_number)
);

-- Goods Dispatch Items (linking to specific stock units)
CREATE TABLE goods_dispatch_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    dispatch_id UUID NOT NULL REFERENCES goods_dispatches(id) ON DELETE CASCADE,
    stock_unit_id UUID NOT NULL REFERENCES stock_units(id),
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Goods Receipt table
CREATE TABLE goods_receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    
    -- Receipt identification
    receipt_number VARCHAR(50) NOT NULL,
    
    -- Senders
    issued_by_partner_id UUID REFERENCES partners(id),
    issued_by_warehouse_id UUID REFERENCES warehouses(id), -- For inter-warehouse transfer
    agent_id UUID REFERENCES partners(id),
    
    -- Linking
    link_type VARCHAR(20) CHECK (link_type IN ('sales_order', 'job_work', 'other')),
    sales_order_id UUID REFERENCES sales_orders(id),
    job_work_id UUID REFERENCES job_works(id),
    other_reference TEXT, -- Custom reference when link_type = 'other'
    
    -- Details
    receipt_date DATE NOT NULL DEFAULT CURRENT_DATE,
    invoice_number VARCHAR(50),
    invoice_amount DECIMAL(10,2),
    transport_details TEXT,
    
    notes TEXT,
    attachments TEXT[], -- Array of file URLs
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, receipt_number)
);

-- Goods Receipt Items (creates new stock units)
CREATE TABLE goods_receipt_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    receipt_id UUID NOT NULL REFERENCES goods_receipts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    quantity_received INTEGER NOT NULL,
    notes TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- BARCODE MANAGEMENT
-- =====================================================

-- Barcode Generation Batches
CREATE TABLE barcode_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    
    batch_name VARCHAR(100) NOT NULL,
    fields_selected TEXT[], -- Fields to display on barcode
    pdf_url TEXT, -- Generated PDF location
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id)
);

-- Barcode Batch Items (which units were included)
CREATE TABLE barcode_batch_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id UUID NOT NULL REFERENCES barcode_batches(id) ON DELETE CASCADE,
    stock_unit_id UUID NOT NULL REFERENCES stock_units(id)
);

-- =====================================================
-- CATALOG CONFIGURATION
-- =====================================================

-- Catalog Configuration table
CREATE TABLE catalog_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Branding
    catalog_name VARCHAR(100),
    logo_url TEXT,
    primary_color VARCHAR(7), -- Hex color
    secondary_color VARCHAR(7),
    font_family VARCHAR(50),
    favicon_url TEXT,
    
    -- Product display configuration
    show_fields JSONB, -- Which product fields to show
    filter_options JSONB, -- Available filter options
    sort_options JSONB, -- Available sort options
    
    -- Legal pages
    terms_conditions TEXT,
    return_policy TEXT,
    privacy_policy TEXT,
    
    -- Contact information
    contact_phone VARCHAR(15),
    contact_email VARCHAR(100),
    contact_address TEXT,
    
    -- Public settings
    accepting_orders BOOLEAN DEFAULT FALSE,
    domain_slug VARCHAR(50) UNIQUE,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    
    UNIQUE(company_id)
);

-- Product Variants/Groups for catalog
CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    variant_name VARCHAR(100) NOT NULL, -- e.g., "Cotton Solids", "Embroidered Collection"
    variant_type VARCHAR(50), -- e.g., "Color", "Material", "Custom"
    display_order INTEGER DEFAULT 0,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Product Variant Items (products grouped into variants)
CREATE TABLE product_variant_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    variant_value VARCHAR(100) NOT NULL, -- e.g., "Red", "Blue", "Cotton"
    display_order INTEGER DEFAULT 0,
    
    UNIQUE(variant_id, product_id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Multi-tenant indexes (company_id is always in WHERE clause)
CREATE INDEX idx_users_company_id ON users(company_id);
CREATE INDEX idx_warehouses_company_id ON warehouses(company_id);
CREATE INDEX idx_products_company_id ON products(company_id);
CREATE INDEX idx_stock_units_company_id ON stock_units(company_id);
CREATE INDEX idx_partners_company_id ON partners(company_id);
CREATE INDEX idx_sales_orders_company_id ON sales_orders(company_id);
CREATE INDEX idx_job_works_company_id ON job_works(company_id);
CREATE INDEX idx_job_work_raw_materials_job_work_id ON job_work_raw_materials(job_work_id);
CREATE INDEX idx_job_work_finished_goods_job_work_id ON job_work_finished_goods(job_work_id);
CREATE INDEX idx_stock_units_receipt_id ON stock_units(created_from_receipt_id);

-- Warehouse-specific indexes
CREATE INDEX idx_stock_units_warehouse_id ON stock_units(warehouse_id);
CREATE INDEX idx_stock_units_status ON stock_units(warehouse_id, status);
CREATE INDEX idx_users_warehouse_id ON users(warehouse_id);

-- Product and inventory indexes
CREATE INDEX idx_stock_units_product_id ON stock_units(product_id);
CREATE INDEX idx_products_product_number ON products(company_id, product_number);
CREATE INDEX idx_stock_units_unit_number ON stock_units(company_id, unit_number);

-- Partner and order indexes
CREATE INDEX idx_partners_type ON partners(company_id, partner_type);
CREATE INDEX idx_partners_phone ON partners(company_id, phone_number);
CREATE INDEX idx_sales_orders_customer ON sales_orders(company_id, customer_id);
CREATE INDEX idx_sales_orders_status ON sales_orders(company_id, status);

-- Date-based indexes for reporting
CREATE INDEX idx_goods_dispatches_date ON goods_dispatches(company_id, dispatch_date);
CREATE INDEX idx_goods_receipts_date ON goods_receipts(company_id, receipt_date);
CREATE INDEX idx_sales_orders_date ON sales_orders(company_id, order_date);

-- Simple indexes for basic text search
CREATE INDEX idx_products_name ON products(company_id, name);
CREATE INDEX idx_partners_name ON partners(company_id, first_name, last_name);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Function to update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to all tables with updated_at column
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename NOT IN ('spatial_ref_sys')
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = t AND column_name = 'updated_at'
        ) THEN
            EXECUTE format('CREATE TRIGGER update_%I_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()', t, t);
        END IF;
    END LOOP;
END;
$$;

-- Function to auto-generate sequence numbers  
CREATE OR REPLACE FUNCTION generate_sequence_number(prefix TEXT, table_name TEXT, company_uuid UUID)
RETURNS TEXT AS $$
DECLARE
    next_seq INTEGER;
    result TEXT;
    column_name TEXT;
BEGIN
    -- Get the appropriate column name based on table
    column_name := CASE 
        WHEN table_name = 'products' THEN 'product_number'
        WHEN table_name = 'sales_orders' THEN 'order_number'
        WHEN table_name = 'job_works' THEN 'job_number'
        WHEN table_name = 'goods_dispatches' THEN 'dispatch_number'
        WHEN table_name = 'goods_receipts' THEN 'receipt_number'
        WHEN table_name = 'stock_units' THEN 'unit_number'
        ELSE 'number'
    END;
    
    -- Get next sequence number for this company and table
    EXECUTE format('SELECT COALESCE(MAX(CAST(SUBSTRING(%I FROM ''^%s-(\d+)$'') AS INTEGER)), 0) + 1 FROM %I WHERE company_id = $1', 
                   column_name, prefix, table_name)
    INTO next_seq
    USING company_uuid;
    
    result := prefix || '-' || LPAD(next_seq::TEXT, 6, '0');
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Auto-generate product numbers
CREATE OR REPLACE FUNCTION auto_generate_product_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.product_number IS NULL OR NEW.product_number = '' THEN
        NEW.product_number := generate_sequence_number('PROD', 'products', NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_product_number
    BEFORE INSERT ON products
    FOR EACH ROW EXECUTE FUNCTION auto_generate_product_number();

-- Auto-generate stock unit numbers
CREATE OR REPLACE FUNCTION auto_generate_unit_number()
RETURNS TRIGGER AS $$
DECLARE
    product_num TEXT;
    next_seq INTEGER;
BEGIN
    IF NEW.unit_number IS NULL OR NEW.unit_number = '' THEN
        SELECT product_number INTO product_num FROM products WHERE id = NEW.product_id;
        
        -- Get next sequence for this product
        SELECT COALESCE(MAX(CAST(SUBSTRING(unit_number FROM product_num || '-SU(\d+)$') AS INTEGER)), 0) + 1
        INTO next_seq
        FROM stock_units 
        WHERE product_id = NEW.product_id;
        
        NEW.unit_number := product_num || '-SU' || LPAD(next_seq::TEXT, 6, '0');
    END IF;
    
    -- Generate QR code from unit number
    IF NEW.qr_code IS NULL OR NEW.qr_code = '' THEN
        NEW.qr_code := NEW.unit_number;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_unit_number
    BEFORE INSERT ON stock_units
    FOR EACH ROW EXECUTE FUNCTION auto_generate_unit_number();

-- Update barcode tracking when stock units are added to barcode batch
CREATE OR REPLACE FUNCTION update_barcode_tracking()
RETURNS TRIGGER AS $$
DECLARE
    batch_created_at TIMESTAMPTZ;
BEGIN
    -- Get the batch creation timestamp
    SELECT created_at INTO batch_created_at
    FROM barcode_batches
    WHERE id = NEW.batch_id;
    
    -- Update stock unit with barcode tracking info
    UPDATE stock_units 
    SET barcode_generated = TRUE,
        barcode_generated_at = batch_created_at
    WHERE id = NEW.stock_unit_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_barcode_tracking
    AFTER INSERT ON barcode_batch_items
    FOR EACH ROW EXECUTE FUNCTION update_barcode_tracking();

-- Auto-generate domain slug from company name with random number
CREATE OR REPLACE FUNCTION generate_domain_slug()
RETURNS TRIGGER AS $$
DECLARE
    base_slug TEXT;
    random_num INTEGER;
    final_slug TEXT;
BEGIN
    -- Generate base slug from company name
    base_slug := LOWER(TRIM(NEW.name));
    base_slug := REGEXP_REPLACE(base_slug, '[^a-z0-9\s-]', '', 'g'); -- Remove special chars
    base_slug := REGEXP_REPLACE(base_slug, '\s+', '-', 'g'); -- Replace spaces with hyphens
    base_slug := REGEXP_REPLACE(base_slug, '-+', '-', 'g'); -- Remove multiple hyphens
    base_slug := TRIM(base_slug, '-'); -- Remove leading/trailing hyphens
    
    -- Generate random 4-digit number (1000-9999)
    random_num := 1000 + (RANDOM() * 9000)::INTEGER;
    
    -- Combine base slug with random number
    final_slug := base_slug || '-' || random_num;
    
    -- Update catalog configuration with generated slug
    UPDATE catalog_configurations 
    SET domain_slug = final_slug 
    WHERE company_id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_domain_slug
    AFTER INSERT OR UPDATE OF name ON companies
    FOR EACH ROW EXECUTE FUNCTION generate_domain_slug();

-- Update sales order total when line items change
CREATE OR REPLACE FUNCTION update_sales_order_total()
RETURNS TRIGGER AS $$
DECLARE
    order_id UUID;
    subtotal DECIMAL(10,2);
    discount_pct DECIMAL(5,2);
    final_total DECIMAL(10,2);
BEGIN
    -- Get the sales order ID from the affected row
    order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);
    
    -- Calculate subtotal from all line items
    SELECT COALESCE(SUM(line_total), 0) 
    INTO subtotal
    FROM sales_order_items 
    WHERE sales_order_id = order_id;
    
    -- Get discount percentage from sales order
    SELECT discount_percentage 
    INTO discount_pct
    FROM sales_orders 
    WHERE id = order_id;
    
    -- Calculate final total with discount applied
    final_total := subtotal * (1 - (COALESCE(discount_pct, 0) / 100));
    
    -- Update the sales order total
    UPDATE sales_orders 
    SET total_amount = final_total
    WHERE id = order_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_sales_order_total
    AFTER INSERT OR UPDATE OR DELETE ON sales_order_items
    FOR EACH ROW EXECUTE FUNCTION update_sales_order_total();

-- Update sales order total when discount percentage changes
CREATE OR REPLACE FUNCTION update_sales_order_total_on_discount()
RETURNS TRIGGER AS $$
DECLARE
    subtotal DECIMAL(10,2);
    final_total DECIMAL(10,2);
BEGIN
    -- Only recalculate if discount_percentage changed
    IF OLD.discount_percentage IS DISTINCT FROM NEW.discount_percentage THEN
        -- Calculate subtotal from all line items
        SELECT COALESCE(SUM(line_total), 0) 
        INTO subtotal
        FROM sales_order_items 
        WHERE sales_order_id = NEW.id;
        
        -- Calculate final total with new discount applied
        final_total := subtotal * (1 - (COALESCE(NEW.discount_percentage, 0) / 100));
        
        -- Update the total amount
        NEW.total_amount := final_total;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_sales_order_total_on_discount
    BEFORE UPDATE ON sales_orders
    FOR EACH ROW EXECUTE FUNCTION update_sales_order_total_on_discount();

-- Auto-populate unit rate from product master
CREATE OR REPLACE FUNCTION auto_populate_unit_rate()
RETURNS TRIGGER AS $$
BEGIN
    -- Only auto-populate unit_rate if not provided or is zero
    -- This allows users to override with custom rates
    IF NEW.unit_rate IS NULL OR NEW.unit_rate = 0 THEN
        -- Fetch selling price from product master
        SELECT selling_price_per_unit 
        INTO NEW.unit_rate
        FROM products 
        WHERE id = NEW.product_id;
        
        -- If product has no selling price, leave unit_rate as provided
        NEW.unit_rate := COALESCE(NEW.unit_rate, 0);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_populate_unit_rate
    BEFORE INSERT OR UPDATE ON sales_order_items
    FOR EACH ROW EXECUTE FUNCTION auto_populate_unit_rate();

-- Prevent reducing required quantity below dispatched quantity
CREATE OR REPLACE FUNCTION validate_required_quantity()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if required_quantity is being reduced below dispatched_quantity
    IF NEW.required_quantity < NEW.dispatched_quantity THEN
        RAISE EXCEPTION 'Cannot reduce required quantity (%) below dispatched quantity (%). Please cancel existing dispatches first.',
            NEW.required_quantity, NEW.dispatched_quantity
            USING HINT = 'To reduce quantity: 1) Cancel existing dispatches, 2) Update required quantity, 3) Create new dispatches if needed',
                  ERRCODE = 'check_violation';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_required_quantity
    BEFORE UPDATE ON sales_order_items
    FOR EACH ROW EXECUTE FUNCTION validate_required_quantity();

-- Auto-create stock units when goods receipt items are added
CREATE OR REPLACE FUNCTION auto_create_stock_units_from_receipt()
RETURNS TRIGGER AS $$
DECLARE
    i INTEGER;
    receipt_warehouse_id UUID;
    product_measuring_unit VARCHAR(20);
BEGIN
    -- Get warehouse from the goods receipt
    SELECT warehouse_id INTO receipt_warehouse_id
    FROM goods_receipts 
    WHERE id = NEW.receipt_id;
    
    -- Get product measuring unit for default size
    SELECT measuring_unit INTO product_measuring_unit
    FROM products 
    WHERE id = NEW.product_id;
    
    -- Create individual stock units for each quantity received
    FOR i IN 1..NEW.quantity_received LOOP
        INSERT INTO stock_units (
            company_id,
            product_id,
            warehouse_id,
            unit_number, -- Will be auto-generated by existing trigger
            size_quantity, -- Default to 1 unit, can be updated later
            status, -- Will default to 'pending_details'
            created_from_receipt_id -- Link back to the goods receipt
        ) VALUES (
            NEW.company_id,
            NEW.product_id,
            receipt_warehouse_id,
            NULL, -- Let auto_generate_unit_number trigger handle this
            1.000, -- Default unit size, admin can update during stock verification
            NEW.receipt_id -- Link to the goods receipt that created this unit
        );
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_create_stock_units_from_receipt
    AFTER INSERT ON goods_receipt_items
    FOR EACH ROW EXECUTE FUNCTION auto_create_stock_units_from_receipt();

-- =====================================================
-- HELPER FUNCTIONS FOR AUTO-SUGGESTIONS
-- =====================================================

-- Function to get tag suggestions for products
CREATE OR REPLACE FUNCTION get_tag_suggestions(
    search_term TEXT DEFAULT '',
    company_id_param UUID DEFAULT NULL
)
RETURNS TABLE(tag TEXT, usage_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        unnest(tags) as tag,
        COUNT(*) as usage_count
    FROM products 
    WHERE company_id = COALESCE(company_id_param, (SELECT company_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
        AND tags IS NOT NULL 
        AND array_length(tags, 1) > 0
        AND (search_term = '' OR unnest(tags) ILIKE search_term || '%')
    GROUP BY unnest(tags)
    ORDER BY usage_count DESC, tag ASC
    LIMIT 10;
$$;

-- Function to get quality grade suggestions from stock units
CREATE OR REPLACE FUNCTION get_quality_grade_suggestions(
    search_term TEXT DEFAULT '',
    company_id_param UUID DEFAULT NULL
)
RETURNS TABLE(quality_grade TEXT, usage_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        su.quality_grade,
        COUNT(*) as usage_count
    FROM stock_units su
    JOIN products p ON su.product_id = p.id
    WHERE p.company_id = COALESCE(company_id_param, (SELECT company_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
        AND su.quality_grade IS NOT NULL 
        AND su.quality_grade != ''
        AND (search_term = '' OR su.quality_grade ILIKE search_term || '%')
    GROUP BY su.quality_grade
    ORDER BY usage_count DESC, su.quality_grade ASC
    LIMIT 10;
$$;

-- Function to get job type suggestions from job works
CREATE OR REPLACE FUNCTION get_job_type_suggestions(
    search_term TEXT DEFAULT '',
    company_id_param UUID DEFAULT NULL
)
RETURNS TABLE(job_type TEXT, usage_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        jw.job_type,
        COUNT(*) as usage_count
    FROM job_works jw
    WHERE jw.company_id = COALESCE(company_id_param, (SELECT company_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
        AND jw.job_type IS NOT NULL 
        AND jw.job_type != ''
        AND (search_term = '' OR jw.job_type ILIKE search_term || '%')
        AND jw.deleted_at IS NULL
    GROUP BY jw.job_type
    ORDER BY usage_count DESC, jw.job_type ASC
    LIMIT 10;
$$;

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- Inventory Summary View
CREATE VIEW inventory_summary AS
SELECT 
    p.company_id,
    p.id as product_id,
    p.name as product_name,
    p.product_number,
    p.material,
    p.color,
    w.id as warehouse_id,
    w.name as warehouse_name,
    COUNT(su.id) as total_units,
    SUM(CASE WHEN su.status = 'in_stock' THEN 1 ELSE 0 END) as in_stock_units,
    SUM(CASE WHEN su.status = 'dispatched' THEN 1 ELSE 0 END) as dispatched_units,
    SUM(CASE WHEN su.status = 'removed' THEN 1 ELSE 0 END) as removed_units,
    SUM(su.size_quantity) as total_quantity,
    SUM(CASE WHEN su.status = 'in_stock' THEN su.size_quantity ELSE 0 END) as in_stock_quantity,
    p.measuring_unit
FROM products p
JOIN stock_units su ON p.id = su.product_id
JOIN warehouses w ON su.warehouse_id = w.id
WHERE su.deleted_at IS NULL
GROUP BY p.company_id, p.id, p.name, p.product_number, p.material, p.color, w.id, w.name, p.measuring_unit;

-- Sales Order Status View
CREATE VIEW sales_order_status AS
SELECT 
    so.company_id,
    so.id as sales_order_id,
    so.order_number,
    so.status,
    so.order_date,
    so.expected_delivery_date,
    p.first_name || ' ' || p.last_name as customer_name,
    p.company_name as customer_company,
    so.total_amount,
    COUNT(soi.id) as total_items,
    COALESCE(SUM(soi.required_quantity), 0) as total_required_qty,
    COALESCE(SUM(soi.dispatched_quantity), 0) as total_dispatched_qty,
    COALESCE(SUM(soi.pending_quantity), 0) as total_pending_qty,
    CASE 
        WHEN COALESCE(SUM(soi.required_quantity), 0) = 0 THEN 0
        ELSE ROUND((COALESCE(SUM(soi.dispatched_quantity), 0) / COALESCE(SUM(soi.required_quantity), 1)) * 100, 2)
    END as completion_percentage
FROM sales_orders so
JOIN partners p ON so.customer_id = p.id
LEFT JOIN sales_order_items soi ON so.id = soi.sales_order_id
WHERE so.deleted_at IS NULL
GROUP BY so.company_id, so.id, so.order_number, so.status, so.order_date, so.expected_delivery_date, 
         p.first_name, p.last_name, p.company_name, so.total_amount;

-- Job Work Progress View  
CREATE VIEW job_work_progress AS
SELECT 
    jw.company_id,
    jw.id as job_work_id,
    jw.job_number,
    jw.job_type,
    jw.status,
    jw.start_date,
    jw.due_date,
    v.first_name || ' ' || v.last_name as vendor_name,
    v.company_name as vendor_company,
    w.name as warehouse_name,
    -- Raw materials progress
    COALESCE(SUM(rm.required_quantity), 0) as raw_required_qty,
    COALESCE(SUM(rm.dispatched_quantity), 0) as raw_dispatched_qty,
    COALESCE(SUM(rm.pending_quantity), 0) as raw_pending_qty,
    -- Finished goods progress  
    COALESCE(SUM(fg.expected_quantity), 0) as finished_expected_qty,
    COALESCE(SUM(fg.received_quantity), 0) as finished_received_qty,
    COALESCE(SUM(fg.pending_quantity), 0) as finished_pending_qty,
    -- Completion percentage
    CASE 
        WHEN COALESCE(SUM(fg.expected_quantity), 0) = 0 THEN 0
        ELSE ROUND((COALESCE(SUM(fg.received_quantity), 0) / COALESCE(SUM(fg.expected_quantity), 1)) * 100, 2)
    END as completion_percentage
FROM job_works jw
JOIN partners v ON jw.vendor_id = v.id
JOIN warehouses w ON jw.warehouse_id = w.id
LEFT JOIN job_work_raw_materials rm ON jw.id = rm.job_work_id
LEFT JOIN job_work_finished_goods fg ON jw.id = fg.job_work_id
WHERE jw.deleted_at IS NULL
GROUP BY jw.company_id, jw.id, jw.job_number, jw.job_type, jw.status, jw.start_date, jw.due_date,
         v.first_name, v.last_name, v.company_name, w.name;

-- Goods Receipt Stock Units View (optimized for receipt page)
CREATE VIEW goods_receipt_stock_units AS
SELECT 
    gr.id as receipt_id,
    gr.receipt_number,
    gr.receipt_date,
    su.id as stock_unit_id,
    su.unit_number,
    su.qr_code,
    su.size_quantity,
    su.quality_grade,
    su.location_description,
    su.status,
    su.manufacturing_date,
    su.barcode_generated,
    p.name as product_name,
    p.material,
    p.color,
    p.measuring_unit
FROM goods_receipts gr
JOIN stock_units su ON gr.id = su.created_from_receipt_id
JOIN products p ON su.product_id = p.id
WHERE su.deleted_at IS NULL;

-- Job Work Details View (optimized for single job work page)
CREATE VIEW job_work_details AS
SELECT 
    jw.*,
    v.first_name || ' ' || v.last_name as vendor_name,
    v.company_name as vendor_company,
    v.phone_number as vendor_phone,
    w.name as warehouse_name,
    a.first_name || ' ' || a.last_name as agent_name,
    -- Raw materials summary
    rm_summary.raw_materials_count,
    rm_summary.total_raw_required,
    rm_summary.total_raw_dispatched,
    rm_summary.total_raw_pending,
    -- Finished goods summary  
    fg_summary.finished_goods_count,
    fg_summary.total_finished_expected,
    fg_summary.total_finished_received,
    fg_summary.total_finished_pending,
    -- Overall completion
    CASE 
        WHEN COALESCE(fg_summary.total_finished_expected, 0) = 0 THEN 0
        ELSE ROUND((COALESCE(fg_summary.total_finished_received, 0) / fg_summary.total_finished_expected) * 100, 2)
    END as completion_percentage
FROM job_works jw
JOIN partners v ON jw.vendor_id = v.id
JOIN warehouses w ON jw.warehouse_id = w.id
LEFT JOIN partners a ON jw.agent_id = a.id
LEFT JOIN (
    SELECT 
        job_work_id,
        COUNT(*) as raw_materials_count,
        SUM(required_quantity) as total_raw_required,
        SUM(dispatched_quantity) as total_raw_dispatched,
        SUM(pending_quantity) as total_raw_pending
    FROM job_work_raw_materials
    GROUP BY job_work_id
) rm_summary ON jw.id = rm_summary.job_work_id
LEFT JOIN (
    SELECT 
        job_work_id,
        COUNT(*) as finished_goods_count,
        SUM(expected_quantity) as total_finished_expected,
        SUM(received_quantity) as total_finished_received,
        SUM(pending_quantity) as total_finished_pending
    FROM job_work_finished_goods  
    GROUP BY job_work_id
) fg_summary ON jw.id = fg_summary.job_work_id;