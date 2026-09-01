# ─────────────────────── state address migration ───────────────────────────
#
# The previous layout keyed subnets and route tables by AVAILABILITY ZONE across
# three separate resources. This one uses a single resource per kind keyed by an
# explicit plan key, so the derived plan generates keys of the form "<tier>-<az>".
#
# These blocks are mandatory for anyone already managing a VPC with the previous
# layout: without them the re-key reads as destroy+create on a live VPC rather
# than a rename. They are inert for a fresh deployment.
#
#   previous                             current
#   aws_subnet.public["us-west-2a"]   -> aws_subnet.this["public-us-west-2a"]
#   aws_subnet.private["us-west-2a"]  -> aws_subnet.this["private-us-west-2a"]
#   aws_subnet.database["us-west-2a"] -> aws_subnet.this["database-us-west-2a"]
#   aws_route_table.public            -> aws_route_table.this["public"]
#   aws_route_table.private["<az>"]   -> aws_route_table.this["private-<az>"]
#   aws_route_table.private["single"] -> aws_route_table.this["private-single"]
#   aws_route_table.database["<az>"]  -> aws_route_table.this["database-<az>"]
#   aws_nat_gateway.main["<k>"]       -> aws_nat_gateway.this["<k>"]
#   aws_eip.nat["<k>"]                -> aws_eip.nat["<k>"]        (unchanged)
#   aws_vpc.main                      -> aws_vpc.this
#   aws_internet_gateway.main         -> aws_internet_gateway.this
#   aws_vpc_endpoint.s3[0]            -> aws_vpc_endpoint.gateway["s3"]
#   aws_vpc_endpoint.<svc>[0]         -> aws_vpc_endpoint.interface["<svc>"]
#
# `moved` addresses must be static, so the per-AZ blocks below are enumerated for
# the AZs a 1.0 environment could have selected. Unmatched blocks are ignored by
# Terraform, so listing more than an environment uses is safe.
#
# ⚠ THE SHARP EDGE: 1.0 declared routes INLINE inside aws_route_table. Inline
# routes are attributes, not resources, so they CANNOT be `moved` into
# aws_route.this[*]. On upgrade Terraform will try to CREATE those routes and hit
# RouteAlreadyExists. Each 1.0 environment must import its existing routes first:
#
#   terraform import 'aws_route.this["public|0.0.0.0/0"]' <rtb-id>_0.0.0.0/0
#
# Do not roll 2.0 out to existing 1.0 environments until this has been proven on
# a throwaway environment. New environments and adoptions are unaffected.

moved {
  from = aws_vpc.main
  to   = aws_vpc.this
}

moved {
  from = aws_internet_gateway.main
  to   = aws_internet_gateway.this
}

moved {
  from = aws_route_table.public
  to   = aws_route_table.this["public"]
}

moved {
  from = aws_route_table.private["single"]
  to   = aws_route_table.this["private-single"]
}

moved {
  from = aws_subnet.public["us-east-1a"]
  to   = aws_subnet.this["public-us-east-1a"]
}

moved {
  from = aws_subnet.public["us-east-1b"]
  to   = aws_subnet.this["public-us-east-1b"]
}

moved {
  from = aws_subnet.public["us-east-1c"]
  to   = aws_subnet.this["public-us-east-1c"]
}

moved {
  from = aws_subnet.public["us-east-1d"]
  to   = aws_subnet.this["public-us-east-1d"]
}

moved {
  from = aws_subnet.public["us-east-1e"]
  to   = aws_subnet.this["public-us-east-1e"]
}

moved {
  from = aws_subnet.public["us-east-1f"]
  to   = aws_subnet.this["public-us-east-1f"]
}

moved {
  from = aws_subnet.public["us-east-2a"]
  to   = aws_subnet.this["public-us-east-2a"]
}

moved {
  from = aws_subnet.public["us-east-2b"]
  to   = aws_subnet.this["public-us-east-2b"]
}

moved {
  from = aws_subnet.public["us-east-2c"]
  to   = aws_subnet.this["public-us-east-2c"]
}

moved {
  from = aws_subnet.public["us-east-2d"]
  to   = aws_subnet.this["public-us-east-2d"]
}

moved {
  from = aws_subnet.public["us-east-2e"]
  to   = aws_subnet.this["public-us-east-2e"]
}

moved {
  from = aws_subnet.public["us-east-2f"]
  to   = aws_subnet.this["public-us-east-2f"]
}

moved {
  from = aws_subnet.public["us-west-1a"]
  to   = aws_subnet.this["public-us-west-1a"]
}

moved {
  from = aws_subnet.public["us-west-1b"]
  to   = aws_subnet.this["public-us-west-1b"]
}

moved {
  from = aws_subnet.public["us-west-1c"]
  to   = aws_subnet.this["public-us-west-1c"]
}

moved {
  from = aws_subnet.public["us-west-1d"]
  to   = aws_subnet.this["public-us-west-1d"]
}

moved {
  from = aws_subnet.public["us-west-1e"]
  to   = aws_subnet.this["public-us-west-1e"]
}

moved {
  from = aws_subnet.public["us-west-1f"]
  to   = aws_subnet.this["public-us-west-1f"]
}

moved {
  from = aws_subnet.public["us-west-2a"]
  to   = aws_subnet.this["public-us-west-2a"]
}

moved {
  from = aws_subnet.public["us-west-2b"]
  to   = aws_subnet.this["public-us-west-2b"]
}

