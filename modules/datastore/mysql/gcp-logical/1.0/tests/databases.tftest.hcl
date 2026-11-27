mock_provider "google" {}
run "creates_declared_databases_on_shared_instance" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = {
      kind = "mysql", flavor = "gcp-logical", version = "1.0"
      spec = { source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 } } }, databases_json = "[\"one\",\"two\"]", cloud_sql_instance = "shared-sandbox" }
    }
  }
  assert {
    condition = length(google_sql_database.logical) == 2 && google_sql_database.logical["one"].instance == "shared-sandbox" && google_sql_database.logical["one"].project == "sandbox-test"
    error_message = "The logical resource must create both declared databases."
  }
}

run "rejects_missing_instance_name" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = { source = {} } }
  }
  expect_failures = [var.instance]
}

run "owner_manages_shared_user_once_with_canonical_password" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = {
      kind = "mysql", flavor = "gcp-logical", version = "1.0"
      spec = {
        source = {}
        cloud_sql_instance = "shared-sandbox"
        managed_users = { central = { host = "%" } }
        canonical_passwords_json = "{\"central\":\"example-password\"}"
      }
    }
  }
  assert {
    condition = try(google_sql_user.shared["central"].name == "central" && nonsensitive(google_sql_user.shared["central"].password) == "example-password", false)
    error_message = "The designated owner must create one account with its canonical password."
  }
}

run "logical_users_get_the_canonical_credential" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = {
      kind = "mysql", flavor = "gcp-logical", version = "1.0"
      spec = {
        source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 } } }
        cloud_sql_instance = "shared-sandbox"
        user_list = { central = { database = "one" } }
        canonical_passwords_json = "{\"central\":\"example-password\"}"
        database_name = "one"
      }
    }
  }
  assert {
    condition = try(nonsensitive(local.output_interfaces.central.password) == "example-password" && local.output_interfaces.central.database == "one", false)
    error_message = "Each declared logical user must expose the canonical credential and intended database."
  }
}

run "user_list_keeps_each_users_default_database" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = {
      kind = "mysql", flavor = "gcp-logical", version = "1.0"
      spec = {
        source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 } } }
        cloud_sql_instance = "shared-sandbox"
        databases_json = "[\"one\",\"two\"]"
        user_list = { central = { database = "two" } }
        canonical_passwords_json = "{\"central\":\"example-password\"}"
      }
    }
  }
  assert {
    condition = try(local.output_interfaces.central.database == "two", false)
    error_message = "The logical resource must preserve each user_list database selection."
  }
}

run "does_not_expose_unrelated_source_users" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = {
      source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 }, other = { username = "other" } } }
      cloud_sql_instance = "shared-sandbox"
    } }
  }
  assert {
    condition = !contains(keys(local.output_interfaces), "other")
    error_message = "Undeclared source user credentials must not be forwarded."
  }
}

run "rejects_missing_user_password" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = {
      source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 } } }
      cloud_sql_instance = "shared-sandbox"
      user_list = { central = {} }
    } }
  }
  expect_failures = [terraform_data.credential_contract]
}

run "owner_can_plan_when_instance_is_sensitive" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = sensitive({
      kind = "mysql", flavor = "gcp-logical", version = "1.0"
      spec = {
        source = {}
        cloud_sql_instance = "shared-sandbox"
        managed_users = { central = { host = "%" } }
        canonical_passwords_json = "{\"central\":\"example-password\"}"
      }
    })
  }
  assert {
    condition = length(google_sql_user.shared) == 1
    error_message = "Public usernames must produce known instance keys even when the payload is sensitive."
  }
}

run "rejects_reserved_interface_names" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = {
      source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 } } }
      cloud_sql_instance = "shared-sandbox"
      user_list = { reader = {} }
      canonical_passwords_json = "{\"reader\":\"example-password\"}"
    } }
  }
  expect_failures = [var.instance]
}

run "rejects_missing_managed_user_password" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = {
      source = {}
      cloud_sql_instance = "shared-sandbox"
      managed_users = { central = {} }
    } }
  }
  expect_failures = [google_sql_user.shared["central"]]
}

run "writer_defaults_to_first_logical_database" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = {
      source = { interfaces = { writer = { host = "10.0.0.3", port = 3306 }, reader = { host = "10.0.0.3", port = 3306 } } }
      cloud_sql_instance = "shared-sandbox"
      databases_json = "[\"one\",\"two\"]"
    } }
  }
  assert {
    condition = local.output_interfaces.writer.database == "one"
    error_message = "Writer must default to the first logical database."
  }
}

run "marks_forwarded_writer_credentials_sensitive" {
  command = plan
  variables {
    inputs = { cloud_account = { attributes = { project_id = "sandbox-test" } } }
    instance_name = "logical-a"
    environment = { name = "sandbox", unique_name = "sandbox", cloud_tags = {} }
    instance = { kind = "mysql", flavor = "gcp-logical", version = "1.0", spec = {
      source = { interfaces = { writer = { host = "10.0.0.3", port = 3306, password = "example-password", connection_string = "mysql://example" } } }
      cloud_sql_instance = "shared-sandbox"
    } }
  }
  assert {
    condition = issensitive(local.output_interfaces.writer.password) && issensitive(local.output_interfaces.writer.connection_string) && contains(local.output_interfaces.writer.secrets, "password") && contains(local.output_interfaces.writer.secrets, "connection_string")
    error_message = "Forwarded credentials must remain sensitive."
  }
}
