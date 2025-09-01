-- Bale Backend - Product Catalog RLS Policies
-- Security policies for products and stock units

-- =====================================================
-- ENABLE RLS ON PRODUCT TABLES
-- =====================================================

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_units ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PRODUCTS TABLE RLS POLICIES
-- =====================================================

-- All users can view products in their company (needed for operations)
CREATE POLICY "Users can view products in their company"
ON products
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id()
);

-- Only company admins can create, update, delete products
CREATE POLICY "Company admins can manage products"
ON products
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

CREATE POLICY "Company admins can update products"
ON products
FOR UPDATE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

CREATE POLICY "Company admins can delete products"
ON products
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- STOCK UNITS TABLE RLS POLICIES
-- =====================================================

-- Admins can view all stock units, staff can view units in their assigned warehouse
CREATE POLICY "Users can view stock units in their scope"
ON stock_units
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can create stock units in any warehouse, staff only in their assigned warehouse
CREATE POLICY "Users can create stock units in their scope"
ON stock_units
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can update all stock units, staff only in their assigned warehouse
CREATE POLICY "Users can update stock units in their scope"
ON stock_units
FOR UPDATE
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
)
WITH CHECK (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can delete stock units in any warehouse, staff only in their assigned warehouse
CREATE POLICY "Users can delete stock units in their scope"
ON stock_units
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- =====================================================
-- PUBLIC CATALOG ACCESS (ANONYMOUS USERS)
-- =====================================================

-- Allow anonymous users to view public products (for catalog)
CREATE POLICY "Anonymous users can view public products"
ON products
FOR SELECT
TO anon
USING (
    show_on_catalog = true AND
    EXISTS (
        SELECT 1 FROM catalog_configurations cc 
        WHERE cc.company_id = products.company_id 
        AND cc.accepting_orders = true
    )
);

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON stock_units TO authenticated;

-- Grant limited permissions to anonymous users (for public catalog)
GRANT SELECT ON products TO anon;