moved {
  from = aws_subnet.public["us-west-2c"]
  to   = aws_subnet.this["public-us-west-2c"]
}

moved {
  from = aws_subnet.public["us-west-2d"]
  to   = aws_subnet.this["public-us-west-2d"]
}

moved {
  from = aws_subnet.public["us-west-2e"]
  to   = aws_subnet.this["public-us-west-2e"]
}

moved {
  from = aws_subnet.public["us-west-2f"]
  to   = aws_subnet.this["public-us-west-2f"]
}

moved {
  from = aws_subnet.public["eu-west-1a"]
  to   = aws_subnet.this["public-eu-west-1a"]
}

moved {
  from = aws_subnet.public["eu-west-1b"]
  to   = aws_subnet.this["public-eu-west-1b"]
}

moved {
  from = aws_subnet.public["eu-west-1c"]
  to   = aws_subnet.this["public-eu-west-1c"]
}

moved {
  from = aws_subnet.public["eu-west-1d"]
  to   = aws_subnet.this["public-eu-west-1d"]
}

moved {
  from = aws_subnet.public["eu-west-1e"]
  to   = aws_subnet.this["public-eu-west-1e"]
}

moved {
  from = aws_subnet.public["eu-west-1f"]
  to   = aws_subnet.this["public-eu-west-1f"]
}

moved {
  from = aws_subnet.public["eu-central-1a"]
  to   = aws_subnet.this["public-eu-central-1a"]
}

moved {
  from = aws_subnet.public["eu-central-1b"]
  to   = aws_subnet.this["public-eu-central-1b"]
}

moved {
  from = aws_subnet.public["eu-central-1c"]
  to   = aws_subnet.this["public-eu-central-1c"]
}

moved {
  from = aws_subnet.public["eu-central-1d"]
  to   = aws_subnet.this["public-eu-central-1d"]
}

moved {
  from = aws_subnet.public["eu-central-1e"]
  to   = aws_subnet.this["public-eu-central-1e"]
}

moved {
  from = aws_subnet.public["eu-central-1f"]
  to   = aws_subnet.this["public-eu-central-1f"]
}

moved {
  from = aws_subnet.public["ap-south-1a"]
  to   = aws_subnet.this["public-ap-south-1a"]
}

moved {
  from = aws_subnet.public["ap-south-1b"]
  to   = aws_subnet.this["public-ap-south-1b"]
}

moved {
  from = aws_subnet.public["ap-south-1c"]
  to   = aws_subnet.this["public-ap-south-1c"]
}

moved {
  from = aws_subnet.public["ap-south-1d"]
  to   = aws_subnet.this["public-ap-south-1d"]
}

moved {
  from = aws_subnet.public["ap-south-1e"]
  to   = aws_subnet.this["public-ap-south-1e"]
}

moved {
  from = aws_subnet.public["ap-south-1f"]
  to   = aws_subnet.this["public-ap-south-1f"]
}

moved {
  from = aws_subnet.public["ap-southeast-1a"]
  to   = aws_subnet.this["public-ap-southeast-1a"]
}

moved {
  from = aws_subnet.public["ap-southeast-1b"]
  to   = aws_subnet.this["public-ap-southeast-1b"]
}

moved {
  from = aws_subnet.public["ap-southeast-1c"]
  to   = aws_subnet.this["public-ap-southeast-1c"]
}

moved {
  from = aws_subnet.public["ap-southeast-1d"]
  to   = aws_subnet.this["public-ap-southeast-1d"]
}

moved {
  from = aws_subnet.public["ap-southeast-1e"]
  to   = aws_subnet.this["public-ap-southeast-1e"]
}

moved {
  from = aws_subnet.public["ap-southeast-1f"]
  to   = aws_subnet.this["public-ap-southeast-1f"]
}

moved {
  from = aws_subnet.public["ap-southeast-2a"]
  to   = aws_subnet.this["public-ap-southeast-2a"]
}

moved {
  from = aws_subnet.public["ap-southeast-2b"]
  to   = aws_subnet.this["public-ap-southeast-2b"]
}

moved {
  from = aws_subnet.public["ap-southeast-2c"]
  to   = aws_subnet.this["public-ap-southeast-2c"]
}

moved {
  from = aws_subnet.public["ap-southeast-2d"]
  to   = aws_subnet.this["public-ap-southeast-2d"]
}

moved {
  from = aws_subnet.public["ap-southeast-2e"]
  to   = aws_subnet.this["public-ap-southeast-2e"]
}

moved {
  from = aws_subnet.public["ap-southeast-2f"]
  to   = aws_subnet.this["public-ap-southeast-2f"]
}

moved {
  from = aws_subnet.public["ap-northeast-1a"]
  to   = aws_subnet.this["public-ap-northeast-1a"]
}

moved {
  from = aws_subnet.public["ap-northeast-1b"]
  to   = aws_subnet.this["public-ap-northeast-1b"]
}

moved {
  from = aws_subnet.public["ap-northeast-1c"]
  to   = aws_subnet.this["public-ap-northeast-1c"]
}

moved {
  from = aws_subnet.public["ap-northeast-1d"]
  to   = aws_subnet.this["public-ap-northeast-1d"]
}

moved {
  from = aws_subnet.public["ap-northeast-1e"]
  to   = aws_subnet.this["public-ap-northeast-1e"]
}

