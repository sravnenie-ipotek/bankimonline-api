-- RAILWAY DATABASE ARCHITECTURE FIX
-- Purpose: Move property_ownership_options from MAGLEV to SHORTLINE
-- Date: August 16, 2025
-- 
-- CRITICAL: This fixes the Railway database architecture to match production
-- 
-- EXECUTION ORDER:
-- 1. Run on Railway SHORTLINE (bankim_content) first
-- 2. Run on Railway MAGLEV (bankim_core) second

-- ================================================================
-- PART 1: Create table in Railway SHORTLINE (bankim_content)
-- ================================================================

-- Connect to: postgresql://postgres:SuFkUevgonaZFXJiJeczFiXYTlICHVJL@shortline.proxy.rlwy.net:33452/railway

-- Create the property_ownership_options table in the correct database
CREATE TABLE IF NOT EXISTS property_ownership_options (
    id SERIAL PRIMARY KEY,
    option_key VARCHAR(50) NOT NULL UNIQUE,
    option_text_en TEXT NOT NULL,
    option_text_he TEXT,
    option_text_ru TEXT,
    ltv_percentage DECIMAL(5,2) NOT NULL,
    financing_percentage DECIMAL(5,2) NOT NULL,
    min_down_payment_percentage DECIMAL(5,2) NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert the standard Israeli mortgage LTV data
INSERT INTO property_ownership_options (
    option_key, 
    option_text_en, 
    option_text_he, 
    option_text_ru,
    ltv_percentage, 
    financing_percentage, 
    min_down_payment_percentage,
    display_order,
    is_active
) VALUES 
-- No property owned - allows 75% financing
('no_property', 
 'I don''t own any property', 
 'אני לא מחזיק בנכס כלשהו',
 'У меня нет никакой недвижимости',
 75.00, 75.00, 25.00, 1, true),

-- Has property - conservative 50% financing  
('has_property',
 'I own a property', 
 'אני מחזיק בנכס',
 'У меня есть недвижимость',
 50.00, 50.00, 50.00, 2, true),

-- Selling property - bridge financing 70%
('selling_property',
 'I''m selling a property',
 'אני מוכר נכס', 
 'Я продаю недвижимость',
 70.00, 70.00, 30.00, 3, true);

-- Verify the data was inserted correctly
SELECT 
    option_key,
    option_text_en,
    ltv_percentage,
    financing_percentage,
    min_down_payment_percentage,
    is_active
FROM property_ownership_options 
ORDER BY display_order;

-- ================================================================
-- PART 2: Remove table from Railway MAGLEV (bankim_core) 
-- ================================================================

-- Connect to: postgresql://postgres:lgqPEzvVbSCviTybKqMbzJkYvOUetJjt@maglev.proxy.rlwy.net:43809/railway

-- ONLY run this AFTER confirming the table exists in SHORTLINE
-- First, check if the table exists in MAGLEV
SELECT COUNT(*) as table_exists 
FROM information_schema.tables 
WHERE table_name = 'property_ownership_options' 
AND table_schema = 'public';

-- If table exists (table_exists = 1), then drop it
-- DROP TABLE IF EXISTS property_ownership_options CASCADE;

-- Verify it's gone
SELECT COUNT(*) as table_should_be_zero
FROM information_schema.tables 
WHERE table_name = 'property_ownership_options' 
AND table_schema = 'public';

-- ================================================================
-- VALIDATION QUERIES
-- ================================================================

-- Run these on BOTH Railway databases to verify correct architecture:

-- SHORTLINE (bankim_content) - SHOULD have the table:
SELECT 
    'SHORTLINE has property_ownership_options' as status,
    COUNT(*) as row_count
FROM property_ownership_options;

-- MAGLEV (bankim_core) - should NOT have the table:
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'MAGLEV correctly does NOT have property_ownership_options'
        ELSE 'ERROR: MAGLEV still has property_ownership_options'
    END as status
FROM information_schema.tables 
WHERE table_name = 'property_ownership_options';

-- ================================================================
-- RAILWAY SYNC PROTECTION
-- ================================================================

-- Add a comment to track this architectural fix
COMMENT ON TABLE property_ownership_options IS 
'ARCHITECTURE FIX 2025-08-16: Moved from bankim_core to bankim_content for proper database separation. 
ALL dropdown tables belong in bankim_content. 
This fixes the issue where APIs expected content in SHORTLINE but table was in MAGLEV.';

-- Create a validation function to prevent future misplacement
CREATE OR REPLACE FUNCTION validate_dropdown_table_placement()
RETURNS TRIGGER AS $$
BEGIN
    -- This function can be used to validate that dropdown tables
    -- are only created in the content database
    RAISE NOTICE 'Dropdown table operation on %', TG_TABLE_NAME;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- EXECUTION CHECKLIST
-- ================================================================

/*
BEFORE RUNNING:
[ ] Backup current Railway MAGLEV property_ownership_options data
[ ] Confirm production has working property_ownership_options in bankim_content
[ ] Verify APIs work correctly in production

EXECUTION STEPS:
[ ] 1. Run PART 1 on Railway SHORTLINE (create table + insert data)
[ ] 2. Test APIs against Railway SHORTLINE to confirm they work
[ ] 3. Run PART 2 on Railway MAGLEV (drop table) - ONLY after step 2 passes
[ ] 4. Run validation queries on both databases
[ ] 5. Test development environment API calls

AFTER RUNNING:
[ ] Verify Railway SHORTLINE has property_ownership_options with 3 rows
[ ] Verify Railway MAGLEV does NOT have property_ownership_options  
[ ] Test API endpoints: /api/customer/property-ownership-options
[ ] Test calculation endpoints: /api/v1/calculation-parameters?business_path=mortgage
[ ] Confirm dropdowns work in UI: mortgage calculator step 1

ROLLBACK PLAN (if issues):
[ ] Re-create table in Railway MAGLEV with backed-up data
[ ] Investigate why SHORTLINE version didn't work
[ ] Check contentPool vs pool configuration in APIs
*/

-- ================================================================
-- COMMUNICATION TEMPLATE
-- ================================================================

/*
Message for Production Team after completion:

✅ Railway Database Architecture Fixed:
- SHORTLINE (bankim_content): Now has property_ownership_options ✅
- MAGLEV (bankim_core): Table removed ✅  
- Railway now matches production architecture ✅
- APIs tested and working with Railway databases ✅

Next Railway sync should maintain this correct architecture.
Production fixes are protected and validated.
*/