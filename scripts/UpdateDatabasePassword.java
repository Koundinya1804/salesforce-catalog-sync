import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.regex.*;
import javax.xml.parsers.DocumentBuilderFactory;
import com.mulesoft.modules.configuration.properties.api.*;
import org.mule.encryption.Encrypter;
import org.yaml.snakeyaml.Yaml;

class UpdateDatabasePassword {
  public static void main(String[] args) throws Exception {
    Path root = Path.of(args[0]);
    var xml = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(root.resolve("src/main/mule/salesforce.xml").toFile());
    var properties = xml.getElementsByTagName("global-property");
    String key = null;
    for (int i = 0; i < properties.getLength(); i++) {
      var element = (org.w3c.dom.Element) properties.item(i);
      if ("encryption.key".equals(element.getAttribute("name"))) key = element.getAttribute("value");
    }
    if (key == null) throw new IllegalStateException("Encryption key is not configured");
    Encrypter cipher = EncryptionAlgorithm.Blowfish.getBuilder().using(EncryptionMode.CBC).forKey(key).useRandomIVs(false).build();
    if (args.length > 1 && args[1].equals("--self-test")) {
      byte[] sample = "test-#-password-123".getBytes(StandardCharsets.UTF_8);
      if (!Arrays.equals(sample, cipher.decrypt(cipher.encrypt(sample)))) throw new IllegalStateException("Encryption round-trip failed");
      System.out.println("Mule encryption round-trip passed; credentials unchanged.");
      return;
    }
    String password = System.console() != null ? new String(System.console().readPassword("Enter MySQL password (hidden): ")) : new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8)).readLine();
    if (password == null) throw new IllegalStateException("No password supplied");
    Map<?,?> config;
    try (Reader input = Files.newBufferedReader(root.resolve("src/main/resources/config.yaml"))) { config = new Yaml().load(input); }
    Map<?,?> db = (Map<?,?>) config.get("db");
    boolean initialize = args.length > 1 && args[1].equals("--initialize-database");
    String url = "jdbc:mysql://" + db.get("host") + ":" + db.get("port") + "/" + (initialize ? "" : db.get("name"));
    try (Connection connection = DriverManager.getConnection(url, String.valueOf(db.get("user")), password);
         Statement statement = connection.createStatement()) {
      if (initialize) {
        if (!"catalog_sync_db".equals(String.valueOf(db.get("name")))) throw new IllegalStateException("Schema script is for catalog_sync_db; configured name differs");
        for (String sql : Files.readString(root.resolve("db/schema.sql")).split(";")) {
          if (!sql.isBlank()) statement.execute(sql.trim());
        }
        connection.setCatalog("catalog_sync_db");
        System.out.println("Application database schema is ready.");
      }
      try (Statement verification = connection.createStatement(); ResultSet result = verification.executeQuery("SELECT 1")) {
        if (!result.next()) throw new IllegalStateException("Database verification failed");
      }
    } catch (SQLException error) {
      System.err.println("Database check failed (" + error.getErrorCode() + ", " + error.getSQLState() + "): " + error.getMessage() + ". Credentials were not changed.");
      System.exit(2);
    }
    String encrypted = Base64.getEncoder().encodeToString(cipher.encrypt(password.getBytes(StandardCharsets.UTF_8)));
    Path secure = root.resolve("src/main/resources/secure-properties.yaml");
    String existing = Files.readString(secure);
    Pattern dbPassword = Pattern.compile("(?m)(^db:\\s*\\r?\\n[ \\t]+password:)[^\\r\\n]*");
    Matcher match = dbPassword.matcher(existing);
    if (!match.find()) throw new IllegalStateException("Cannot find db.password in secure-properties.yaml");
    String replacement = match.group(1) + " \"![" + encrypted + "]\"";
    String updated = match.replaceFirst(Matcher.quoteReplacement(replacement));
    Files.writeString(secure, updated, StandardCharsets.UTF_8);
    System.out.println("Database login verified and encrypted password updated. Salesforce credentials were preserved.");
  }
}
