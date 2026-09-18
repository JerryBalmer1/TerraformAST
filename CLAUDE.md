# TerraformAST

PowerShell module that parses Terraform `.tf` files into an HCL AST via a Go `c-shared` DLL (`hashicorp/hcl/v2`).

Requires PowerShell 7.4+, Pester 6.1.0+, Terraform CLI (fixture/dev check), and a running Docker engine to build the DLL.

## Layout

```
src/go/                 Go parser (hcl_parser.go) — buildmode=c-shared
src/TerraformAST/       PowerShell module root
  TerraformAST.psd1
  TerraformAST.psm1     P/Invoke + ConvertFrom-TerraformHclFile + Get-TerraformAST
  lib/                  TerraformAST.dll (build artifact, gitignored) + TerraformAST.h
infra/                  Fixture modules used by tests and README examples
tests/                  Pester 6.1+ (*.Tests.ps1)
Dockerfile              Cross-compile Windows DLL with mingw from Linux
.build.ps1              InvokeBuild: CheckDependencies, BuildDLL, Test, Package
```

Module name is **TerraformAST**. Do not reintroduce `PS.Util.Terraform`.

Public cmdlet is `Get-TerraformAST`:
- `-Path` directory (optional `-Recurse`)
- `-FilePath` one `.tf` file

## Build

DLL is not committed (`*.dll` in `.gitignore`). Produce it with:

```powershell
Invoke-Build CheckDependencies
Invoke-Build BuildDLL
Invoke-Build
```

`CheckDependencies` runs once per `Invoke-Build` invocation. `BuildDLL` and `Test` both depend on it.

Paths that must stay aligned:

| Role | Path |
|---|---|
| `go build -o` | `/app/src/TerraformAST/lib/TerraformAST.dll` |
| Docker `COPY --from=builder` | `/app/src/TerraformAST/lib/TerraformAST.dll` → `/TerraformAST.dll` |
| `docker cp` in BuildDLL | `terraformast-tmp:/TerraformAST.dll` → `src\TerraformAST\lib\TerraformAST.dll` |
| Module loader | `Join-Path $PSScriptRoot "lib\TerraformAST.dll"` |

Image tag is `terraformast`. Temporary container is `terraformast-tmp`.

`mkdir -p` the lib directory in the builder stage before `go build`.

## Conventions

- Work on `develop`. PRs into `main`.
- Keep changes scoped. No drive-by refactors.
- Do not commit secrets, `.tfstate`, compiled `.dll` files, or `TerraformAST.zip`.
- PowerShell 7.4+. Go module is `hcl_parser`.
- Fixtures live under `infra/`. Do not resurrect root `test.tf`.

## Do not

- Invent cloud credentials or real provider configs for fixtures.
- Change export names `ParseHCL` / `FreeString` without updating the P/Invoke signatures.
- Put `terraform.exe` in `ExternalModuleDependencies` — that field is PowerShell modules only.
