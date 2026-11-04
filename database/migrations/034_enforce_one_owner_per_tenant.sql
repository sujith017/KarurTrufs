BEGIN;

-- Remove the old OWNER / MANAGER role restriction
ALTER TABLE tenant_memberships
DROP CONSTRAINT tenant_memberships_role_check;

-- Only business owners can have tenant-level memberships
ALTER TABLE tenant_memberships
ADD CONSTRAINT tenant_memberships_owner_only
CHECK (role = 'OWNER');

-- Allow only one owner per business
CREATE UNIQUE INDEX one_owner_per_tenant
ON tenant_memberships (tenant_id)
WHERE role = 'OWNER';

COMMIT;