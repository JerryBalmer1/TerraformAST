[CmdletBinding()]
Param()

$global:BUILD_ROOT        = $PSScriptRoot
$script:BUILD_MODULE_NAME = "TerraformAST"

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

if (-not(Get-Module -ListAvailable -Name InvokeBuild)) {
    Install-Module -Name InvokeBuild -Scope CurrentUser -Verbose -Force
}


######################################################################################################
# InvokeBuild - Tasks
######################################################################################################



task Clean {}


task BuildDLL {

    $libDirectory = Join-Path $PSScriptRoot "src\TerraformAST\lib"
    $libPath      = Join-Path $libDirectory "TerraformAST.dll"

    if (-not(Test-Path $libDirectory)) {
        New-Item -Path $libDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    if (Test-Path $libPath) {
        Remove-Item -Path $libPath -Force -ErrorAction Stop | Out-Null
    }

    docker build -t ps-util-terraform .
    docker create --name psutiltmp ps-util-terraform
    docker cp psutiltmp:/TerraformAST.dll $libPath
    docker rm psutiltmp

}

task RemoveModule {
    Remove-Module -Name $script:BUILD_MODULE_NAME -Force -ErrorAction SilentlyContinue
}

task ImportModule {
    $modulePath = Join-Path $PSScriptRoot "src\TerraformAST"
    Import-Module $modulePath -Force -ErrorAction Stop
}

task Test RemoveModule,ImportModule, {

    Invoke-Pester -Output Detailed

}

task Package {
    # Create a zip file of the TerraformAST directory
    $zipPath = Join-Path $PSScriptRoot "TerraformAST.zip"
    Compress-Archive -Path "$PSScriptRoot/TerraformAST/*" -DestinationPath $zipPath -Force

    Write-Host "Module packaged successfully: $zipPath" -ForegroundColor Green
}




# Default task (runs if no task is specified)
task . Test