# Test the OCR + AI chain by passing a raw receipt text dump.
# Usage: ./tool/test_ocr.ps1 "MCDONALD'S total 500"

param (
    [Parameter(Mandatory=$true)]
    [string]$ReceiptText
)

# Run the existing parser CLI with the receipt text
dart tool/parser_cli.dart "$ReceiptText" "Rishi, Prasi, Alex" "Rishi"
