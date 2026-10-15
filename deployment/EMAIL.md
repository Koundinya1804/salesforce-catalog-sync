# Email summary notifications

The summary uses `dwl/run-summary-email.dwl`, lists created and updated counts separately, and includes the rejects CSV when permanent failures exist. The CSV is built from the same run's reject records, so it remains available even when writing the filesystem copy fails.

For Gmail use SMTP host `smtp.gmail.com`, port `587`, and the full sender Gmail address for `smtp.user` and `smtp.from`. Set `smtp.to` to the master data team's address. The SMTP connection requires STARTTLS and verifies the server hostname.

Store the App Password encrypted under `smtp.password` in the selected secure properties YAML, or override `smtp.password` with a protected CloudHub property. Never commit a live App Password or environment configuration. The supplied secure-properties example contains an encrypted dummy SMTP password for mocked tests.

In Runtime Manager open the application, then **Settings > Properties**. Keep the Aiven database settings, set the email properties and `smtp.enabled=true`, and apply changes after uploading the updated JAR. SMTP remains disabled by default so ordinary MUnit runs cannot send mail.

Delivery is attempted once plus `smtp.maxRetries` retries (default 2), with `smtp.retryDelayMs` milliseconds between attempts (default 1000). On success the database run has `email_status=SENT`. Exhausted attempts produce `PENDING_RETRY`, while product counters and the catalog run outcome remain valid. This marker requires an operator or a notification replay worker to perform a later resend; the bounded attempts happen automatically within the current run.

For verification, trigger a sync after deployment and check the recipient's inbox and spam folder for the summary and attachment. Check Runtime Manager logs for `[EMAIL]`, and the run row's `email_status`. Mocked unit tests verify successful sending, the no-attachment case, CSV content, and all three failed attempts without sending real mail.
