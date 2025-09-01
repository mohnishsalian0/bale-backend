-- Bale Backend - Core RLS Policies
-- Multi-tenant security with role-based access control for core tables

-- =====================================================
-- ENABLE RLS ON CORE TABLES
-- =====================================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- UTILITY FUNCTIONS FOR RLS
-- =====================================================

-- Function to get current user's company_id
CREATE OR REPLACE FUNCTION get_user_company_id()
RETURNS UUID AS $$
DECLARE
    user_company UUID;
BEGIN
    SELECT company_id INTO user_company 
    FROM users 
    WHERE auth_user_id = auth.uid();
    
    RETURN user_company;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role 
    FROM users 
    WHERE auth_user_id = auth.uid();
    
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's warehouse_id
CREATE OR REPLACE FUNCTION get_user_warehouse_id()
RETURNS UUID AS $$
DECLARE
    user_warehouse UUID;
BEGIN
    SELECT warehouse_id INTO user_warehouse 
    FROM users 
    WHERE auth_user_id = auth.uid();
    
    RETURN user_warehouse;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is company admin
CREATE OR REPLACE FUNCTION is_company_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN get_user_role() = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is staff
CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN get_user_role() = 'staff';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- COMPANIES TABLE RLS POLICIES
-- =====================================================

-- Company admins can read their own company
CREATE POLICY "Company admins can view their company"
ON companies
FOR SELECT
TO authenticated
USING (
    id = get_user_company_id() AND is_company_admin()
);

-- Company admins can update their own company
CREATE POLICY "Company admins can update their company"
ON companies
FOR UPDATE
TO authenticated
USING (
    id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- USERS TABLE RLS POLICIES
-- =====================================================

-- Users can view their own record and admins can view all users in their company
CREATE POLICY "Users can view users in their company"
ON users
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        auth_user_id = auth.uid() OR is_company_admin()
    )
);

-- Only company admins can create new users
CREATE POLICY "Company admins can create users"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- Users can update their own profile, admins can update all users in their company
CREATE POLICY "Users can update profiles in their company"
ON users
FOR UPDATE
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        auth_user_id = auth.uid() OR is_company_admin()
    )
)
WITH CHECK (
    company_id = get_user_company_id() AND (
        auth_user_id = auth.uid() OR is_company_admin()
    )
);

-- Only company admins can delete users
CREATE POLICY "Company admins can delete users"
ON users
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- WAREHOUSES TABLE RLS POLICIES
-- =====================================================

-- Admins can view all warehouses, staff can view their assigned warehouse
CREATE POLICY "Users can view warehouses in their company"
ON warehouses
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR id = get_user_warehouse_id()
    )
);

-- Only company admins can create, update, delete warehouses
CREATE POLICY "Company admins can manage warehouses"
ON warehouses
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- GRANT PERMISSIONS TO AUTHENTICATED USERS
-- =====================================================

-- Grant basic permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON companies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON warehouses TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;