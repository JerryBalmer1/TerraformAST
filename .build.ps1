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

if (-not(Get-Module -ListAvailable -Name InvokeBuild)) {
    Install-Module -Name InvokeBuild -Scope CurrentUser -Verbose -Force
}


######################################################################################################
# InvokeBuild - Tasks
######################################################################################################

<#

$pat = ""

$ENV:AZDO_PERSONAL_ACCESS_TOKEN=$pat
$ENV:AZDO_ORG_SERVICE_URL="https://dev.azure.com/jlbalmerjr1"

#>



task Docker {
    # docker buildx build -no-cache -f Dockerfile --output type=local,dest=./dist . 
    # docker buildx build --no-cache --output type=local,dest=./src/PS.Util.Terraform/lib ./PS.Util.Terraform.dll
    docker buildx build --no-cache --output type=local,dest=./src/PS.Util.Terraform/lib ./PS.Util.Terraform.dll

    docker buildx build --no-cache -o ./src/PS.Util.Terraform/lib .
    docker buildx build --no-cache --output type=local,dest=./PS.Util.Terraform.dll ./src/PS.Util.Terraform/lib 


}


# Define the build tasks
task BuildDll Clean, {
    # Navigate to the Go directory
    Set-Location "$PSScriptRoot/go"

    # Build the Go code into a DLL
    go build -o "$PSScriptRoot/TerraformAST/hcl_parser.dll" -buildmode=c-shared .

    # Verify the DLL was created
    $dllPath = Join-Path "$PSScriptRoot/TerraformAST" "hcl_parser.dll"
    if (Test-Path $dllPath) {
        Write-Host "DLL built successfully and placed in the TerraformAST directory: $dllPath" -ForegroundColor Green
    } else {
        Write-Host "Failed to build the DLL. Check the Go build output for errors." -ForegroundColor Red
    }
}

task Clean {

    Remove-Module -Name TerraformAst -Force -ErrorAction SilentlyContinue

    # Remove the DLL from the TerraformAST directory
    $dllPath = Join-Path "$PSScriptRoot/TerraformAST" "hcl_parser.dll"
    if (Test-Path $dllPath) {
        Remove-Item $dllPath -Force
        Write-Host "DLL removed from the TerraformAST directory." -ForegroundColor Green
    } else {
        Write-Host "DLL not found in the TerraformAST directory." -ForegroundColor Yellow
    }

    if (Test-Path "bin") {
        Write-Host "bin"
    }

}

task Package {
    # Create a zip file of the TerraformAST directory
    $zipPath = Join-Path $PSScriptRoot "TerraformAST.zip"
    Compress-Archive -Path "$PSScriptRoot/TerraformAST/*" -DestinationPath $zipPath -Force

    Write-Host "Module packaged successfully: $zipPath" -ForegroundColor Green
}

task ImportModule {

    $module = [System.IO.DirectoryInfo](Join-Path $PSScriptRoot 'TerraformAST')

    Remove-Module -Name $module.Name -ErrorAction SilentlyContinue

    Import-Module $module.FullName -Verbose -Force

    Get-Command -Module TerraformAST

}

task Test ImportModule, {

    Get-TFConfig

    $params = @{
        WorkingDirectory = ".\tests"
    }
    
    Set-TFConfig @params

    Get-TFConfig

    Invoke-TFInit

}

# Default task (runs if no task is specified)
task . ImportModule