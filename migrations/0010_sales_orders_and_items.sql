-- Bale Backend - Sales Order Management
-- Customer order management with real-time fulfillment tracking

-- =====================================================
-- SALES ORDERS TABLE
-- =====================================================

CREATE TABLE sales_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Order identification
    order_number VARCHAR(50) NOT NULL,
    
    -- Customer information
    customer_id UUID NOT NULL REFERENCES partners(id),
    agent_id UUID REFERENCES partners(id),
    
    -- Order details
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE, -- Optional, can be set later during order processing
    fulfillment_warehouse_id UUID REFERENCES warehouses(id),
    
    -- Financial
    advance_amount DECIMAL(10,2) DEFAULT 0,
    discount_percentage DECIMAL(5,2) DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100), -- Percentage value (0-100)
    total_amount DECIMAL(10,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'approval_pending' 
        CHECK (status IN ('approval_pending', 'in_progress', 'completed', 'cancelled')),
    
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
    
    UNIQUE(company_id, order_number)
);

-- =====================================================
-- SALES ORDER LINE ITEMS
-- =====================================================

CREATE TABLE sales_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    sales_order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    -- Quantities
    required_quantity DECIMAL(10,3) NOT NULL,
    dispatched_quantity DECIMAL(10,3) DEFAULT 0,
    pending_quantity DECIMAL(10,3) GENERATED ALWAYS AS (required_quantity - dispatched_quantity) STORED,
    
    -- Pricing
    unit_rate DECIMAL(10,2),
    line_total DECIMAL(10,2) GENERATED ALWAYS AS (required_quantity * COALESCE(unit_rate, 0)) STORED,
    
    notes TEXT,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Sales Orders indexes
CREATE INDEX idx_sales_orders_company_id ON sales_orders(company_id);
CREATE INDEX idx_sales_orders_customer ON sales_orders(company_id, customer_id);
CREATE INDEX idx_sales_orders_status ON sales_orders(company_id, status);
CREATE INDEX idx_sales_orders_date ON sales_orders(company_id, order_date);
CREATE INDEX idx_sales_orders_warehouse ON sales_orders(fulfillment_warehouse_id);
CREATE INDEX idx_sales_orders_order_number ON sales_orders(company_id, order_number);

-- Sales Order Items indexes
CREATE INDEX idx_sales_order_items_company_id ON sales_order_items(company_id);
CREATE INDEX idx_sales_order_items_sales_order ON sales_order_items(sales_order_id);
CREATE INDEX idx_sales_order_items_product ON sales_order_items(product_id);

-- =====================================================
-- SALES ORDER STATUS VIEW
-- =====================================================

CREATE VIEW sales_order_status AS
SELECT 
    so.company_id,
    so.id as sales_order_id,
    so.order_number,
    so.status,
    so.order_date,
    so.expected_delivery_date,
    p.first_name || ' ' || p.last_name as customer_name,
    p.company_name as customer_company,
    so.total_amount,
    COUNT(soi.id) as total_items,
    COALESCE(SUM(soi.required_quantity), 0) as total_required_qty,
    COALESCE(SUM(soi.dispatched_quantity), 0) as total_dispatched_qty,
    COALESCE(SUM(soi.pending_quantity), 0) as total_pending_qty,
    CASE 
        WHEN COALESCE(SUM(soi.required_quantity), 0) = 0 THEN 0
        ELSE ROUND((COALESCE(SUM(soi.dispatched_quantity), 0) / COALESCE(SUM(soi.required_quantity), 1)) * 100, 2)
    END as completion_percentage
FROM sales_orders so
JOIN partners p ON so.customer_id = p.id
LEFT JOIN sales_order_items soi ON so.id = soi.sales_order_id
WHERE so.deleted_at IS NULL
GROUP BY so.company_id, so.id, so.order_number, so.status, so.order_date, so.expected_delivery_date, 
         p.first_name, p.last_name, p.company_name, so.total_amount;

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_sales_orders_updated_at 
    BEFORE UPDATE ON sales_orders 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sales_order_items_updated_at 
    BEFORE UPDATE ON sales_order_items 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-generate order numbers
