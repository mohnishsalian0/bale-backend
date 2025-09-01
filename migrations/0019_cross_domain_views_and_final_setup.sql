-- Bale Backend - Cross-Domain Views and Final Setup
-- Complex views that span multiple business domains and final database setup

-- =====================================================
-- COMPREHENSIVE ORDER FULFILLMENT VIEW
-- =====================================================

CREATE VIEW comprehensive_order_fulfillment AS
SELECT 
    so.company_id,
    so.id as sales_order_id,
    so.order_number,
    so.status as order_status,
    so.order_date,
    so.expected_delivery_date,
    
    -- Customer information
    c.first_name || ' ' || c.last_name as customer_name,
    c.company_name as customer_company,
    c.phone_number as customer_phone,
    
    -- Warehouse information
    w.name as fulfillment_warehouse,
    
    -- Order financial summary
    so.total_amount,
    so.advance_amount,
    so.discount_percentage,
    
    -- Fulfillment progress
    COALESCE(SUM(soi.required_quantity), 0) as total_required_qty,
    COALESCE(SUM(soi.dispatched_quantity), 0) as total_dispatched_qty,
    COALESCE(SUM(soi.pending_quantity), 0) as total_pending_qty,
    
    -- Completion metrics
    CASE 
        WHEN COALESCE(SUM(soi.required_quantity), 0) = 0 THEN 0
        ELSE ROUND((COALESCE(SUM(soi.dispatched_quantity), 0) / COALESCE(SUM(soi.required_quantity), 1)) * 100, 2)
    END as fulfillment_percentage,
    
    -- Dispatch summary
    COUNT(DISTINCT gd.id) as total_dispatches,
    COUNT(DISTINCT CASE WHEN gd.is_cancelled = false THEN gd.id END) as active_dispatches,
    
    -- Job work integration
    COUNT(DISTINCT jw.id) as linked_job_works,
    COUNT(DISTINCT CASE WHEN jw.status = 'completed' THEN jw.id END) as completed_job_works,
    
    -- Recent activity
    GREATEST(
        so.updated_at,
        MAX(soi.updated_at),
        MAX(gd.updated_at),
        MAX(jw.updated_at)
    ) as last_activity_at

FROM sales_orders so
JOIN partners c ON so.customer_id = c.id
LEFT JOIN warehouses w ON so.fulfillment_warehouse_id = w.id
LEFT JOIN sales_order_items soi ON so.id = soi.sales_order_id
LEFT JOIN goods_dispatches gd ON so.id = gd.sales_order_id
LEFT JOIN job_works jw ON so.id = jw.sales_order_id
WHERE so.deleted_at IS NULL
GROUP BY so.company_id, so.id, so.order_number, so.status, so.order_date, so.expected_delivery_date,
         c.first_name, c.last_name, c.company_name, c.phone_number, w.name, so.total_amount, 
         so.advance_amount, so.discount_percentage, so.updated_at;

-- =====================================================
-- WAREHOUSE ACTIVITY DASHBOARD VIEW
-- =====================================================

CREATE VIEW warehouse_activity_dashboard AS
SELECT 
    w.company_id,
    w.id as warehouse_id,
    w.name as warehouse_name,
    
    -- Stock summary
    COUNT(DISTINCT su.id) as total_stock_units,
    SUM(CASE WHEN su.status = 'in_stock' THEN 1 ELSE 0 END) as available_units,
    SUM(CASE WHEN su.status = 'dispatched' THEN 1 ELSE 0 END) as dispatched_units,
    
    -- Recent activity counts (last 30 days)
    COUNT(DISTINCT CASE 
        WHEN gr.receipt_date >= CURRENT_DATE - INTERVAL '30 days' 
        THEN gr.id 
    END) as receipts_last_30_days,
    
    COUNT(DISTINCT CASE 
        WHEN gd.dispatch_date >= CURRENT_DATE - INTERVAL '30 days' AND gd.is_cancelled = false
        THEN gd.id 
    END) as dispatches_last_30_days,
    
    COUNT(DISTINCT CASE 
        WHEN jw.start_date >= CURRENT_DATE - INTERVAL '30 days'
        THEN jw.id 
    END) as job_works_last_30_days,
    
    -- Pending operations
    COUNT(DISTINCT CASE WHEN jw.status = 'in_progress' THEN jw.id END) as active_job_works,
    COUNT(DISTINCT CASE 
        WHEN so.status IN ('approval_pending', 'in_progress') 
        THEN so.id 
    END) as pending_sales_orders,
    
    -- Barcode generation status
    COUNT(DISTINCT CASE WHEN su.barcode_generated = false THEN su.id END) as units_without_barcodes,
    
    -- Staff information
    COUNT(DISTINCT u.id) as assigned_staff_count,
    
    -- Last activity timestamp
    GREATEST(
        MAX(gr.updated_at),
        MAX(gd.updated_at),
        MAX(jw.updated_at),
        MAX(su.updated_at)
    ) as last_activity_at

