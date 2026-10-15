# CatalogPriceBookSync — MuleSoft Integration Project

Automated, API-Led catalog and price synchronization from MySQL ERP database to Salesforce Sales Cloud (`Product2` and `PricebookEntry`).

Designed for the Cognizant MuleSoft Hackathon.

---

## 1. Project Prerequisites

* **Operating System**: Windows 10/11 or Linux
* **Java Development Kit (JDK)**: Eclipse Adoptium JDK 17 (tested with `jdk-17.0.20.1+1`)
* **Anypoint Studio**: Version 7.18+ or 8.x
* **Mule Runtime**: Mule Enterprise Runtime 4.12.1 (minimum Mule 4.12.0)
* **Apache Maven**: Version 3.9+
* **Database**: MySQL 8.0+ running on `localhost:3306`
* **Salesforce**: Developer Edition or Sandbox org with Administrator / Standard User access with `Product2`, `Pricebook2`, `PricebookEntry`, and `Case` permissions.

---

## Clone and configure

```bash
git clone https://github.com/Koundinya1804/salesforce-catalog-sync.git
cd salesforce-catalog-sync
```

Copy `src/main/resources/config-example.yaml` to `config.yaml` and `secure-properties-example.yaml` to `secure-properties.yaml` in the same directory. The example encrypted values are placeholders for mocked tests; replace them with your own encrypted credentials before running live integrations. The development encryption key is configured in `salesforce.xml`; override it and regenerate encrypted values for your deployment.

The default MUnit suites mock external connections and do not send real emails or write Salesforce products. With JDK 17 and Maven configured, run `mvn test` to execute all 42 tests. Open `target/site/munit/coverage/summary.html` for coverage.

For cloud deployment, follow [CloudHub 2.0 setup](deployment/CLOUDHUB2.md) and [Aiven setup](deployment/AIVEN.md). GitHub stores the project source; the application runs in Mule or CloudHub.

## 2. Connectors & Module Versions

Configured in [`pom.xml`](pom.xml):
* `mule-http-connector`: 1.11.3
* `mule-sockets-connector`: 1.2.7
* `mule-db-connector`: 1.16.1
* `mysql-connector-j`: 8.0.33 (shared library)
* `mule-salesforce-connector`: 12.0.4
* `mule-apikit-module`: 1.12.0
* `mule-objectstore-connector`: 1.2.2
* `mule-file-connector`: 1.5.5
* `mule-vm-connector`: 2.0.1
* `mule-email-connector`: 1.8.0
* `munit-maven-plugin`: 3.7.3
* `munit-runner` / `munit-tools`: 3.7.3

---

## 3. Configuration & Secrets Management

* **Active Configuration**: [`src/main/resources/config.yaml`](src/main/resources/config.yaml)
* **Placeholder Template**: [`src/main/resources/config-example.yaml`](src/main/resources/config-example.yaml)
* **Security Notice**: Never commit live passwords, security tokens, or encryption keys to version control. Keep `.gitignore` active.

### Setting Up Secure Properties
To encrypt credentials using Mule Secure Properties Tool:
```powershell
java -jar secure-properties-tool.jar string encrypt Blowfish CBC "YourKey" "YourPassword"
```
Configure in XML using `<secure-properties:config key="${encryption.key}" file="config-secure.yaml" />`.

---

## 4. MySQL Database Setup

Ensure MySQL is running on `127.0.0.1:3306` with database `catalog_sync_db`:
```sql
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
```

---

## 5. Salesforce Setup

1. **Custom External ID Field**:
   * Object: `Product2`
   * Field Name: `ERP_Product_Code__c`
   * Type: `Text(50)`, Unique, External ID.
2. **Price Book Setup**:
   * Create standard Price Book and an active custom Price Book named `ERP Catalog Price Book`.
3. **Permissions**:
   * User requires Read/Write permissions on `Product2`, `Pricebook2`, `PricebookEntry`, and `Case`.

---

## 6. How to Run in Anypoint Studio

1. Open **Anypoint Studio**.
2. Go to **File $\rightarrow$ Import $\rightarrow$ Anypoint Studio $\rightarrow$ Anypoint Studio project from File System**.
3. Select root directory `.`.
4. Right-click the project $\rightarrow$ **Run As $\rightarrow$ Mule Application**.
5. Verify console logs indicate:
   ```
   **********************************************************************
   * Started app 'salesforce'                                           *
   **********************************************************************
   ```

---

## 7. How to Call the API in Postman

* **Base URL**: `http://localhost:8081/api`
* **APIKit Console**: `http://localhost:8081/console`

### Request 1: Trigger Catalog Synchronization
* **Method**: `POST`
* **URL**: `http://localhost:8081/api/catalog/sync`
* **Headers**:
  * `Content-Type`: `application/json`
  * `X-Correlation-ID`: `corr-postman-001`
* **Body** (Raw JSON):
```json
{
  "requestedBy": "tester@cognizant.com",
  "fullSync": false,
  "productCodes": ["PRD-AUT-140"]
}
```
* **Expected Response**: `HTTP 202 Accepted`
```json
{
  "runId": "RUN-20261013-100000",
  "triggerType": "MANUAL_API",
  "scope": "PARTIAL",
  "status": "RUNNING",
  "correlationId": "corr-postman-001",
  "recordsProcessed": 0
}
```

