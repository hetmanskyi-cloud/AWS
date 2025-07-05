# --- Lambda Layer Module Outputs --- #
# Exposes key attributes of the created Lambda Layer version.

# --- Layer Version ARN --- #
output "layer_version_arn" {
  description = "The ARN of the created Lambda Layer version. This is used to attach the layer to a Lambda function."
  value       = aws_lambda_layer_version.lambda_layer.arn
}

# --- Notes --- #
# The 'layer_version_arn' is the primary output and should be passed to the 'layers' argument of an 'aws_lambda_function' resource.
