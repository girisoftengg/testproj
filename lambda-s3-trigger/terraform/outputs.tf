output "lambda_function_name" {
  value = aws_lambda_function.lambda_s3_trigger.function_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.example_bucket.bucket
}
