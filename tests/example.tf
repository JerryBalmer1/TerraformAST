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
  #org_service_url = "https://dev.azure.com/jlbalmerjr1"
  #personal_access_token = var.azure_devops_pat
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

/*

Your Mom....

*/

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


