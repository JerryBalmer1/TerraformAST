# example.tf

terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">=0.1.0"
    }
  }
}

# Providers
provider "azurerm" {
  features {}
}

provider "azuredevops" {

}

resource "azuredevops_project" "example" {
  name               = "Example Project"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
}

resource "azuredevops_build_folder" "example" {
  project_id  = azuredevops_project.example.id
  path        = "\\ExampleFolder"
  description = "ExampleFolder description"
}


output "hello" {
  value = "asdf"
}

variable "somevariable" {
  default = "qwer"
}

data "azuredevops_projects" "example" {
  name  = "Example Project"
  state = "wellFormed"
}


