-- Sukh Fabric Inventory Management System - Row Level Security (RLS) Policies (Fixed)
-- Multi-tenant security with role-based access control

-- =====================================================
-- ENABLE RLS ON ALL TABLES
-- =====================================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_works ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_work_raw_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_work_finished_goods ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_dispatches ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_dispatch_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipt_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE barcode_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE barcode_batch_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variant_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE quality_grade_tags ENABLE ROW LEVEL SECURITY;

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
-- PARTNERS TABLE RLS POLICIES
-- =====================================================

-- Admins can view all partners, staff can view partners (needed for dispatch/receipt operations)
CREATE POLICY "Users can view partners in their company"
ON partners
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id()
);

-- Only company admins can create, update, delete partners
CREATE POLICY "Company admins can manage partners"
ON partners
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

CREATE POLICY "Company admins can update partners"
ON partners
FOR UPDATE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

CREATE POLICY "Company admins can delete partners"
ON partners
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- SALES ORDERS TABLE RLS POLICIES
-- =====================================================

-- Admins can view all sales orders, staff can view orders for their assigned warehouse
CREATE POLICY "Users can view sales orders in their scope"
ON sales_orders
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR fulfillment_warehouse_id = get_user_warehouse_id() OR fulfillment_warehouse_id IS NULL
    )
);

-- Only company admins can create sales orders
CREATE POLICY "Company admins can create sales orders"
ON sales_orders
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- Admins can update all sales orders
CREATE POLICY "Company admins can update sales orders"
ON sales_orders
FOR UPDATE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- Admins can delete sales orders
CREATE POLICY "Company admins can delete sales orders"
ON sales_orders
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- SALES ORDER ITEMS TABLE RLS POLICIES
-- =====================================================

-- Users can view sales order items if they can view the parent sales order
CREATE POLICY "Users can view sales order items in their scope"
ON sales_order_items
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM sales_orders so 
        WHERE so.id = sales_order_id 
        AND so.company_id = get_user_company_id()
        AND (is_company_admin() OR so.fulfillment_warehouse_id = get_user_warehouse_id() OR so.fulfillment_warehouse_id IS NULL)
    )
);

-- Only company admins can create, update, delete sales order items
CREATE POLICY "Company admins can manage sales order items"
ON sales_order_items
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- JOB WORKS TABLE RLS POLICIES
-- =====================================================

-- Admins can view all job works, staff can view job works in their assigned warehouse
CREATE POLICY "Users can view job works in their scope"
ON job_works
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can create job works for any warehouse, staff only for their assigned warehouse
CREATE POLICY "Users can create job works in their scope"
ON job_works
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can update all job works, staff only in their assigned warehouse
CREATE POLICY "Users can update job works in their scope"
ON job_works
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

-- Admins can delete job works, staff only in their assigned warehouse
CREATE POLICY "Users can delete job works in their scope"
ON job_works
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- =====================================================
-- JOB WORK RELATED TABLES RLS POLICIES
-- =====================================================

-- Job work raw materials and finished goods follow parent job work access
CREATE POLICY "Users can view job work raw materials in their scope"
ON job_work_raw_materials
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM job_works jw 
        WHERE jw.id = job_work_id 
        AND jw.company_id = get_user_company_id()
        AND (is_company_admin() OR jw.warehouse_id = get_user_warehouse_id())
    )
);

CREATE POLICY "Users can manage job work raw materials in their scope"
ON job_work_raw_materials
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM job_works jw 
        WHERE jw.id = job_work_id 
        AND jw.company_id = get_user_company_id()
        AND (is_company_admin() OR jw.warehouse_id = get_user_warehouse_id())
    )
)
WITH CHECK (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM job_works jw 
        WHERE jw.id = job_work_id 
        AND jw.company_id = get_user_company_id()
        AND (is_company_admin() OR jw.warehouse_id = get_user_warehouse_id())
    )
);

-- Similar policies for job work finished goods
CREATE POLICY "Users can view job work finished goods in their scope"
ON job_work_finished_goods
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM job_works jw 
        WHERE jw.id = job_work_id 
        AND jw.company_id = get_user_company_id()
        AND (is_company_admin() OR jw.warehouse_id = get_user_warehouse_id())
    )
);

