locals {
  enabled          = module.this.enabled
  managed_policies = [for arn in var.iam_policies : arn if can(regex("^arn:aws[^:]*:iam::aws:policy/", arn))]
  policies         = length(local.managed_policies) > 0 ? local.managed_policies : null
  policy_document_map = {
    "gitops"        = local.gitops_policy
    "lambda_cicd"   = local.lambda_cicd_policy
    "inline_policy" = one(module.iam_policy.*.json)
  }
  custom_policy_map = merge(local.policy_document_map, local.overridable_additional_custom_policy_map)

  # Ignore empty policies of the form `"{}"` as well as null policies
  active_policy_map = { for k, v in local.custom_policy_map : k => v if try(length(v), 0) > 3 }
}

module "iam_policy" {
  enabled = local.enabled && length(var.iam_policy) > 0

  source  = "cloudposse/iam-policy/aws"
  version = "2.0.2"

  iam_policy = var.iam_policy

  context = module.this.context
}

module "gha_assume_role" {
  source = "../account-map/modules/team-assume-role-policy"

  trusted_github_repos = var.github_actions_allowed_repos

  context = module.this.context
}

module "github_oidc_role" {
  source  = "cloudposse/iam-role/aws"
  version = "0.22.0"

  assume_role_policy   = module.gha_assume_role.github_assume_role_policy
  role_description     = var.role_description
  max_session_duration = var.max_session_duration
  managed_policy_arns  = toset(coalesce(local.policies, []))
  use_fullname         = var.use_fullname
  # Disable the module's built-in policy creation; inline policies are managed
  # separately via aws_iam_role_policy resources to support multiple named policies.
  policy_document_count = 0

  context = module.this.context
}

resource "aws_iam_role_policy" "default" {
  for_each = local.enabled ? local.active_policy_map : {}

  name   = each.key
  role   = module.github_oidc_role.name
  policy = each.value
}
