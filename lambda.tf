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
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Creating an IAM policy for AWS Bedrock
resource "aws_iam_policy" "bedrock_access" {
  name        = "LambdaBedrockInvokePolicy"
  description = "Allows Lambda honeypot to invoke Bedrock foundation models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
  
}

# Attaching the policy to the role
resource "aws_iam_role_policy_attachment" "bedrock_lambda_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

# Defining machine specification
resource "aws_lambda_function" "payload_analyzer" {
  function_name    = "ThreatPayloadAnalyzer"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 30

  # Container image configuration
  package_type = "Image"
  image_uri = "${aws_ecr_repository.threat_analyzer.repository_url}:latest"
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

# AWS lambda permission
resource "aws_lambda_permission" "allow_public_function_url" {
  statement_id           = "AllowPublicInvokeNew"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.payload_analyzer.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# Creating a container repository
resource "aws_ecr_repository" "threat_analyzer" {
  name                 = "threat-payload-analyzer"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}