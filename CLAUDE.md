# TerraformAST

PowerShell module that parses Terraform `.tf` files into an HCL AST via a Go `c-shared` DLL (`hashicorp/hcl/v2`).

## Layout

```
src/go/                 Go parser (hcl_parser.go) — buildmode=c-shared
src/TerraformAST/       PowerShell module root
  TerraformAST.psd1
  TerraformAST.psm1     P/Invoke + Get-TerraformAST
  lib/                  TerraformAST.dll (build artifact) + TerraformAST.h
Dockerfile              Cross-compile Windows DLL with mingw from Linux
.build.ps1              InvokeBuild tasks (BuildDLL, Test, Package)
```

Module name is **TerraformAST**. Do not reintroduce `PS.Util.Terraform`.

## Build

DLL is not committed (`*.dll` in `.gitignore`). Produce it with:

```powershell
Invoke-Build BuildDLL
```

That builds the image, copies `/TerraformAST.dll` from the container into `src/TerraformAST/lib/TerraformAST.dll`.

Paths that must stay aligned:

| Role | Path |
|---|---|
| `go build -o` | `/app/src/TerraformAST/lib/TerraformAST.dll` |
| Docker `COPY --from=builder` | `/app/src/TerraformAST/lib/TerraformAST.dll` → `/TerraformAST.dll` |
| `docker cp` in BuildDLL | `psutiltmp:/TerraformAST.dll` → `src\TerraformAST\lib\TerraformAST.dll` |
| Module loader | `Join-Path $PSScriptRoot "lib\TerraformAST.dll"` |

`mkdir -p` the lib directory in the builder stage before `go build`.

## Conventions

- Work on `develop`. PRs into `main`.
- Keep changes scoped. No drive-by refactors.
- Do not commit secrets, `.tfstate`, or compiled `.dll` files.
- PowerShell 7+. Go module is `hcl_parser`.
- Image tag `ps-util-terraform` and container name `psutiltmp` are historical; rename only if you update every reference in `.build.ps1`.

## Do not

- Invent cloud credentials or real provider configs for fixtures.
- Change export names `ParseHCL` / `FreeString` without updating the P/Invoke signatures.
