-- Bootstrap script run once on a fresh data volume by postgres entrypoint.
-- Creates an empty test database alongside the main one.
SELECT 'CREATE DATABASE andiamo_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'andiamo_test')\gexec
