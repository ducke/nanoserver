[CmdletBinding()]
param
(
  [int]$Count,
  [string]$ParentDisk,
  [string]$VMNamePrefix = 'NanoFTW',
  [string]$SwitchName = 'Internal'

)

$CurrentDir = $PWD

$RootVmPath = Join-Path $CurrentDir '\Virtual Machines'

foreach ($i in $Count)
{
  $VmName = '{0}{1}' -f $VMNamePrefix,$i
  Write-Verbose ('Creating VM with name: {0}' -f $VmName)
  #Create the necessary folders
  $VmPath = Join-Path $RootVmPath $VmName
  New-Item -Path $VmPath -ItemType 'Directory'
  $VmPathHd = Join-Path $vmpath 'Virtual Hard Disks'
  New-Item -Path $VmPathHd -ItemType 'Directory'
  #create a VHDX – differencing format
  $VhdPath = Join-Path $VmPathHd 'Vitual Hard DisksDisk0.vhd'
  Write-Verbose ('VHDPath: {0}' -f $VmPath)
  New-VHD -ParentPath $ParentDisk -Differencing -Path $VhdPath

  #Create the VM
  $NewVmPara = @{
    VHDPath = $VhdPath
    Name = $VmName
    Path = $RootVmPath
    SwitchName = $SwitchName
  }
  New-VM @NewVmPara
  #New-VM -VHDPath "$vhdpath" -Name $VmName -Path "$vmpathVirtual Machine" -SwitchName 'ExternalNAT' -WhatIf

  #Configure Dynamic Memory
  $SetVmMem = @{
    VMName = $VmName
    DynamicMemoryEnabled = $true
    MaximumBytes = 8GB
    MinimumBytes = 512MB
    StartupBytes = 1GB
  }
  Set-VMMemory @SetVmMem
  #Set-VMMemory -VMName "VM$i" -DynamicMemoryEnabled $True -MaximumBytes 8GB -MinimumBytes 512MB -StartupBytes 1GB -WhatIf

  #Start the VM

  Start-VM $VmName

  #Add the VM to the cluster

}