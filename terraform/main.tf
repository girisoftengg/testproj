provider "aws" {
  region = "us-east-1"  # Correct region code for N. Virginia
}

resource "aws_s3_bucket" "example_bucket" {
  bucket = "strbucket202512"  # Replace with your unique bucket name
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  description = "Allow Lambda to access S3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.example_bucket.arn}/*",
          "${aws_s3_bucket.example_bucket.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# Create the .zip file from lambda.py in the src directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambada"    # Directory containing lambda.py
  output_path = "lambda_code.zip"  # The output .zip file
}

# Upload Lambda .zip code to S3
resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.example_bucket.bucket
  key    = "lambda_code.zip"
  source = data.archive_file.lambda_zip.output_path  # Path to the .zip file created by archive_file

  depends_on = [aws_s3_bucket.example_bucket]  # Ensure the S3 bucket is created first
}

resource "aws_lambda_function" "lambda_s3_trigger" {
  function_name = "lambda_s3_trigger"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  # Deploy code from the .zip file uploaded to S3
  s3_bucket     = aws_s3_bucket.example_bucket.bucket
  s3_key        = aws_s3_object.lambda_code.key

  depends_on = [aws_s3_bucket.example_bucket]
}

resource "aws_s3_bucket_notification" "s3_event_trigger" {
  bucket = aws_s3_bucket.example_bucket.id

  lambda_function {
    events     = ["s3:ObjectCreated:*"]
    filter_suffix = ".txt"  # Optional: trigger only on .txt files
    lambda_function_arn = aws_lambda_function.lambda_s3_trigger.arn
  }

  depends_on = [aws_lambda_function.lambda_s3_trigger]
}

output "lambda_function_name" {
  value = aws_lambda_function.lambda_s3_trigger.function_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.example_bucket.bucket
}








