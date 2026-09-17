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
# InvokeBuild - Tasks
######################################################################################################

task Clean {}

task BuildDLL {

    $libDirectory = Join-Path $PSScriptRoot "src\TerraformAST\lib"
    $libPath      = Join-Path $libDirectory "TerraformAST.dll"

    if (-not (Test-Path $libDirectory)) {
        New-Item -Path $libDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    if (Test-Path $libPath) {
        Remove-Item -Path $libPath -Force -ErrorAction Stop | Out-Null
    }

    docker rm -f psutiltmp 2>$null | Out-Null

    docker build -t ps-util-terraform .
    if ($LASTEXITCODE -ne 0) {
        throw "docker build failed with exit code $LASTEXITCODE"
    }

    docker create --name psutiltmp ps-util-terraform
    if ($LASTEXITCODE -ne 0) {
        throw "docker create failed with exit code $LASTEXITCODE"
    }

    docker cp psutiltmp:/TerraformAST.dll $libPath
    if ($LASTEXITCODE -ne 0) {
        docker rm -f psutiltmp 2>$null | Out-Null
        throw "docker cp failed with exit code $LASTEXITCODE"
    }

    docker rm psutiltmp

    if (-not (Test-Path $libPath)) {
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

task Test RemoveModule,ImportModule, {

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

task . Test
