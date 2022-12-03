locals {
  project                     = var.project == null ? random_string.project.result : var.project
  environment                 = terraform.workspace == "default" ? var.environment : terraform.workspace
  resource_suffix             = "${local.project}-${local.environment}-${var.region}"
  global_resource_suffix      = "${local.project}-${local.environment}"
  load_balancer_ip_address    = cidrhost(azurerm_subnet.cluster.address_prefixes.0, pow(2, 32 - tonumber(split("/", var.address_space.0).1)) - 2)
  private_link_nat_ip_address = cidrhost(var.address_space.2, pow(2, 32 - tonumber(split("/", var.address_space.2).1)) - 2)
  hostnames = {
    gateway   = "${local.project}-agw.${local.dns_zone_name}"
    frontdoor = "${local.project}-fd.${local.dns_zone_name}"
    api       = "${local.project}-api.${local.dns_zone_name}"
    lbe       = "${local.project}-lbe.${local.dns_zone_name}"
  }
}
