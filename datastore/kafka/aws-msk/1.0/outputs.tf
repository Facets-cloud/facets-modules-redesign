locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = aws_msk_cluster.main.bootstrap_brokers_tls != "" ? aws_msk_cluster.main.bootstrap_brokers_tls : aws_msk_cluster.main.bootstrap_brokers
      connection_string = "kafka://${aws_msk_cluster.main.bootstrap_brokers_tls != "" ? aws_msk_cluster.main.bootstrap_brokers_tls : aws_msk_cluster.main.bootstrap_brokers}"
      username          = "\"\""
      password          = "\"\""
      endpoints         = { for idx, broker in split(",", aws_msk_cluster.main.bootstrap_brokers_tls != "" ? aws_msk_cluster.main.bootstrap_brokers_tls : aws_msk_cluster.main.bootstrap_brokers) : tostring(idx) => broker }
    }
    secrets = ["cluster"]
  }
}