### Request 2: Check Run Status
* **Method**: `GET`
* **URL**: `http://localhost:8081/api/catalog/runs/RUN-20261013-100000`
* **Expected Response**: `HTTP 200 OK` (or `404 Not Found` if run ID does not exist).

---

## 8. How to Run MUnit Tests

Run via command line using the configured Maven wrapper:
```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
mvn test
```
* **Verification**: Run the current test suites with `./scripts/build.ps1 -Goal test`. Unit tests mock external services; API smoke tests use the real HTTP listener.
* **Application Coverage**: The fresh test output and `target/site/munit/coverage/summary.html` report the current coverage.
* **Coverage Report**: View HTML report at `target/site/munit/coverage/summary.html`.

---

## 9. Verification in Salesforce and MySQL

### In Salesforce
* Navigate to **App Launcher $\rightarrow$ Products**.
* Verify `ERP_Product_Code__c = PRD-AUT-140` has `IsActive = true` and custom price book entry.
* Verify `ERP_Product_Code__c = PRD-AUT-090` has `IsActive = false` (Discontinued).
* Navigate to **App Launcher $\rightarrow$ Cases**.
* Verify Case with subject `[ALERT] CatalogPriceBookSync Failures - Run ...` exists when rejections occur.

### In MySQL
```sql
SELECT * FROM sync_run ORDER BY started_at DESC LIMIT 5;
SELECT * FROM product_sync_log ORDER BY log_seq DESC LIMIT 10;
```

---

## 10. Known Limitations & Architecture Notes

1. **Mule Domain Application**: Not required. The application runs as a standalone deployment managing its own listener configuration on `http://0.0.0.0:8081` without port sharing requirements.
2. **API Autodiscovery**: Optional. Configure API Manager separately if policies or managed API analytics are required. The catalog synchronization endpoints run without API autodiscovery.
3. **SMTP Delivery**: Reusable plain-text summary is compiled by `run-summary-email.dwl`. Delivery is disabled (`smtp.enabled: false`) until valid host credentials are provided.

## Local development verification

Use JDK 17 for both Maven and the Mule application. `mule-artifact.json` declares Java 17, and MUnit uses the runtime version from `app.runtime` in `pom.xml`.

```powershell
./scripts/build.ps1 -Goal package
```

The build script uses the portable JDK under `target/jdk17-current` when present, otherwise `JAVA_HOME`. If Maven is absent from PATH, it uses Anypoint Studio's bundled Maven. These tools under `target` are local prerequisites, not part of the distributable application. After deleting `target`, supply an installed JDK 17 using `-JavaHome` and Maven or Anypoint Studio.

For development, import this project's `pom.xml` into Anypoint Studio and choose **Run As > Mule Application**, with Java 17 and Mule 4.12.1. Studio includes a runtime for development; a separate standalone Enterprise runtime needs a valid license. The standalone helper `./scripts/run.ps1 -MuleHome <licensed-runtime-folder>` is intended for that licensed runtime.

If launching from a Windows app that redirects temporary folders, add this VM property with an absolute folder inside the project: `-Djdk.net.unixdomain.tmpdir=<project-folder>/target/java-sockets`. The build config includes this setting for MUnit. This allows Java to use its supported TCP fallback when Unix-domain sockets cannot be created.

Expected API behavior:
- `POST /api/catalog/sync` registers the run and returns HTTP 202 while processing continues asynchronously.
- `GET /api/catalog/runs/{runId}` returns HTTP 200 for an existing run and HTTP 404 for an unknown run.
- `GET /console/` serves the API console.
- Invalid requests return HTTP 400.

Run IDs use UUIDs to prevent collisions. Product retrieval no longer truncates the catalog at 200 rows. Price-book lookup preserves the product list and both price-book IDs. Fatal processing errors mark the run `FAILED` when the database is reachable. Rejections are written under `target/rejects` relative to the launch working directory.

SMTP is disabled by default. Configure Gmail STARTTLS, an encrypted App Password, and the sender/recipient settings as described in [email configuration](deployment/EMAIL.md). `SENT` is recorded only after the email connector completes; exhausted delivery attempts record `PENDING_RETRY` without changing the catalog run outcome. Nonempty rejects are attached as CSV.
The verified Studio `salesforce` regression build contains 42 tests (37 flow tests and 5 real HTTP checks), with 0 failures and 0 errors and 100.00% processor coverage (170 / 170). See [verified test results](docs/test-results.md) for the regression summary. The added SMTP failure test confirms notification failures are recorded without interrupting catalog finalization.

To verify real external connections separately, run `./scripts/check-connections.ps1`. It reads the ERP catalog, retrieves Salesforce price-book IDs, and submits an audited partial sync for a deliberately nonmatching product code. This adds a verification row to `sync_run` and does not modify Salesforce products. Default unit tests do not depend on live credentials.

The initial MySQL setup script is `db/schema.sql`. Apply it to the MySQL instance before starting the application. To change the database password later, run `pwsh -File ./scripts/set-db-password.ps1`; it prompts privately, verifies the database login, and updates only the encrypted database password.
The live MySQL, Salesforce price-book, and HTTP synchronization checks also passed. The initialized ERP database is empty; load business products and prices before performing a real catalog sync. The app's test listener stops after verification; use Anypoint Studio to keep the development application running.
