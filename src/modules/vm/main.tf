data "azurerm_subnet" "this" {
  name                 = var.subnet_name
  resource_group_name  = var.subnet_resource_group_name
  virtual_network_name = var.subnet_virtual_network_name
}

resource "random_integer" "this" {
  count = var.virtual_machine_count
  min   = 1000
  max   = 5000
}

resource "azurerm_network_interface" "this" {
  count               = var.virtual_machine_count
  name                = format("%s-nic-%s", var.virtual_machine_name, random_integer.this[count.index].result)
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location

  ip_configuration {
    name                          = format("ipconfig%s", random_integer.this[count.index].result)
    subnet_id                     = data.azurerm_subnet.this.id
    private_ip_address_allocation = "dynamic"
  }

  tags = var.tags
}

resource "azurerm_virtual_machine" "this" {
  count                            = var.virtual_machine_count
  name                             = format("%s%s", var.virtual_machine_name, count.index + 1)
  resource_group_name              = var.resource_group_name
  location                         = var.resource_group_location
  network_interface_ids            = [azurerm_network_interface.this[count.index].id]
  vm_size                          = var.virtual_machine_size
  delete_os_disk_on_termination    = "true"
  delete_data_disks_on_termination = "true"
  license_type                     = "Windows_Server"

  identity {
    type = "SystemAssigned"
  }

  storage_os_disk {
    name              = format("%s_os_disk_1_%s", var.virtual_machine_name, random_integer.this[count.index].result)
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = "128"
    managed_disk_type = "Premium_LRS"
  }

  storage_data_disk {
    name              = format("%s_data_disk_1_%s", var.virtual_machine_name, random_integer.this[count.index].result)
    caching           = "ReadOnly"
    create_option     = "Empty"
    disk_size_gb      = "256"
    lun               = 0
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = format("%s%s", var.os_profile_computer_name, count.index + 1)
    admin_username = var.os_profile_admin_username
    admin_password = var.os_profile_admin_password
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "this" {
  count                = var.virtual_machine_count
  name                 = "AzureDevOpsTools"
  resource_group_name  = var.resource_group_name
  location             = var.resource_group_location
  virtual_machine_name = azurerm_virtual_machine.this[count.index].name
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
  {
  "commandToExecute": "powershell.exe -NonInteractive -ExecutionPolicy Unrestricted Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/gvanderberg/devops-agents/master/windows/Setup-BuildAgent.ps1'))",
  "timestamp" : "12"
  }
SETTINGS

  tags = var.tags
}