CREATE OR REPLACE FUNCTION auto_generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
        NEW.order_number := generate_sequence_number('SO', 'sales_orders', NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_order_number
    BEFORE INSERT ON sales_orders
    FOR EACH ROW EXECUTE FUNCTION auto_generate_order_number();

-- Auto-populate unit rate from product master
CREATE OR REPLACE FUNCTION auto_populate_unit_rate()
RETURNS TRIGGER AS $$
BEGIN
    -- Only auto-populate unit_rate if not provided or is zero
    -- This allows users to override with custom rates
    IF NEW.unit_rate IS NULL OR NEW.unit_rate = 0 THEN
        -- Fetch selling price from product master
        SELECT selling_price_per_unit 
        INTO NEW.unit_rate
        FROM products 
        WHERE id = NEW.product_id;
        
        -- If product has no selling price, leave unit_rate as provided
        NEW.unit_rate := COALESCE(NEW.unit_rate, 0);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_populate_unit_rate
    BEFORE INSERT OR UPDATE ON sales_order_items
    FOR EACH ROW EXECUTE FUNCTION auto_populate_unit_rate();

-- Update sales order total when line items change
CREATE OR REPLACE FUNCTION update_sales_order_total()
RETURNS TRIGGER AS $$
DECLARE
    order_id UUID;
    subtotal DECIMAL(10,2);
    discount_pct DECIMAL(5,2);
    final_total DECIMAL(10,2);
BEGIN
    -- Get the sales order ID from the affected row
    order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);
    
    -- Calculate subtotal from all line items
    SELECT COALESCE(SUM(line_total), 0) 
    INTO subtotal
    FROM sales_order_items 
    WHERE sales_order_id = order_id;
    
    -- Get discount percentage from sales order
    SELECT discount_percentage 
    INTO discount_pct
    FROM sales_orders 
    WHERE id = order_id;
    
    -- Calculate final total with discount applied
    final_total := subtotal * (1 - (COALESCE(discount_pct, 0) / 100));
    
    -- Update the sales order total
    UPDATE sales_orders 
    SET total_amount = final_total
    WHERE id = order_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_sales_order_total
    AFTER INSERT OR UPDATE OR DELETE ON sales_order_items
    FOR EACH ROW EXECUTE FUNCTION update_sales_order_total();

-- Update sales order total when discount percentage changes
CREATE OR REPLACE FUNCTION update_sales_order_total_on_discount()
RETURNS TRIGGER AS $$
DECLARE
    subtotal DECIMAL(10,2);
    final_total DECIMAL(10,2);
BEGIN
    -- Only recalculate if discount_percentage changed
    IF OLD.discount_percentage IS DISTINCT FROM NEW.discount_percentage THEN
        -- Calculate subtotal from all line items
        SELECT COALESCE(SUM(line_total), 0) 
        INTO subtotal
        FROM sales_order_items 
        WHERE sales_order_id = NEW.id;
        
        -- Calculate final total with new discount applied
        final_total := subtotal * (1 - (COALESCE(NEW.discount_percentage, 0) / 100));
        
        -- Update the total amount
        NEW.total_amount := final_total;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_sales_order_total_on_discount
    BEFORE UPDATE ON sales_orders
    FOR EACH ROW EXECUTE FUNCTION update_sales_order_total_on_discount();

-- Prevent reducing required quantity below dispatched quantity
CREATE OR REPLACE FUNCTION validate_required_quantity()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if required_quantity is being reduced below dispatched_quantity
    IF NEW.required_quantity < NEW.dispatched_quantity THEN
        RAISE EXCEPTION 'Cannot reduce required quantity (%) below dispatched quantity (%). Please cancel existing dispatches first.',
            NEW.required_quantity, NEW.dispatched_quantity
            USING HINT = 'To reduce quantity: 1) Cancel existing dispatches, 2) Update required quantity, 3) Create new dispatches if needed',
                  ERRCODE = 'check_violation';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_required_quantity
    BEFORE UPDATE ON sales_order_items
    FOR EACH ROW EXECUTE FUNCTION validate_required_quantity();

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure sales orders belong to a company
ALTER TABLE sales_orders ADD CONSTRAINT check_sales_order_company_not_null 
    CHECK (company_id IS NOT NULL);