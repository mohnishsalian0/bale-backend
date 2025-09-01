-- Bale Backend - Sales Order RLS Policies
-- Security policies for sales order management

-- =====================================================
-- ENABLE RLS ON SALES TABLES
-- =====================================================

ALTER TABLE sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_order_items ENABLE ROW LEVEL SECURITY;

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
-- PUBLIC CATALOG ACCESS (ANONYMOUS USERS)
-- =====================================================

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
-- GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON sales_orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sales_order_items TO authenticated;

-- Grant limited permissions to anonymous users (for public catalog)
GRANT INSERT ON sales_orders TO anon;
GRANT INSERT ON sales_order_items TO anon;