CREATE POLICY "Users can manage job work finished goods in their scope"
ON job_work_finished_goods
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM job_works jw 
        WHERE jw.id = job_work_id 
        AND jw.company_id = get_user_company_id()
        AND (is_company_admin() OR jw.warehouse_id = get_user_warehouse_id())
    )
)
WITH CHECK (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM job_works jw 
        WHERE jw.id = job_work_id 
        AND jw.company_id = get_user_company_id()
        AND (is_company_admin() OR jw.warehouse_id = get_user_warehouse_id())
    )
);

-- =====================================================
-- GOODS DISPATCH TABLE RLS POLICIES
-- =====================================================

-- Admins can view all dispatches, staff can view dispatches from their assigned warehouse
CREATE POLICY "Users can view goods dispatches in their scope"
ON goods_dispatches
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can create dispatches from any warehouse, staff only from their assigned warehouse
CREATE POLICY "Users can create goods dispatches in their scope"
ON goods_dispatches
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can update all dispatches, staff only from their assigned warehouse
CREATE POLICY "Users can update goods dispatches in their scope"
ON goods_dispatches
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

-- Admins can delete dispatches, staff only from their assigned warehouse
CREATE POLICY "Users can delete goods dispatches in their scope"
ON goods_dispatches
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- =====================================================
-- GOODS DISPATCH ITEMS TABLE RLS POLICIES
-- =====================================================

-- Users can view dispatch items if they can view the parent dispatch
CREATE POLICY "Users can view goods dispatch items in their scope"
ON goods_dispatch_items
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM goods_dispatches gd 
        WHERE gd.id = dispatch_id 
        AND gd.company_id = get_user_company_id()
        AND (is_company_admin() OR gd.warehouse_id = get_user_warehouse_id())
    )
);

-- Users can manage dispatch items if they can manage the parent dispatch
CREATE POLICY "Users can manage goods dispatch items in their scope"
ON goods_dispatch_items
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM goods_dispatches gd 
        WHERE gd.id = dispatch_id 
        AND gd.company_id = get_user_company_id()
        AND (is_company_admin() OR gd.warehouse_id = get_user_warehouse_id())
    )
)
WITH CHECK (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM goods_dispatches gd 
        WHERE gd.id = dispatch_id 
        AND gd.company_id = get_user_company_id()
        AND (is_company_admin() OR gd.warehouse_id = get_user_warehouse_id())
    )
);

-- =====================================================
-- GOODS RECEIPT TABLE RLS POLICIES
-- =====================================================

-- Admins can view all receipts, staff can view receipts for their assigned warehouse
CREATE POLICY "Users can view goods receipts in their scope"
ON goods_receipts
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can create receipts for any warehouse, staff only for their assigned warehouse
CREATE POLICY "Users can create goods receipts in their scope"
ON goods_receipts
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can update all receipts, staff only for their assigned warehouse
CREATE POLICY "Users can update goods receipts in their scope"
ON goods_receipts
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

-- Only admins can delete receipts (soft delete for audit)
CREATE POLICY "Company admins can delete goods receipts"
ON goods_receipts
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- GOODS RECEIPT ITEMS TABLE RLS POLICIES
-- =====================================================

-- Users can view receipt items if they can view the parent receipt
CREATE POLICY "Users can view goods receipt items in their scope"
ON goods_receipt_items
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM goods_receipts gr 
        WHERE gr.id = receipt_id 
        AND gr.company_id = get_user_company_id()
        AND (is_company_admin() OR gr.warehouse_id = get_user_warehouse_id())
    )
);

-- Users can manage receipt items if they can manage the parent receipt
CREATE POLICY "Users can manage goods receipt items in their scope"
ON goods_receipt_items
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM goods_receipts gr 
        WHERE gr.id = receipt_id 
        AND gr.company_id = get_user_company_id()
        AND (is_company_admin() OR gr.warehouse_id = get_user_warehouse_id())
    )
)
WITH CHECK (
    company_id = get_user_company_id() AND
    EXISTS (
        SELECT 1 FROM goods_receipts gr 
        WHERE gr.id = receipt_id 
        AND gr.company_id = get_user_company_id()
        AND (is_company_admin() OR gr.warehouse_id = get_user_warehouse_id())
    )
);

