variable "ResourceGroup" {}


# Create virtual network
resource "azurerm_virtual_network" "TFNet" {
    name                = "TFVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "East US"
    resource_group_name = var.ResourceGroup

    tags = {
        environment = "Terraform VNET"
    }
}

# Create network security group 
resource "azurerm_network_security_group" "tfnsg" {
  name                = "LabNSG"
  location            = "East US"
  resource_group_name = var.ResourceGroup
}

#Create NSG inbound rules
resource "azurerm_network_security_rule" "tfinbound1" {
  name                        = "Web80"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "80"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.ResourceGroup
  network_security_group_name = azurerm_network_security_group.tfnsg.name
}

resource "azurerm_network_security_rule" "tfinbound2" {
  name                        = "Web8080"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "8080"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.ResourceGroup
  network_security_group_name = azurerm_network_security_group.tfnsg.name
}

  resource "azurerm_network_security_rule" "tfinbound4" {
  name                        = "SSH"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.ResourceGroup
  network_security_group_name = azurerm_network_security_group.tfnsg.name
}

# Create NSG outbound rules
  resource "azurerm_network_security_rule" "tfoutbound3" {
  name                        = "Web80Out"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "80"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.ResourceGroup
  network_security_group_name = azurerm_network_security_group.tfnsg.name
}

# Create subnet
resource "azurerm_subnet" "tfsubnet" {
    name                 = "ev-terraform-subnet"
    resource_group_name = var.ResourceGroup
    virtual_network_name = azurerm_virtual_network.TFNet.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Associate NSG to subnet
resource "azurerm_subnet_network_security_group_association" "tfnsgassoc" {
  subnet_id                 = azurerm_subnet.tfsubnet.id
  network_security_group_id = azurerm_network_security_group.tfnsg.id
}

# Deploy Public IP
resource "azurerm_public_ip" "tfpip" {
  name                = "ev-terraform-pip1"
  location            = "East US"
  resource_group_name = var.ResourceGroup
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# Create NIC
resource "azurerm_network_interface" "tfnic" {
  name                = "ev-terraform-vm-nic"
  location            = "East US"
  resource_group_name = var.ResourceGroup

    ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.tfsubnet.id
    private_ip_address_allocation  = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tfpip.id
  }
}

# Create Boot Diagnostic Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = "vmdiagnosticsev5"
  resource_group_name      = var.ResourceGroup
  location                 = "East US"
   account_tier            = "Standard"
   account_replication_type = "LRS"

   tags = {
    environment = "Boot Diagnostic Storage"
    CreatedBy = "RockstarEV"
   }
  }

resource "azurerm_storage_container" "tfcontainer" {
  name                  = "terraform-storage-container-ev"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "tfblob" {
  name                   = "terraform-blob-ev"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.tfcontainer.name
  type                   = "Block"
}
resource "azurerm_storage_share" "tfshare" {
  name                 = "terraform-fileshare-ev"  
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 50
}

# Create Virtual Machine
resource "azurerm_virtual_machine" "tfvm5" {
  name                  = "ev-terraform-vm"
  location              = "East US"
  resource_group_name   = var.ResourceGroup
  network_interface_ids = [azurerm_network_interface.tfnic.id]
  vm_size               = "Standard_B1s"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk1"
    disk_size_gb      = "128"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "eviac"
    admin_username = "rockstarev"
    admin_password = "Password12345!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

boot_diagnostics {
        enabled     = "true"
        storage_uri = azurerm_storage_account.sa.primary_blob_endpoint
    }
}