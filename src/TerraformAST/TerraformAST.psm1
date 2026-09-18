$dllPath = Join-Path $PSScriptRoot "lib\TerraformAST.dll"
if (-not (Test-Path $dllPath)) {
    throw "DLL not found: $dllPath"
}

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

# Default view: Type, Name, Line, Column, File.
# Everything else is still on the object — use Format-List * or Select-Object *.
$blockTypeName = 'TerraformAST.Block'
Update-TypeData -TypeName $blockTypeName -DefaultDisplayPropertySet Type, Name, Line, Column, File -Force
Update-TypeData -TypeName $blockTypeName -MemberType ScriptProperty -MemberName Name -Value {
    if ($this.Labels) { $this.Labels -join '.' }
} -Force
Update-TypeData -TypeName $blockTypeName -MemberType ScriptProperty -MemberName Line -Value {
    $this.TypeRange.Start.Line
} -Force
Update-TypeData -TypeName $blockTypeName -MemberType ScriptProperty -MemberName Column -Value {
    $this.TypeRange.Start.Column
} -Force
Update-TypeData -TypeName $blockTypeName -MemberType ScriptProperty -MemberName File -Value {
    if ($this.TypeRange.Filename) {
        Split-Path -Path $this.TypeRange.Filename -Leaf
    }
} -Force

function ConvertTo-TerraformAstBlock {
    param($Block)
    $Block.PSObject.TypeNames.Insert(0, 'TerraformAST.Block')
    $Block
}

function ConvertFrom-TerraformHclFile {
    <#
    .SYNOPSIS
        Parses one Terraform .tf file through the native HCL DLL and emits its blocks.

    .DESCRIPTION
        ConvertFrom-TerraformHclFile is the single-file parser used by Get-TerraformAST.
        It resolves a literal path, calls ParseHCL on TerraformAST.dll (HashiCorp HCL v2),
        converts the JSON payload to objects, and writes each top-level block from
        Body.Blocks to the pipeline.

        Prefer Get-TerraformAST for directories, recursion, and validation. This function
        assumes the path already exists.

    .PARAMETER LiteralPath
        Full or relative path to a single .tf file. Wildcards are not expanded.

    .EXAMPLE
        ConvertFrom-TerraformHclFile -LiteralPath .\infra\variables.tf

        Parse one file and emit its HCL blocks.

    .EXAMPLE
        Get-TerraformAST -FilePath .\infra\main.tf

        Public wrapper that validates the path, then calls this function.

    .OUTPUTS
        TerraformAST.Block. Default view is Type, Name, Line, Column, File.
        TypeRange, LabelRanges, Body, and brace ranges remain on the object.

    .NOTES
        Not exported. Get-TerraformAST is the supported entry point.
        Parse failures throw so a 7.4+ agent with ErrorAction Stop can correct them.

    .LINK
        Get-TerraformAST

    .LINK
        https://github.com/JerryBalmer1/TerraformAST
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $LiteralPath
    )

    $absPath = (Resolve-Path -LiteralPath $LiteralPath -ErrorAction Stop).Path
    Write-Verbose "Parsing $absPath"

    $astJsonPtr = [TerraformAST.HCLParser]::ParseHCL($absPath)
    if ($astJsonPtr -eq [IntPtr]::Zero) {
        throw "Failed to parse HCL file: Null pointer returned ($absPath)"
    }

    try {
        $astJson = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($astJsonPtr)
    }
    finally {
        [TerraformAST.HCLParser]::FreeString($astJsonPtr)
    }

    if (-not $astJson) {
        throw "Failed to convert AST JSON to string ($absPath)"
    }

    if ($astJson.StartsWith("Error ")) {
        throw "$astJson ($absPath)"
    }

    if ($PSVersionTable.PSVersion.Major -gt 5) {
        $ast = $astJson | ConvertFrom-Json -Depth 99 -ErrorAction Stop
    }
    else {
        $ast = $astJson | ConvertFrom-Json -ErrorAction Stop
    }

    $ast.Body.Blocks | ForEach-Object { ConvertTo-TerraformAstBlock -Block $_ }
}

function Get-TerraformAST {
    <#
    .SYNOPSIS
        Parses Terraform .tf files into an HCL abstract syntax tree.

    .DESCRIPTION
        Get-TerraformAST walks one file or a directory of Terraform configuration and
        returns the HCL blocks produced by HashiCorp HCL v2 (the language library
        Terraform uses).

        Use -FilePath for a single .tf file. Use -Path for a directory. Add -Recurse
        to include .tf files in subdirectories.

        Default display is Type, Name, Line, Column, and File. Source ranges and Body
        stay on the object; use Format-List * when you need the full tree.

    .PARAMETER Path
        Directory that contains Terraform .tf files.

    .PARAMETER Recurse
        When -Path is used, include .tf files in child directories.

    .PARAMETER FilePath
        A single Terraform .tf file.

    .EXAMPLE
        Get-TerraformAST -Path .\infra

        Parse every .tf file in the infra directory (not recursive).

    .EXAMPLE
        Get-TerraformAST -Path .\infra -Recurse

        Parse every .tf file under infra, including nested modules.

    .EXAMPLE
        Get-TerraformAST -FilePath .\infra\main.tf

        Parse one Terraform file.

    .EXAMPLE
        Get-ChildItem .\infra -Filter *.tf | Get-TerraformAST

        Pipeline input binds to -FilePath via the FullName alias.

    .OUTPUTS
        TerraformAST.Block

    .LINK
        https://github.com/JerryBalmer1/TerraformAST

    .LINK
        https://www.powershellgallery.com/packages/TerraformAST/1.0.1
    #>
    [CmdletBinding(DefaultParameterSetName = 'Directory')]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = 'Directory',
            Position = 0,
            HelpMessage = 'Directory that contains .tf files.'
        )]
        [ValidateScript({
            if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                throw "Path '$_' is not an existing directory."
            }
            $true
        })]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Directory')]
        [switch]
        $Recurse,

        [Parameter(
            Mandatory,
            ParameterSetName = 'File',
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'Path to a single .tf file.'
        )]
        [Alias('FullName')]
        [ValidateScript({
            if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
                throw "FilePath '$_' is not an existing file."
            }
            if (-not ([System.IO.FileInfo]$_).Extension.Equals('.tf', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "FilePath '$_' must have a .tf extension."
            }
            $true
        })]
        [string]
        $FilePath
    )

    begin {
        Write-Verbose "[ $($MyInvocation.InvocationName) ] $($PSCmdlet.ParameterSetName)"
    }

    process {
        $files = switch ($PSCmdlet.ParameterSetName) {
            'File' {
                Get-Item -LiteralPath $FilePath
            }
            'Directory' {
                $gci = @{
                    LiteralPath = $Path
                    Filter      = '*.tf'
                    File        = $true
                    ErrorAction = 'Stop'
                }
                if ($Recurse) {
                    $gci.Recurse = $true
                }
                Get-ChildItem @gci
            }
        }

        if (-not $files) {
            Write-Error "No .tf files found."
            return
        }

        foreach ($file in $files) {
            try {
                ConvertFrom-TerraformHclFile -LiteralPath $file.FullName
            }
            catch {
                Write-Error -ErrorRecord $_
            }
        }
    }
}
