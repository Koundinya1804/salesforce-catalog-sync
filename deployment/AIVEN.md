# Aiven MySQL setup

Create a MySQL service on Aiven's Free plan. Copy `aiven.properties.example` to `aiven.properties` and enter the host, port, user, and database from your service's Connection information.

Download your service's CA certificate to `deployment/aiven-ca.pem`. With JDK 17, create the application truststore:

```powershell
keytool -importcert -noprompt -alias aiven-project-ca -file deployment/aiven-ca.pem -keystore src/main/resources/aiven-truststore.p12 -storetype PKCS12 -storepass aiven-ca-store
```

The CA and truststore are local files excluded from Git. Create this truststore from your own Aiven service's CA.

Run `scripts/configure-aiven.ps1` using PowerShell 7 from this project. Copy the database password from Aiven's Connection information and paste it only at the script's hidden prompt.

The script authenticates over TLS with certificate and hostname verification using the saved Aiven CA. It creates the four application tables in `defaultdb` and checks their row counts. It does not import products or prices from your laptop. It saves a separate cloud configuration with an encrypted password and preserves the local configuration. It also copies the generated resources into the Studio `salesforce` project.

After successful setup, rebuild the Studio project's Mule application JAR. The new archive must contain `config-aiven.yaml`, `secure-properties-aiven.yaml`, and `aiven-truststore.p12` before deployment.

In CloudHub 2.0, use the properties from `cloudhub2-aiven.properties.example`, Java 17, a compatible Mule runtime, one replica for the demonstration, and Object Store v2. Keep SMTP disabled for the initial cloud verification.

The truststore contains only the public CA certificate. Its password is not a database credential. The generated YAML files contain environment configuration and encrypted live credentials; both are excluded from Git.

Official instructions: https://aiven.io/docs/products/mysql/get-started
