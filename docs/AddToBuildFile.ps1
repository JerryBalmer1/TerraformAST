cd src/go
go mod tidy
go mod download
go build -o "../PS.Util.Terraform/lib/PS.Util.Terraform.dll" -buildmode=c-shared .