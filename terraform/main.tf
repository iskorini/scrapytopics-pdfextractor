terraform {
    backend s3 {
        bucket = "schipani-tf-state"
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
    acl    = "private"
}

resource "aws_lambda_function" "pdfextractor_lambda" {
    function_name = var.lambda_function_name
    filename      = "lambda_pdfextractor.zip"
    handler       = "app.pdf_handler"
    runtime       = "python3.12"
    role          = aws_iam_role.lambda_exec.arn
}

resource "aws_iam_role" "lambda_role" { 
    name = "${var.lambda_function_name}_lambda_role"
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

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
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
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdfextractor_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.scrapy_topics_bucket.arn
}

resource "aws_s3_bucket_notification" "s3_to_lambda" {
  bucket = aws_s3_bucket.scrapy_topics_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdfextractor_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "pdf/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}