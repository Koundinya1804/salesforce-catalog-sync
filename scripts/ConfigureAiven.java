import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.regex.*;
import javax.xml.parsers.DocumentBuilderFactory;
import org.yaml.snakeyaml.Yaml;
import com.mulesoft.modules.configuration.properties.api.*;
import org.mule.encryption.Encrypter;

class ConfigureAiven {
  @SuppressWarnings("unchecked")
  public static void main(String[] args) throws Exception {
    Path root = Path.of(args[0]);
    Properties settings = new Properties();
    try (Reader reader = Files.newBufferedReader(root.resolve("deployment/aiven.properties"))) { settings.load(reader); }
    var xml = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(root.resolve("src/main/mule/salesforce.xml").toFile());
    String encryptionKey = null;
    var globals = xml.getElementsByTagName("global-property");
    for (int i = 0; i < globals.getLength(); i++) {
      var element = (org.w3c.dom.Element) globals.item(i);
      if (element.getAttribute("name").equals("encryption.key")) encryptionKey = element.getAttribute("value");
    }
    if (encryptionKey == null) throw new IllegalStateException("Application encryption key is missing");
    Encrypter cipher = EncryptionAlgorithm.Blowfish.getBuilder().using(EncryptionMode.CBC).forKey(encryptionKey).useRandomIVs(false).build();
    if (args.length > 1 && args[1].equals("--self-test")) {
      byte[] sample = "aiven-encryption-check".getBytes(StandardCharsets.UTF_8);
      if (!Arrays.equals(sample, cipher.decrypt(cipher.encrypt(sample)))) throw new IllegalStateException("Encryption check failed");
      java.security.KeyStore store = java.security.KeyStore.getInstance("PKCS12");
      try (InputStream input = Files.newInputStream(root.resolve("src/main/resources/aiven-truststore.p12"))) { store.load(input, "aiven-ca-store".toCharArray()); }
      if (!store.containsAlias("aiven-project-ca")) throw new IllegalStateException("Aiven CA is missing");
      System.out.println("Aiven setup validation passed. No credentials or databases changed.");
      return;
    }
    String password = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8)).readLine();
    if (password == null || password.isEmpty()) throw new IllegalArgumentException("No Aiven password supplied");
    Properties connectionProperties = new Properties();
    connectionProperties.setProperty("user", settings.getProperty("db.user"));
    connectionProperties.setProperty("password", password);
    connectionProperties.setProperty("sslMode", "VERIFY_IDENTITY");
    connectionProperties.setProperty("trustCertificateKeyStoreUrl", root.resolve("src/main/resources/aiven-truststore.p12").toUri().toString());
    connectionProperties.setProperty("trustCertificateKeyStoreType", "PKCS12");
    connectionProperties.setProperty("trustCertificateKeyStorePassword", "aiven-ca-store");
    connectionProperties.setProperty("connectTimeout", "15000");
    connectionProperties.setProperty("socketTimeout", "30000");
    String url = "jdbc:mysql://" + settings.getProperty("db.host") + ":" + settings.getProperty("db.port") + "/" + settings.getProperty("db.name");
    try (Connection connection = DriverManager.getConnection(url, connectionProperties); Statement statement = connection.createStatement()) {
      // Aiven supplies defaultdb, so create only the application tables in that database.
      String schema = Files.readString(root.resolve("db/schema.sql"));
      for (String sql : schema.split(";")) {
        String trimmed = sql.trim();
        if (trimmed.isEmpty() || trimmed.toUpperCase(Locale.ROOT).startsWith("CREATE DATABASE") || trimmed.toUpperCase(Locale.ROOT).startsWith("USE ")) continue;
        statement.execute(trimmed);
      }
      try (ResultSet tls = statement.executeQuery("SHOW SESSION STATUS LIKE 'Ssl_cipher'")) {
        if (!tls.next() || tls.getString(2).isBlank()) throw new IllegalStateException("Connection is not TLS encrypted");
      }
      for (String table : List.of("product_master", "product_price", "sync_run", "product_sync_log")) {
        try (ResultSet result = statement.executeQuery("SELECT COUNT(*) FROM " + table)) { result.next(); System.out.println(table + ": " + result.getLong(1) + " rows"); }
      }
    }
    Path resources = root.resolve("src/main/resources");
    Map<String,Object> config;
    try (Reader input = Files.newBufferedReader(resources.resolve("config.yaml"))) { config = new Yaml().load(input); }
    Map<String,Object> db = (Map<String,Object>) config.get("db");
    for (String name : List.of("host", "port", "user", "name")) db.put(name, settings.getProperty("db." + name));
    db.put("sslMode", "VERIFY_IDENTITY");
    String encrypted = Base64.getEncoder().encodeToString(cipher.encrypt(password.getBytes(StandardCharsets.UTF_8)));
    String secureText = Files.readString(resources.resolve("secure-properties.yaml"));
    Matcher match = Pattern.compile("(?m)(^db:\\s*\\r?\\n[ \\t]+password:)[^\\r\\n]*").matcher(secureText);
    if (!match.find()) throw new IllegalStateException("Cannot find encrypted database password entry");
    String secureCloud = match.replaceFirst(Matcher.quoteReplacement(match.group(1) + " \"![" + encrypted + "]\""));
    Files.writeString(resources.resolve("config-aiven.yaml"), new Yaml().dump(config));
    Files.writeString(resources.resolve("secure-properties-aiven.yaml"), secureCloud);
    System.out.println("Aiven TLS login verified; four tables ready; encrypted cloud configuration saved. Local configuration was preserved.");
  }
}
