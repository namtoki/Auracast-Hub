# Location Module Outputs

output "place_index_name" {
  description = "Place Index name"
  value       = aws_location_place_index.main.index_name
}

output "place_index_arn" {
  description = "Place Index ARN"
  value       = aws_location_place_index.main.index_arn
}

output "map_name" {
  description = "Map name"
  value       = aws_location_map.main.map_name
}

output "map_arn" {
  description = "Map ARN"
  value       = aws_location_map.main.map_arn
}

output "geofence_collection_name" {
  description = "Geofence Collection name"
  value       = aws_location_geofence_collection.main.collection_name
}

output "geofence_collection_arn" {
  description = "Geofence Collection ARN"
  value       = aws_location_geofence_collection.main.collection_arn
}

output "tracker_name" {
  description = "Tracker name"
  value       = aws_location_tracker.main.tracker_name
}

output "tracker_arn" {
  description = "Tracker ARN"
  value       = aws_location_tracker.main.tracker_arn
}

output "route_calculator_name" {
  description = "Route Calculator name"
  value       = aws_location_route_calculator.main.calculator_name
}

output "location_access_policy_arn" {
  description = "Location access policy ARN"
  value       = aws_iam_policy.location_access.arn
}
