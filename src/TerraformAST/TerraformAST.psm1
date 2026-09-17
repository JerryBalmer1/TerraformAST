$dllPath = Join-Path $PSScriptRoot "lib\TerraformAST.dll"
if (-not (Test-Path $dllPath)) {
    throw "DLL not found: $dllPath"
}

# Verbatim C# string so Windows backslashes are not treated as escapes.
$signature = @"
    [DllImport(@"$dllPath", EntryPoint = "ParseHCL", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr ParseHCL(string filePath);

    [DllImport(@"$dllPath", EntryPoint = "FreeString", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
    public static extern void FreeString(IntPtr str);
"@

$typeName = 'TerraformAST.HCLParser'
$alreadyLoaded = [AppDomain]::CurrentDomain.GetAssemblies() |
    ForEach-Object { try { $_.GetType($typeName, $false, $false) } catch { $null } } |
    Where-Object { $_ }

if (-not $alreadyLoaded) {
    Add-Type -MemberDefinition $signature -Name HCLParser -Namespace TerraformAST
}

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

        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            Write-Error "The -Path $Path does not exist!"
            return
        }

        if (-not (([System.IO.FileInfo]$Path).Extension -eq ".tf")) {
            Write-Error "The -Path $Path file extension is not .tf"
            return
        }

        $absPath = try {
            (Resolve-Path $Path -ErrorAction Stop).Path
        } catch {
            Write-Error $_.Exception.Message
            return
        }

        Write-Verbose " - $absPath"

        try {
            $astJsonPtr = [TerraformAST.HCLParser]::ParseHCL($absPath)

            if ($astJsonPtr -eq [IntPtr]::Zero) {
                throw "Failed to parse HCL file: Null pointer returned"
            }

            try {
                $astJson = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($astJsonPtr)
            }
            finally {
                [TerraformAST.HCLParser]::FreeString($astJsonPtr)
            }

            if (-not $astJson) {
                throw "Failed to convert AST JSON to string"
            }

            if ($astJson.StartsWith("Error ")) {
                throw $astJson
            }

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

            $ast.Body.Blocks | ForEach-Object { $_ }
        }
        catch {
            throw "Error in Get-TerraformAST: $_"
        }
    }

    END {
        Write-Verbose "[ $($MyInvocation.InvocationName) ] Executing"
    }
}
