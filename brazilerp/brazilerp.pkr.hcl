packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    windows-update = {
      version = "0.15.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "temp_compute_name" {
  type = string
}

variable "temp_os_disk_name"{
  type = string
}

variable "temp_nic_name" {
  type = string
}

variable "image_publisher" {
  type = string
}

variable "image_offer" {
  type = string
}

variable "image_sku" {
  type = string
}

variable "location" {
  type = string
}

variable "managed_image_name" {
  type = string
}

variable "managed_image_resource_group_name" {
  type = string
}

variable "image_version" {
  type = string
}

variable "vm_size" {
  type = string
}

source "azure-arm" "windowsvm" {
  async_resourcegroup_delete          = false
  client_id                           = var.client_id
  client_secret                       = var.client_secret
  subscription_id                     = var.subscription_id
  tenant_id                           = var.tenant_id
  build_resource_group_name           = "***"
  temp_compute_name                   = var.temp_compute_name
  temp_nic_name                       = var.temp_nic_name
  temp_os_disk_name                   = var.temp_os_disk_name
  virtual_network_name                = "***"
  virtual_network_subnet_name         = "snet-us1-prd-vdi-01"
  virtual_network_resource_group_name = "***"
  shared_image_gallery {
    subscription = var.subscription_id
    resource_group       = "***"
    gallery_name         = "***"
    image_name           = var.managed_image_name
  }
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = "***"
    gallery_name         = "***"
    image_name           = var.managed_image_name
    image_version        = var.image_version
    replication_regions  = ["eastus","brazilsouth"]
    storage_account_type = "Standard_ZRS"
  }
  os_type                                = "Windows"
  private_virtual_network_with_public_ip = "false"
  vtpm_enabled                           = "true"
  secure_boot_enabled                    = "true"
  vm_size                                = var.vm_size
  communicator                           = "winrm"
  winrm_insecure                         = "true"
  winrm_timeout                          = "3m"
  winrm_use_ssl                          = "true"
  winrm_username                         = "***"
  
}

build {
  sources = ["source.azure-arm.windowsvm"]

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "include:$true"
    ]
    update_limit = 30
  }

  # Restart
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted.'}\""
  }

  provisioner "windows-update" {
    search_criteria = "AutoSelectOnWebSites=0 and IsInstalled=0"
    filters = [
      "include:$true"
    ]
    update_limit = 25
  }

  # Restart
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted.'}\""
  }

  #Clean up Image
  provisioner "powershell" {
    inline = [
      "Write-Host 'Running DISM cleanup-image...'",
      "dism /online /cleanup-image /startcomponentcleanup /resetbase"
    ]
  }

  # Restart
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted.'}\""
  }

  #Deprovision
  provisioner "powershell" {
    inline = [
      " # NOTE: the following *3* lines are only needed if the you have installed the Guest Agent.",
      "  while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "  #while ((Get-Service WindowsAzureTelemetryService).Status -ne 'Running') { Start-Sleep -s 5 }",
      "  while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",

      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }
}