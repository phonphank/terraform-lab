# Configure the Microsoft Azure Provider
provider "azurerm" {
	subscription_id = "8afbe872-4126-415f-bbf5-59890b64e029"
	client_id = "7838c180-37d1-4ef8-a13b-b872a00d5c96"
	client_secret = "1R3a43RH=hR=@A[H4_3I?xpQIjB9.6y="
	tenant_id = "6e06e42d-6925-47c6-b9e7-9581c7ca302a"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "plew" {
    name     = "${var.prefix}"
    location = "eastus"

    tags = {
        environment = "Terraform Plew Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "plewnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.plew.name

    tags = {
        environment = "Terraform Plew Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "plewsubnet" {
    name                 = "plewSubnet"
    resource_group_name  = azurerm_resource_group.plew.name
    virtual_network_name = azurerm_virtual_network.plewnetwork.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "plewpublicip" {
    name                         = "plewPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.plew.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Plew Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "plewnsg" {
    name                = "plewNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.plew.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Plew Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "plewnic" {
    name                      = "plewNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.plew.name
    network_security_group_id = azurerm_network_security_group.plewnsg.id

    ip_configuration {
        name                          = "plewNicConfiguration"
        subnet_id                     = azurerm_subnet.plewsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.plewpublicip.id
    }

    tags = {
        environment = "Terraform Plew Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.plew.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "plewstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.plew.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Plew Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "plewvm" {
    name                  = "plewVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.plew.name
    network_interface_ids = [azurerm_network_interface.plewnic.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "plewOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.5"
        version   = "latest"
    }

    os_profile {
        computer_name  = "plewvm"
        admin_username = "plew"
        admin_password = "P@ssw0rd1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.plewstorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform plew"
    }
}
