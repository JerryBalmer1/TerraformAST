FROM mcr.microsoft.com/powershell:latest AS builder

USER root

RUN apt-get update && apt-get install -y \
    git \
    golang-go \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

ENV CGO_ENABLED=1 \
    GOOS=windows \
    GOARCH=amd64 \
    CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++

RUN mkdir -p /app/src/TerraformAST/lib && \
    cd ./src/go && \
    sed -i '/^go /d' go.mod && \
    go mod tidy && \
    go build -o "/app/src/TerraformAST/lib/TerraformAST.dll" -buildmode=c-shared .

FROM mcr.microsoft.com/powershell:latest

COPY --from=builder /app/src/TerraformAST/lib/TerraformAST.dll /TerraformAST.dll

ENTRYPOINT ["pwsh"]

CMD ["-NoLogo"]
