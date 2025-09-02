-- Bale Backend - Job Works Management
-- Job work coordination with goods dispatch and receipt integration

-- =====================================================
-- JOB WORKS TABLE
-- =====================================================

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
    created_by UUID NOT NULL REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, job_number)
);

-- =====================================================
-- JOB WORK RAW MATERIALS (what we send to vendor)
-- =====================================================

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

-- =====================================================
-- JOB WORK FINISHED GOODS (what we receive from vendor)
-- =====================================================

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
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Job Works indexes
CREATE INDEX idx_job_works_company_id ON job_works(company_id);
CREATE INDEX idx_job_works_warehouse_id ON job_works(warehouse_id);
CREATE INDEX idx_job_works_vendor ON job_works(vendor_id);
CREATE INDEX idx_job_works_status ON job_works(company_id, status);
CREATE INDEX idx_job_works_job_number ON job_works(company_id, job_number);
CREATE INDEX idx_job_works_job_type ON job_works(company_id, job_type);
CREATE INDEX idx_job_works_start_date ON job_works(company_id, start_date);

-- Raw Materials indexes
CREATE INDEX idx_job_work_raw_materials_company_id ON job_work_raw_materials(company_id);
CREATE INDEX idx_job_work_raw_materials_job_work_id ON job_work_raw_materials(job_work_id);
CREATE INDEX idx_job_work_raw_materials_product_id ON job_work_raw_materials(product_id);

-- Finished Goods indexes
CREATE INDEX idx_job_work_finished_goods_company_id ON job_work_finished_goods(company_id);
CREATE INDEX idx_job_work_finished_goods_job_work_id ON job_work_finished_goods(job_work_id);
CREATE INDEX idx_job_work_finished_goods_product_id ON job_work_finished_goods(product_id);

-- =====================================================
-- JOB WORK PROGRESS VIEW
-- =====================================================

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

-- =====================================================
-- JOB WORK DETAILS VIEW (for single job work page)
-- =====================================================

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

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_job_works_updated_at 
    BEFORE UPDATE ON job_works 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_work_raw_materials_updated_at 
    BEFORE UPDATE ON job_work_raw_materials 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_work_finished_goods_updated_at 
    BEFORE UPDATE ON job_work_finished_goods 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-generate job numbers
CREATE OR REPLACE FUNCTION auto_generate_job_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.job_number IS NULL OR NEW.job_number = '' THEN
        NEW.job_number := generate_sequence_number('JW', 'job_works', NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_job_number
    BEFORE INSERT ON job_works
    FOR EACH ROW EXECUTE FUNCTION auto_generate_job_number();

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure job works belong to a company
ALTER TABLE job_works ADD CONSTRAINT check_job_work_company_not_null 
    CHECK (company_id IS NOT NULL);