-- Bale Backend - Warehouses Management
-- Location-based inventory management with staff assignment

-- =====================================================
-- WAREHOUSES TABLE
-- =====================================================

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
    created_by UUID REFERENCES users(id) NOT NULL,
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, name)
);

-- Add foreign key constraint for warehouse assignment in users table
ALTER TABLE users ADD CONSTRAINT fk_user_warehouse 
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Multi-tenant index
CREATE INDEX idx_warehouses_company_id ON warehouses(company_id);

-- Staff assignment lookup
CREATE INDEX idx_users_warehouse_id ON users(warehouse_id);

-- Warehouse name lookup within company
CREATE INDEX idx_warehouses_name ON warehouses(company_id, name);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_warehouses_updated_at 
    BEFORE UPDATE ON warehouses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure warehouses belong to a company
ALTER TABLE warehouses ADD CONSTRAINT check_warehouse_company_not_null 
    CHECK (company_id IS NOT NULL);

-- Ensure staff users have warehouse assignment
ALTER TABLE users ADD CONSTRAINT check_staff_has_warehouse 
    CHECK (role != 'staff' OR warehouse_id IS NOT NULL);
