Describe "TerraformAST" {

    BeforeAll {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $infra    = Join-Path $repoRoot "infra"
        $mainTf   = Join-Path $infra "main.tf"
        Set-Variable -Name RepoRoot -Value $repoRoot -Scope Script
        Set-Variable -Name Infra    -Value $infra    -Scope Script
        Set-Variable -Name MainTf   -Value $mainTf   -Scope Script
    }

    Context "Get-TerraformAST" {

        It "is exported" {
            Get-Command Get-TerraformAST -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It "parses infra with -Path" {
            $ast = @(Get-TerraformAST -Path $Infra -ErrorAction Stop)
            $ast | Should -Not -BeNullOrEmpty
            $ast.Type | Should -Contain "variable"
            $ast.Type | Should -Contain "module"
            $ast.Type | Should -Not -Contain "nested-only-sentinel"
        }

        It "parses infra with -Path -Recurse and includes nested modules" {
            $ast = @(Get-TerraformAST -Path $Infra -Recurse -ErrorAction Stop)
            $labels = @($ast | ForEach-Object { $_.Labels })
            $labels | Should -Contain "endpoint"
            $labels | Should -Contain "listener"
        }

        It "parses a file with -FilePath" {
            $ast = @(Get-TerraformAST -FilePath $MainTf -ErrorAction Stop)
            $ast | Should -Not -BeNullOrEmpty
            $ast.Type | Should -Contain "terraform"
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

    Context "block types in infra" {

        BeforeAll {
            $blocks = @(Get-TerraformAST -Path $Infra -ErrorAction Stop)
            Set-Variable -Name Blocks -Value $blocks -Scope Script
        }

        It "finds terraform" {
            $Blocks.Type | Should -Contain "terraform"
        }

        It "finds provider" {
            $Blocks.Type | Should -Contain "provider"
        }

        It "finds variable" {
            $Blocks.Type | Should -Contain "variable"
        }

        It "finds locals" {
            $Blocks.Type | Should -Contain "locals"
        }

        It "finds resource" {
            $Blocks.Type | Should -Contain "resource"
        }

        It "finds data" {
            $Blocks.Type | Should -Contain "data"
        }

        It "finds module" {
            $Blocks.Type | Should -Contain "module"
        }

        It "finds output" {
            $Blocks.Type | Should -Contain "output"
        }

        It "finds check" {
            $Blocks.Type | Should -Contain "check"
        }
    }

    Context "variable labels in infra" {

        BeforeAll {
            $names = @(
                Get-TerraformAST -Path $Infra -ErrorAction Stop |
                    Where-Object Type -eq "variable" |
                    ForEach-Object { $_.Labels[0] }
            )
            Set-Variable -Name VariableNames -Value $names -Scope Script
        }

        It "includes string variable aws_region" {
            $VariableNames | Should -Contain "aws_region"
        }

        It "includes number variable instance_count" {
            $VariableNames | Should -Contain "instance_count"
        }

        It "includes bool variable enable_public_ip" {
            $VariableNames | Should -Contain "enable_public_ip"
        }

        It "includes list variable availability_zones" {
            $VariableNames | Should -Contain "availability_zones"
        }

        It "includes map variable tags" {
            $VariableNames | Should -Contain "tags"
        }

        It "includes object variable endpoint" {
            $VariableNames | Should -Contain "endpoint"
        }

        It "includes tuple variable pair" {
            $VariableNames | Should -Contain "pair"
        }
    }
}
