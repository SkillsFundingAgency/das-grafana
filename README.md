# das-grafana

## User Management

User management is handled by a combination of Auth0 and GitHub, this integration prevents login using the admin account from a browser.  After deploying a new instance of das-grafana you will need to add users to the admin roles by making API calls using the admin account.  The admin credentials are stored in a Kubernetes secret.  Execute the following PowerShell to add a user to an admin role.  First login with your user via the Auth0 GitHub flow then execute the following PowerShell to make your user an admin:

```
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
$Headers = @{Authorization=("Basic {0}" -f $Base64AuthInfo); "Content-Type" = "application/json"}
$GrafanaBaseUri = "https://<env>-tools.apprenticeships.education.gov.uk/grafana"
## test authentication works
Invoke-RestMethod -Uri $GrafanaBaseUri/api/orgs -Method GET -Headers $Headers
$Body = @{"loginOrEmail"="user@example.com";"role"="Admin"}
Invoke-RestMethod -Uri $GrafanaBaseUri/api/orgs/<orgid>/users -Method POST -Headers $Headers -Body $($Body | ConvertTo-Json -Compress) -UserAgent $([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome.ToString()) -Verbose
```

Once your user is an admin you'll be able to complete the remaining config, including adding other users as admin, via the Grafana GUI.
