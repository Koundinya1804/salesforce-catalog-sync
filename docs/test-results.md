# Verified MUnit results

Validated with Mule Enterprise 4.12.1, Java 17, and MUnit 3.7.3.

| Suite | Tests | Failures | Errors |
| --- | ---: | ---: | ---: |
| catalog-sync-test-suite.xml | 37 | 0 | 0 |
| api-smoke-test-suite.xml | 5 | 0 | 0 |
| Total | 42 | 0 | 0 |

The complete regression run covered 170 of 170 processors across 23 containers: **100% application coverage**.

The HTTP suite checks request validation, accepted asynchronous synchronization, missing runs, the API console page, and the gzip response header required to load the console's AMF model.

Run both suites in the same execution to measure full application coverage. The smoke suite alone covers 16 of 170 processors (9.41%).

Optional live verification also passed for MySQL with TLS certificate and hostname validation, Salesforce price-book lookup, and an API synchronization request that intentionally matched no products. Live checks are separate from the default mocked regression suite.

Coverage measures executed Mule processors; it does not guarantee that every possible data combination or external-service failure has been tested.

Email regression tests verify separate created/updated counts, a correctly escaped rejects CSV attachment, successful sending, and three exhausted delivery attempts recorded as `PENDING_RETRY`. A separate local integration verification successfully sent one actual Gmail summary with the rejected sample attached. That live test and its credentials are excluded from GitHub and the normal regression suite. CloudHub must receive the updated JAR and `smtp.enabled=true` before it sends notifications.
