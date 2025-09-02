-- Bale Backend - Companies and Users Management
-- Multi-tenant foundation with role-based access control

-- =====================================================
-- COMPANIES TABLE (TENANT ISOLATION)
-- =====================================================

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
    created_by UUID NOT NULL,
    modified_by UUID,
    deleted_at TIMESTAMPTZ
);

-- =====================================================
-- USERS/STAFF TABLE WITH ROLE-BASED ACCESS
-- =====================================================

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
    warehouse_id UUID, -- Single warehouse assignment for staff (FK will be added later)
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Authentication (handled by Supabase Auth)
    auth_user_id UUID UNIQUE,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,
    modified_by UUID,
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, phone_number)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Multi-tenant indexes (company_id is always in WHERE clause)
CREATE INDEX idx_users_company_id ON users(company_id);

-- Authentication lookup
CREATE INDEX idx_users_auth_user_id ON users(auth_user_id);

-- Phone number lookup within company
CREATE INDEX idx_users_phone ON users(company_id, phone_number);

-- Role-based queries
CREATE INDEX idx_users_role ON users(company_id, role);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_companies_updated_at 
    BEFORE UPDATE ON companies 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure users belong to a company
ALTER TABLE users ADD CONSTRAINT check_user_company_not_null 
    CHECK (company_id IS NOT NULL);