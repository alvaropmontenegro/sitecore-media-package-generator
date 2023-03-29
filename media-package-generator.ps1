Import-Function -Name Setup-PackageGenerator

function Create-New-Package {
	param(
	    [string]$packagePrefix,
		[string]$counterOfPackages
	)

	$packageName = $packagePrefix + "_" + $counterOfPackages
    
	Write-Host "-> Creating $packageName"

	$package = New-Package $packageName;
	$package.Sources.Clear();
	$package.Metadata.Author = $Author;
	$package.Metadata.Publisher = $Publisher;
	$package.Metadata.Version = $Version;
	$package.Metadata.Readme = $Readme;
	
	return $package
}

function Download-Package {
	param([Sitecore.Install.PackageProject]$package)

	$packageFileName = "$($package.Name).zip"

	Export-Package -Project $package -Path $packageFileName -Zip
	Send-File "$($SitecorePackageFolder)\$($packageFileName)"
	Remove-Item "$($SitecorePackageFolder)\$($packageFileName)"
	[environment]::NewLine
}

function Process-Packages {
    
	[environment]::NewLine
	Write-Host "### Processing the packages. It might take some time, grab a coffee!"
	Write-Host "*Don't forget to click on 'Download' and then 'Close' to close the pop up.*"
	[environment]::NewLine

	$package = Create-New-Package -packagePrefix $packagePrefix -counterOfPackages "0"
	[double]$currentPackageSize = 0.0

	$items = Get-ChildItem -Path $selectedItem.Paths.FullPath -Recurse
	$totalItems = $items.Length
	$counterItems = 0

	$items | ForEach-Object {
		Write-Host "Preparing:" $_.ItemPath

		$counterItems++

		$source = $_ | New-ExplicitItemSource -Name $_.Name -InstallMode $InstallMode -MergeMode $MergeMode
		$package.Sources.Add($source);

		$mediaItemSize = ($_.Size / 1024 / 1024)

		if (($currentPackageSize + $mediaItemSize) -gt $packageSize) {
			Download-Package -package $package

			$counterOfPackages += 1
			$currentPackageSize = 0
			$package = Create-New-Package -packagePrefix $packagePrefix -counterOfPackages $counterOfPackages
		}
		elseif ($counterItems -ge $totalItems) {
			Download-Package -package $package
		}
		else {
			$currentPackageSize += $mediaItemSize
		}
	}
}

##Parameters
$selectedItem = Get-Item -Path "/sitecore/media library/"
$counterOfPackages = 0
[double]$packageSize = 0

$parameters = @(
	@{ Name = "selectedItem"; Title = "Item"; Tooltip = "Select the item you want to create packages"; Root = "sitecore/media library/"; Tab = "Main" },
	@{ Name = "packageSize"; Value = "50"; Title = "Size (MB)"; Tooltip = "Enter the package size to be generated"; Tab = "Main" },
	@{ Name = "packagePrefix"; Title = "Package Name"; Value = "Package"; Tab = "Package Metadata" },
	@{ Name = "Author"; Value = [Sitecore.Context]::User.Profile.FullName; Tab = "Package Metadata" },
	@{ Name = "Publisher"; Value = [Sitecore.SecurityModel.License.License]::Licensee; Tab = "Package Metadata" },
	@{ Name = "Version"; Value = $selectedItem.Version; Tab = "Package Metadata" },
	@{ Name = "Readme"; Title = "Readme"; Lines = 8; Tab = "Package Metadata" },
	@{ Name = "Mode"; Title = "Installation Options"; Value = "Merge-Merge"; Options = $installOptions; OptionTooltips = $installOptionsTooltips; Tooltip = "Hover over each option to view a short description."; Hint = "How should the installer behave if the package contains items that already exist?"; Editor = "combo"; Tab = "Installation Options" }
)

$props = @{} + $defaultProps
$props["Title"] = "Transform Large Media Content into Small Packages"
$props["Description"] = "This tool allows you to download large media content into small packages quickly. It turns the process faster and easier to migrate from one instance to another one."
$props["Parameters"] = $parameters
$props["Width"] = 630
$props["Height"] = 750

$result = Read-Variable @props

Resolve-Error

if ($result -ne "ok") {
	Close-Window
	exit
}

$InstallMode = [Sitecore.Install.Utils.InstallMode]::Undefined
$MergeMode = [Sitecore.Install.Utils.MergeMode]::Undefined

switch ($Mode) {
	"Overwrite" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::Overwrite
	}

	"Merge-Merge" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::Merge
		$MergeMode = [Sitecore.Install.Utils.MergeMode]::Merge
	}

	"Merge-Clear" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::Merge
		$MergeMode = [Sitecore.Install.Utils.MergeMode]::Clear
	}

	"Merge-Append" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::Merge
		$MergeMode = [Sitecore.Install.Utils.MergeMode]::Append
	}

	"Skip" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::Skip
	}

	"SideBySide" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::SideBySide
	}

	"AskUser" {
		$InstallMode = [Sitecore.Install.Utils.InstallMode]::Undefined
	}
}

Process-Packages

[environment]::NewLine
Write-Host "Packages created successfully!"
