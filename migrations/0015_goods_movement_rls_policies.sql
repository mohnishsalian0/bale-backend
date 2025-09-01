-- Bale Backend - Goods Movement RLS Policies
-- Security policies for goods dispatch and receipt

-- =====================================================
-- ENABLE RLS ON GOODS MOVEMENT TABLES
-- =====================================================

ALTER TABLE goods_dispatches ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_dispatch_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE goods_receipt_items ENABLE ROW LEVEL SECURITY;

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
-- GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON goods_dispatches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON goods_dispatch_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON goods_receipts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON goods_receipt_items TO authenticated;