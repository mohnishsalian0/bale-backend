-- Bale Backend - Stock Units and Inventory Management
-- Individual fabric rolls/pieces tracking with barcode management

-- =====================================================
-- STOCK UNITS TABLE
-- =====================================================

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
    created_from_receipt_id UUID, -- FK will be added in goods movement migration
    
    notes TEXT,
    
    -- Barcode tracking
    barcode_generated BOOLEAN DEFAULT FALSE,
    barcode_generated_at TIMESTAMPTZ,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, unit_number)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Multi-tenant index
CREATE INDEX idx_stock_units_company_id ON stock_units(company_id);

-- Warehouse-specific indexes (most common queries)
CREATE INDEX idx_stock_units_warehouse_id ON stock_units(warehouse_id);
CREATE INDEX idx_stock_units_status ON stock_units(warehouse_id, status);

-- Product relationship
CREATE INDEX idx_stock_units_product_id ON stock_units(product_id);

-- Unit number lookup within company
CREATE INDEX idx_stock_units_unit_number ON stock_units(company_id, unit_number);

-- Receipt tracking (for audit trail)
CREATE INDEX idx_stock_units_receipt_id ON stock_units(created_from_receipt_id);

-- Barcode generation tracking
CREATE INDEX idx_stock_units_barcode_generated ON stock_units(warehouse_id, barcode_generated);

-- Quality grade filtering
CREATE INDEX idx_stock_units_quality_grade ON stock_units(company_id, quality_grade);

-- =====================================================
-- INVENTORY SUMMARY VIEW
-- =====================================================

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

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_stock_units_updated_at 
    BEFORE UPDATE ON stock_units 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure stock units belong to a company
ALTER TABLE stock_units ADD CONSTRAINT check_stock_unit_company_not_null 
    CHECK (company_id IS NOT NULL);