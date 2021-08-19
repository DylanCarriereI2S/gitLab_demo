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

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  acl           = "private"
  force_destroy = true
}

data "archive_file" "lambdas_code" {
  type = "zip"

  source_dir  = "${path.module}/backend/src"
  output_path = "${path.module}/backend/code.zip"
}

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

resource "aws_s3_bucket_object" "backend_code" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "code.zip"
  source = data.archive_file.lambdas_code.output_path

  etag = filemd5(data.archive_file.lambdas_code.output_path)
}

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

resource "aws_cloudwatch_log_group" "hello_world" {
  name = "/aws/lambda/${aws_lambda_function.get-todos.function_name}"

  retention_in_days = 30
}

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

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "tado_Database_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.database_policy.arn
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

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

resource "aws_apigatewayv2_integration" "get-todos" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get-todos.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "post-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.post-todo.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "delete-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.delete-todo.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}


resource "aws_apigatewayv2_route" "get-todos" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /get-todos"
  target    = "integrations/${aws_apigatewayv2_integration.get-todos.id}"
}

resource "aws_apigatewayv2_route" "post-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /post-todo"
  target    = "integrations/${aws_apigatewayv2_integration.post-todo.id}"
}

resource "aws_apigatewayv2_route" "delete-todo" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /delete-todo"
  target    = "integrations/${aws_apigatewayv2_integration.delete-todo.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_getTodos" {
  statement_id  = "AllowExecutionFromAPIGatewayGetTodos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-todos.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_postTodo" {
  statement_id  = "AllowExecutionFromAPIGatewayPostTodo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post-todo.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_deleteTodo" {
  statement_id  = "AllowExecutionFromAPIGatewayDeleteTodo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete-todo.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# data "external" "frontend_build" {
#   program = ["bash", "-c", <<EOT
# (npm ci && npm run build -- --env.PARAM="$(jq -r '.param')") >&2 && echo "{\"dest\": \"dist\"}"
#   EOT
#   ]
#   working_dir = "${path.module}/frontend/todolistapp-v1"
#   query = {
#     param = "Hi from Terraform!"
#   }
# }