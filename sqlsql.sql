SELECT
    r.rolname AS role_name,
    current_database() AS database_name,
    'DATABASE' AS object_type,
    n.nspname || '.' || p.proname AS object_name,
    'FUNCTION' AS privilege_type,
    'FUNCTION OWNER' AS privilege_name,
    r.rolcanlogin AS can_login
FROM
    pg_proc p
JOIN
    pg_namespace n ON p.pronamespace = n.oid
JOIN
    pg_roles r ON r.oid = p.proowner;
