CREATE DATABASE IF NOT EXISTS catalog_sync_db;
USE catalog_sync_db;

CREATE TABLE IF NOT EXISTS product_master (
    erp_code VARCHAR(50) PRIMARY KEY,
    product_name VARCHAR(255),
    description TEXT,
    family VARCHAR(50),
    uom VARCHAR(20),
    status VARCHAR(20),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_price (
    erp_code VARCHAR(50) PRIMARY KEY,
    unit_price DECIMAL(12,2),
    currency VARCHAR(10) DEFAULT 'INR',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (erp_code) REFERENCES product_master(erp_code)
);

CREATE TABLE IF NOT EXISTS sync_run (
    run_id VARCHAR(50) PRIMARY KEY,
    trigger_type VARCHAR(30),
    requested_by VARCHAR(100),
    scope VARCHAR(20),
    watermark_from TIMESTAMP NULL,
    watermark_to TIMESTAMP NULL,
    records_read INT DEFAULT 0,
    created_count INT DEFAULT 0,
    updated_count INT DEFAULT 0,
    deactivated_count INT DEFAULT 0,
    retried_count INT DEFAULT 0,
    failed_count INT DEFAULT 0,
    run_status VARCHAR(30),
    rejects_file VARCHAR(255),
    sf_case_number VARCHAR(50),
    email_status VARCHAR(50),
    correlation_id VARCHAR(100),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS product_sync_log (
    log_seq BIGINT AUTO_INCREMENT PRIMARY KEY,
    run_id VARCHAR(50),
    erp_code VARCHAR(50),
    operation VARCHAR(50),
    salesforce_id VARCHAR(50),
    pricebook_entry_id VARCHAR(50),
    record_status VARCHAR(30),
    error_code VARCHAR(50),
    error_message TEXT,
    retry_count INT DEFAULT 0,
    correlation_id VARCHAR(100),
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_run_product UNIQUE (run_id, erp_code, operation),
    FOREIGN KEY (run_id) REFERENCES sync_run(run_id)
);
