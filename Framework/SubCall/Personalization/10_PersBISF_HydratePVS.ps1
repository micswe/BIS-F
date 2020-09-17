<#
    .Synopsis
      Enables pre-caching of files for PVS systems
    .Description
      Enables pre-caching of files for PVS systems
      Tested on Server 2019
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Trentent Tye

      History
		  2019.08.16 TT: Script created
		  18.08.2019 MS: integrate into BIS-F
		  01.04.2020 Micswe: Add PVS Disk mode
		  20.04.2020 Micswe: Add Work Hours, Skip Hydrate on boot in WorkHourse
		  24.04.2020 Micswe: BugFix hang on many Clients
		  19.09.2020 Micswe: Add Exclude FolderPath

	  .Link
		  https://github.com/EUCweb/BIS-F/issues/129

	  .Link
		  https://eucweb.com
#>

Begin {
	Write-BISFLog -Msg "Hydrate Begin"
	#$script_path = $MyInvocation.MyCommand.Path
	#$script_dir = Split-Path -Parent $script_path
	#$script_name = [System.IO.Path]::GetFileName($script_path)
	if ($LIC_BISF_CLI_PVSHydration -eq "YES") { $EnableMode = $true }
	if ($LIC_BISF_CLI_PVSHydration -eq "NO") { $DisableMode = $true }
	$PathsToCache = $LIC_BISF_CLI_PVSHydration_Paths
	$ExtensionsToCache = $LIC_BISF_CLI_PVSHydration_Extensions
	$PathsToExclude = $LIC_BISF_CLI_PVSHydration_ExcludePaths
	[int]$only_runto=5
	[bool]$check_Work_Hour=$true
}

Process {
	####################################################################
	####### Functions #####
	####################################################################
	function FileToCache ($File) {
		#Write-BISFLog -Msg "Caching File : $File" -ShowConsole -Color Cyan
		$hydratedFile = [System.IO.File]::ReadAllBytes($File)
	}
  	####################################################################
	####### End functions #####
	####################################################################

	Write-BISFLog -Msg "Hydrate Prozess Start"

	$WriteCacheType = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\bnistack\PVSAgent).WriteCacheType
	Switch ($WriteCacheType)
	{
		0 {$WriteCacheTypeTxt = "Private"}
		1 {$WriteCacheTypeTxt = "Cache on Server"}
		3 {$WriteCacheTypeTxt = "Cache in Device RAM"}
		4 {$WriteCacheTypeTxt = "Cache on Device Hard Disk"}
		7 {$WriteCacheTypeTxt = "Cache on Server, Persistent"}
		9 {$WriteCacheTypeTxt = "Cache in Device RAM with Overflow on Hard Disk"}
		10 {$WriteCacheTypeTxt = "Private async"}
		11 {$WriteCacheTypeTxt = "Server persistent async"}
		12 {$WriteCacheTypeTxt = "Cache in Device RAM with Overflow on Hard Disk async"}
		default {$WriteCacheTypeTxt = "WriteCacheType $WriteCacheType not defined !!"}
	}
	Write-BISFLog -Msg "PVS WriteCacheType is set to $WriteCacheType - $WriteCacheTypeTxt"

	if ($WriteCacheType -eq 0) {   # 4:Cache on Device Hard Disk // 9:Cache in Device RAM with Overflow on Hard Disk // 12:Cache in Device RAM with Overflow on Hard Disk async
		Write-BISFLog -Msg "PVS Software is in Master mode, skip precache."  -ShowConsole -Color Yellow
		Return	
	}	
	
	#check time
	[int]$time_hour=(Get-Date -Format HH)

	if (($time_hour -ge $only_runfrom -or $time_hour -le $only_runto) -or $check_Work_Hour -eq $false)
	{
		Write-BISFLog -Msg "Start Hydrate in RunHours: Yes"  -ShowConsole -Color Yellow

		if (-not(Test-BISFPVSSoftware)) {
			Write-BISFLog -Msg "PVS Software not found. Skipping file precache."  -ShowConsole -Color Yellow
			Return
		}
		if (-not($EnableMode) -or ($DisableMode)) {
			Write-BISFLog -Msg "File precache configuration not found. Skipping."  -ShowConsole -Color Yellow
			Return
		}

		#foreach ($Path in ($PathsToCache.split("|"))) {
		#	Write-BISFLog -Msg "Caching files with extensions $ExtensionsToCache in $Path" -ShowConsole -Color Cyan
		#	foreach ($File in (Get-ChildItem -Path $Path -Recurse -File -Include $ExtensionsToCache.Split(","))) {
		#		FileToCache -File $File
		#	}
		#}

		foreach ($Path in ($PathsToCache.split("|"))) { 
            Write-BISFLog -Msg "Caching files with extensions $ExtensionsToCache in $Path" -ShowConsole -Color Cyan
            $noDirRegex='^{0}' -f ($PathsToExclude.Replace("\","\\").Replace("(","\(").Replace(")","\)").Split("|") -join ('|^'))            
            Write-BISFLog -Msg "RegEx: $noDirRegex" -ShowConsole -Color Yellow

            foreach ($File in (Get-ChildItem -Path $Path -Recurse -File -Include $ExtensionsToCache.Split(","))) 
            { 
                if ($File.DirectoryName -inotmatch $noDirRegex) 
                { 
			   		FileToCache -File $File
                } 
            }                     
		}
	}
	else
	{
		Write-BISFLog -Msg "Skype Hydrate, Start in Work hours."  -ShowConsole -Color Yellow
	}
}

End {
	Add-BISFFinishLine
}
