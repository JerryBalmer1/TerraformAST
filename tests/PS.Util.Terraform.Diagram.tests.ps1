
Describe "PS.Util.Terraform.Diagram" {
    
    BeforeAll {
        Invoke-Build ImportModule
    }

    AfterAll {
        Invoke-Build RemoveModule
    }

    Context "- Get-TerraformAST" {
        BeforeAll {
            $path = Join-Path $global:BUILD_ROOT "test.tf"
            $ast = Get-TerraformAST -Path $path -ErrorAction Stop
        }
        It "Should return AST" {
            # Replace 'Get-HelloWorld' with a real function from your module
            $ast | Should -Not -BeNullOrEmpty
        }
    }

}