moved {
  from = aws_subnet.public["ap-northeast-1f"]
  to   = aws_subnet.this["public-ap-northeast-1f"]
}

moved {
  from = aws_subnet.private["us-east-1a"]
  to   = aws_subnet.this["private-us-east-1a"]
}

moved {
  from = aws_subnet.private["us-east-1b"]
  to   = aws_subnet.this["private-us-east-1b"]
}

moved {
  from = aws_subnet.private["us-east-1c"]
  to   = aws_subnet.this["private-us-east-1c"]
}

moved {
  from = aws_subnet.private["us-east-1d"]
  to   = aws_subnet.this["private-us-east-1d"]
}

moved {
  from = aws_subnet.private["us-east-1e"]
  to   = aws_subnet.this["private-us-east-1e"]
}

moved {
  from = aws_subnet.private["us-east-1f"]
  to   = aws_subnet.this["private-us-east-1f"]
}

moved {
  from = aws_subnet.private["us-east-2a"]
  to   = aws_subnet.this["private-us-east-2a"]
}

moved {
  from = aws_subnet.private["us-east-2b"]
  to   = aws_subnet.this["private-us-east-2b"]
}

moved {
  from = aws_subnet.private["us-east-2c"]
  to   = aws_subnet.this["private-us-east-2c"]
}

moved {
  from = aws_subnet.private["us-east-2d"]
  to   = aws_subnet.this["private-us-east-2d"]
}

moved {
  from = aws_subnet.private["us-east-2e"]
  to   = aws_subnet.this["private-us-east-2e"]
}

moved {
  from = aws_subnet.private["us-east-2f"]
  to   = aws_subnet.this["private-us-east-2f"]
}

moved {
  from = aws_subnet.private["us-west-1a"]
  to   = aws_subnet.this["private-us-west-1a"]
}

moved {
  from = aws_subnet.private["us-west-1b"]
  to   = aws_subnet.this["private-us-west-1b"]
}

moved {
  from = aws_subnet.private["us-west-1c"]
  to   = aws_subnet.this["private-us-west-1c"]
}

moved {
  from = aws_subnet.private["us-west-1d"]
  to   = aws_subnet.this["private-us-west-1d"]
}

moved {
  from = aws_subnet.private["us-west-1e"]
  to   = aws_subnet.this["private-us-west-1e"]
}

moved {
  from = aws_subnet.private["us-west-1f"]
  to   = aws_subnet.this["private-us-west-1f"]
}

moved {
  from = aws_subnet.private["us-west-2a"]
  to   = aws_subnet.this["private-us-west-2a"]
}

moved {
  from = aws_subnet.private["us-west-2b"]
  to   = aws_subnet.this["private-us-west-2b"]
}

moved {
  from = aws_subnet.private["us-west-2c"]
  to   = aws_subnet.this["private-us-west-2c"]
}

moved {
  from = aws_subnet.private["us-west-2d"]
  to   = aws_subnet.this["private-us-west-2d"]
}

moved {
  from = aws_subnet.private["us-west-2e"]
  to   = aws_subnet.this["private-us-west-2e"]
}

moved {
  from = aws_subnet.private["us-west-2f"]
  to   = aws_subnet.this["private-us-west-2f"]
}

moved {
  from = aws_subnet.private["eu-west-1a"]
  to   = aws_subnet.this["private-eu-west-1a"]
}

moved {
  from = aws_subnet.private["eu-west-1b"]
  to   = aws_subnet.this["private-eu-west-1b"]
}

moved {
  from = aws_subnet.private["eu-west-1c"]
  to   = aws_subnet.this["private-eu-west-1c"]
}

moved {
  from = aws_subnet.private["eu-west-1d"]
  to   = aws_subnet.this["private-eu-west-1d"]
}

moved {
  from = aws_subnet.private["eu-west-1e"]
  to   = aws_subnet.this["private-eu-west-1e"]
}

moved {
  from = aws_subnet.private["eu-west-1f"]
  to   = aws_subnet.this["private-eu-west-1f"]
}

moved {
  from = aws_subnet.private["eu-central-1a"]
  to   = aws_subnet.this["private-eu-central-1a"]
}

moved {
  from = aws_subnet.private["eu-central-1b"]
  to   = aws_subnet.this["private-eu-central-1b"]
}

moved {
  from = aws_subnet.private["eu-central-1c"]
  to   = aws_subnet.this["private-eu-central-1c"]
}

moved {
  from = aws_subnet.private["eu-central-1d"]
  to   = aws_subnet.this["private-eu-central-1d"]
}

moved {
  from = aws_subnet.private["eu-central-1e"]
  to   = aws_subnet.this["private-eu-central-1e"]
}

moved {
  from = aws_subnet.private["eu-central-1f"]
  to   = aws_subnet.this["private-eu-central-1f"]
}

moved {
  from = aws_subnet.private["ap-south-1a"]
  to   = aws_subnet.this["private-ap-south-1a"]
}

moved {
  from = aws_subnet.private["ap-south-1b"]
  to   = aws_subnet.this["private-ap-south-1b"]
}

moved {
  from = aws_subnet.private["ap-south-1c"]
  to   = aws_subnet.this["private-ap-south-1c"]
}

moved {
  from = aws_subnet.private["ap-south-1d"]
  to   = aws_subnet.this["private-ap-south-1d"]
}

