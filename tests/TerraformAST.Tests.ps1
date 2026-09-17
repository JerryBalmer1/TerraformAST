Describe "TerraformAST" {

    BeforeAll {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $fixture  = Join-Path $repoRoot "test.tf"
        Set-Variable -Name RepoRoot -Value $repoRoot -Scope Script
        Set-Variable -Name Fixture  -Value $fixture  -Scope Script
    }

    Context "Get-TerraformAST" {

        It "is exported" {
            Get-Command Get-TerraformAST -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It "parses a file with -FilePath" {
            $ast = Get-TerraformAST -FilePath $Fixture -ErrorAction Stop
            $ast | Should -Not -BeNullOrEmpty
        }

        It "parses a directory with -Path" {
            $ast = Get-TerraformAST -Path $RepoRoot -ErrorAction Stop
            $ast | Should -Not -BeNullOrEmpty
        }

        It "parses a directory with -Path -Recurse" {
            $ast = Get-TerraformAST -Path $RepoRoot -Recurse -ErrorAction Stop
            $ast | Should -Not -BeNullOrEmpty
        }

        It "rejects a missing file" {
            { Get-TerraformAST -FilePath (Join-Path $RepoRoot "does-not-exist.tf") -ErrorAction Stop } |
                Should -Throw
        }

        It "rejects a non-.tf FilePath" {
            { Get-TerraformAST -FilePath $PSCommandPath -ErrorAction Stop } |
                Should -Throw
        }

        It "rejects a missing directory" {
            { Get-TerraformAST -Path (Join-Path $RepoRoot "does-not-exist-dir") -ErrorAction Stop } |
                Should -Throw
        }

    }

}
