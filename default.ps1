# These properties needs to stay put and should have a different value, depending on the
# repository its in, corresponding to a section in the machine's configuration.yml file
properties {
	$DefaultConfiguration = "Release"
	$nugetFeedUrl = "http://proget.eprod.com:81/nuget/Foundation_Testing_Nuget"
	$inCore = @("LinqToQuerystring\\LinqToQuerystring.csproj")
	$inEntity = @("LinqToQuerystring.EntityFramework\\LinqToQuerystring.EntityFramework.csproj")
	$inOther =    @("LinqToQuerystring.Nancy\\LinqToQuerystring.Nancy.csproj",
					"LinqToQuerystring.WebApi\\LinqToQuerystring.WebApi.csproj",
					"LinqToQuerystring.WebApi\\LinqToQuerystring.WebApi2.csproj")
    $SolutionFile = ".\\LinqToQuerystring.sln"
}

###################################################################################
# Discover Functions
###################################################################################
task ? {
    WriteDocumentation
}

###################################################################################
# Orchestration
###################################################################################
task default -depends RestorePackages, Compile
task Build -depends Clean, RestorePackages, Compile -description "Clean and Compile the Solution in one fell swoop"

###################################################################################
# Utility Tasks.
###################################################################################
task FixProjects -description "Fixes all .csproject files in the repo." {
    & .\Tools\Fixproj\fixproj.exe -fix -d -dd -s -r -t . -m *.csproj
}

###################################################################################
# Compilation Tasks.
###################################################################################
task RestorePackages {
	$nugetexe = Get-Item .\.nuget\NuGet.exe
	Write-Host "Restoring packages for solution: @" $SolutionFile -ForegroundColor Cyan
	exec { & $nugetexe restore $SolutionFile }
}


task Clean -description "Cleans the solution" {  
    Invoke-Clean $SolutionFile
}

task Compile -description "This Compiles the Solution." {  
    Invoke-Compile $SolutionFile 
}


###################################################################################
# Packaging Tasks. 
###################################################################################

task Package:All -description "Package and push all Nuget packages" -depends Package:Core, Package:Entity, Package:Other
task Package:Pack:All -description "Package all Nuget packages" -depends Package:Pack:Core, Package:Pack:Entity, Package:Pack:Other

task Package:Core {
    ForEach($target in $inCore) {
		Invoke-Package $target
		Invoke-Package-Push $target $nugetFeedUrl
	}
}

task Package:Entity {
    ForEach($target in $inEntity) {
		Invoke-Package $target
		Invoke-Package-Push $target $nugetFeedUrl
	}
}

task Package:Other {
    ForEach($target in $inOther) {
        Invoke-Package $target
        Invoke-Package-Push $target $nugetFeedUrl
    }
}

task Package:Pack:Core {
    ForEach($target in $inCore) {
		Invoke-Package $target
	}
}

task Package:Pack:Entity {
    ForEach($target in $inEntity) {
		Invoke-Package $target
	}
}

task Package:Pack:Other {
    ForEach($target in $inOther) {
		Invoke-Package $target
	}
}

###########################################
# PowerShell implementation
###########################################

function Invoke-Package {
	[CmdletBinding()]
    param(
		[Parameter(Position=0,Mandatory=1)] [string]$ProjectFile = $null,
		[Parameter(Position=1,Mandatory=0)] [bool]$WithSymbols = $true,
		[Parameter(Position=2,Mandatory=0)] [string]$Configuration = $DefaultConfiguration
	)

    $file = Get-Item $ProjectFile
    $OutputDirectory = $file.Directory;
     
	if ($WithSymbols -eq $true) {
		$symbols = "-Symbols"
	} else {
		$symbols = ""
	}
    
    Push-Location $file.Directory	
    ../.nuget/NuGet.exe pack $file -Prop Configuration=$Configuration -OutputDirectory $OutputDirectory $symbols
    Pop-Location 
}

function Invoke-Package-Push {
	[CmdletBinding()]  
    param(
		[Parameter(Position=0,Mandatory=1)] [string]$ProjectFile = $null,
		[Parameter(Position=1,Mandatory=1)] [string]$DestinationLocation = $null)
	
	$file = Get-Item $ProjectFile
	$symbolsPackageWildcard = "$($file.DirectoryName)\*.symbols.nupkg"
	$allPackageWildcard = "$($file.DirectoryName)\*.nupkg"
	
	$symbolsPackageExists = Test-Path $symbolsPackageWildcard	
	if($symbolsPackageExists) {
		$packageWildCard = $symbolsPackageWildcard		
	}
	else {		
		$packageWildCard = $allPackageWildcard		
	}	
	
	./.nuget/NuGet.exe push -Source $DestinationLocation $packageWildcard	
	
    Write-Host "Cleaning up Packages locally"
    Remove-Item $allPackageWildcard
    Write-Host "Local Packages Cleaned up"
}

function Invoke-Clean {  
	[CmdletBinding()]  
    param(
		[Parameter(Position=0,Mandatory=1)] [string]$slnPath = $null)  
    $msbuildexe = Get-Item "C:\Program Files (x86)\MSBuild\12.0\bin\msbuild.exe" -ErrorAction SilentlyContinue
    
	Write-Host "Running Clean for solution: @" $slnPath -ForegroundColor Cyan
	
	exec { & $msbuildexe $slnPath /t:clean /v:m /nologo }
}

function Invoke-Compile {    
    [CmdletBinding()]  
    param(  
        [Parameter(Position=0,Mandatory=1)] [string]$slnPath = $null,
        [Parameter(Position=1,Mandatory=0)] [string]$configuration = $DefaultConfiguration,
        [Parameter(Position=2,Mandatory=0)] [string]$platform = "Any CPU")
    $msbuildexe = Get-Item "C:\Program Files (x86)\MSBuild\12.0\bin\msbuild.exe" -ErrorAction SilentlyContinue

 
    Write-Host "Running Build for solution @" $slnPath -ForegroundColor Cyan
    $config = "Configuration=" + $configuration + ";Platform="+ $platform
    
    exec { & $msbuildexe $slnPath /m /nologo /p:$config /t:build /v:m }
}
