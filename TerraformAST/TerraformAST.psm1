# Load the Go DLL using P/Invoke
$dllPath = Join-Path $PSScriptRoot "hcl_parser.dll"
if (-not (Test-Path $dllPath)) {
    throw "DLL not found: $dllPath"
}

# Escape backslashes in the file path
$escapedDllPath = $dllPath -replace '\\', '\\'

# Define the signatures of the Go functions
$signature = @"
    [DllImport("$escapedDllPath", CharSet = CharSet.Ansi)]
    public static extern IntPtr ParseHCL(string filePath);

    [DllImport("$escapedDllPath", CharSet = CharSet.Ansi)]
    public static extern void FreeString(IntPtr str);
"@

try {
    # Add the type definition
    Add-Type -MemberDefinition $signature -Name HCLParser -Namespace Go
} catch {
    throw "Failed to define Go function: $_"
}

function Get-TerraformAST {
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "The path to the Terraform file to parse."
        )]
        [Alias("FullName")]
        [String]
        $Path
    )

    BEGIN {

        Write-Verbose "[ $($MyInvocation.InvocationName) ] Executing"

        if (-not(Get-Command -Name terraform.exe -ErrorAction SilentlyContinue)) {
            Write-Error "Terraform is not installed!"
            return
        }

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

            $astJsonPtr = [Go.HCLParser]::ParseHCL($absPath)
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

            # Convert the JSON string to a PowerShell object and pretty-print it

            $ast = try {

                if ($PSVersionTable.PSVersion.Major -gt 5) {
                    $astJson | ConvertFrom-Json -Depth 99 -ErrorAction Stop
                } else {
                    $astJson | ConvertFrom-Json -ErrorAction Stop
                }
                
            } catch {
                Write-Error $_.Exception.Message
                return
            }

            $ast.Body.Blocks | ForEach-Object {
                $_
            }

        } catch {
            throw "Error in Get-TerraformAST: $_"
        }

    }

    END {

        Write-Verbose "[ $($MyInvocation.InvocationName) ] Executing"

    }

}