moved {
  from = aws_subnet.private["ap-south-1e"]
  to   = aws_subnet.this["private-ap-south-1e"]
}

moved {
  from = aws_subnet.private["ap-south-1f"]
  to   = aws_subnet.this["private-ap-south-1f"]
}

moved {
  from = aws_subnet.private["ap-southeast-1a"]
  to   = aws_subnet.this["private-ap-southeast-1a"]
}

moved {
  from = aws_subnet.private["ap-southeast-1b"]
  to   = aws_subnet.this["private-ap-southeast-1b"]
}

moved {
  from = aws_subnet.private["ap-southeast-1c"]
  to   = aws_subnet.this["private-ap-southeast-1c"]
}

moved {
  from = aws_subnet.private["ap-southeast-1d"]
  to   = aws_subnet.this["private-ap-southeast-1d"]
}

moved {
  from = aws_subnet.private["ap-southeast-1e"]
  to   = aws_subnet.this["private-ap-southeast-1e"]
}

moved {
  from = aws_subnet.private["ap-southeast-1f"]
  to   = aws_subnet.this["private-ap-southeast-1f"]
}

moved {
  from = aws_subnet.private["ap-southeast-2a"]
  to   = aws_subnet.this["private-ap-southeast-2a"]
}

moved {
  from = aws_subnet.private["ap-southeast-2b"]
  to   = aws_subnet.this["private-ap-southeast-2b"]
}

moved {
  from = aws_subnet.private["ap-southeast-2c"]
  to   = aws_subnet.this["private-ap-southeast-2c"]
}

moved {
  from = aws_subnet.private["ap-southeast-2d"]
  to   = aws_subnet.this["private-ap-southeast-2d"]
}

moved {
  from = aws_subnet.private["ap-southeast-2e"]
  to   = aws_subnet.this["private-ap-southeast-2e"]
}

moved {
  from = aws_subnet.private["ap-southeast-2f"]
  to   = aws_subnet.this["private-ap-southeast-2f"]
}

moved {
  from = aws_subnet.private["ap-northeast-1a"]
  to   = aws_subnet.this["private-ap-northeast-1a"]
}

moved {
  from = aws_subnet.private["ap-northeast-1b"]
  to   = aws_subnet.this["private-ap-northeast-1b"]
}

moved {
  from = aws_subnet.private["ap-northeast-1c"]
  to   = aws_subnet.this["private-ap-northeast-1c"]
}

moved {
  from = aws_subnet.private["ap-northeast-1d"]
  to   = aws_subnet.this["private-ap-northeast-1d"]
}

moved {
  from = aws_subnet.private["ap-northeast-1e"]
  to   = aws_subnet.this["private-ap-northeast-1e"]
}

moved {
  from = aws_subnet.private["ap-northeast-1f"]
  to   = aws_subnet.this["private-ap-northeast-1f"]
}

moved {
  from = aws_subnet.database["us-east-1a"]
  to   = aws_subnet.this["database-us-east-1a"]
}

moved {
  from = aws_subnet.database["us-east-1b"]
  to   = aws_subnet.this["database-us-east-1b"]
}

moved {
  from = aws_subnet.database["us-east-1c"]
  to   = aws_subnet.this["database-us-east-1c"]
}

moved {
  from = aws_subnet.database["us-east-1d"]
  to   = aws_subnet.this["database-us-east-1d"]
}

moved {
  from = aws_subnet.database["us-east-1e"]
  to   = aws_subnet.this["database-us-east-1e"]
}

moved {
  from = aws_subnet.database["us-east-1f"]
  to   = aws_subnet.this["database-us-east-1f"]
}

moved {
  from = aws_subnet.database["us-east-2a"]
  to   = aws_subnet.this["database-us-east-2a"]
}

moved {
  from = aws_subnet.database["us-east-2b"]
  to   = aws_subnet.this["database-us-east-2b"]
}

moved {
  from = aws_subnet.database["us-east-2c"]
  to   = aws_subnet.this["database-us-east-2c"]
}

moved {
  from = aws_subnet.database["us-east-2d"]
  to   = aws_subnet.this["database-us-east-2d"]
}

moved {
  from = aws_subnet.database["us-east-2e"]
  to   = aws_subnet.this["database-us-east-2e"]
}

moved {
  from = aws_subnet.database["us-east-2f"]
  to   = aws_subnet.this["database-us-east-2f"]
}

moved {
  from = aws_subnet.database["us-west-1a"]
  to   = aws_subnet.this["database-us-west-1a"]
}

moved {
  from = aws_subnet.database["us-west-1b"]
  to   = aws_subnet.this["database-us-west-1b"]
}

moved {
  from = aws_subnet.database["us-west-1c"]
  to   = aws_subnet.this["database-us-west-1c"]
}

moved {
  from = aws_subnet.database["us-west-1d"]
  to   = aws_subnet.this["database-us-west-1d"]
}

moved {
  from = aws_subnet.database["us-west-1e"]
  to   = aws_subnet.this["database-us-west-1e"]
}

moved {
  from = aws_subnet.database["us-west-1f"]
  to   = aws_subnet.this["database-us-west-1f"]
}

moved {
  from = aws_subnet.database["us-west-2a"]
  to   = aws_subnet.this["database-us-west-2a"]
}

moved {
  from = aws_subnet.database["us-west-2b"]
  to   = aws_subnet.this["database-us-west-2b"]
}

