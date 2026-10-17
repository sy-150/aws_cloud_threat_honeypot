# Reading from a lambda function and outputting a zip file
data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_payload_analyzer.zip"
  
}

# Creating an IAM role with the permissions needed to execute Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "ThreatAnalyzerLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attaching the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Defining machine specification
resource "aws_lambda_function" "payload_analyzer" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ThreatPayloadAnalyzer"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler" # Locates the file containing the lambda_handler and calling said function
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # Calculates ZIP file binary hash to ensure changes will be automatically detected and uploaded to AWS during terraform apply
  runtime          = "python3.11"
  timeout          = 10
}

# Creating the lambda function URL
resource "aws_lambda_function_url" "payload_analyzer_url" {
  function_name      = aws_lambda_function.payload_analyzer.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }
}