FROM warehouses w
LEFT JOIN stock_units su ON w.id = su.warehouse_id AND su.deleted_at IS NULL
LEFT JOIN goods_receipts gr ON w.id = gr.warehouse_id AND gr.deleted_at IS NULL
LEFT JOIN goods_dispatches gd ON w.id = gd.warehouse_id AND gd.deleted_at IS NULL
LEFT JOIN job_works jw ON w.id = jw.warehouse_id AND jw.deleted_at IS NULL
LEFT JOIN sales_orders so ON w.id = so.fulfillment_warehouse_id AND so.deleted_at IS NULL
LEFT JOIN users u ON w.id = u.warehouse_id AND u.deleted_at IS NULL
WHERE w.deleted_at IS NULL
GROUP BY w.company_id, w.id, w.name;

-- =====================================================
-- PARTNER TRANSACTION SUMMARY VIEW
-- =====================================================

CREATE VIEW partner_transaction_summary AS
SELECT 
    p.company_id,
    p.id as partner_id,
    p.first_name || ' ' || p.last_name as partner_name,
    p.company_name,
    p.partner_type,
    p.phone_number,
    p.email,
    
    -- Sales orders (as customer)
    COUNT(DISTINCT CASE WHEN p.partner_type = 'Customer' THEN so.id END) as total_sales_orders,
    COALESCE(SUM(CASE WHEN p.partner_type = 'Customer' THEN so.total_amount END), 0) as total_sales_value,
    COUNT(DISTINCT CASE 
        WHEN p.partner_type = 'Customer' AND so.status = 'completed' 
        THEN so.id 
    END) as completed_sales_orders,
    
    -- Job works (as vendor)
    COUNT(DISTINCT CASE WHEN p.partner_type = 'Vendor' THEN jw.id END) as total_job_works,
    COUNT(DISTINCT CASE 
        WHEN p.partner_type = 'Vendor' AND jw.status = 'completed' 
        THEN jw.id 
    END) as completed_job_works,
    
    -- Goods movements
    COUNT(DISTINCT gd_to.id) as goods_dispatched_to,
    COUNT(DISTINCT gd_agent.id) as goods_dispatched_via_agent,
    COUNT(DISTINCT gr_from.id) as goods_received_from,
    
    -- Recent activity
    GREATEST(
        MAX(so.updated_at),
        MAX(jw.updated_at),
        MAX(gd_to.updated_at),
        MAX(gr_from.updated_at)
    ) as last_transaction_at,
    
    -- Days since last activity
    CASE 
        WHEN GREATEST(
            MAX(so.updated_at),
            MAX(jw.updated_at),
            MAX(gd_to.updated_at),
            MAX(gr_from.updated_at)
        ) IS NOT NULL 
        THEN CURRENT_DATE - GREATEST(
            MAX(so.updated_at),
            MAX(jw.updated_at),
            MAX(gd_to.updated_at),
            MAX(gr_from.updated_at)
        )::DATE
        ELSE NULL 
    END as days_since_last_activity

