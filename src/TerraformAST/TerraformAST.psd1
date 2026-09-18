@{

    RootModule        = 'TerraformAST.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = '2d0b1461-c90f-421d-9c12-a3ed0486f0f9'
    Author            = 'Jerry Balmer'
    CompanyName       = 'Jerry Balmer'
    Copyright         = '(c) Jerry Balmer. All rights reserved.'
    Description       = 'Parse Terraform .tf files into an HCL abstract syntax tree from PowerShell. Requires PowerShell 7.4+ so agents can treat errors as terminating.'
    PowerShellVersion = '7.4'

    FunctionsToExport = @('Get-TerraformAST')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # ExternalModuleDependencies is PowerShell *modules* only (names Install-Module
    # would resolve). terraform.exe is a native binary, not a module, and this
    # parser does not call it — HCL is loaded from TerraformAST.dll.
    PrivateData = @{
        PSData = @{
            Tags                       = @('Terraform', 'HCL', 'AST', 'InfrastructureAsCode', 'PowerShell74')
            ProjectUri                 = 'https://github.com/JerryBalmer1/TerraformAST'
            LicenseUri                 = 'https://github.com/JerryBalmer1/TerraformAST'
            ReleaseNotes               = '2.0.0: Breaking. -Path is a directory; use -FilePath for a single .tf file. Requires PowerShell 7.4+. Native parser built from HashiCorp HCL v2.'
            RequireLicenseAcceptance   = $false
            ExternalModuleDependencies = @()
        }
    }

}
