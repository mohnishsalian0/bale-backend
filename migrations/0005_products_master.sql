-- Bale Backend - Products Master Catalog
-- Central product catalog with fabric-specific attributes

-- =====================================================
-- PRODUCTS MASTER TABLE
-- =====================================================

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Identity
    product_number VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    show_on_catalog BOOLEAN DEFAULT TRUE,
    
    -- Fabric specifications
    material VARCHAR(50) CHECK (material IN (
        -- Natural Fibers
        'Cotton', 'Silk', 'Wool', 'Linen', 'Jute', 'Hemp', 'Cashmere', 'Mohair', 'Alpaca',
        -- Synthetic Fibers  
        'Polyester', 'Nylon', 'Acrylic', 'Spandex', 'Lycra', 'Rayon', 'Viscose', 'Modal',
        -- Semi-Synthetic
        'Bamboo', 'Tencel', 'Cupro',
        -- Specialty/Technical
        'Microfiber', 'Fleece', 'Denim', 'Canvas', 'Twill', 'Satin', 'Chiffon', 'Georgette', 
        'Organza', 'Taffeta', 'Velvet', 'Corduroy', 'Jacquard', 'Brocade',
        -- Blends & Custom
        'Cotton-Polyester', 'Cotton-Spandex', 'Cotton-Linen', 'Poly-Cotton', 'Wool-Silk', 
        'Silk-Cotton', 'Blend', 'Custom'
    )),
    color VARCHAR(50),
    color_hex VARCHAR(7), -- RGB hex code
    gsm INTEGER CHECK (gsm BETWEEN 50 AND 500),
    thread_count_cm INTEGER,
    tags TEXT[], -- Array for categorization
    
    -- Stock information
    measuring_unit VARCHAR(20) NOT NULL CHECK (measuring_unit IN ('Meters', 'Yards', 'Kg', 'Pieces')),
    cost_price_per_unit DECIMAL(10,2),
    selling_price_per_unit DECIMAL(10,2),
    min_stock_alert BOOLEAN DEFAULT FALSE,
    min_stock_threshold INTEGER DEFAULT 0,
    
    -- Additional information
    hsn_code VARCHAR(20),
    notes TEXT,
    product_images TEXT[], -- Array of image URLs
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(company_id, product_number)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Multi-tenant index
CREATE INDEX idx_products_company_id ON products(company_id);

-- Product number lookup within company
CREATE INDEX idx_products_product_number ON products(company_id, product_number);

-- Product name search
CREATE INDEX idx_products_name ON products(company_id, name);

-- Material and color filtering
CREATE INDEX idx_products_material ON products(company_id, material);
CREATE INDEX idx_products_color ON products(company_id, color);

-- Catalog visibility
CREATE INDEX idx_products_catalog_visibility ON products(company_id, show_on_catalog);

-- Tag-based search (GIN index for arrays)
CREATE INDEX idx_products_tags ON products USING GIN(tags);

-- Price range queries
CREATE INDEX idx_products_selling_price ON products(company_id, selling_price_per_unit);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON products 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-generate product numbers
CREATE OR REPLACE FUNCTION auto_generate_product_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.product_number IS NULL OR NEW.product_number = '' THEN
        NEW.product_number := generate_sequence_number('PROD', 'products', NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_product_number
    BEFORE INSERT ON products
    FOR EACH ROW EXECUTE FUNCTION auto_generate_product_number();

-- =====================================================
-- SECURITY CONSTRAINTS
-- =====================================================

-- Ensure products belong to a company
ALTER TABLE products ADD CONSTRAINT check_product_company_not_null 
    CHECK (company_id IS NOT NULL);