locals{
  vm_name = toset([
    "master",
    "worker"
  ])
}

data "azurerm_resource_group" "resourcegroup" {
  name     = "${var.username}-k8s101-workshop"
}

resource "azurerm_virtual_network" "linuxvmnetwork" {
  name                = "${var.username}-k8s_network"
  address_space       = ["10.0.0.0/24"]
  location            = data.azurerm_resource_group.resourcegroup.location
  resource_group_name = data.azurerm_resource_group.resourcegroup.name
}

resource "azurerm_subnet" "protectedsubnet" {
  name                 = "protected_subnet"
  resource_group_name  = data.azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.linuxvmnetwork.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_public_ip" "linuxpip" {
  for_each            = local.vm_name
  name                = "${each.key}_pip"
  location            = data.azurerm_resource_group.resourcegroup.location
  resource_group_name = data.azurerm_resource_group.resourcegroup.name
  allocation_method   = "Static"
  domain_name_label   = "${var.username}-${each.key}"
}

resource "azurerm_network_interface" "nic" {
  for_each            = local.vm_name
  name                = "${each.key}-node_nic"
  location            = data.azurerm_resource_group.resourcegroup.location
  resource_group_name = data.azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "${each.key}_ipconfig"
    subnet_id                     = azurerm_subnet.protectedsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linuxpip[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "linuxvm" {
  for_each              = local.vm_name
  name                  = "node-${each.key}"
  resource_group_name   = data.azurerm_resource_group.resourcegroup.name
  location              = data.azurerm_resource_group.resourcegroup.location
  size                  = "Standard_B2s"
  admin_username        = "ubuntu"
  admin_password        = "AdminPassword1234!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
