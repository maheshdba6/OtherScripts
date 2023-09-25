Skip to content
 Enterprise
Search or jump to…
Pull requests
Issues
Explore
 
@prashant-dixit 
fitb-edm-dba
/
prashant_lambdas
Public
Code
Issues
Pull requests
Projects
Wiki
Security
Insights
Settings
prashant_lambdas/main.tf
@prashant-dixit
prashant-dixit Update main.tf
Latest commit d287f37 4 days ago
 History
 1 contributor
281 lines (254 sloc)  8.17 KB

##################################################################################
# DATA INPUTS
##################################################################################
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
##################################################################################
# RESOURCES
##################################################################################

locals {
  common-tags = {}

  environment_map = var.environment_variables[*]
  kms_key_arn     = (var.environment_variables == null && var.kms_key_arn == null) ? null : var.kms_key_arn

  lambda_execution_role_name = (var.lambda_role_name == "") ? "${var.function_name}_iam_for_auth_lambda" : var.lambda_role_name
  create_execution_role = (var.lambda_role_name == "") ? "true" : "true"
}




resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}

output "execution_role_vale" {
  value = "${local.create_execution_role}"
}
# IAM roles and Policies
# Standard AWS trust policy allowing lambda to assume role
resource "aws_iam_role" "lambda_role" {
  count      = (local.create_execution_role == "true") ? 1 : 0
  name       = local.lambda_execution_role_name
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/pubcloud/AppTeamIAMBoundary"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "assume_role_policy" {
   count      = (local.create_execution_role == "true") ? 1 : 0
   name        = "lambda-${var.function_name}-assume_role_policy"
   path        = "/"
   description = "IAM policy for assume role"
   policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:*",
            "s3-object-lambda:*"
        ],
        "Resource": "*"
    },
    {
        "Sid": "LambdaCrossAccount",
        "Effect": "Allow",
        "Action": "sts:AssumeRole",
        "Resource": "arn:aws:iam::009973789139:role/list-org-accounts"
    },
    {
        "Sid": "LambdaCrossAccountRDSRole",
        "Effect": "Allow",
        "Action": "sts:AssumeRole",
        "Resource": "arn:aws:iam::*:role/edm/LambdaCrossAccountFunctionRole"
    },
    {
        "Sid": "LambdaCrossAccountDev",
        "Effect": "Allow",
        "Action": "sts:AssumeRole",
        "Resource": "arn:aws:iam::*:role/EDMCrossAccountRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "assume_role_policy_attachment" {
  count      = (local.create_execution_role == "true") ? 1 : 0
  role       = local.lambda_execution_role_name
  policy_arn = aws_iam_policy.assume_role_policy[count.index].arn
  depends_on = [aws_iam_policy.assume_role_policy, aws_iam_role.lambda_role]
}  

resource "aws_iam_policy" "rds_policy" {
  name        = "lambda-${var.function_name}-rds_policy"
  path        = "/"
  description = "IAM policy for reading from a rds"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "RDSReadAccess",
        "Effect": "Allow",
        "Action": "rds:Describe*",
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "rds_policy_attachment" {
  role       = local.lambda_execution_role_name
  policy_arn = aws_iam_policy.rds_policy.arn
  depends_on = [aws_iam_policy.rds_policy, aws_iam_role.lambda_role]
}

resource "aws_iam_policy" "s3_policy" {
  name        = "lambda-${var.function_name}-s3_policy"
  path        = "/"
  description = "IAM policy for full access to s3"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "s3-object-lambda:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = local.lambda_execution_role_name
  policy_arn = aws_iam_policy.s3_policy.arn
  depends_on = [aws_iam_policy.s3_policy, aws_iam_role.lambda_role]
}

resource "aws_iam_policy" "secret_manageer_policy" {
  name        = "lambda-${var.function_name}-secret_manageer_policy"
  path        = "/"
  description = "IAM policy for reading secrets from secrets manager"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "DescribeRDSsecret",
        "Effect": "Allow",
        "Action": [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
        ],
        "Resource": [
            "arn:aws:secretsmanager:*:*:secret:*/*rds-password*",
            "*"
        ]
    },
    {
        "Sid": "ListSecrets",
        "Effect": "Allow",
        "Action": [
            "secretsmanager:GetRandomPassword",
            "secretsmanager:CreateSecret",
            "secretsmanager:ListSecrets"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "secret_manageer_policy_attachment" {
  role       = local.lambda_execution_role_name
  policy_arn = aws_iam_policy.secret_manageer_policy.arn
  depends_on = [aws_iam_policy.secret_manageer_policy, aws_iam_role.lambda_role]
}

data "aws_iam_policy" "managed_lambda_basic_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "aws_iam_policy" "managed_lambda_vpc_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# attach the basic role if there are no subnet attachments
resource "aws_iam_role_policy_attachment" "role_managed_policy_attachment" {
  count      = length(var.subnet_ids) == 0 ? 1 : 0
  role       = local.lambda_execution_role_name
  policy_arn = data.aws_iam_policy.managed_lambda_basic_policy.arn
  depends_on = [aws_iam_role.lambda_role]
}

# attach the vpc role if subnet attachments are needed
resource "aws_iam_role_policy_attachment" "role_managed_vpc_policy_attachment" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = local.lambda_execution_role_name
  policy_arn = data.aws_iam_policy.managed_lambda_vpc_policy.arn
  depends_on = [aws_iam_role.lambda_role]
}


resource "aws_lambda_function" "new_lambda" {
  function_name    = var.function_name
  filename         = var.file_name
  handler          = var.handler
  memory_size      = 10240
  role             = aws_iam_role.lambda_role[0].arn
  runtime          = var.python_runtime
  source_code_hash = filebase64sha256(var.file_name)
  timeout          = var.timeout
  layers           = length(var.layer_arns) > 0 ? var.layer_arns : []
  kms_key_arn      = local.kms_key_arn
  reserved_concurrent_executions = var.reserved_concurrent_executions 
  vpc_config {
    security_group_ids = var.security_group_ids                #var.security_group_ids
    subnet_ids         = [for value in var.subnet_ids : value] #var.subnet_ids
  }
  dynamic "environment" {
    for_each = local.environment_map
    content {
      variables = environment.value
    }
  }
  tracing_config {
    mode = "Active"
  }
  ephemeral_storage {
    size = 10240 # Min 512 MB and the Max 10240 MB
  }
  depends_on = [aws_iam_role.lambda_role]
}

# lambda insights
resource "aws_iam_role_policy_attachment" "insights_policy" {
  role       = local.lambda_execution_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  depends_on = [aws_iam_role.lambda_role]
}

# lambda Xray
resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access" {
  role       = local.lambda_execution_role_name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  depends_on = [aws_iam_role.lambda_role]
}

resource "aws_lambda_permission" "lambda_permissions" {
  for_each      = toset(var.invoke_function_principal)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.new_lambda.function_name
  principal     = each.value
  depends_on = [aws_iam_role.lambda_role]
}
Footer5/3 Bank
5/3 Bank
5/3 Bank
© 2023 GitHub, Inc.
Footer navigation
Help
Support
API
Training
Blog
About
GitHub Enterprise Server 3.7.11
You have no unread notifications
