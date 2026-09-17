Describe "TerraformAST" {

    BeforeAll {
        $script:RepoRoot = Split-Path $PSScriptRoot -Parent
        $script:Fixture  = Join-Path $script:RepoRoot "test.tf"
    }

    Context "Get-TerraformAST" {

        It "is exported" {
            Get-Command Get-TerraformAST -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It "parses test.tf" {
            $ast = Get-TerraformAST -Path $script:Fixture -ErrorAction Stop
            $ast | Should -Not -BeNullOrEmpty
        }

        It "rejects a missing file" {
            { Get-TerraformAST -Path (Join-Path $script:RepoRoot "does-not-exist.tf") -ErrorAction Stop } |
                Should -Throw
        }

        It "rejects a non-.tf path" {
            { Get-TerraformAST -Path $PSCommandPath -ErrorAction Stop } |
                Should -Throw
        }

    }

}
