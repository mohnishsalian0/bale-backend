-- Bale Backend - Partners Management
-- Comprehensive partner management for customers, suppliers, vendors, and agents

-- =====================================================
-- PARTNERS TABLE
-- =====================================================

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
    created_by UUID NOT NULL REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, phone_number)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Multi-tenant index
CREATE INDEX idx_partners_company_id ON partners(company_id);

-- Partner type filtering (common query pattern)
CREATE INDEX idx_partners_type ON partners(company_id, partner_type);

-- Phone number lookup within company
CREATE INDEX idx_partners_phone ON partners(company_id, phone_number);

-- Name-based search
CREATE INDEX idx_partners_name ON partners(company_id, first_name, last_name);

-- Company name search
CREATE INDEX idx_partners_company_name ON partners(company_id, company_name);

-- Email lookup
CREATE INDEX idx_partners_email ON partners(company_id, email);

-- GST number lookup
CREATE INDEX idx_partners_gst ON partners(company_id, gst_number) WHERE gst_number IS NOT NULL;

-- Location-based queries
CREATE INDEX idx_partners_city ON partners(company_id, city);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_partners_updated_at 
    BEFORE UPDATE ON partners 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure partners belong to a company
ALTER TABLE partners ADD CONSTRAINT check_partner_company_not_null 
    CHECK (company_id IS NOT NULL);