moved {
  from = aws_subnet.database["us-west-2c"]
  to   = aws_subnet.this["database-us-west-2c"]
}

moved {
  from = aws_subnet.database["us-west-2d"]
  to   = aws_subnet.this["database-us-west-2d"]
}

moved {
  from = aws_subnet.database["us-west-2e"]
  to   = aws_subnet.this["database-us-west-2e"]
}

moved {
  from = aws_subnet.database["us-west-2f"]
  to   = aws_subnet.this["database-us-west-2f"]
}

moved {
  from = aws_subnet.database["eu-west-1a"]
  to   = aws_subnet.this["database-eu-west-1a"]
}

moved {
  from = aws_subnet.database["eu-west-1b"]
  to   = aws_subnet.this["database-eu-west-1b"]
}

moved {
  from = aws_subnet.database["eu-west-1c"]
  to   = aws_subnet.this["database-eu-west-1c"]
}

moved {
  from = aws_subnet.database["eu-west-1d"]
  to   = aws_subnet.this["database-eu-west-1d"]
}

moved {
  from = aws_subnet.database["eu-west-1e"]
  to   = aws_subnet.this["database-eu-west-1e"]
}

moved {
  from = aws_subnet.database["eu-west-1f"]
  to   = aws_subnet.this["database-eu-west-1f"]
}

moved {
  from = aws_subnet.database["eu-central-1a"]
  to   = aws_subnet.this["database-eu-central-1a"]
}

moved {
  from = aws_subnet.database["eu-central-1b"]
  to   = aws_subnet.this["database-eu-central-1b"]
}

moved {
  from = aws_subnet.database["eu-central-1c"]
  to   = aws_subnet.this["database-eu-central-1c"]
}

moved {
  from = aws_subnet.database["eu-central-1d"]
  to   = aws_subnet.this["database-eu-central-1d"]
}

moved {
  from = aws_subnet.database["eu-central-1e"]
  to   = aws_subnet.this["database-eu-central-1e"]
}

moved {
  from = aws_subnet.database["eu-central-1f"]
  to   = aws_subnet.this["database-eu-central-1f"]
}

moved {
  from = aws_subnet.database["ap-south-1a"]
  to   = aws_subnet.this["database-ap-south-1a"]
}

moved {
  from = aws_subnet.database["ap-south-1b"]
  to   = aws_subnet.this["database-ap-south-1b"]
}

moved {
  from = aws_subnet.database["ap-south-1c"]
  to   = aws_subnet.this["database-ap-south-1c"]
}

moved {
  from = aws_subnet.database["ap-south-1d"]
  to   = aws_subnet.this["database-ap-south-1d"]
}

moved {
  from = aws_subnet.database["ap-south-1e"]
  to   = aws_subnet.this["database-ap-south-1e"]
}

moved {
  from = aws_subnet.database["ap-south-1f"]
  to   = aws_subnet.this["database-ap-south-1f"]
}

moved {
  from = aws_subnet.database["ap-southeast-1a"]
  to   = aws_subnet.this["database-ap-southeast-1a"]
}

moved {
  from = aws_subnet.database["ap-southeast-1b"]
  to   = aws_subnet.this["database-ap-southeast-1b"]
}

moved {
  from = aws_subnet.database["ap-southeast-1c"]
  to   = aws_subnet.this["database-ap-southeast-1c"]
}

moved {
  from = aws_subnet.database["ap-southeast-1d"]
  to   = aws_subnet.this["database-ap-southeast-1d"]
}

moved {
  from = aws_subnet.database["ap-southeast-1e"]
  to   = aws_subnet.this["database-ap-southeast-1e"]
}

moved {
  from = aws_subnet.database["ap-southeast-1f"]
  to   = aws_subnet.this["database-ap-southeast-1f"]
}

moved {
  from = aws_subnet.database["ap-southeast-2a"]
  to   = aws_subnet.this["database-ap-southeast-2a"]
}

moved {
  from = aws_subnet.database["ap-southeast-2b"]
  to   = aws_subnet.this["database-ap-southeast-2b"]
}

moved {
  from = aws_subnet.database["ap-southeast-2c"]
  to   = aws_subnet.this["database-ap-southeast-2c"]
}

moved {
  from = aws_subnet.database["ap-southeast-2d"]
  to   = aws_subnet.this["database-ap-southeast-2d"]
}

moved {
  from = aws_subnet.database["ap-southeast-2e"]
  to   = aws_subnet.this["database-ap-southeast-2e"]
}

moved {
  from = aws_subnet.database["ap-southeast-2f"]
  to   = aws_subnet.this["database-ap-southeast-2f"]
}

moved {
  from = aws_subnet.database["ap-northeast-1a"]
  to   = aws_subnet.this["database-ap-northeast-1a"]
}

moved {
  from = aws_subnet.database["ap-northeast-1b"]
  to   = aws_subnet.this["database-ap-northeast-1b"]
}

moved {
  from = aws_subnet.database["ap-northeast-1c"]
  to   = aws_subnet.this["database-ap-northeast-1c"]
}

moved {
  from = aws_subnet.database["ap-northeast-1d"]
  to   = aws_subnet.this["database-ap-northeast-1d"]
}

moved {
  from = aws_subnet.database["ap-northeast-1e"]
  to   = aws_subnet.this["database-ap-northeast-1e"]
}

