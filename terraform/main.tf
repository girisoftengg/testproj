provider "aws" {
  region = "us-east-1"
}

# Create an S3 Bucket to store the Lambda code
resource "aws_s3_bucket" "example_bucket" {
  bucket = "strbucket202512"
}

# Declare the aws_caller_identity data source to get account ID
data "aws_caller_identity" "current" {}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_s3_trigger_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# CloudWatch Logs Policy for Lambda
resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "lambda_logs_policy"
  description = "Allow Lambda to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# Attach CloudWatch Logs policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}
# Create the .zip file from lambda.py in the src directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambada"    # Directory containing lambda.py
  output_path = "lambda_code.zip"  # The output .zip file
}

# Upload Lambda .zip code to S3
resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.example_bucket.bucket
  key    = "lambda_code.zip"
  source = data.archive_file.lambda_zip.output_path  # Path to the .zip file created by archive_file

  depends_on = [aws_s3_bucket.example_bucket]  # Ensure the S3 bucket is created first
}

# Create Lambda function
resource "aws_lambda_function" "lambda_s3_trigger" {
  function_name = "lambda_s3_trigger"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  s3_bucket     = aws_s3_bucket.example_bucket.bucket
  s3_key        = "lambda_code.zip"  # Assuming the Lambda code is already uploaded

  depends_on = [aws_s3_bucket.example_bucket]
}

# Add permission for S3 to trigger the Lambda function
resource "aws_lambda_permission" "allow_s3_trigger" {
  statement_id  = "AllowS3Trigger"
  action        = "lambda:InvokeFunction"
  principal     = "s3.amazonaws.com"
  function_name = aws_lambda_function.lambda_s3_trigger.function_name
  source_arn    = aws_s3_bucket.example_bucket.arn
}

# Create S3 notification to trigger Lambda function
resource "aws_s3_bucket_notification" "s3_event_trigger" {
  bucket = aws_s3_bucket.example_bucket.id

  lambda_function {
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".txt"  # Trigger only on .txt files
    lambda_function_arn = aws_lambda_function.lambda_s3_trigger.arn
  }

  depends_on = [aws_lambda_function.lambda_s3_trigger, aws_lambda_permission.allow_s3_trigger]
}

# Outputs
output "lambda_function_name" {
  value = aws_lambda_function.lambda_s3_trigger.function_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.example_bucket.bucket
}



