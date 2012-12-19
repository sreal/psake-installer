# ADFC FuseTalk Installer psake script
# Usage:
#   > Invoke-Psake
#   > Invoke-Psake Package
#   > Invoke-Psake Install
#   > Invoke-Psake Uninstall


properties {
  $base_dir    = Resolve-Path .
  $projectpath = "C:\projects\cadetnet\cadetnet-cmc4\ADFC.FuseTalk"
  $this_file   = "default.ps1"
  $config      = Get-Config
[[INCLUDE_FILES]]
  $config_files = @( "Web.config" )
  $config_enviroments = @( "PROD", "UAT", "STAGE", "TEST", "DEV" )
  $config_format = "{0}.{1}" # 0 is file and 1 is environment
  $zip_source = "tmp_to_delete\"
  $package_name = "C:\Projects\tmp\FuseTalkInstallPackage.zip"
  $script_files =  @($this_file)
}

task Debug {
  Write-Host base_dir: $base_dir
  Write-Host projectpath: $projectpath
  Write-Host config: $config
}


task default -depends Help


task Help {
  Write-Host ADFC FuseTalk Customization Installer
  Write-Host -------------------------------------
  Write-Host ''
  Write-Host Usage:
  Write-Host '  '+ > Invoke-Psake
  Write-Host '  '+ > Invoke-Psake Package
  Write-Host '  '+ > Invoke-Psake Install
  Write-Host
}


task Uninstall {
  $uninstall = $config._uninstalldir

  $uninstall_success = $false;

  if ( Test-Path $uninstall ) {
    $previous = Get-ChildItem ("{0}*_{1}" -F $uninstall, $this_file ) | Sort-Object Name -Desc | Select -First 1

    Invoke-Psake $previous Uninstall-Impl

    $uninstall_success = $true
  }

}



task Uninstall-Impl {

  Write-Host 'Removing files from install: ' -Fore Gray -NoNewLine
  $install_files | % {
    $f = Join-Path $config._appfolder $_
    Write-Host . -nonewline -Fore GREEN

    if ( Test-Path -Type Container $f ) {
      Remove-Item $_ -Force -Recurse

    } elseif ( Test-Path -Type Container $f ) {
      Remove-Item $_ -Force -Recurse

    } else {
      Write-Host x -nonewline -Fore RED

    }
  }
  Write-Host ' : Done: ' -Fore Gray -NoNewLine


  Write-Host 'Removing configs from file ' -Fore Gray -NoNewLine
  $config_files | % {
    Write-Host . -nonewline -Fore GREEN
    $f = Join-Path $config._appfolder $_
    if ( Test-Path -Type Container $f ) {
      Remove-Item $_ -Force -Recurse
    } else {
      Write-Host x -nonewline -Fore RED
    }
  }
  Write-Host ' : Done: ' -Fore Gray -NoNewLine

}




task Install-Uninstaller {

  $uninstall = $config._uninstalldir

  $script = Join-Path $base_dir $this_file

  Write-host $script

  if ( -not (Test-Path $script) ) {
    Write-Host No uninstaller found. Skipping... -Fore Gray
    Return
  }

  if ( -not (Test-Path $uninstall) ) {
    Write-Host Uninstaller directory not found. Creating... -Fore Gray
    New-Item -Type Directory $uninstall | Out-Null
  }

  $dated = "{0}{1}_{2}" -F $uninstall, (Get-Date -Format yyyyMMdd), $this_file

  Write-Host $this_file

  Copy-Item $script $dated -Force | Out-Null

  Write-Host -Fore Green Uninstaller created at $dated

}



task Install {

  Invoke-Psake Uninstall

  Write-Host 'Copying files for install: ' -Fore Gray -NoNewLine
  $source_path = Join-Path $base_dir package
  $install_files | % { Copy-File-or-Directory $_ $source_path $config._appfolder }
  Write-Host ' : Done' -Fore GRAY

  Write-Host 'Copying config file: ' -Fore Gray -NoNewLine
  $config_files | % {
    $f = $config_format -f ( Join-Path $source_path $_ ), $config._envname
    Copy-Item $f $_
    Copy-File-or-Directory $_ $base_dir $config._appfolder
    Remove-Item $_
  }
  Write-Host ' : Done' -Fore GRAY

  Invoke-Psake Install-Uninstaller
}




