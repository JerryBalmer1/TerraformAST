<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&height=220&section=header&color=0:1B1030,45:5C4EE5,100:844FBA&text=TerraformAST&fontSize=52&fontColor=FFFFFF&fontAlignY=38&desc=Parse%20.tf%20files%20into%20an%20HCL%20abstract%20syntax%20tree&descSize=16&descAlignY=62&animation=fadeIn" alt="TerraformAST" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-7.4%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell 7.4+" />
  <img src="https://img.shields.io/badge/Pester-6.1%2B-0078D4?style=for-the-badge" alt="Pester 6.1+" />
  <img src="https://img.shields.io/badge/HCL-v2-844FBA?style=for-the-badge" alt="HashiCorp HCL v2" />
  <a href="https://www.powershellgallery.com/packages/TerraformAST"><img src="https://img.shields.io/powershellgallery/v/TerraformAST?style=for-the-badge&label=Gallery" alt="PowerShell Gallery" /></a>
</p>

<p align="center">
  <sub><a href="https://github.com/kyechan99/capsule-render">Above was created by capsule-render</a></sub>
</p>

PowerShell module that parses Terraform `.tf` files into an HCL abstract syntax tree.

> **Requires PowerShell 7.4+.** Agents, skills, and tool runners should use 7.4 (or later) so `$ErrorActionPreference = 'Stop'` is a first-class default you can rely on. On older hosts a failed parse is often a *non-terminating* error: the pipeline keeps going, the agent reads “success,” and it never gets a chance to correct the path or the HCL. 7.4 is the line this module draws so an agent actually *sees* the failure and can fix it.

There was no Terraform AST cmdlet I could drop into a pipeline, so this module exists. The native parser is a `c-shared` DLL built from [HashiCorp HCL v2](https://github.com/hashicorp/hcl) — the same language library Terraform uses — not from the `hashicorp/terraform` application repository.

Source version **2.0.0** (`-Path` is a directory; `-FilePath` is a single `.tf` file). Gallery listing still at [TerraformAST 1.0.1](https://www.powershellgallery.com/packages/TerraformAST/1.0.1) until 2.0.0 is published.

---

## Requirements

- OS: Windows (native DLL is a Windows build)
- PowerShell **7.4 or later** (enforced by the module manifest)
- ~100 MB free space if you are compiling the DLL yourself (Go + Docker)

## Setup

- Grab the latest build from the PowerShell Gallery (or clone this repo).
- Install for your user account — no admin required.
- Import the module and point `Get-TerraformAST` at `infra` or a `.tf` file.

## Downloads & Links

- [Get the latest published build](https://www.powershellgallery.com/packages/TerraformAST/1.0.1)
- Homepage: https://github.com/JerryBalmer1/TerraformAST
- Gallery: https://www.powershellgallery.com/packages/TerraformAST
- Parser library: https://github.com/hashicorp/hcl

---

## Install

```powershell
Install-Module -Name TerraformAST -Scope CurrentUser
Import-Module TerraformAST
```

## Examples

The repo ships an `infra/` fixture: a root module, a `network` child module, and a nested `endpoint` module. No cloud credentials.

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

### Shape of a variable block

Each pipeline object is one HCL block from HashiCorp HCL v2. Besides `Type` and `Labels`, the object keeps the source map: file name, line, column, and byte offset on the type, each label, and both braces.

```powershell
Get-TerraformAST -FilePath .\infra\variables.tf |
    Where-Object { $_.Type -eq 'variable' -and $_.Labels -contains 'aws_region' } |
    Select-Object -First 1 |
    Format-List *
```

```text
Type            : variable
Labels          : {aws_region}
Body            : @{Attributes=System.Collections.Hashtable; Blocks=System.Object[]}
TypeRange       : @{Filename=C:\__Code\TerraformAST\infra\variables.tf; Start=; End=}
LabelRanges     : {@{Filename=C:\__Code\TerraformAST\infra\variables.tf; Start=; End=}}
OpenBraceRange  : @{Filename=C:\__Code\TerraformAST\infra\variables.tf; Start=; End=}
CloseBraceRange : @{Filename=C:\__Code\TerraformAST\infra\variables.tf; Start=; End=}
```

`Format-List` collapses nested range objects. Pull the coordinates off the properties:

```powershell
$block = Get-TerraformAST -FilePath .\infra\variables.tf |
    Where-Object { $_.Type -eq 'variable' -and $_.Labels -contains 'aws_region' } |
    Select-Object -First 1

$block.TypeRange.Start | Format-List Line, Column, Byte
$block.TypeRange.End   | Format-List Line, Column, Byte
```

```text
Line   : 1
Column : 1
Byte   : 0

Line   : 1
Column : 9
Byte   : 8
```

`variable` on line 1 of `infra/variables.tf` is columns 1–8; the label `aws_region` is in `$block.LabelRanges[0]`. Same pattern on every block type (`resource`, `module`, `output`, …): **`Type`**, **`Labels`**, **`Body`**, plus **`TypeRange` / `LabelRanges` / `OpenBraceRange` / `CloseBraceRange`**.

```powershell
# Line of every root block under .\infra
Get-TerraformAST -Path .\infra |
    Select-Object Type,
                  @{ n = 'Name'; l = { $_.Labels -join '.' } },
                  @{ n = 'Line'; l = { $_.TypeRange.Start.Line } },
                  @{ n = 'File'; l = { Split-Path $_.TypeRange.Filename -Leaf } }
```

```text
Type      Name              Line File
----      ----              ---- ----
terraform                      1 main.tf
provider  null                 1 main.tf
variable  aws_region           1 variables.tf
variable  instance_count       7 variables.tf
output    region               1 outputs.tf
```

```powershell
# Types present at the root of .\infra (no -Recurse)
Get-TerraformAST -Path .\infra |
    Select-Object -ExpandProperty Type -Unique
```

```text
terraform
provider
variable
locals
resource
data
module
output
check
```

---

## Build the DLL (contributors)

If `TerraformAST.dll` is already loaded in this PowerShell process, Windows will refuse to delete it. `BuildDLL` unloads the module first and, if the file is still locked, renames it to `TerraformAST.dll.old` before writing the new one. A brand-new `pwsh` session is still the cleanest option.

```powershell
Invoke-Build CheckDependencies
Invoke-Build BuildDLL
Invoke-Build
```

`BuildDLL` cross-compiles `src/go` with `github.com/hashicorp/hcl/v2` and copies `TerraformAST.dll` into `src/TerraformAST/lib/`.

## Disclaimer

This project is independent. It is not affiliated with HashiCorp.

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&height=120&section=footer&color=0:844FBA,55:5C4EE5,100:1B1030&text=Get-TerraformAST&fontSize=28&fontColor=FFFFFF&fontAlignY=70&animation=fadeIn" alt="" />
</p>
