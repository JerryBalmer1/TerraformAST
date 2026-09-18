[CmdletBinding()]
Param()

######################################################################################################
# InvokeBuild - ArgumentCompleters
######################################################################################################

Register-ArgumentCompleter -CommandName Invoke-Build.ps1 -ParameterName Task -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

    (Invoke-Build -Task ?? -File ($boundParameters['File'])).get_Keys() -like "$wordToComplete*" | .{process{
        New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', $_
    }}
}

Register-ArgumentCompleter -CommandName Invoke-Build.ps1 -ParameterName File -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

    Get-ChildItem -Directory -Name "$wordToComplete*" | .{process{
        New-Object System.Management.Automation.CompletionResult $_, $_, 'ProviderContainer', $_
    }}

    if (!($boundParameters['Task'] -eq '**')) {
        Get-ChildItem -File -Name "$wordToComplete*.ps1" | .{process{
            New-Object System.Management.Automation.CompletionResult $_, $_, 'Command', $_
        }}
    }
}

######################################################################################################
# InvokeBuild - Install InvokeBuild
######################################################################################################

if (-not (Get-Module -ListAvailable -Name InvokeBuild)) {
    Install-Module -Name InvokeBuild -Scope CurrentUser -Verbose -Force
}

######################################################################################################
# Helpers
######################################################################################################

function Get-RepoBranch {
    $name = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $name) {
        throw "Not a git repository (or git is not on PATH)."
    }
    $name.Trim()
}

function Assert-GitClean {
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed."
    }
    if ($status) {
        throw "Working tree is not clean. Commit or stash first.`n$status"
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]
        $Arguments
    )
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot "src\TerraformAST\TerraformAST.psd1"
}

function Get-ManifestVersion {
    $manifestPath = Get-ModuleManifestPath
    $data = Import-PowerShellDataFile -Path $manifestPath
    [version]$data.ModuleVersion
}

function Get-NextBuildVersion {
    $current = Get-ManifestVersion
    $build = if ($current.Build -lt 0) { 0 } else { $current.Build }
    [version]::new($current.Major, $current.Minor, $build + 1)
}

function Set-ManifestVersion {
    param(
        [Parameter(Mandatory)]
        [version]
        $Version
    )
    $manifestPath = Get-ModuleManifestPath
    $text = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop
    $updated = [regex]::Replace(
        $text,
        "(ModuleVersion\s*=\s*')([^']+)(')",
        { param($m) $m.Groups[1].Value + $Version.ToString() + $m.Groups[3].Value },
        1
    )
    if ($updated -eq $text) {
        throw "Could not find ModuleVersion in $manifestPath"
    }
    Set-Content -LiteralPath $manifestPath -Value $updated -NoNewline -ErrorAction Stop
}

######################################################################################################
# InvokeBuild - Tasks
######################################################################################################

# Runs at most once per Invoke-Build invocation. Later tasks that list it as a
# dependency reuse the result; they do not probe again.
task CheckDependencies {

    $failures = [System.Collections.Generic.List[string]]::new()

    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion -lt [version]'7.4') {
        $failures.Add("PowerShell 7.4+ is required. This session is $psVersion. Install pwsh 7.4 or later and rerun.")
    }
    else {
        Write-Host "OK  PowerShell $psVersion" -ForegroundColor Green
    }

    $minPester = [version]'6.1.0'
    $pesterMod = Get-Module -ListAvailable -Name Pester |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $pesterMod) {
        $failures.Add("Pester $minPester+ is required. Install-Module Pester -MinimumVersion 6.1.0 -Scope CurrentUser -Force")
    }
    elseif ($pesterMod.Version -lt $minPester) {
        $failures.Add("Pester $($pesterMod.Version) is installed; $minPester or later is required. Update-Module Pester -Force")
    }
    else {
        Write-Host "OK  Pester $($pesterMod.Version)" -ForegroundColor Green
    }

    $terraform = Get-Command terraform -ErrorAction SilentlyContinue
    if (-not $terraform) {
        $failures.Add("terraform is not on PATH. Install Terraform and ensure `terraform version` works.")
    }
    else {
        $tfOut = & terraform version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("terraform was found but `terraform version` failed:`n$tfOut")
        }
        else {
            $tfLine = ($tfOut -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1)
            Write-Host "OK  $tfLine ($($terraform.Source))" -ForegroundColor Green
        }
    }

    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        $failures.Add("docker is not on PATH. Install Docker Desktop (or the Docker CLI) and ensure `docker version` works.")
    }
    else {
        Write-Host "OK  docker CLI ($($docker.Source))" -ForegroundColor Green

        $null = & docker info --format '{{.ServerVersion}}' 2>&1
        if ($LASTEXITCODE -ne 0) {
            $infoOut = & docker info 2>&1 | Out-String
            $failures.Add("Docker CLI is present but the Docker engine is not running. Start Docker Desktop and wait until it is ready.`n$infoOut")
        }
        else {
            Write-Host "OK  Docker engine is up" -ForegroundColor Green
        }
    }

    if ($failures.Count -gt 0) {
        throw (@('CheckDependencies failed:', $failures) -join "`n - ")
    }

}

