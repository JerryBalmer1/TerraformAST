# TerraformAST

PowerShell module that parses Terraform `.tf` files into an HCL abstract syntax tree.

There was no Terraform AST cmdlet I could drop into a pipeline, so this module exists. The native parser is a `c-shared` DLL built from [HashiCorp HCL v2](https://github.com/hashicorp/hcl) — the same language library Terraform uses — not from the `hashicorp/terraform` application repository.

Published on the PowerShell Gallery: [TerraformAST 1.0.1](https://www.powershellgallery.com/packages/TerraformAST/1.0.1)

---

## Requirements

- OS: Windows (native DLL is a Windows build)
- PowerShell 7+
- ~100 MB free space if you are compiling the DLL yourself (Go + Docker)

## Setup

- Grab the latest build from the PowerShell Gallery (or clone this repo).
- Install for your user account — no admin required.
- Import the module and point `Get-TerraformAST` at a directory or a `.tf` file.

## Downloads & Links

- [Get the latest build](https://www.powershellgallery.com/packages/TerraformAST/1.0.1)
- Homepage: https://github.com/JerryBalmer1/TerraformAST
- Gallery: https://www.powershellgallery.com/packages/TerraformAST/1.0.1
- Parser library: https://github.com/hashicorp/hcl

---

## Install

```powershell
Install-Module -Name TerraformAST -Scope CurrentUser
Import-Module TerraformAST
```

## Examples

### Directory (`-Path`)

Parse `.tf` files in one folder. Subfolders are skipped.

```powershell
Get-TerraformAST -Path .\infra
```

### Directory, recursive (`-Path -Recurse`)

Include nested modules and child directories.

```powershell
Get-TerraformAST -Path .\infra -Recurse
```

### Single file (`-FilePath`)

```powershell
Get-TerraformAST -FilePath .\infra\main.tf
```

---

## Build the DLL (contributors)

```powershell
Invoke-Build BuildDLL
Invoke-Build
```

`BuildDLL` cross-compiles `src/go` with `github.com/hashicorp/hcl/v2` and copies `TerraformAST.dll` into `src/TerraformAST/lib/`.

## Disclaimer

This project is independent. It is not affiliated with HashiCorp.