moved {
  from = aws_subnet.database["ap-northeast-1f"]
  to   = aws_subnet.this["database-ap-northeast-1f"]
}

moved {
  from = aws_route_table.private["us-east-1a"]
  to   = aws_route_table.this["private-us-east-1a"]
}

moved {
  from = aws_route_table.private["us-east-1b"]
  to   = aws_route_table.this["private-us-east-1b"]
}

moved {
  from = aws_route_table.private["us-east-1c"]
  to   = aws_route_table.this["private-us-east-1c"]
}

moved {
  from = aws_route_table.private["us-east-1d"]
  to   = aws_route_table.this["private-us-east-1d"]
}

moved {
  from = aws_route_table.private["us-east-1e"]
  to   = aws_route_table.this["private-us-east-1e"]
}

moved {
  from = aws_route_table.private["us-east-1f"]
  to   = aws_route_table.this["private-us-east-1f"]
}

moved {
  from = aws_route_table.private["us-east-2a"]
  to   = aws_route_table.this["private-us-east-2a"]
}

moved {
  from = aws_route_table.private["us-east-2b"]
  to   = aws_route_table.this["private-us-east-2b"]
}

moved {
  from = aws_route_table.private["us-east-2c"]
  to   = aws_route_table.this["private-us-east-2c"]
}

moved {
  from = aws_route_table.private["us-east-2d"]
  to   = aws_route_table.this["private-us-east-2d"]
}

moved {
  from = aws_route_table.private["us-east-2e"]
  to   = aws_route_table.this["private-us-east-2e"]
}

moved {
  from = aws_route_table.private["us-east-2f"]
  to   = aws_route_table.this["private-us-east-2f"]
}

moved {
  from = aws_route_table.private["us-west-1a"]
  to   = aws_route_table.this["private-us-west-1a"]
}

moved {
  from = aws_route_table.private["us-west-1b"]
  to   = aws_route_table.this["private-us-west-1b"]
}

moved {
  from = aws_route_table.private["us-west-1c"]
  to   = aws_route_table.this["private-us-west-1c"]
}

moved {
  from = aws_route_table.private["us-west-1d"]
  to   = aws_route_table.this["private-us-west-1d"]
}

moved {
  from = aws_route_table.private["us-west-1e"]
  to   = aws_route_table.this["private-us-west-1e"]
}

moved {
  from = aws_route_table.private["us-west-1f"]
  to   = aws_route_table.this["private-us-west-1f"]
}

moved {
  from = aws_route_table.private["us-west-2a"]
  to   = aws_route_table.this["private-us-west-2a"]
}

moved {
  from = aws_route_table.private["us-west-2b"]
  to   = aws_route_table.this["private-us-west-2b"]
}

moved {
  from = aws_route_table.private["us-west-2c"]
  to   = aws_route_table.this["private-us-west-2c"]
}

moved {
  from = aws_route_table.private["us-west-2d"]
  to   = aws_route_table.this["private-us-west-2d"]
}

moved {
  from = aws_route_table.private["us-west-2e"]
  to   = aws_route_table.this["private-us-west-2e"]
}

moved {
  from = aws_route_table.private["us-west-2f"]
  to   = aws_route_table.this["private-us-west-2f"]
}

moved {
  from = aws_route_table.private["eu-west-1a"]
  to   = aws_route_table.this["private-eu-west-1a"]
}

moved {
  from = aws_route_table.private["eu-west-1b"]
  to   = aws_route_table.this["private-eu-west-1b"]
}

moved {
  from = aws_route_table.private["eu-west-1c"]
  to   = aws_route_table.this["private-eu-west-1c"]
}

moved {
  from = aws_route_table.private["eu-west-1d"]
  to   = aws_route_table.this["private-eu-west-1d"]
}

moved {
  from = aws_route_table.private["eu-west-1e"]
  to   = aws_route_table.this["private-eu-west-1e"]
}

moved {
  from = aws_route_table.private["eu-west-1f"]
  to   = aws_route_table.this["private-eu-west-1f"]
}

moved {
  from = aws_route_table.private["eu-central-1a"]
  to   = aws_route_table.this["private-eu-central-1a"]
}

moved {
  from = aws_route_table.private["eu-central-1b"]
  to   = aws_route_table.this["private-eu-central-1b"]
}

moved {
  from = aws_route_table.private["eu-central-1c"]
  to   = aws_route_table.this["private-eu-central-1c"]
}

moved {
  from = aws_route_table.private["eu-central-1d"]
  to   = aws_route_table.this["private-eu-central-1d"]
}

moved {
  from = aws_route_table.private["eu-central-1e"]
  to   = aws_route_table.this["private-eu-central-1e"]
}

moved {
  from = aws_route_table.private["eu-central-1f"]
  to   = aws_route_table.this["private-eu-central-1f"]
}

moved {
  from = aws_route_table.private["ap-south-1a"]
  to   = aws_route_table.this["private-ap-south-1a"]
}

moved {
  from = aws_route_table.private["ap-south-1b"]
  to   = aws_route_table.this["private-ap-south-1b"]
}

moved {
  from = aws_route_table.private["ap-south-1c"]
  to   = aws_route_table.this["private-ap-south-1c"]
}

moved {
  from = aws_route_table.private["ap-south-1d"]
  to   = aws_route_table.this["private-ap-south-1d"]
}

moved {
  from = aws_route_table.private["ap-south-1e"]
  to   = aws_route_table.this["private-ap-south-1e"]
}

