function Get-TerraformAST {
    [CmdletBinding()]
    Param(

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "The path to the Terraform file (.tf) to parse."
        )]
        [Alias("FullName")]
        [String]
        $Path
        
    )

    BEGIN {

        Write-Verbose "[ $($MyInvocation.InvocationName) ] Executing"

    }

    PROCESS {

        if (-not(Test-Path -Path $Path -PathType Leaf)) {
            Write-Error "The -Path $($Path) does not exist!"
            return
        }

        if (-not(([System.IO.FileInfo]$Path).Extension -eq ".tf")) {
            Write-Error "The -Path $($Path) file extension is not .tf"
            return
        }

        # Resolve the absolute path (cross-platform)

        $absPath = try {

            Resolve-Path $Path -ErrorAction Stop | Select-Object -ExpandProperty Path

        } catch {

            Write-Error $_.Exception.Message
            return

        }

        Write-Verbose " - $($absPath)"
        
        # Call the Go function to parse the HCL file
        
        try {

            $pathPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($absPath)

            try {

                $astJsonPtr = [Go.HCLParser]::ParseHCL($pathPtr)

                if ($astJsonPtr -eq [IntPtr]::Zero) {
                    throw "Failed to parse HCL file: Null pointer returned"
                }

                # Convert the returned pointer to a PowerShell string
                $astJson = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($astJsonPtr)

                if (-not $astJson) {
                    throw "Failed to convert AST JSON to string"
                }

                # Free the memory allocated by Go
                [Go.HCLParser]::FreeString($astJsonPtr)

            } finally {

                [System.Runtime.InteropServices.Marshal]::FreeHGlobal($pathPtr)

            }

            # Convert the JSON string to a PowerShell object and pretty-print it

            $ast = try {

                if ($PSVersionTable.PSVersion.Major -gt 5) {
                    $astJson | ConvertFrom-Json -Depth 99 -ErrorAction Stop
                }
                else {
                    $astJson | ConvertFrom-Json -ErrorAction Stop
                }
                
            } catch {
                Write-Error $_.Exception.Message
                return
            }

            $ast.Body.Blocks | ForEach-Object {
                $_
            }

        }
        catch {

            throw "Error in Get-TerraformAST: $_"

        }

    }

    END {

        Write-Verbose "[ $($MyInvocation.InvocationName) ] Executing"

    }

}

Export-ModuleMember -Function Get-TerraformAST