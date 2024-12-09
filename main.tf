terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.14.1"
    }
  }
}

variable "cloud_token" {
 type = string
 description = "A Grafana Cloud access policy token"
}

variable "users_added" {
 type = bool
 default = false
 description = "Users were added to the stack"
}

// Step 1: Create a new stack
provider "grafana" {
  alias = "cloud"
  cloud_access_policy_token = var.cloud_token
}


resource "grafana_cloud_stack" "my_stack" {
  provider = grafana.cloud

  name        = "matiasbterraformtesting"
  slug        = "matiasbterraformtesting"
  region_slug = "us" # Example "us","eu" etc; update oncall_url accordingly

}

// Step 2: Create a service account and key for the stack
resource "grafana_cloud_stack_service_account" "cloud_sa" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.my_stack.slug

  name        = "satesting"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_cloud_stack_service_account_token" "cloud_sa" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.my_stack.slug

  name               = "terraform serviceaccount key"
  service_account_id = grafana_cloud_stack_service_account.cloud_sa.id
}


// Step 3: Create resources within the stack
provider "grafana" {
  alias = "my_stack"

  url  = grafana_cloud_stack.my_stack.url
  auth = grafana_cloud_stack_service_account_token.cloud_sa.key
  oncall_url  = "https://oncall-prod-us-central-0.grafana.net/oncall/"
}


module "grafana-stack" {
  source = "./grafana/"
  providers = {
    grafana = grafana.my_stack
  }
}

module "oncall" {
  source = "./oncall/"
  count = var.users_added ? 1 : 0
  depends_on = [module.grafana-stack]
  providers = {
    grafana = grafana.my_stack
  }
}
