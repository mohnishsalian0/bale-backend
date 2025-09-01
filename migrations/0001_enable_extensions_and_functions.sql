-- Bale Backend - Extensions and Core Functions
-- Enable required extensions and create utility functions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- UTILITY FUNCTIONS FOR AUTO-GENERATION
-- =====================================================

-- Function to update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-generate sequence numbers  
CREATE OR REPLACE FUNCTION generate_sequence_number(prefix TEXT, table_name TEXT, company_uuid UUID)
RETURNS TEXT AS $$
DECLARE
    next_seq INTEGER;
    result TEXT;
    column_name TEXT;
BEGIN
    -- Get the appropriate column name based on table
    column_name := CASE 
        WHEN table_name = 'products' THEN 'product_number'
        WHEN table_name = 'sales_orders' THEN 'order_number'
        WHEN table_name = 'job_works' THEN 'job_number'
        WHEN table_name = 'goods_dispatches' THEN 'dispatch_number'
        WHEN table_name = 'goods_receipts' THEN 'receipt_number'
        WHEN table_name = 'stock_units' THEN 'unit_number'
        ELSE 'number'
    END;
    
    -- Get next sequence number for this company and table
    EXECUTE format('SELECT COALESCE(MAX(CAST(SUBSTRING(%I FROM ''^%s-(\d+)$'') AS INTEGER)), 0) + 1 FROM %I WHERE company_id = $1', 
                   column_name, prefix, table_name)
    INTO next_seq
    USING company_uuid;
    
    result := prefix || '-' || LPAD(next_seq::TEXT, 6, '0');
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- HELPER FUNCTIONS FOR AUTO-SUGGESTIONS
-- =====================================================

-- Function to get tag suggestions for products
CREATE OR REPLACE FUNCTION get_tag_suggestions(
    search_term TEXT DEFAULT '',
    company_id_param UUID DEFAULT NULL
)
RETURNS TABLE(tag TEXT, usage_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        unnest(tags) as tag,
        COUNT(*) as usage_count
    FROM products 
    WHERE company_id = COALESCE(company_id_param, (SELECT company_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
        AND tags IS NOT NULL 
        AND array_length(tags, 1) > 0
        AND (search_term = '' OR unnest(tags) ILIKE search_term || '%')
    GROUP BY unnest(tags)
    ORDER BY usage_count DESC, tag ASC
    LIMIT 10;
$$;

-- Function to get quality grade suggestions from stock units
CREATE OR REPLACE FUNCTION get_quality_grade_suggestions(
    search_term TEXT DEFAULT '',
    company_id_param UUID DEFAULT NULL
)
RETURNS TABLE(quality_grade TEXT, usage_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        su.quality_grade,
        COUNT(*) as usage_count
    FROM stock_units su
    JOIN products p ON su.product_id = p.id
    WHERE p.company_id = COALESCE(company_id_param, (SELECT company_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
        AND su.quality_grade IS NOT NULL 
        AND su.quality_grade != ''
        AND (search_term = '' OR su.quality_grade ILIKE search_term || '%')
    GROUP BY su.quality_grade
    ORDER BY usage_count DESC, su.quality_grade ASC
    LIMIT 10;
$$;

-- Function to get job type suggestions from job works
CREATE OR REPLACE FUNCTION get_job_type_suggestions(
    search_term TEXT DEFAULT '',
    company_id_param UUID DEFAULT NULL
)
RETURNS TABLE(job_type TEXT, usage_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        jw.job_type,
        COUNT(*) as usage_count
    FROM job_works jw
    WHERE jw.company_id = COALESCE(company_id_param, (SELECT company_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
        AND jw.job_type IS NOT NULL 
        AND jw.job_type != ''
        AND (search_term = '' OR jw.job_type ILIKE search_term || '%')
        AND jw.deleted_at IS NULL
    GROUP BY jw.job_type
    ORDER BY usage_count DESC, jw.job_type ASC
    LIMIT 10;
$$;