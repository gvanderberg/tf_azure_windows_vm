provider "azurerm" {
  version = "~>1.41.0"
}

provider "random" {
  version = "~>2.2.1"
}

terraform {
  required_version = "~>0.12.0"
  backend "remote" {}
}