FROM partners p
LEFT JOIN sales_orders so ON p.id = so.customer_id AND so.deleted_at IS NULL
LEFT JOIN job_works jw ON p.id = jw.vendor_id AND jw.deleted_at IS NULL
LEFT JOIN goods_dispatches gd_to ON p.id = gd_to.dispatch_to_partner_id AND gd_to.deleted_at IS NULL
LEFT JOIN goods_dispatches gd_agent ON p.id = gd_agent.agent_id AND gd_agent.deleted_at IS NULL
LEFT JOIN goods_receipts gr_from ON p.id = gr_from.issued_by_partner_id AND gr_from.deleted_at IS NULL
WHERE p.deleted_at IS NULL
GROUP BY p.company_id, p.id, p.first_name, p.last_name, p.company_name, 
         p.partner_type, p.phone_number, p.email;

-- =====================================================
-- INVENTORY MOVEMENT AUDIT TRAIL
-- =====================================================

CREATE VIEW inventory_movement_audit_trail AS
-- Goods Receipts (Inward movement)
SELECT 
    'RECEIPT' as movement_type,
    gr.company_id,
    gr.warehouse_id,
    w.name as warehouse_name,
    gr.id as transaction_id,
    gr.receipt_number as transaction_number,
    gr.receipt_date as transaction_date,
    p.first_name || ' ' || p.last_name as partner_name,
    p.partner_type,
    gr.link_type,
    gr.sales_order_id,
    gr.job_work_id,
    gr.other_reference,
    COUNT(gri.id) as items_count,
    SUM(gri.quantity_received) as total_quantity,
    gr.invoice_amount,
    gr.created_by as created_by_user_id,
    gr.created_at,
    'IN' as direction
FROM goods_receipts gr
JOIN warehouses w ON gr.warehouse_id = w.id
LEFT JOIN partners p ON gr.issued_by_partner_id = p.id
LEFT JOIN goods_receipt_items gri ON gr.id = gri.receipt_id
WHERE gr.deleted_at IS NULL
GROUP BY gr.company_id, gr.warehouse_id, w.name, gr.id, gr.receipt_number, 
         gr.receipt_date, p.first_name, p.last_name, p.partner_type,
         gr.link_type, gr.sales_order_id, gr.job_work_id, gr.other_reference,
         gr.invoice_amount, gr.created_by, gr.created_at

UNION ALL

-- Goods Dispatches (Outward movement)
SELECT 
    'DISPATCH' as movement_type,
    gd.company_id,
    gd.warehouse_id,
    w.name as warehouse_name,
    gd.id as transaction_id,
    gd.dispatch_number as transaction_number,
    gd.dispatch_date as transaction_date,
    COALESCE(p.first_name || ' ' || p.last_name, wh.name) as partner_name,
    COALESCE(p.partner_type, 'Warehouse') as partner_type,
    gd.link_type,
    gd.sales_order_id,
    gd.job_work_id,
    gd.other_reference,
    COUNT(gdi.id) as items_count,
    COUNT(gdi.stock_unit_id) as total_quantity, -- Each dispatch item is one stock unit
    gd.invoice_amount,
    gd.created_by as created_by_user_id,
    gd.created_at,
    'OUT' as direction
FROM goods_dispatches gd
JOIN warehouses w ON gd.warehouse_id = w.id
LEFT JOIN partners p ON gd.dispatch_to_partner_id = p.id
LEFT JOIN warehouses wh ON gd.dispatch_to_warehouse_id = wh.id
LEFT JOIN goods_dispatch_items gdi ON gd.id = gdi.dispatch_id
WHERE gd.deleted_at IS NULL AND gd.is_cancelled = false
GROUP BY gd.company_id, gd.warehouse_id, w.name, gd.id, gd.dispatch_number,
         gd.dispatch_date, p.first_name, p.last_name, p.partner_type, wh.name,
         gd.link_type, gd.sales_order_id, gd.job_work_id, gd.other_reference,
         gd.invoice_amount, gd.created_by, gd.created_at

ORDER BY transaction_date DESC, created_at DESC;

