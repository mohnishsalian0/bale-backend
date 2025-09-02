-- Bale Backend - Barcode Generation System
-- Comprehensive barcode generation with customization and batch printing

-- =====================================================
-- BARCODE GENERATION BATCHES
-- =====================================================

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
    created_by UUID NOT NULL REFERENCES users(id),
    modified_by UUID REFERENCES users(id)
);

-- =====================================================
-- BARCODE BATCH ITEMS (which units were included)
-- =====================================================

CREATE TABLE barcode_batch_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id UUID NOT NULL REFERENCES barcode_batches(id) ON DELETE CASCADE,
    stock_unit_id UUID NOT NULL REFERENCES stock_units(id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Barcode Batches indexes
CREATE INDEX idx_barcode_batches_company_id ON barcode_batches(company_id);
CREATE INDEX idx_barcode_batches_warehouse_id ON barcode_batches(warehouse_id);
CREATE INDEX idx_barcode_batches_created_at ON barcode_batches(warehouse_id, created_at);

-- Barcode Batch Items indexes
CREATE INDEX idx_barcode_batch_items_batch_id ON barcode_batch_items(batch_id);
CREATE INDEX idx_barcode_batch_items_stock_unit ON barcode_batch_items(stock_unit_id);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_barcode_batches_updated_at 
    BEFORE UPDATE ON barcode_batches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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