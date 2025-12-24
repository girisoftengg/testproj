provider "aws" {
  region = "us-east-1"
}

# Declare the aws_region variable
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"  # You can change this default or pass it explicitly when running terraform apply
}

# Define S3 Bucket name as a variable
variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "strbucket202512"  # Set a default value or override during `terraform apply`
}

# Get existing CloudWatch Log Group
#resource "aws_cloudwatch_log_group" "existing_log_group" {
#  name = "/aws-glue/jobs/logs-v2"
#}
data "aws_cloudwatch_log_group" "existing_log_group" {
  log_group_name = "/aws/glue/jobs/logs-v2"  # Replace with your existing log group name
}

# Create an S3 Bucket to store the Lambda code
resource "aws_s3_bucket" "example_bucket" {
  bucket = "strbucket202512"
}

# Lambda Execution Role with S3 and CloudWatch Logs permissions
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

# Attach both CloudWatch Logs and S3 permissions policy to Lambda execution role
resource "aws_iam_policy" "lambda_permissions_policy" {
  name        = "lambda_permissions_policy"
  description = "Allow Lambda to access S3 and write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs Permissions
      {
        Action   = [
          "logs:CreateLogStream",  # Allows Lambda to create log streams
          "logs:PutLogEvents"      # Allows Lambda to write log events
        ]
        Effect   = "Allow"
        Resource = data.aws_cloudwatch_log_group.existing_log_group.arn
      },
      # S3 Permissions
      {
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/*",  # Dynamically use the bucket name
          "arn:aws:s3:::${var.s3_bucket_name}"
        ]
      }
    ]
  })
}

# Attach the combined policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_permissions_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_permissions_policy.arn
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
  handler       = "lambda_function.lambda_handler" # Make sure this matches your Lambda code's entry point
  runtime       = "python3.8" # Adjust runtime if necessary
  s3_bucket     = aws_s3_bucket.example_bucket.bucket # Use the variable for the S3 bucket name
  s3_key        = "lambda_code.zip"  # Assuming the Lambda code is already uploaded

  depends_on = [aws_iam_role_policy_attachment.lambda_permissions_policy_attachment]
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
    # Remove or comment the next line to accept all formats (no filtering)
    # filter_suffix      = ".txt"  # This line is now removed for all formats
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










