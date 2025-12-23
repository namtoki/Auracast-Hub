# Auracast Hub - Location Module (Amazon Location Service)

# ============================================================================
# Place Index (Geocoding)
# ============================================================================

resource "aws_location_place_index" "main" {
  index_name  = "${var.name_prefix}-places"
  data_source = "Esri"

  data_source_configuration {
    intended_use = "SingleUse"
  }

  tags = {
    Name = "${var.name_prefix}-place-index"
  }
}

# ============================================================================
# Map
# ============================================================================

resource "aws_location_map" "main" {
  map_name = "${var.name_prefix}-map"

  configuration {
    style = "VectorEsriNavigation"
  }

  tags = {
    Name = "${var.name_prefix}-map"
  }
}

# ============================================================================
# Geofence Collection (Optional - for area notifications)
# ============================================================================

resource "aws_location_geofence_collection" "main" {
  collection_name = "${var.name_prefix}-geofences"

  tags = {
    Name = "${var.name_prefix}-geofence-collection"
  }
}

# ============================================================================
# Tracker (Optional - for real-time location tracking)
# ============================================================================

resource "aws_location_tracker" "main" {
  tracker_name = "${var.name_prefix}-tracker"

  position_filtering = "TimeBased"

  tags = {
    Name = "${var.name_prefix}-tracker"
  }
}

# Link Tracker to Geofence Collection
resource "aws_location_tracker_association" "main" {
  consumer_arn = aws_location_geofence_collection.main.collection_arn
  tracker_name = aws_location_tracker.main.tracker_name
}

# ============================================================================
# Route Calculator
# ============================================================================

resource "aws_location_route_calculator" "main" {
  calculator_name = "${var.name_prefix}-routes"
  data_source     = "Esri"

  tags = {
    Name = "${var.name_prefix}-route-calculator"
  }
}

# ============================================================================
# IAM Policy for Location Service Access
# ============================================================================

resource "aws_iam_policy" "location_access" {
  name        = "${var.name_prefix}-location-access"
  description = "Policy for accessing Amazon Location Service resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "geo:SearchPlaceIndexForPosition",
          "geo:SearchPlaceIndexForText",
          "geo:SearchPlaceIndexForSuggestions"
        ]
        Resource = aws_location_place_index.main.index_arn
      },
      {
        Effect = "Allow"
        Action = [
          "geo:GetMapTile",
          "geo:GetMapStyleDescriptor",
          "geo:GetMapSprites",
          "geo:GetMapGlyphs"
        ]
        Resource = aws_location_map.main.map_arn
      },
      {
        Effect = "Allow"
        Action = [
          "geo:GetGeofence",
          "geo:ListGeofences",
          "geo:PutGeofence",
          "geo:BatchDeleteGeofence",
          "geo:BatchPutGeofence",
          "geo:BatchEvaluateGeofences"
        ]
        Resource = aws_location_geofence_collection.main.collection_arn
      },
      {
        Effect = "Allow"
        Action = [
          "geo:GetDevicePosition",
          "geo:GetDevicePositionHistory",
          "geo:BatchGetDevicePosition",
          "geo:BatchUpdateDevicePosition"
        ]
        Resource = aws_location_tracker.main.tracker_arn
      },
      {
        Effect = "Allow"
        Action = [
          "geo:CalculateRoute",
          "geo:CalculateRouteMatrix"
        ]
        Resource = aws_location_route_calculator.main.calculator_arn
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-location-policy"
  }
}
