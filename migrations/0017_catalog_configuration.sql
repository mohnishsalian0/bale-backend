-- Bale Backend - Catalog Configuration System
-- Public sales catalog with branding and product organization

-- =====================================================
-- CATALOG CONFIGURATION TABLE
-- =====================================================

CREATE TABLE catalog_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Branding
    catalog_name VARCHAR(100),
    logo_url TEXT,
    primary_color VARCHAR(7), -- Hex color
    secondary_color VARCHAR(7),
    font_family VARCHAR(50),
    favicon_url TEXT,
    
    -- Product display configuration
    show_fields JSONB, -- Which product fields to show
    filter_options JSONB, -- Available filter options
    sort_options JSONB, -- Available sort options
    
    -- Legal pages
    terms_conditions TEXT,
    return_policy TEXT,
    privacy_policy TEXT,
    
    -- Contact information
    contact_phone VARCHAR(15),
    contact_email VARCHAR(100),
    contact_address TEXT,
    
    -- Public settings
    accepting_orders BOOLEAN DEFAULT FALSE,
    domain_slug VARCHAR(50) UNIQUE,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES users(id),
    modified_by UUID REFERENCES users(id),
    
    UNIQUE(company_id)
);

-- =====================================================
-- PRODUCT VARIANTS/GROUPS FOR CATALOG
-- =====================================================

CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    variant_name VARCHAR(100) NOT NULL, -- e.g., "Cotton Solids", "Embroidered Collection"
    variant_type VARCHAR(50), -- e.g., "Color", "Material", "Custom"
    display_order INTEGER DEFAULT 0,
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- PRODUCT VARIANT ITEMS (products grouped into variants)
-- =====================================================

CREATE TABLE product_variant_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    variant_value VARCHAR(100) NOT NULL, -- e.g., "Red", "Blue", "Cotton"
    display_order INTEGER DEFAULT 0,
    
    UNIQUE(variant_id, product_id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Catalog Configuration indexes
CREATE INDEX idx_catalog_configurations_company_id ON catalog_configurations(company_id);
CREATE INDEX idx_catalog_configurations_domain_slug ON catalog_configurations(domain_slug);
CREATE INDEX idx_catalog_configurations_accepting_orders ON catalog_configurations(accepting_orders);

-- Product Variants indexes
CREATE INDEX idx_product_variants_company_id ON product_variants(company_id);
CREATE INDEX idx_product_variants_display_order ON product_variants(company_id, display_order);

-- Product Variant Items indexes
CREATE INDEX idx_product_variant_items_variant_id ON product_variant_items(variant_id);
CREATE INDEX idx_product_variant_items_product_id ON product_variant_items(product_id);
CREATE INDEX idx_product_variant_items_display_order ON product_variant_items(variant_id, display_order);

-- =====================================================
-- TRIGGERS FOR AUTO-UPDATES
-- =====================================================

-- Auto-update timestamps
CREATE TRIGGER update_catalog_configurations_updated_at 
    BEFORE UPDATE ON catalog_configurations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_variants_updated_at 
    BEFORE UPDATE ON product_variants 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-generate domain slug from company name with random number
CREATE OR REPLACE FUNCTION generate_domain_slug()
RETURNS TRIGGER AS $$
DECLARE
    base_slug TEXT;
    random_num INTEGER;
    final_slug TEXT;
BEGIN
    -- Generate base slug from company name
    base_slug := LOWER(TRIM(NEW.name));
    base_slug := REGEXP_REPLACE(base_slug, '[^a-z0-9\s-]', '', 'g'); -- Remove special chars
    base_slug := REGEXP_REPLACE(base_slug, '\s+', '-', 'g'); -- Replace spaces with hyphens
    base_slug := REGEXP_REPLACE(base_slug, '-+', '-', 'g'); -- Remove multiple hyphens
    base_slug := TRIM(base_slug, '-'); -- Remove leading/trailing hyphens
    
    -- Generate random 4-digit number (1000-9999)
    random_num := 1000 + (RANDOM() * 9000)::INTEGER;
    
    -- Combine base slug with random number
    final_slug := base_slug || '-' || random_num;
    
    -- Update catalog configuration with generated slug
    UPDATE catalog_configurations 
    SET domain_slug = final_slug 
    WHERE company_id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_domain_slug
    AFTER INSERT OR UPDATE OF name ON companies
    FOR EACH ROW EXECUTE FUNCTION generate_domain_slug();