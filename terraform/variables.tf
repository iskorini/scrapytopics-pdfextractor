variable "aws_region" {
    description = "The AWS region to deploy resources in"
    type        = string
    default     = "eu-south-1"
}

variable "scrapy_topics_bucket" {
    description = "The name of the S3 bucket to store the Terraform state file"
    type        = string
    default     = "fschipani-scrapy-topics"
}

variable "lambda_function_name" {
    description = "The name of the Lambda function for PDF extraction"
    type        = string
    default     = "pdfextractor"
}