moved {
  from = aws_route_table.private["ap-south-1f"]
  to   = aws_route_table.this["private-ap-south-1f"]
}

moved {
  from = aws_route_table.private["ap-southeast-1a"]
  to   = aws_route_table.this["private-ap-southeast-1a"]
}

moved {
  from = aws_route_table.private["ap-southeast-1b"]
  to   = aws_route_table.this["private-ap-southeast-1b"]
}

moved {
  from = aws_route_table.private["ap-southeast-1c"]
  to   = aws_route_table.this["private-ap-southeast-1c"]
}

moved {
  from = aws_route_table.private["ap-southeast-1d"]
  to   = aws_route_table.this["private-ap-southeast-1d"]
}

moved {
  from = aws_route_table.private["ap-southeast-1e"]
  to   = aws_route_table.this["private-ap-southeast-1e"]
}

moved {
  from = aws_route_table.private["ap-southeast-1f"]
  to   = aws_route_table.this["private-ap-southeast-1f"]
}

moved {
  from = aws_route_table.private["ap-southeast-2a"]
  to   = aws_route_table.this["private-ap-southeast-2a"]
}

moved {
  from = aws_route_table.private["ap-southeast-2b"]
  to   = aws_route_table.this["private-ap-southeast-2b"]
}

moved {
  from = aws_route_table.private["ap-southeast-2c"]
  to   = aws_route_table.this["private-ap-southeast-2c"]
}

moved {
  from = aws_route_table.private["ap-southeast-2d"]
  to   = aws_route_table.this["private-ap-southeast-2d"]
}

moved {
  from = aws_route_table.private["ap-southeast-2e"]
  to   = aws_route_table.this["private-ap-southeast-2e"]
}

moved {
  from = aws_route_table.private["ap-southeast-2f"]
  to   = aws_route_table.this["private-ap-southeast-2f"]
}

moved {
  from = aws_route_table.private["ap-northeast-1a"]
  to   = aws_route_table.this["private-ap-northeast-1a"]
}

moved {
  from = aws_route_table.private["ap-northeast-1b"]
  to   = aws_route_table.this["private-ap-northeast-1b"]
}

moved {
  from = aws_route_table.private["ap-northeast-1c"]
  to   = aws_route_table.this["private-ap-northeast-1c"]
}

moved {
  from = aws_route_table.private["ap-northeast-1d"]
  to   = aws_route_table.this["private-ap-northeast-1d"]
}

moved {
  from = aws_route_table.private["ap-northeast-1e"]
  to   = aws_route_table.this["private-ap-northeast-1e"]
}

moved {
  from = aws_route_table.private["ap-northeast-1f"]
  to   = aws_route_table.this["private-ap-northeast-1f"]
}

moved {
  from = aws_route_table.database["us-east-1a"]
  to   = aws_route_table.this["database-us-east-1a"]
}

moved {
  from = aws_route_table.database["us-east-1b"]
  to   = aws_route_table.this["database-us-east-1b"]
}

moved {
  from = aws_route_table.database["us-east-1c"]
  to   = aws_route_table.this["database-us-east-1c"]
}

moved {
  from = aws_route_table.database["us-east-1d"]
  to   = aws_route_table.this["database-us-east-1d"]
}

moved {
  from = aws_route_table.database["us-east-1e"]
  to   = aws_route_table.this["database-us-east-1e"]
}

moved {
  from = aws_route_table.database["us-east-1f"]
  to   = aws_route_table.this["database-us-east-1f"]
}

moved {
  from = aws_route_table.database["us-east-2a"]
  to   = aws_route_table.this["database-us-east-2a"]
}

moved {
  from = aws_route_table.database["us-east-2b"]
  to   = aws_route_table.this["database-us-east-2b"]
}

moved {
  from = aws_route_table.database["us-east-2c"]
  to   = aws_route_table.this["database-us-east-2c"]
}

moved {
  from = aws_route_table.database["us-east-2d"]
  to   = aws_route_table.this["database-us-east-2d"]
}

moved {
  from = aws_route_table.database["us-east-2e"]
  to   = aws_route_table.this["database-us-east-2e"]
}

moved {
  from = aws_route_table.database["us-east-2f"]
  to   = aws_route_table.this["database-us-east-2f"]
}

moved {
  from = aws_route_table.database["us-west-1a"]
  to   = aws_route_table.this["database-us-west-1a"]
}

moved {
  from = aws_route_table.database["us-west-1b"]
  to   = aws_route_table.this["database-us-west-1b"]
}

moved {
  from = aws_route_table.database["us-west-1c"]
  to   = aws_route_table.this["database-us-west-1c"]
}

moved {
  from = aws_route_table.database["us-west-1d"]
  to   = aws_route_table.this["database-us-west-1d"]
}

moved {
  from = aws_route_table.database["us-west-1e"]
  to   = aws_route_table.this["database-us-west-1e"]
}

moved {
  from = aws_route_table.database["us-west-1f"]
  to   = aws_route_table.this["database-us-west-1f"]
}

moved {
  from = aws_route_table.database["us-west-2a"]
  to   = aws_route_table.this["database-us-west-2a"]
}

moved {
  from = aws_route_table.database["us-west-2b"]
  to   = aws_route_table.this["database-us-west-2b"]
}

moved {
  from = aws_route_table.database["us-west-2c"]
  to   = aws_route_table.this["database-us-west-2c"]
}

