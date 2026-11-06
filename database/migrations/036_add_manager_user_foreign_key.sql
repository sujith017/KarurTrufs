BEGIN;

ALTER TABLE venue_manager_assignments
ADD CONSTRAINT venue_manager_assignments_manager_user_fk
FOREIGN KEY (manager_user_id)
REFERENCES users(id)
ON DELETE RESTRICT;

COMMIT;