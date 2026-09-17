
function Test-TerraformInitialization {
    [CmdletBinding()]
    Param(

        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [String]
        $Path

    )


    PROCESS {

        if (-not(Test-Path -Path $Path)) {
            Write-Error "The path $($Path) does not exist!"
            return
        }

        $resolvedPath = (Resolve-Path -Path $Path).Path
        
        $files = Get-ChildItem -Path $resolvedPath -Force -ErrorAction Stop | Where-Object {
            $_.Extension -eq ".tf"
        }

        if (-not($files)) {
            Write-Error "Failed to find any .tf files in $($resolvedPath)"
            return
        }

        try {

            $terraformDirectory = Join-Path $resolvedPath ".terraform"
            Get-Item -Path $terraformDirectory -Force -Verbose:$false -ErrorAction Stop | Out-Null

        }
        catch {
            Write-Error "The Terraform module is not initalized. The module must be initialized for this module to work."
            return
        }


    }

}

function Get-TerraformModule {
    [CmdletBinding()]
    Param(

        [Parameter(ValueFromPipeline)]
        [String]
        $Path

    )

    BEGIN {

        try {
            Test-TerraformInitialization -Path $Path -ErrorAction "Stop"
        }
        catch {
            Write-Error $_.Exception.Message
            return
        }

        $isTerraformModuleRoot = $true
        $rootModulePath        = (Resolve-Path -Path $Path).Path

        $tfModules = [System.Collections.ArrayList]@()

    }

    PROCESS {

        $modulePath = (Resolve-Path -Path $Path).Path

    }

    END {


    }

}

Test-TerraformInitialization $Path
