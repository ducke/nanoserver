[CmdletBinding()]
param
(
  [string]$IsoPath = 'C:\Downloads\en_windows_server_technical_preview_2_x64_dvd_6651466.iso',
  [string]$WorkingDir = (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().tostring())),
  [Parameter(Mandatory = $true)]
  [ValidateScript({Test-Path $_})]
  [string]$NanoServerSource,
  [Parameter(Mandatory = $true)]
  [ValidateSet('Compute','FailoverCluster','Storage','Worker')]
  $Role,
  [switch]$GuestDrivers,
  [switch]$OEMDrivers,
  [switch]$ReverseForwarders,
  [ValidateScript({Test-Path $_})]
  [string]$SetupCompleteFile
)
begin
{
  filter VerboseOutput
  {
    $_ | Out-String -Stream | Write-Verbose
  }
}
process
{
  If (-not (Test-Path $WorkingDir -PathType Container))
  {
    mkdir $WorkingDir | Out-Null
  }
  #region Download Convert.WindowsImage.ps1 from Github
  #$Url = 'https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f/file/59237/6/Convert-WindowsImage.ps1'
  $Url = 'https://raw.githubusercontent.com/ducke/Convert-WindowsImage/master/Convert-WindowsImage.ps1'

  $CurrentPath = $PWD

  $FileName = (Split-Path $Url -Leaf)
  $FilePath = Join-Path $WorkingDir $FileName

  'Try to download {0} from {1} and save to {2}' -f $FileName,$Url,$FilePath | VerboseOutput
  try
  {
    (new-object net.webclient).DownloadFile($Url, $FilePath)  
  }
  catch
  {
    write-warning ('{0} {1}' -f $error[0].GetType().FullName,$error[0].Exception.Message)
    return
  }
  
  #endregion

  #region Download unattend.xml
  $UnattendXmlUrl = 'https://raw.githubusercontent.com/ducke/nanoserver/master/Unattend.xml'
  $UnattendFileName = (Split-Path $UnattendXmlUrl -Leaf)
  $UnattendXmlFilePath = Join-Path $WorkingDir $UnattendFileName
  'Try to download {0} from {1} and save to {2}' -f $UnattendFileName,$UnattendXmlUrl,$UnattendXmlFilePath #| VerboseOutput
  try
  {
    (new-object net.webclient).DownloadFile($UnattendXmlUrl, $UnattendXmlFilePath)  
  }
  catch
  {
    write-warning ('{0} {1}' -f $error[0].GetType().FullName,$error[0].Exception.Message)
    return
  }
  #endregion

  #region copy nano files in working directory
  $NanoServerWim = Join-Path $NanoServerSource 'NanoServer.wim'
  $NanoServerPkg = Join-Path $NanoServerSource 'Packages'
  '{0} : {1} : {2}' -f $NanoServerSource,$NanoServerWim,$NanoServerPkg | VerboseOutput
  If (-not (Test-Path $NanoServerWim))
  {
    throw 'NanoServer.wim not found! Exit'
  }
  If (-not(Test-Path $NanoServerPkg))
  {
    throw 'Packages Folder not found! Exit'
  }


  $DestWim = Copy-Item -Path $NanoServerWim -Destination $WorkingDir -PassThru
  $DestPkg = Copy-Item -Path $NanoServerPkg -Destination $WorkingDir -Recurse -PassThru
    #endregion


  #Convert-WindowsImage.ps1 -SourcePath C:\Downloads\NanoServer\NanoServer.wim -vhd "c:\dev\nanoserver\NanoServer.vhd" -VHDFormat VHD -Edition 1
  $NanoServerVhd = Join-Path $WorkingDir 'NanoServer.vhd'
  . $FilePath -SourcePath $DestWim.FullName -Vhd $NanoServerVhd -VHDFormat VHD -Edition 1 -UnattendPath $UnattendXmlFilePath

#region copy stuff to vhd
  $MountDir = Join-Path $WorkingDir 'mountdir'
  If (-not(Test-Path $MountDir))
  {
    mkdir $MountDir | Out-Null
  }
  try
  {
    'Mounting NanoServer VHD..' | VerboseOutput
    Mount-WindowsImage -Path $MountDir -Index 1 -ImagePath $NanoServerVhd
    if (-not ($Role -like 'Worker'))
    {
      $FileList = $DestPkg | Where-Object name -like "*$Role*"
    }
    if ($ReverseForwarders)
    {
      $Filelist += $DestPkg | Where-Object name -like '*ReverseForwarders*'
    }
    if ($GuestDrivers)
    {
      $Filelist += $DestPkg |  Where-Object name -like '*Guest*' 
    }
    if ($OEMDrivers)
    {
      $Filelist += $DestPkg |  Where-Object name -like '*OEM*' 
    }

    foreach ($File in $Filelist)
    {
      Add-WindowsPackage -PackagePath ($File.FullName) -Path $MountDir
    }

#region copy setup
    if ($SetupCompleteFile)
    {
      $SetupFolder = Join-Path $MountDir 'Windows\Setup\Scripts'
      If (-not(Test-Path $SetupFolder))
      {
        mkdir $SetupFolder
      }
      Copy-Item -Path $SetupCompleteFile -Destination $SetupFolder -PassThru

    }

#endregion
  }
  catch
  {
    write-warning ('{0} {1}' -f $error[0].GetType().FullName,$error[0].Exception.Message)
    return
  }
  finally
  {
    Dismount-WindowsImage -Path $MountDir -Save
  }
#endregion
 
}
end
{
  #Remove-Item $WorkingDir -Recurse -Force -WhatIf
  #explorer.exe $WorkingDir
}
