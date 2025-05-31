-- PostgreSQL Initialization Script for DFIR IRIS

-- Create the main database if it doesn't exist
-- This is typically handled by the POSTGRES_DB environment variable

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS iris;
CREATE SCHEMA IF NOT EXISTS velociraptor;

-- Set search path
ALTER DATABASE iris_db SET search_path TO iris, public;

-- Create iris user permissions
GRANT ALL PRIVILEGES ON SCHEMA iris TO iris;
GRANT ALL PRIVILEGES ON SCHEMA velociraptor TO iris;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA iris TO iris;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA iris TO iris;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA iris TO iris;

-- Create tables for Velociraptor integration
CREATE TABLE IF NOT EXISTS velociraptor.clients (
    client_id VARCHAR(255) PRIMARY KEY,
    hostname VARCHAR(255),
    os_info JSONB,
    first_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    labels TEXT[],
    status VARCHAR(50) DEFAULT 'online',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS velociraptor.hunts (
    hunt_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    creator VARCHAR(255),
    artifact_sources TEXT[],
    state VARCHAR(50) DEFAULT 'RUNNING',
    created_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires TIMESTAMP WITH TIME ZONE,
    client_count INTEGER DEFAULT 0,
    completed_clients INTEGER DEFAULT 0,
    stats JSONB
);

CREATE TABLE IF NOT EXISTS velociraptor.flows (
    flow_id VARCHAR(255) PRIMARY KEY,
    client_id VARCHAR(255) REFERENCES velociraptor.clients(client_id),
    session_id VARCHAR(255),
    flow_name VARCHAR(255),
    artifact_name VARCHAR(255),
    state VARCHAR(50) DEFAULT 'RUNNING',
    create_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_requests INTEGER DEFAULT 0,
    outstanding_requests INTEGER DEFAULT 0,
    artifacts_with_results TEXT[],
    total_uploaded_files INTEGER DEFAULT 0,
    total_expected_uploaded_bytes BIGINT DEFAULT 0,
    total_uploaded_bytes BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS velociraptor.artifacts (
    artifact_id SERIAL PRIMARY KEY,
    flow_id VARCHAR(255) REFERENCES velociraptor.flows(flow_id),
    artifact_name VARCHAR(255),
    artifact_path VARCHAR(500),
    collected_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    row_data JSONB,
    file_path VARCHAR(500),
    file_size BIGINT,
    file_hash VARCHAR(255)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_clients_hostname ON velociraptor.clients(hostname);
CREATE INDEX IF NOT EXISTS idx_clients_last_seen ON velociraptor.clients(last_seen);
CREATE INDEX IF NOT EXISTS idx_clients_status ON velociraptor.clients(status);
CREATE INDEX IF NOT EXISTS idx_hunts_state ON velociraptor.hunts(state);
CREATE INDEX IF NOT EXISTS idx_hunts_created_time ON velociraptor.hunts(created_time);
CREATE INDEX IF NOT EXISTS idx_flows_client_id ON velociraptor.flows(client_id);
CREATE INDEX IF NOT EXISTS idx_flows_state ON velociraptor.flows(state);
CREATE INDEX IF NOT EXISTS idx_artifacts_flow_id ON velociraptor.artifacts(flow_id);
CREATE INDEX IF NOT EXISTS idx_artifacts_collected_time ON velociraptor.artifacts(collected_time);

-- Create functions for automatic timestamps
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamps
CREATE TRIGGER set_timestamp_clients
    BEFORE UPDATE ON velociraptor.clients
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_set_timestamp();

-- Insert initial data
INSERT INTO velociraptor.clients (client_id, hostname, os_info, labels, status) 
VALUES (
    'C.local_test_client', 
    'test-client', 
    '{"platform": "linux", "release": "Ubuntu 20.04"}',
    ARRAY['test', 'local'],
    'online'
) ON CONFLICT (client_id) DO NOTHING;

-- Grant permissions on new tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA velociraptor TO iris;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA velociraptor TO iris;