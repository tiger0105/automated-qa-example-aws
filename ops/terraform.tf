# Variables & Providers
# -----------------------------------------------
variable "public_key_path" {
  default = "key.pub"
}
variable "user_data" {
  default = "user_data"
}
variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "us-east-1"
}
variable "amis" {
  type = "map"
  default = {
    "us-east-1" = "ami-2757f631"
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

provider "archive" {}

# VPC, Networking & Security Groups
# -----------------------------------------------
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "default" {
  name        = "automated-qa-webserver"
  description = "webserver ports & ssh"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "automated-qa"
  public_key = "${file(var.public_key_path)}"
}


# EC2 Instances
# -----------------------------------------------
resource "aws_instance" "test-api" {
  tags {
    Name = "test-api"
  }
  ami                    = "${lookup(var.amis, var.region)}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id              = "${aws_subnet.default.id}"
  user_data              = "${file(var.user_data)}"
}
resource "aws_instance" "manager" {
  tags {
    Name = "manager"
  }
  ami                    = "${lookup(var.amis, var.region)}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id              = "${aws_subnet.default.id}"
  user_data              = "${file(var.user_data)}"
}

resource "aws_eip" "test-api" {
  instance = "${aws_instance.test-api.id}"
}
resource "aws_eip" "manager" {
  instance = "${aws_instance.manager.id}"
}

data "archive_file" "test-api-checklist-lambda" {
  type        = "zip"
  source_dir  = "lambda_source"
  output_path = "test-api-checklist.zip"
}
data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "lambda_exec" {
  name               = "lambda_exec"
  assume_role_policy = "${data.aws_iam_policy_document.policy.json}"
}
resource "aws_lambda_function" "test-api-checklist" {
  function_name = "test-api-checklist"

  filename         = "${data.archive_file.test-api-checklist-lambda.output_path}"
  source_code_hash = "${data.archive_file.test-api-checklist-lambda.output_base64sha256}"

  role    = "${aws_iam_role.lambda_exec.arn}"
  handler = "index.handler"
  runtime = "nodejs8.10"

  environment {
    variables = {
      TARGET_ROOT = "${aws_eip.test-api.public_ip}"
    }
  }
}
resource "aws_api_gateway_rest_api" "test-api-checklist" {
  name        = "test-api-checklist"
  description = "text-api-checklist api gateway"
}
resource "aws_api_gateway_resource" "test-api-checklist" {
  rest_api_id = "${aws_api_gateway_rest_api.test-api-checklist.id}"
  parent_id   = "${aws_api_gateway_rest_api.test-api-checklist.root_resource_id}"
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "test-api-checklist" {
  rest_api_id   = "${aws_api_gateway_rest_api.test-api-checklist.id}"
  resource_id   = "${aws_api_gateway_resource.test-api-checklist.id}"
  http_method   = "ANY"
  authorization = "NONE"
}
resource "aws_api_gateway_method" "test-api-checklist-root" {
  rest_api_id   = "${aws_api_gateway_rest_api.test-api-checklist.id}"
  resource_id   = "${aws_api_gateway_rest_api.test-api-checklist.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "test-api-checklist" {
  rest_api_id = "${aws_api_gateway_rest_api.test-api-checklist.id}"
  resource_id = "${aws_api_gateway_method.test-api-checklist.resource_id}"
  http_method = "${aws_api_gateway_method.test-api-checklist.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.test-api-checklist.invoke_arn}"
}
resource "aws_api_gateway_integration" "test-api-checklist-root" {
  rest_api_id = "${aws_api_gateway_rest_api.test-api-checklist.id}"
  resource_id = "${aws_api_gateway_method.test-api-checklist-root.resource_id}"
  http_method = "${aws_api_gateway_method.test-api-checklist-root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.test-api-checklist.invoke_arn}"
}
resource "aws_api_gateway_deployment" "test-api-checklist" {
  depends_on = [
    "aws_api_gateway_integration.test-api-checklist",
    "aws_api_gateway_integration.test-api-checklist-root",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.test-api-checklist.id}"
  stage_name  = "prod"
}
resource "aws_lambda_permission" "text-api-checklist-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test-api-checklist.arn}"
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_deployment.test-api-checklist.execution_arn}/*/*"
}

# Output
# -----------------------------------------------
output "test-api-ip" {
  value = "${aws_eip.test-api.public_ip}"
}
output "manager-ip" {
  value = "${aws_eip.manager.public_ip}"
}
output "text-api-checklist-url" {
  value = "${aws_api_gateway_deployment.test-api-checklist.invoke_url}"
}
