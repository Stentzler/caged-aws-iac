output "rest_api_id" {
  description = "ID of the private REST API."
  value       = aws_api_gateway_rest_api.this.id
}

output "stage_name" {
  description = "Name of the deployed API stage."
  value       = aws_api_gateway_stage.this.stage_name
}

output "resource_path" {
  description = "Resource path exposed by the API."
  value       = aws_api_gateway_resource.route.path
}

output "resource_id" {
  description = "ID of the API Gateway resource exposed by the API."
  value       = aws_api_gateway_resource.route.id
}

output "invoke_url" {
  description = "Private execute-api invoke URL. It is reachable only through the configured VPC endpoint."
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}${aws_api_gateway_resource.route.path}"
}

output "vpc_endpoint_id" {
  description = "ID of the execute-api VPC endpoint allowed by the private API policy."
  value       = aws_vpc_endpoint.execute_api.id
}

output "vpc_endpoint_dns_names" {
  description = "DNS names assigned to the execute-api VPC endpoint."
  value       = aws_vpc_endpoint.execute_api.dns_entry[*].dns_name
}
