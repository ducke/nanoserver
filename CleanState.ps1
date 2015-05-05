[CmdletBinding()]
param
(
  [string]$VMNamePrefix = 'Nano'
)

$Vms = Get-VM ('{0}*' -f $VMNamePrefix)

If ([string]::IsNullOrEmpty($Vms))
{
  Write-Warning 'No Vms found! Exit'
  return
}
foreach ($Vm in $Vms)
{
  Stop-VM $Vm -TurnOff -Force
  Remove-VM $Vm -Force
  Remove-Item $Vm.Path -Recurse -Force

}