task BuildDLL CheckDependencies, {

    $libDirectory = Join-Path $PSScriptRoot "src\TerraformAST\lib"
    $libPath      = Join-Path $libDirectory "TerraformAST.dll"
    $imageName    = "terraformast"
    $containerName = "terraformast-tmp"

    if (-not (Test-Path $libDirectory)) {
        New-Item -Path $libDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    Remove-Module -Name TerraformAST -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $libPath) {
        try {
            Remove-Item -LiteralPath $libPath -Force -ErrorAction Stop
        }
        catch {
            $stale = "$libPath.old"
            if (Test-Path -LiteralPath $stale) {
                Remove-Item -LiteralPath $stale -Force -ErrorAction SilentlyContinue
            }
            Move-Item -LiteralPath $libPath -Destination $stale -Force -ErrorAction Stop
        }
    }

    docker rm -f $containerName 2>$null | Out-Null
    docker rm -f psutiltmp 2>$null | Out-Null

    docker build -t $imageName .
    if ($LASTEXITCODE -ne 0) {
        throw "docker build failed with exit code $LASTEXITCODE"
    }

    docker create --name $containerName $imageName
    if ($LASTEXITCODE -ne 0) {
        throw "docker create failed with exit code $LASTEXITCODE"
    }

    docker cp "${containerName}:/TerraformAST.dll" $libPath
    if ($LASTEXITCODE -ne 0) {
        docker rm -f $containerName 2>$null | Out-Null
        throw "docker cp failed with exit code $LASTEXITCODE"
    }

    docker rm $containerName

    if (-not (Test-Path -LiteralPath $libPath)) {
        throw "BuildDLL did not produce $libPath"
    }

}

task RemoveModule {
    Remove-Module -Name TerraformAST -Force -ErrorAction SilentlyContinue
}

task ImportModule {
    $modulePath = Join-Path $PSScriptRoot "src\TerraformAST"
    Import-Module $modulePath -Force -ErrorAction Stop
}

task Test CheckDependencies, RemoveModule, ImportModule, {

    $pesterPath = Join-Path $PSScriptRoot "tests"
    $testFiles  = Get-ChildItem -Path $pesterPath -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue

    if (-not $testFiles) {
        throw "No *.Tests.ps1 files found under $pesterPath"
    }

    $result = Invoke-Pester -Path $pesterPath -Output Detailed -PassThru

    if ($result.FailedCount -gt 0) {
        throw "Pester failed $($result.FailedCount) test(s)"
    }

}

task Package {
    $zipPath = Join-Path $PSScriptRoot "TerraformAST.zip"
    Compress-Archive -Path "$PSScriptRoot/src/TerraformAST/*" -DestinationPath $zipPath -Force
    Write-Host "Module packaged successfully: $zipPath" -ForegroundColor Green
}

# develop only. Bump ModuleVersion build, squash develop onto main, annotated tag, push.
task Release {

    $branch = Get-RepoBranch
    if ($branch -ne 'develop') {
        throw "Release must run on develop. Current branch is '$branch'."
    }

    Assert-GitClean
    Invoke-Git fetch, origin

    $current = Get-ManifestVersion
    $next    = Get-NextBuildVersion
    Write-Host "Bumping ModuleVersion $current -> $next" -ForegroundColor Cyan

    Set-ManifestVersion -Version $next
    Invoke-Git add, (Get-ModuleManifestPath)
    Invoke-Git commit, -m, "Bump version to $next"

    Invoke-Git checkout, main
    Invoke-Git pull, origin, main
    Invoke-Git merge, --squash, develop
    Invoke-Git commit, -m, "Release $next"
    Invoke-Git tag, -a, $next.ToString(), -m, "Release $next"
    Invoke-Git push, origin, main
    Invoke-Git push, origin, $next.ToString()

    Invoke-Git checkout, develop
    Invoke-Git merge, main, -m, "Sync develop with release $next"
    Invoke-Git push, origin, develop

    Write-Host "Release $next is on main (annotated tag $next). Checkout main and Invoke-Build Publish." -ForegroundColor Green
}

# main only. Prompt for a Gallery key if needed, then Publish-Module.
task Publish {

    $branch = Get-RepoBranch
    if ($branch -ne 'main') {
        throw "Publish must run on main. Current branch is '$branch'. Checkout main after Release."
    }

    $libPath = Join-Path $PSScriptRoot "src\TerraformAST\lib\TerraformAST.dll"
    if (-not (Test-Path -LiteralPath $libPath)) {
        throw "TerraformAST.dll is missing. Run Invoke-Build BuildDLL before Publish (the DLL is gitignored)."
    }

    if (-not $env:PSGALLERY_API_KEY) {
        $secure = Read-Host "PowerShell Gallery API key" -AsSecureString
        if (-not $secure -or $secure.Length -eq 0) {
            throw "A PowerShell Gallery API key is required."
        }
        $env:PSGALLERY_API_KEY = [System.Net.NetworkCredential]::new('', $secure).Password
        Write-Host "PSGALLERY_API_KEY is set for this process only." -ForegroundColor Yellow
    }
    else {
        Write-Host "Using existing PSGALLERY_API_KEY from the environment." -ForegroundColor Yellow
    }

    $modulePath = Join-Path $PSScriptRoot "src\TerraformAST"
    $version    = Get-ManifestVersion

    Publish-Module -Path $modulePath -NuGetApiKey $env:PSGALLERY_API_KEY -Repository PSGallery -ErrorAction Stop
    Write-Host "Published TerraformAST $version to the PowerShell Gallery." -ForegroundColor Green
}

task . Test
