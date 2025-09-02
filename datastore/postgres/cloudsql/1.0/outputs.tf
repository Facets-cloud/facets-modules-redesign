locals {
  output_attributes = {
    port            = "5432"
    instance_name   = google_sql_database_instance.main.name
    database_name   = google_sql_database.default.name
    connection_name = google_sql_database_instance.main.connection_name
  }
  output_interfaces = {
    reader = {
      host              = length(google_sql_database_instance.read_replica) > 0 ? google_sql_database_instance.read_replica[0].private_ip_address : google_sql_database_instance.main.private_ip_address
      username          = google_sql_user.master_user.name
      password          = google_sql_user.master_user.password
      connection_string = length(google_sql_database_instance.read_replica) > 0 ? "postgres://${google_sql_user.master_user.name}:${google_sql_user.master_user.password}@${google_sql_database_instance.read_replica[0].private_ip_address}:5432/${google_sql_database.default.name}" : "postgres://${google_sql_user.master_user.name}:${google_sql_user.master_user.password}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.default.name}"
    }
    writer = {
      host              = google_sql_database_instance.main.private_ip_address
      username          = google_sql_user.master_user.name
      password          = google_sql_user.master_user.password
      connection_string = "postgres://${google_sql_user.master_user.name}:${google_sql_user.master_user.password}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.default.name}"
    }
  }
}