task Clean {
  if ( Test-Path $zip_source) {
    Remove-Item $zip_source -Recurse -Force
  }
  if ( Test-Path $package_name) {
    Remove-Item $package_name -Force
  }
}
task SetupSession {
  $has_pscx = (Get-Module -ListAvailable | ? { $_.Name -eq 'pscx'} ) -ne $null
  if (-not $has_pscx){
    Write-Error "SETUP ERROR: You MUST have PSCX (http://pscx.codeplex.com/) installed!"
    Exit
  }
  Import-Module pscx

  $has_pscx = (Get-Module -ListAvailable | ? { $_.Name -eq 'psake'} ) -ne $null
  if (-not $has_pscx){
    Write-Error "SETUP ERROR: You MUST have PSake (https://github.com/psake/psake/) installed!"
    Exit
  }
  Import-Module pscx
}


task Package -depends Clean, SetupSession {
  $zip_source =  New-Item -Type Directory $zip_source
  $source =  New-Item -Type Directory "$zip_source/package/"

  Write-Host 'Copying files for package: ' -Fore Gray -NoNewLine
  $install_files | % { Copy-File-or-Directory $_ $projectpath $source }
  Write-Host ' : Done' -Fore GRAY


  Write-Host 'Adding configuration to zip: ' -Fore Gray -NoNewLine
  $config_files       | % { $cf = $_;
  $config_enviroments | % {
      Copy-File-or-Directory ($config_format -f $cf, $_) $projectpath $source
  }}
  Write-Host ' : Done' -Fore Gray


  Write-Host 'Adding Release Scripts: ' -Fore GRAY -NoNewLine
  $script_files | % { Copy-File-or-Directory $_ $base_dir $zip_source }
  Write-Host ' : Done' -Fore Gray



  Write-Host 'Creating Zip: ' -Fore GRAY -NoNewLine
  try   { Write-Zip "$zip_source/*" $package_name -Quiet | Out-Null; Write-Host . -Fore GREEN -NoNewLine; }
  catch { Write-Host x -Fore RED  -NoNewLine; }
  Write-Host ' : Done' -Fore Gray

  Remove-Item $zip_source -Recurse -Force

}



# This is the heavy lifter for moving files about
Function Copy-File-or-Directory( $file, $source_path, $dest_path) {
  Write-Host . -nonewline -Fore Green

  $from_file = Join-Path $source_path $file
  $to_file   = Join-Path $dest_path $file

  if ( -not (Test-Path $from_file) ) {
#    Write-Host x -Fore RED -NoNewLine
    Write-Host $from_file -Fore RED
    Return
  }

  if ( Test-Path -Type Container $from_file ) {
    if ( -not (Test-Path $to_file) ) {
       $to_file = New-Item -Type Directory $to_file -Force

    }
  } else {
    $to_file = New-Item -Type File $to_file -Force

  }

  $to_file   = Resolve-Path $to_file
  $from_file = Resolve-Path $from_file
  Copy-Item $from_file $to_file -Force -Recurse
}



##
#Configuration

Function Get-Config {
  switch -regex ($env:COMPUTERNAME)
    {
      '<<TEST_CONFIG>>' { return Config_TEST  }
      '<<STAGE_CONFIG>>' { return Config_STAGE }
      '<<UAT_CONFIG>>' { return Config_UAT   }
      '<<PROD_CONFIG>>' { return Config_PROD  }
      default        { return Config_DEV   }
    }
}

Function Config_Default {
  $c = 1 | select-object _envname, _appfolder, _uninstalldir
  $c._envname = 'not-defined'
  $c._appfolder = 'D:\WebApps\ADFC.FuseTalk\web\forum\'
  $c._uninstalldir = 'D:\adfc\FuseTalk-Uninstaller\'
  return $c
}
Function Config_DEV {
  $c = Config_Default;
  $c._envname = 'DEV'
  $c._appfolder = 'C:\projects\tmp\FuseTalk-AppFolder_1\'
  $c._uninstalldir = 'C:\projects\tmp\FuseTalk-Uninstaller\'
  return $c
}
Function Config_TEST {
  $c = Config_Default;
  $c._envname = 'TEST'
  return $c
}
Function Config_STAGE {
  $c = Config_Default;
  $c._envname = 'STAGE'
  return $c
}
Function Config_UAT {
  $c = Config_Default;
  $c._envname = 'UAT'
  return $c
}
Function Config_PROD {
  $c = Config_Default;
  $c._envname = 'PROD'
  return $c
}