-- =====================================================
-- BARCODE MANAGEMENT RLS POLICIES
-- =====================================================

-- Admins can view all barcode batches, staff can view batches for their assigned warehouse
CREATE POLICY "Users can view barcode batches in their scope"
ON barcode_batches
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can create barcode batches for any warehouse, staff only for their assigned warehouse
CREATE POLICY "Users can create barcode batches in their scope"
ON barcode_batches
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id() AND (
        is_company_admin() OR warehouse_id = get_user_warehouse_id()
    )
);

-- Admins can update all barcode batches, staff only for their assigned warehouse
CREATE POLICY "Users can update barcode batches in their scope"
ON barcode_batches
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

-- Users can view barcode batch items if they can view the parent batch
CREATE POLICY "Users can view barcode batch items in their scope"
ON barcode_batch_items
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM barcode_batches bb 
        WHERE bb.id = batch_id 
        AND bb.company_id = get_user_company_id()
        AND (is_company_admin() OR bb.warehouse_id = get_user_warehouse_id())
    )
);

-- Users can manage barcode batch items if they can manage the parent batch
CREATE POLICY "Users can manage barcode batch items in their scope"
ON barcode_batch_items
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM barcode_batches bb 
        WHERE bb.id = batch_id 
        AND bb.company_id = get_user_company_id()
        AND (is_company_admin() OR bb.warehouse_id = get_user_warehouse_id())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM barcode_batches bb 
        WHERE bb.id = batch_id 
        AND bb.company_id = get_user_company_id()
        AND (is_company_admin() OR bb.warehouse_id = get_user_warehouse_id())
    )
);

-- =====================================================
-- CATALOG CONFIGURATION RLS POLICIES
-- =====================================================

-- Only company admins can manage catalog configuration (one per company)
CREATE POLICY "Company admins can manage catalog configuration"
ON catalog_configurations
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- PRODUCT VARIANTS RLS POLICIES
-- =====================================================

-- Users can view product variants in their company
CREATE POLICY "Users can view product variants in their company"
ON product_variants
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id()
);

-- Only company admins can manage product variants
CREATE POLICY "Company admins can manage product variants"
ON product_variants
FOR ALL
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- Users can view product variant items if they can view the parent variant
CREATE POLICY "Users can view product variant items in their scope"
ON product_variant_items
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM product_variants pv 
        WHERE pv.id = variant_id 
        AND pv.company_id = get_user_company_id()
    )
);

-- Only company admins can manage product variant items
CREATE POLICY "Company admins can manage product variant items"
ON product_variant_items
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM product_variants pv 
        WHERE pv.id = variant_id 
        AND pv.company_id = get_user_company_id()
        AND is_company_admin()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM product_variants pv 
        WHERE pv.id = variant_id 
        AND pv.company_id = get_user_company_id()
        AND is_company_admin()
    )
);

-- =====================================================
-- QUALITY GRADE TAGS RLS POLICIES
-- =====================================================

-- All users can view quality grade tags in their company
CREATE POLICY "Users can view quality grade tags in their company"
ON quality_grade_tags
FOR SELECT
TO authenticated
USING (
    company_id = get_user_company_id()
);

-- All users can create quality grade tags (for dynamic tag creation)
CREATE POLICY "Users can create quality grade tags"
ON quality_grade_tags
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_user_company_id()
);

-- Only company admins can update quality grade tags
CREATE POLICY "Company admins can update quality grade tags"
ON quality_grade_tags
FOR UPDATE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
)
WITH CHECK (
    company_id = get_user_company_id() AND is_company_admin()
);

-- Only company admins can delete quality grade tags
CREATE POLICY "Company admins can delete quality grade tags"
ON quality_grade_tags
FOR DELETE
TO authenticated
USING (
    company_id = get_user_company_id() AND is_company_admin()
);

