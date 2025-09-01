-- Bale Backend - Job Works RLS Policies
-- Security policies for job works management

-- =====================================================
-- ENABLE RLS ON JOB WORK TABLES
-- =====================================================

ALTER TABLE job_works ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_work_raw_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_work_finished_goods ENABLE ROW LEVEL SECURITY;

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
-- JOB WORK RAW MATERIALS RLS POLICIES
-- =====================================================

-- Users can view job work raw materials if they can view the parent job work
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

-- Users can manage job work raw materials if they can manage the parent job work
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

-- =====================================================
-- JOB WORK FINISHED GOODS RLS POLICIES
-- =====================================================

-- Users can view job work finished goods if they can view the parent job work
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

-- Users can manage job work finished goods if they can manage the parent job work
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
-- GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON job_works TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON job_work_raw_materials TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON job_work_finished_goods TO authenticated;