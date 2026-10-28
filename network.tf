data "aws_vpc" "selected" { id = var.vpc_id }
data "aws_subnet" "selected" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}
data "aws_route_table" "selected" {
  for_each  = toset(var.private_subnet_ids)
  subnet_id = each.value
}
resource "terraform_data" "network_prerequisites" {
  input = var.private_subnet_ids
  lifecycle {
    precondition {
      condition     = data.aws_vpc.selected.enable_dns_support && data.aws_vpc.selected.enable_dns_hostnames
      error_message = "Private EKS API DNS requires VPC DNS support and hostnames."
    }
    precondition {
      condition     = alltrue([for s in values(data.aws_subnet.selected) : s.vpc_id == var.vpc_id && !s.map_public_ip_on_launch]) && length(distinct([for s in values(data.aws_subnet.selected) : s.availability_zone])) >= 2
      error_message = "Subnets must belong to this VPC, disable automatic public IPs, and span at least two AZs."
    }
    precondition {
      condition     = alltrue(flatten([for t in values(data.aws_route_table.selected) : [for route in t.routes : !startswith(coalesce(route.gateway_id, "none"), "igw-")]]))
      error_message = "Private subnet route tables must not route directly to an internet gateway."
    }
  }
}
