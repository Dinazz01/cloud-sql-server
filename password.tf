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
#############################################################

instance_name = "csql-instance-${substr(var.environment, 0, 1)}-${local.location_short}-${var.platform}-${var.name}"

which generates names like:

csql-instance-d-use4-hhtt-csql-instance3
Option 1 (Recommended): Make the random suffix optional

Instead of always appending random numbers, make it configurable.

Step 1. Create a random integer
resource "random_integer" "instance_suffix" {
  min = 1000
  max = 9999
}
Step 2. Add a variable
variable "append_random_suffix" {
  description = "Append a random 4-digit suffix to resource names."
  type        = bool
  default     = false
}
Step 3. Update the name
locals {
  instance_name = var.append_random_suffix ?
    "csql-instance-${substr(var.environment, 0, 1)}-${local.location_short}-${var.platform}-${var.name}-${random_integer.instance_suffix.result}" :
    "csql-instance-${substr(var.environment, 0, 1)}-${local.location_short}-${var.platform}-${var.name}"
}

Now you'll get either:

Without suffix:

csql-instance-d-use4-hhtt-instance3

With suffix:

csql-instance-d-use4-hhtt-instance3-4821
Option 2: Use random_string

If you prefer alphanumeric values:

resource "random_string" "instance_suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

Then:

locals {
  instance_name = "csql-instance-${substr(var.environment, 0, 1)}-${local.location_short}-${var.platform}-${var.name}-${random_string.instance_suffix.result}"
}

Produces:

csql-instance-d-use4-hhtt-instance3-7315
Option 3 (My recommendation for enterprise environments)

Instead of using random numbers in production, I recommend using them only for ephemeral environments such as feature branches or developer sandboxes.

For example:

locals {
  use_random_suffix = contains(
    ["dev", "sandbox", "feature"],
    lower(var.environment)
  )

  instance_name = local.use_random_suffix ?
    "csql-instance-${substr(var.environment, 0, 1)}-${local.location_short}-${var.platform}-${var.name}-${random_integer.instance_suffix.result}" :
    "csql-instance-${substr(var.environment, 0, 1)}-${local.location_short}-${var.platform}-${var.name}"
}

This gives you:

Environment	Instance Name
dev	csql-instance-d-use4-hhtt-instance3-4821
sandbox	csql-instance-s-use4-hhtt-instance3-7315
uat	csql-instance-u-use4-hhtt-instance3
prod	csql-instance-p-use4-hhtt-instance3
