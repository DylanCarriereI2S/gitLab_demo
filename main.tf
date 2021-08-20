terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 4
}

# Bucket to upload lambda code
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  acl           = "private"
  force_destroy = true
}

# Create backend zip file code to upload s3
data "archive_file" "lambdas_code" {
  type = "zip"

  source_dir  = "${path.module}/backend/src"
  output_path = "${path.module}/backend/code.zip"
}

# Create DynamoDB table "Todo"
resource "aws_dynamodb_table" "todo_database" {
  name             = "todoDatabase"
  hash_key         = "PK"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  attribute {
    name = "PK"
    type = "S"
  }

}

# Create one item in the Table
resource "aws_dynamodb_table_item" "first_todo" {
  table_name = aws_dynamodb_table.todo_database.name
  hash_key   = aws_dynamodb_table.todo_database.hash_key

  item = <<ITEM
{
  "PK": {"S": "first-uuid"},
  "content": {"S": "Todo from my Dynamodb Table"},
  "completed": {"BOOL": false}
}
ITEM
}

# Upload backend lambda code to S3 
resource "aws_s3_bucket_object" "backend_code" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "code.zip"
  source = data.archive_file.lambdas_code.output_path

  etag = filemd5(data.archive_file.lambdas_code.output_path)
}

# Create lambda getTodos
resource "aws_lambda_function" "get-todos" {
  function_name = "GetTodos"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.backend_code.key

  runtime = "nodejs12.x"
  handler = "get-todos.handler"

  source_code_hash = data.archive_file.lambdas_code.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TODO_TABLE = aws_dynamodb_table.todo_database.id
    }
  }
}

# Create lambda postTodos
resource "aws_lambda_function" "post-todo" {
  function_name = "PostTodo"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.backend_code.key

  runtime = "nodejs12.x"
  handler = "post-todo.handler"

  source_code_hash = data.archive_file.lambdas_code.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TODO_TABLE = aws_dynamodb_table.todo_database.id
    }
  }
}

# Create lambda deleteTodos
resource "aws_lambda_function" "delete-todo" {
  function_name = "DeleteTodo"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.backend_code.key

  runtime = "nodejs12.x"
  handler = "delete-todo.handler"

  source_code_hash = data.archive_file.lambdas_code.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TODO_TABLE = aws_dynamodb_table.todo_database.id
    }
  }
}

resource "aws_lambda_function" "option-todo" {
  function_name = "OptionTodo"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.backend_code.key

  runtime = "nodejs12.x"
  handler = "option-todo.handler"

  source_code_hash = data.archive_file.lambdas_code.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

}

# Create backend lambda role
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

# Create Database policy for Todo table
resource "aws_iam_policy" "database_policy" {
  name        = "todoDatabasePolicy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_dynamodb_table.todo_database.arn}",
        "${aws_dynamodb_table.todo_database.arn}/*"
      ]
    }
  ]
}
EOF
}

# Attach policy to the Iam role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach policy to the Iam role
resource "aws_iam_role_policy_attachment" "tado_Database_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.database_policy.arn
}

# Create API Gateway
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

# Create API Gateway stage
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "dev"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# Create API Gateway integration
resource "aws_apigatewayv2_integration" "get-todos" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get-todos.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Create API Gateway integration
resource "aws_apigatewayv2_integration" "post-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.post-todo.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Create API Gateway integration
resource "aws_apigatewayv2_integration" "delete-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.delete-todo.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "option-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.option-todo.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Create API Gateway route
resource "aws_apigatewayv2_route" "get-todos" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /todo"
  target    = "integrations/${aws_apigatewayv2_integration.get-todos.id}"
}

# Create API Gateway integration
resource "aws_apigatewayv2_route" "post-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /todo"
  target    = "integrations/${aws_apigatewayv2_integration.post-todo.id}"
}

# Create API Gateway integration
resource "aws_apigatewayv2_route" "delete-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /todo"
  target    = "integrations/${aws_apigatewayv2_integration.delete-todo.id}"
}

# Create API Gateway integration
resource "aws_apigatewayv2_route" "option-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "OPTIONS /todo"
  target    = "integrations/${aws_apigatewayv2_integration.option-todo.id}"
}

# Create API Gateway integration
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

# Create API Gateway trigger for lambda
resource "aws_lambda_permission" "api_gw_getTodos" {
  statement_id  = "AllowExecutionFromAPIGatewayGetTodos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-todos.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Create API Gateway trigger for lambda
resource "aws_lambda_permission" "api_gw_postTodo" {
  statement_id  = "AllowExecutionFromAPIGatewayPostTodo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post-todo.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Create API Gateway trigger for lambda
resource "aws_lambda_permission" "api_gw_deleteTodo" {
  statement_id  = "AllowExecutionFromAPIGatewayDeleteTodo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete-todo.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Create API Gateway trigger for lambda
resource "aws_lambda_permission" "api_gw_optionTodo" {
  statement_id  = "AllowExecutionFromAPIGatewayOptionTodo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.option-todo.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Edit 'environements.terraform.ts' file to pass API URL to frontend 
resource "local_file" "environment_frontend_apiurl" {
  content     = <<EOF
  export const environment = {
    production: false,
    apiUrl: '${aws_apigatewayv2_stage.lambda.invoke_url}'
  };
  EOF
  filename = "${path.module}/frontend/todolistapp-v1/src/environments/environements.terraform.ts"
}
