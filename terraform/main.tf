#### Terraform Configuration for AWS Lambda and API Gateway ####
terraform {
    backend s3 {
        bucket = "fschipani-tf-state"
        key = "pdfextractor/terraform.tfstate"
        region = "eu-south-1"
        encrypt=true
    }   
}

provider "aws" {
    region = var.aws_region
}

resource "aws_s3_bucket" "scrapy_topics_bucket" {
    bucket = var.scrapy_topics_bucket
    force_destroy = true
}

## LAMBDA ##

resource "aws_lambda_layer_version" "pdfextractor_layer" {
  filename         = "${path.module}/layer.zip"
  layer_name       = "pdfextractor-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash = filebase64sha256("${path.module}/layer.zip")
}

resource "aws_lambda_function" "pdfextractor_lambda" {
  function_name = "pdfextractor"
  filename      = "${path.module}/deployment.zip"
  source_code_hash = filebase64sha256("${path.module}/deployment.zip")
  handler       = "app.pdf_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn
  layers        = [aws_lambda_layer_version.pdfextractor_layer.arn]
  timeout       = 60
  memory_size   = 512
  environment {
    variables = {
      BUCKET_NAME = var.scrapy_topics_bucket
    }
  }
}


resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_policy" "lambda_s3_policy" {
  name = "${var.lambda_function_name}_s3_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.scrapy_topics_bucket.arn,
          "${aws_s3_bucket.scrapy_topics_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

###############################

# API Gateway REST
resource "aws_api_gateway_rest_api" "pdf-api" {
  name = "pdf-api"
}

resource "aws_api_gateway_resource" "extract" {
  rest_api_id = aws_api_gateway_rest_api.pdf-api.id
  parent_id   = aws_api_gateway_rest_api.pdf-api.root_resource_id
  path_part   = "extract"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.pdf-api.id
  resource_id   = aws_api_gateway_resource.extract.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.pdf-api.id
  resource_id             = aws_api_gateway_resource.extract.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.pdfextractor_lambda.invoke_arn
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdfextractor_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.pdf-api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda
    aws_api_gateway_integration.options]
  rest_api_id = aws_api_gateway_rest_api.pdf-api.id
  triggers = {
    redeployment = timestamp()
  }
}

resource "aws_api_gateway_stage" "default" {
  stage_name    = "default"
  rest_api_id   = aws_api_gateway_rest_api.pdf-api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_api_gateway_method" "options" {
  rest_api_id = aws_api_gateway_rest_api.pdf-api.id
  resource_id = aws_api_gateway_resource.extract.id
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id             = aws_api_gateway_rest_api.pdf-api.id
  resource_id             = aws_api_gateway_resource.extract.id
  http_method             = aws_api_gateway_method.options.http_method
  type                    = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_response" {
  depends_on = [aws_api_gateway_integration.options]
  rest_api_id = aws_api_gateway_rest_api.pdf-api.id
  resource_id = aws_api_gateway_resource.extract.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
      "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
      "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
      "method.response.header.Access-Control-Allow-Origin"  = "'*'" # TODO: Change to your domain
    }

  response_templates = {
    "application/json" = ""
  }
}


resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.pdf-api.id
  resource_id = aws_api_gateway_resource.extract.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}