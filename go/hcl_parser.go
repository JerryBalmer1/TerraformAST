package main

/*
#include <stdlib.h> // Include the C standard library for free()
*/
import "C"
import (
	"encoding/json"
	"fmt"
	"github.com/hashicorp/hcl/v2/hclparse"
	"log"
	"path/filepath"
	"unsafe" // Add the unsafe package
)

//export ParseHCL
func ParseHCL(filePath *C.char) *C.char {
	// Convert the C string to a Go string
	goFilePath := C.GoString(filePath)

	// Resolve the absolute path (cross-platform)
	absPath, err := filepath.Abs(goFilePath)
	if err != nil {
		log.Printf("Error resolving absolute path: %v", err)
		return C.CString(fmt.Sprintf("Error resolving absolute path: %v", err))
	}

	// Parse the HCL file
	parser := hclparse.NewParser()
	file, diags := parser.ParseHCLFile(absPath)
	if diags.HasErrors() {
		log.Printf("Error parsing HCL file: %v", diags)
		return C.CString(fmt.Sprintf("Error parsing HCL file: %v", diags))
	}

	// Marshal the AST to JSON
	astJson, err := json.Marshal(file)
	if err != nil {
		log.Printf("Error marshaling AST to JSON: %v", err)
		return C.CString(fmt.Sprintf("Error marshaling AST to JSON: %v", err))
	}

	// Return the JSON as a C string
	return C.CString(string(astJson))
}

//export FreeString
func FreeString(str *C.char) {
	C.free(unsafe.Pointer(str))
}

func main() {} // Required for `c-shared` build mode
