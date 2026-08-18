



Get-ChildItem -Recurse -Force -File | Where-Object {$_.Extension -eq '.dll'}

ENTRYPOINT ["pwsh"]
CMD []

FROM mcr.microsoft.com/powershell:latest AS exporter
COPY --from=builder /src/PS.Util.Terraform/lib/PS.Util.Terraform.dll /src/PS.Util.Terraform/lib/PS.Util.Terraform.dll






task BuildDLL {
    docker build -t ps.util.terraform .
    docker run -it --rm ps.util.terraform
    Get-ChildItem -Recurse -Force -File | Where-Object {$_.Extension -eq '.dll'} | Foreach-Object {
        $_.FullName | Write-Host -ForegroundColor Magenta
    }

}




