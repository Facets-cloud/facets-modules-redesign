locals {
  output_attributes = {
    cluster_arn                  = aws_msk_cluster.main.arn
    cluster_name                 = aws_msk_cluster.main.cluster_name
    bootstrap_brokers            = aws_msk_cluster.main.bootstrap_brokers
    bootstrap_brokers_tls        = aws_msk_cluster.main.bootstrap_brokers_tls
    bootstrap_brokers_sasl_scram = try(aws_msk_cluster.main.bootstrap_brokers_sasl_scram, "")
    kafka_version                = aws_msk_cluster.main.kafka_version
    security_group_id            = local.security_group_id
    configuration_arn            = local.is_import ? "N/A - Imported cluster" : aws_msk_configuration.main[0].arn
    zookeeper_connect_string     = aws_msk_cluster.main.zookeeper_connect_string
    kms_key_id                   = local.is_import ? "N/A - Imported cluster" : aws_kms_key.msk[0].arn
    log_group_name               = local.is_import ? "N/A - Imported cluster" : aws_cloudwatch_log_group.msk_logs[0].name
    number_of_broker_nodes       = aws_msk_cluster.main.number_of_broker_nodes
    current_version              = aws_msk_cluster.main.current_version
  }
  output_interfaces = {
    cluster = {
      endpoint          = aws_msk_cluster.main.bootstrap_brokers_tls != "" ? aws_msk_cluster.main.bootstrap_brokers_tls : aws_msk_cluster.main.bootstrap_brokers
      connection_string = "kafka://${aws_msk_cluster.main.bootstrap_brokers_tls != "" ? aws_msk_cluster.main.bootstrap_brokers_tls : aws_msk_cluster.main.bootstrap_brokers}"
      username          = "\"\""
      password          = "\"\""
      endpoints         = { for idx, broker in split(",", aws_msk_cluster.main.bootstrap_brokers_tls != "" ? aws_msk_cluster.main.bootstrap_brokers_tls : aws_msk_cluster.main.bootstrap_brokers) : tostring(idx) => broker }
    }
  }
}