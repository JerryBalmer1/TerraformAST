# Load the Go DLL using P/Invoke
$dllPath = Join-Path $PSScriptRoot "lib\TerraformAST.dll"
if (-not (Test-Path $dllPath)) {
    throw "DLL not found: $dllPath"
}

# Escape backslashes in the file path
$escapedDllPath = $dllPath -replace '\\', '\\'

# Define the signatures of the Go functions
$signature = @"
    [DllImport("$escapedDllPath", EntryPoint = "ParseHCL", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr ParseHCL(IntPtr filePath);

    [DllImport("$escapedDllPath", EntryPoint = "FreeString", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.Cdecl)]
    public static extern void FreeString(IntPtr str);
"@

# Add the type definition

$typeName = 'Go.HCLParser'

$assemblies    = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() }
$alreadyLoaded = $assemblies | Where-Object { $_.FullName -eq $typeName }

if (-not $alreadyLoaded) {
    Add-Type -MemberDefinition $signature -Name HCLParser -Namespace Go
}


foreach($module in (Get-ChildItem (Join-Path $PSScriptRoot "modules"))) {

    Import-Module $module.FullName -Force

}




