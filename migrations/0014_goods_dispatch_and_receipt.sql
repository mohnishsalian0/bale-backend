-- Bale Backend - Goods Movement (Dispatch and Receipt)
-- Comprehensive outward and inward inventory management

-- =====================================================
-- GOODS DISPATCH TABLE
-- =====================================================

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

-- =====================================================
-- GOODS DISPATCH ITEMS (linking to specific stock units)
-- =====================================================

CREATE TABLE goods_dispatch_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    dispatch_id UUID NOT NULL REFERENCES goods_dispatches(id) ON DELETE CASCADE,
    stock_unit_id UUID NOT NULL REFERENCES stock_units(id),
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- GOODS RECEIPT TABLE
-- =====================================================

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

-- =====================================================
-- GOODS RECEIPT ITEMS (creates new stock units)
-- =====================================================

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

-- Now add the missing foreign key constraint to stock_units
ALTER TABLE stock_units ADD CONSTRAINT fk_stock_unit_receipt 
    FOREIGN KEY (created_from_receipt_id) REFERENCES goods_receipts(id);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Goods Dispatch indexes
CREATE INDEX idx_goods_dispatches_company_id ON goods_dispatches(company_id);
CREATE INDEX idx_goods_dispatches_warehouse_id ON goods_dispatches(warehouse_id);
CREATE INDEX idx_goods_dispatches_date ON goods_dispatches(company_id, dispatch_date);
CREATE INDEX idx_goods_dispatches_dispatch_number ON goods_dispatches(company_id, dispatch_number);
CREATE INDEX idx_goods_dispatches_partner ON goods_dispatches(dispatch_to_partner_id);
CREATE INDEX idx_goods_dispatches_sales_order ON goods_dispatches(sales_order_id);
CREATE INDEX idx_goods_dispatches_job_work ON goods_dispatches(job_work_id);

-- Goods Dispatch Items indexes
CREATE INDEX idx_goods_dispatch_items_company_id ON goods_dispatch_items(company_id);
CREATE INDEX idx_goods_dispatch_items_dispatch_id ON goods_dispatch_items(dispatch_id);
CREATE INDEX idx_goods_dispatch_items_stock_unit ON goods_dispatch_items(stock_unit_id);

-- Goods Receipt indexes
CREATE INDEX idx_goods_receipts_company_id ON goods_receipts(company_id);
CREATE INDEX idx_goods_receipts_warehouse_id ON goods_receipts(warehouse_id);
CREATE INDEX idx_goods_receipts_date ON goods_receipts(company_id, receipt_date);
CREATE INDEX idx_goods_receipts_receipt_number ON goods_receipts(company_id, receipt_number);
CREATE INDEX idx_goods_receipts_partner ON goods_receipts(issued_by_partner_id);
CREATE INDEX idx_goods_receipts_sales_order ON goods_receipts(sales_order_id);
CREATE INDEX idx_goods_receipts_job_work ON goods_receipts(job_work_id);

-- Goods Receipt Items indexes
CREATE INDEX idx_goods_receipt_items_company_id ON goods_receipt_items(company_id);
CREATE INDEX idx_goods_receipt_items_receipt_id ON goods_receipt_items(receipt_id);
CREATE INDEX idx_goods_receipt_items_product_id ON goods_receipt_items(product_id);

-- =====================================================
-- GOODS RECEIPT STOCK UNITS VIEW
-- =====================================================

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

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_goods_dispatches_updated_at 
    BEFORE UPDATE ON goods_dispatches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_goods_dispatch_items_updated_at 
    BEFORE UPDATE ON goods_dispatch_items 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_goods_receipts_updated_at 
    BEFORE UPDATE ON goods_receipts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_goods_receipt_items_updated_at 
    BEFORE UPDATE ON goods_receipt_items 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-generate dispatch numbers
CREATE OR REPLACE FUNCTION auto_generate_dispatch_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.dispatch_number IS NULL OR NEW.dispatch_number = '' THEN
        NEW.dispatch_number := generate_sequence_number('GD', 'goods_dispatches', NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_dispatch_number
    BEFORE INSERT ON goods_dispatches
    FOR EACH ROW EXECUTE FUNCTION auto_generate_dispatch_number();

-- Auto-generate receipt numbers
CREATE OR REPLACE FUNCTION auto_generate_receipt_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.receipt_number IS NULL OR NEW.receipt_number = '' THEN
        NEW.receipt_number := generate_sequence_number('GR', 'goods_receipts', NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_receipt_number
    BEFORE INSERT ON goods_receipts
    FOR EACH ROW EXECUTE FUNCTION auto_generate_receipt_number();

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