moved {
  from = aws_route_table.database["us-west-2d"]
  to   = aws_route_table.this["database-us-west-2d"]
}

moved {
  from = aws_route_table.database["us-west-2e"]
  to   = aws_route_table.this["database-us-west-2e"]
}

moved {
  from = aws_route_table.database["us-west-2f"]
  to   = aws_route_table.this["database-us-west-2f"]
}

moved {
  from = aws_route_table.database["eu-west-1a"]
  to   = aws_route_table.this["database-eu-west-1a"]
}

moved {
  from = aws_route_table.database["eu-west-1b"]
  to   = aws_route_table.this["database-eu-west-1b"]
}

moved {
  from = aws_route_table.database["eu-west-1c"]
  to   = aws_route_table.this["database-eu-west-1c"]
}

moved {
  from = aws_route_table.database["eu-west-1d"]
  to   = aws_route_table.this["database-eu-west-1d"]
}

moved {
  from = aws_route_table.database["eu-west-1e"]
  to   = aws_route_table.this["database-eu-west-1e"]
}

moved {
  from = aws_route_table.database["eu-west-1f"]
  to   = aws_route_table.this["database-eu-west-1f"]
}

moved {
  from = aws_route_table.database["eu-central-1a"]
  to   = aws_route_table.this["database-eu-central-1a"]
}

moved {
  from = aws_route_table.database["eu-central-1b"]
  to   = aws_route_table.this["database-eu-central-1b"]
}

moved {
  from = aws_route_table.database["eu-central-1c"]
  to   = aws_route_table.this["database-eu-central-1c"]
}

moved {
  from = aws_route_table.database["eu-central-1d"]
  to   = aws_route_table.this["database-eu-central-1d"]
}

moved {
  from = aws_route_table.database["eu-central-1e"]
  to   = aws_route_table.this["database-eu-central-1e"]
}

moved {
  from = aws_route_table.database["eu-central-1f"]
  to   = aws_route_table.this["database-eu-central-1f"]
}

moved {
  from = aws_route_table.database["ap-south-1a"]
  to   = aws_route_table.this["database-ap-south-1a"]
}

moved {
  from = aws_route_table.database["ap-south-1b"]
  to   = aws_route_table.this["database-ap-south-1b"]
}

moved {
  from = aws_route_table.database["ap-south-1c"]
  to   = aws_route_table.this["database-ap-south-1c"]
}

moved {
  from = aws_route_table.database["ap-south-1d"]
  to   = aws_route_table.this["database-ap-south-1d"]
}

moved {
  from = aws_route_table.database["ap-south-1e"]
  to   = aws_route_table.this["database-ap-south-1e"]
}

moved {
  from = aws_route_table.database["ap-south-1f"]
  to   = aws_route_table.this["database-ap-south-1f"]
}

moved {
  from = aws_route_table.database["ap-southeast-1a"]
  to   = aws_route_table.this["database-ap-southeast-1a"]
}

moved {
  from = aws_route_table.database["ap-southeast-1b"]
  to   = aws_route_table.this["database-ap-southeast-1b"]
}

moved {
  from = aws_route_table.database["ap-southeast-1c"]
  to   = aws_route_table.this["database-ap-southeast-1c"]
}

moved {
  from = aws_route_table.database["ap-southeast-1d"]
  to   = aws_route_table.this["database-ap-southeast-1d"]
}

moved {
  from = aws_route_table.database["ap-southeast-1e"]
  to   = aws_route_table.this["database-ap-southeast-1e"]
}

moved {
  from = aws_route_table.database["ap-southeast-1f"]
  to   = aws_route_table.this["database-ap-southeast-1f"]
}

moved {
  from = aws_route_table.database["ap-southeast-2a"]
  to   = aws_route_table.this["database-ap-southeast-2a"]
}

moved {
  from = aws_route_table.database["ap-southeast-2b"]
  to   = aws_route_table.this["database-ap-southeast-2b"]
}

moved {
  from = aws_route_table.database["ap-southeast-2c"]
  to   = aws_route_table.this["database-ap-southeast-2c"]
}

moved {
  from = aws_route_table.database["ap-southeast-2d"]
  to   = aws_route_table.this["database-ap-southeast-2d"]
}

moved {
  from = aws_route_table.database["ap-southeast-2e"]
  to   = aws_route_table.this["database-ap-southeast-2e"]
}

moved {
  from = aws_route_table.database["ap-southeast-2f"]
  to   = aws_route_table.this["database-ap-southeast-2f"]
}

moved {
  from = aws_route_table.database["ap-northeast-1a"]
  to   = aws_route_table.this["database-ap-northeast-1a"]
}

moved {
  from = aws_route_table.database["ap-northeast-1b"]
  to   = aws_route_table.this["database-ap-northeast-1b"]
}

moved {
  from = aws_route_table.database["ap-northeast-1c"]
  to   = aws_route_table.this["database-ap-northeast-1c"]
}

moved {
  from = aws_route_table.database["ap-northeast-1d"]
  to   = aws_route_table.this["database-ap-northeast-1d"]
}

moved {
  from = aws_route_table.database["ap-northeast-1e"]
  to   = aws_route_table.this["database-ap-northeast-1e"]
}

moved {
  from = aws_route_table.database["ap-northeast-1f"]
  to   = aws_route_table.this["database-ap-northeast-1f"]
}