-- =====================================================
-- COMPANY PERFORMANCE METRICS VIEW
-- =====================================================

CREATE VIEW company_performance_metrics AS
SELECT 
    c.id as company_id,
    c.name as company_name,
    
    -- Basic counts
    COUNT(DISTINCT w.id) as total_warehouses,
    COUNT(DISTINCT u.id) as total_users,
    COUNT(DISTINCT p.id) as total_partners,
    COUNT(DISTINCT prod.id) as total_products,
    COUNT(DISTINCT su.id) as total_stock_units,
    
    -- Sales performance (last 30 days)
    COUNT(DISTINCT CASE 
        WHEN so.order_date >= CURRENT_DATE - INTERVAL '30 days'
        THEN so.id 
    END) as sales_orders_last_30_days,
    
    COALESCE(SUM(CASE 
        WHEN so.order_date >= CURRENT_DATE - INTERVAL '30 days'
        THEN so.total_amount 
    END), 0) as sales_value_last_30_days,
    
    -- Operational activity (last 30 days)
    COUNT(DISTINCT CASE 
        WHEN gr.receipt_date >= CURRENT_DATE - INTERVAL '30 days'
        THEN gr.id 
    END) as receipts_last_30_days,
    
    COUNT(DISTINCT CASE 
        WHEN gd.dispatch_date >= CURRENT_DATE - INTERVAL '30 days' AND gd.is_cancelled = false
        THEN gd.id 
    END) as dispatches_last_30_days,
    
    COUNT(DISTINCT CASE 
        WHEN jw.start_date >= CURRENT_DATE - INTERVAL '30 days'
        THEN jw.id 
    END) as job_works_last_30_days,
    
    -- Current status
    COUNT(DISTINCT CASE WHEN so.status IN ('approval_pending', 'in_progress') THEN so.id END) as pending_orders,
    COUNT(DISTINCT CASE WHEN jw.status = 'in_progress' THEN jw.id END) as active_job_works,
    
    -- Catalog status
    CASE WHEN cc.accepting_orders = true THEN 'Active' ELSE 'Inactive' END as catalog_status,
    cc.domain_slug,
    
    -- Recent activity
    GREATEST(
        MAX(so.updated_at),
        MAX(gr.updated_at),
        MAX(gd.updated_at),
        MAX(jw.updated_at),
        MAX(su.updated_at)
    ) as last_activity_at

FROM companies c
LEFT JOIN warehouses w ON c.id = w.company_id AND w.deleted_at IS NULL
LEFT JOIN users u ON c.id = u.company_id AND u.deleted_at IS NULL
LEFT JOIN partners p ON c.id = p.company_id AND p.deleted_at IS NULL
LEFT JOIN products prod ON c.id = prod.company_id AND prod.deleted_at IS NULL
LEFT JOIN stock_units su ON c.id = su.company_id AND su.deleted_at IS NULL
LEFT JOIN sales_orders so ON c.id = so.company_id AND so.deleted_at IS NULL
LEFT JOIN goods_receipts gr ON c.id = gr.company_id AND gr.deleted_at IS NULL
LEFT JOIN goods_dispatches gd ON c.id = gd.company_id AND gd.deleted_at IS NULL
LEFT JOIN job_works jw ON c.id = jw.company_id AND jw.deleted_at IS NULL
LEFT JOIN catalog_configurations cc ON c.id = cc.company_id
WHERE c.deleted_at IS NULL
GROUP BY c.id, c.name, cc.accepting_orders, cc.domain_slug;

-- =====================================================
-- GRANT VIEW PERMISSIONS
-- =====================================================

-- Grant view permissions to authenticated users
GRANT SELECT ON comprehensive_order_fulfillment TO authenticated;
GRANT SELECT ON warehouse_activity_dashboard TO authenticated;
GRANT SELECT ON partner_transaction_summary TO authenticated;
GRANT SELECT ON inventory_movement_audit_trail TO authenticated;
GRANT SELECT ON company_performance_metrics TO authenticated;