output "vpc_endpoint_service_name" {
  value = aws_vpc_endpoint_service.nlb.service_name
}


output "nlb_hostname" {
  value = aws_lb.nlb.dns_name
}
