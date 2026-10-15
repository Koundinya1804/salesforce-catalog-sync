# Deploy salesforce to CloudHub 2.0

1. Open Anypoint Platform > Runtime Manager and choose Sandbox.
2. Select Deploy application. Use `salesforce-catalog-sync` if that name is available.
3. Select CloudHub 2.0 and an available shared-space region.
4. Upload the newly verified `salesforce-1.0.0-SNAPSHOT-mule-application.jar` from the Studio project's `target` directory.
5. Select Java 17 and an available Mule runtime compatible with the application's minimum version, 4.12.0. The local tests use Mule 4.12.1.
6. Start with one replica for this demonstration. Choose a replica size from the capacity already available in your account.
7. After the Aiven setup succeeds and the JAR is rebuilt, enter the values from `cloudhub2-aiven.properties.example` in Properties. Set and protect `encryption.key` using the key that matches the bundled encrypted configuration. Keep SMTP disabled for this deployment.
8. Enable Object Store v2 for the synchronization watermark.
9. Deploy, wait for Running, then inspect the application logs. Use the application URL displayed by Runtime Manager; the API routes start with `/api` and the API console with `/console`.

Use the separate Aiven configuration described in `AIVEN.md`. The original configuration still points to `localhost` for local development. CloudHub needs `config.file=config-aiven.yaml` and `secure.config.file=secure-properties-aiven.yaml` to use the reachable Aiven database. Deployment must be verified in Runtime Manager before it can be called successful.

CloudHub 2.0 does not support persistent VM queues. Set `vm.queueType=TRANSIENT`; the default remains `PERSISTENT` for local use. Transient queue messages are lost on restart. Use external messaging if durable queue storage is needed.

Reject CSV files under `/tmp` are temporary and are lost on restart. Use external storage if those files need to be retained.

Official references:
- https://docs.mulesoft.com/cloudhub-2/ch2-deploy-shared-space
- https://docs.mulesoft.com/cloudhub-2/ch2-features
- https://docs.mulesoft.com/cloudhub-2/ch2-protect-app-props
- https://docs.mulesoft.com/cloudhub-2/ch2-understand-app-restart
