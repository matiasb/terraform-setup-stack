terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.14.1"
    }
  }
}

// Create OnCall resources

data "grafana_oncall_team" "some_team" {
  provider = grafana
  name     = "Some Team"
}

// Create an escalation chain
resource "grafana_oncall_escalation_chain" "escalation" {
  provider = grafana
  name     = "Escalation chain"
  team_id  = data.grafana_oncall_team.some_team.id
}

resource "grafana_oncall_integration" "prod_alertmanager" {
  provider = grafana
  name     = "Created via terraform"
  type     = "alertmanager"
  team_id  = data.grafana_oncall_team.some_team.id
  default_route {
    escalation_chain_id = grafana_oncall_escalation_chain.escalation.id
  }
}

resource "grafana_oncall_outgoing_webhook" "example_webhook" {
  provider = grafana
  name     = "This is an example"
  url      = "https://example.com/"
}


resource "grafana_oncall_escalation" "notify_schedule" {
  provider = grafana
  escalation_chain_id = grafana_oncall_escalation_chain.escalation.id
  type                = "notify_on_call_from_schedule"
  notify_on_call_from_schedule = grafana_oncall_schedule.primary_schedule.id 
  position            = 1
}

resource "grafana_oncall_schedule" "primary_schedule" {
  provider = grafana
  name               = "Primary"
  type               = "calendar"
  time_zone = "Etc/UTC"
  team_id  = data.grafana_oncall_team.some_team.id
  shifts = [
    grafana_oncall_on_call_shift.primary_shift.id,
  ]
}

locals {
  teams = {
    primary = [
      "matiasb",
    ]
  }

  // OnCall API operates with resources ID's, so we convert emails into ID's to be used later.
  teams_map_of_user_id = { for team_name, username_list in local.teams : team_name => [
    for username in username_list : lookup(data.grafana_oncall_user.all_users, username).id
  ] }
  users_map_by_id = { for username, grafana_oncall_user in data.grafana_oncall_user.all_users : grafana_oncall_user.id => grafana_oncall_user }
}

// Importing all users from OnCall backend as a flat set.
data "grafana_oncall_user" "all_users" {
  provider = grafana
  for_each = toset(flatten([
    for team_name, username_list in local.teams : [
      username_list
    ]
  ]))
  username = each.key
}

resource "grafana_oncall_on_call_shift" "primary_shift" {
  provider = grafana
  name       = "Primary shift"
  type       = "rolling_users"
  start      = "2024-10-28T12:00:00"
  team_id    = data.grafana_oncall_team.some_team.id
  duration   = 60 * 60 * 8 // 8 hours
  frequency  = "weekly"
  interval   = 1
  by_day     = ["MO", "TU", "WE", "TH", "FR"]
  week_start = "MO"
  rolling_users = [for k in flatten([
    local.teams_map_of_user_id.primary,
  ]) : [k]]
}
