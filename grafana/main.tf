terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.15.0"
    }
  }
}

// Create a team
resource "grafana_team" "some_team" {
  provider = grafana
  name = "Some Team"
  members = []
}

resource "grafana_folder" "my_folder" {
  provider = grafana

  title = "Test Folder"
}
