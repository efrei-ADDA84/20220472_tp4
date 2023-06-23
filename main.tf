provider "azurerm" {
  features {}
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  default     = "765266c6-9a23-4638-af32-dd1e32613047"
}

variable "azure_resource_group" {
  description = "Azure Resource Group"
  default     = "ADDA84-CTP"
}

variable "azure_location" {
  description = "Azure Location"
  default     = "francecentral"
}

variable "vm_name" {
  description = "Azure VM Name"
  default     = "devops-20220472"

}

variable "vm_size" {
  description = "Azure VM Size"
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Admin Username"
  default     = "devops"
}


variable "subnet_id" {
  description = "Subnet ID"
  default     = null
}

data "azurerm_subnet" "subnet" {
  name                 = "internal"
  virtual_network_name = "network-tp4"
  resource_group_name  = var.azure_resource_group
}


locals {
  subnet_id = data.azurerm_subnet.subnet.id
}


resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = var.azure_location
  resource_group_name = var.azure_resource_group

  ip_configuration {
    name                          = "${var.vm_name}-ipconfig"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}


variable "os_disk_size_gb" {
  description = "OS Disk Size (in GB)"
  default     = 30
}

resource "tls_private_key" "ssh_key" {
  algorithm   = "RSA"
  rsa_bits    = 4096
}

output "public_key" {
  value = tls_private_key.ssh_key.public_key_openssh
}

output "private_key" {
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}



resource "azurerm_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = var.azure_location
  resource_group_name   = var.azure_resource_group
  network_interface_ids = [azurerm_network_interface.nic.id]

  vm_size           = var.vm_size
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.vm_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = var.os_disk_size_gb
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    custom_data    = filebase64("cloud-init.txt")
  }

  os_profile_linux_config {
  disable_password_authentication = true

  ssh_keys {
    path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    key_data = tls_private_key.ssh_key.public_key_openssh
  }
}

  
}