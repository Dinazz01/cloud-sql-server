In this module, passwords are handled in two ways:

Use an existing password from Secret Manager
Generate a password with Terraform using random_password
1. Root password / admin password

For SQL Server, Cloud SQL requires a root/admin password.

Your module does this logic:

root_password =
var.root_password_secret != null ?
data.google_secret_manager_secret_version.root_password_from_secret[0].secret_data :
random_password.root_password_generated.result

Meaning:

If root_password_secret is provided, Terraform reads the password from Google Secret Manager.
If root_password_secret is not provided, Terraform generates one using random_password.

Example YAML:

root_password_secret: csql-sqlserver-root-password

Then Terraform reads:

data "google_secret_manager_secret_version" "root_password_from_secret"

If you do not provide that secret, Terraform uses:

resource "random_password" "root_password_generated"
2. Additional database user passwords

For extra users, the module also supports Secret Manager.

Example YAML:

users:
  sql_app_user:
    password_secret: csql-sqlserver-app-user-password

Terraform reads that secret and uses it here:

password = data.google_secret_manager_secret_version.db_user_passwords[each.key].secret_data

So the user password comes from Secret Manager.

3. Generated additional user passwords

Your module also has this:

resource "random_password" "additional_user_passwords" {
  for_each = {
    for db_user_key, db_user_cfg in var.users :
    db_user_key => db_user_cfg
    if try(db_user_cfg.password, null) == null
  }

  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

This means:

If a user does not provide a password, Terraform can generate one.
But you need to make sure the generated password is actually used in google_sql_user.

Recommended logic:

password = try(
  data.google_secret_manager_secret_version.db_user_passwords[each.key].secret_data,
  random_password.additional_user_passwords[each.key].result
)
Important security point

Even if passwords come from Secret Manager, Terraform may still store the password value in the Terraform state.

So best practice is:

Use a secure remote backend
Restrict access to the Terraform state bucket
Enable state encryption
Avoid committing passwords to YAML or .tfvars
Prefer Secret Manager for real environments
Simple flow
YAML
 └── root_password_secret provided?
       ├── yes → read password from Secret Manager
       └── no  → generate password with random_password

YAML users
 └── user password_secret provided?
       ├── yes → read password from Secret Manager
       └── no  → generate password with random_password
Best production recommendation

For production, use this pattern:

root_password_secret: csql-sqlserver-root-password

users:
  app_user:
    password_secret: csql-sqlserver-app-user-password

Avoid hardcoded passwords in YAML.