-- =====================================================
-- PUBLIC CATALOG ACCESS (ANONYMOUS USERS)
-- =====================================================

-- Allow anonymous users to view public catalogs
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

-- Allow anonymous users to view public catalog configurations
CREATE POLICY "Anonymous users can view public catalog configurations"
ON catalog_configurations
FOR SELECT
TO anon
USING (
    accepting_orders = true
);

-- Allow anonymous users to view public product variants
CREATE POLICY "Anonymous users can view public product variants"
ON product_variants
FOR SELECT
TO anon
USING (
    EXISTS (
        SELECT 1 FROM catalog_configurations cc 
        WHERE cc.company_id = product_variants.company_id 
        AND cc.accepting_orders = true
    )
);

-- Allow anonymous users to view public product variant items
CREATE POLICY "Anonymous users can view public product variant items"
ON product_variant_items
FOR SELECT
TO anon
USING (
    EXISTS (
        SELECT 1 FROM product_variants pv 
        JOIN catalog_configurations cc ON pv.company_id = cc.company_id
        WHERE pv.id = product_variant_items.variant_id 
        AND cc.accepting_orders = true
    )
);

-- Allow anonymous users to create sales orders (from public catalog)
CREATE POLICY "Anonymous users can create sales orders from public catalog"
ON sales_orders
FOR INSERT
TO anon
WITH CHECK (
    EXISTS (
        SELECT 1 FROM catalog_configurations cc 
        WHERE cc.company_id = sales_orders.company_id 
        AND cc.accepting_orders = true
    )
);

-- Allow anonymous users to create sales order items for public catalog orders
CREATE POLICY "Anonymous users can create sales order items from public catalog"
ON sales_order_items
FOR INSERT
TO anon
WITH CHECK (
    EXISTS (
        SELECT 1 FROM sales_orders so
        JOIN catalog_configurations cc ON so.company_id = cc.company_id
        WHERE so.id = sales_order_items.sales_order_id 
        AND cc.accepting_orders = true
    )
);

-- =====================================================
-- GRANT PERMISSIONS TO AUTHENTICATED USERS
-- =====================================================

-- Grant basic permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant limited permissions to anonymous users (for public catalog)
GRANT SELECT ON products TO anon;
GRANT SELECT ON catalog_configurations TO anon;
GRANT SELECT ON product_variants TO anon;
GRANT SELECT ON product_variant_items TO anon;
GRANT SELECT ON partners TO anon; -- Needed for customer creation
GRANT INSERT ON sales_orders TO anon;
GRANT INSERT ON sales_order_items TO anon;
GRANT INSERT ON partners TO anon; -- For new customer creation from catalog

-- =====================================================
-- ADDITIONAL SECURITY CONSTRAINTS
-- =====================================================

-- Ensure users belong to a company
ALTER TABLE users ADD CONSTRAINT check_user_company_not_null 
    CHECK (company_id IS NOT NULL);

-- Ensure staff users have warehouse assignment
ALTER TABLE users ADD CONSTRAINT check_staff_has_warehouse 
    CHECK (role != 'staff' OR warehouse_id IS NOT NULL);

-- Ensure warehouses belong to a company
ALTER TABLE warehouses ADD CONSTRAINT check_warehouse_company_not_null 
    CHECK (company_id IS NOT NULL);

-- Ensure all business entities belong to a company
ALTER TABLE products ADD CONSTRAINT check_product_company_not_null 
    CHECK (company_id IS NOT NULL);
ALTER TABLE stock_units ADD CONSTRAINT check_stock_unit_company_not_null 
    CHECK (company_id IS NOT NULL);
ALTER TABLE partners ADD CONSTRAINT check_partner_company_not_null 
    CHECK (company_id IS NOT NULL);
ALTER TABLE sales_orders ADD CONSTRAINT check_sales_order_company_not_null 
    CHECK (company_id IS NOT NULL);
ALTER TABLE job_works ADD CONSTRAINT check_job_work_company_not_null 
    CHECK (company_id IS NOT NULL);