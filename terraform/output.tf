output "linuxvm_master_FQDN" {
  value       = azurerm_public_ip.linuxpip["master"].fqdn
}

output "linuxvm_worker_FQDN" {
  value       = azurerm_public_ip.linuxpip["worker"].fqdn
}

output "linuxvm_username" {
  value       = azurerm_linux_virtual_machine.linuxvm["master"].admin_username 
}

output "linuxvm_password" {
  value       = azurerm_linux_virtual_machine.linuxvm["master"].admin_password
  sensitive = true
}