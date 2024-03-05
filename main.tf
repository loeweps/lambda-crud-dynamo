terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

#Create a dynamoDb table to hold items
resource "aws_dynamodb_table" "crud_table" {
  name           = "crud-http-items"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "userid"
}


#Create role for Lambda to assume
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Create a role for Lambda function to stop EC2 instances
resource "aws_iam_role" "dynamo_crud_role" {
  name               = "dynamo-crud-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

#Lambda start package
data "archive_file" "dynamo_mjs" {  
  type = "zip"  
  source_file = "./code/index.mjs" 
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "crud_function" {
  function_name = "dynamo-crud-function"
  role          = aws_iam_role.dynamo_crud_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "lambda_function.zip"
}

resource "aws_iam_policy" "dynamodb_access_policy" {
  name        = "DynamoDbAccessPolicy"
  description = "Policy granting permissions to interact with MongoDB"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Resource  = "arn:aws:dynamodb:*:*:table/crud-http-items"
      },
      {
        Effect    = "Allow",
        Action    = "execute-api:Invoke",
        Resource  = "arn:aws:execute-api:*:*:*"
      }
    ]
  })
}

# Attach the db access policy to the role
resource "aws_iam_policy_attachment" "dynamodb_policy_attachment" {
  name       = "dynamodb-policy-attachment"
  roles      = [aws_iam_role.dynamo_crude_role.name]
  policy_arn = aws_iam_policy.dynamodb_access_policy.arn
}

resource "aws_apigatewayv2_api" "crud_api" {
  name          = "crud-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "get_item_id" {
  api_id    = aws_apigatewayv2_api.crud_api.id
  route_key = "GET /items/{id}"
}

resource "aws_apigatewayv2_route" "get_items" {
  api_id    = aws_apigatewayv2_api.crud_api.id
  route_key = "GET /items"
}

resource "aws_apigatewayv2_route" "put_items" {
  api_id    = aws_apigatewayv2_api.crud_api.id
  route_key = "PUT /items"
}

resource "aws_apigatewayv2_route" "delete_item_id" {
  api_id    = aws_apigatewayv2_api.crud_api.id
  route_key = "DELETE /items/{id}"
}

resource "aws_api_gatewayv2_integration" "integration1" {
  api_id               = aws_api_gatewayv2_api.example_api.id
  integration_type     = "HTTP_PROXY"
  integration_uri      = "http://example.com/resource1"
  integration_method   = "GET"
  connection_type      = "INTERNET"
  payload_format_version = "2.0"
}


