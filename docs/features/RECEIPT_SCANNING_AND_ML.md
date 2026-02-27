# Receipt scanning and ML stack

Planned receipt-related features (attachments, scan-to-prefill, and later bill-splitting-from-photo) and the chosen ML/AI stack. Receipt **attachments** are an Expenso Plus feature; see docs/internal/MONETIZATION_EXECUTION.md.

## Chosen stack (when implemented)

| Step | Technology | Role |
|------|------------|------|
| Capture/clean receipt image | **Firebase ML Kit — Document Scanner** | Edge detection, crop, rotate, filters; optional ML cleaning. On-device, no camera permission from app. Flutter: `google_mlkit_document_scanner`. |
| Image → text | **Firebase ML Kit — Text Recognition** (on-device or cloud) | OCR. Cloud = first 1k/month free, better for dense receipt text. |
| Text → structured expense | **Groq** (existing) | Same Magic Bar parser: amount, description, split type, participants, payer. `GroqExpenseParserService.parse(userInput: ocrText, ...)`. |

Flow: **Document Scanner (optional) → image → Text Recognition → raw text → Groq → ParsedExpenseResult → existing confirmation flow.**

Rationale: One parsing brain (Groq) for both typed Magic Bar and OCR text. Firebase ML keeps receipt/vision in the same ecosystem (auth, Firestore, Storage already used). No new vendor for OCR unless we later need higher receipt-specific accuracy.

## What does not replace what

- **ML Kit** (text recognition, document scanner, barcode, etc.) does **not** do natural-language → structured expense. It only does vision/OCR and simple NL (translation, language ID). It cannot replace Groq.
- **Gemini** (Firebase AI / Google AI) **can** replace Groq for the parsing step (same prompt → JSON). Recommendation: keep Groq for now; revisit Gemini when consolidating vendors or when adding multimodal (image → Gemini → expense in one call).

## Alternatives (for reference)

| Option | Use when |
|-------|----------|
| **Google Document AI — Expense parser** | Need 95–99% receipt accuracy; OK with ~$0.01/receipt, no free tier. |
| **Veryfi Receipts API** | Want 100 free receipts/month then paid; structured receipt fields (total, merchant, line items). |
| **Mindee Receipt API** | Strong receipt accuracy, structured output; evaluate free tier vs paid. |
| **Tesseract / on-device only** | Offline-first, zero cost; lower accuracy than cloud. |

OMR (optical mark recognition, e.g. checkboxes/bubbles on forms): Firebase ML has no dedicated OMR API. Use **Gemini** with image input and a prompt like “which options are selected?” or deploy a custom TensorFlow Lite model.

## Plus gating (receipts)

- **Receipt attachments** (store photo with expense) = **Expenso Plus**, with 3 free attachments per account then paywall. See MONETIZATION_EXECUTION.md Feature 3.
- **Product decision TBD:** Whether **scan-to-prefill** (camera → OCR → Groq → prefill Magic Bar) is (a) part of the same Plus receipt feature (e.g. “Scan receipt” counts toward 3 free / Plus), or (b) free as an input method with only **attaching** the image to the expense gated as Plus.

## Implementation order (from APP_BLUEPRINT)

1. **Receipt attachments** (Plus): attach photo to expense; storage (e.g. Firebase Storage or local). No OCR required for v1.
2. **Scan to prefill** (optional): Document Scanner + Text Recognition → text → Groq; prefill Magic Bar; optionally attach image (then Plus gating applies if attach).
3. **Bill splitting via camera (OCR)** (deferred): One photo, extract line items + total, assign to people. High risk; do last. See APP_BLUEPRINT §9.3.

## Dependencies

- Flutter: `google_mlkit_document_scanner`, ML Kit text recognition (or Firebase ML Vision for cloud). Firebase project already required.
- Groq: existing `GROQ_API_KEY`; parser contract in docs/features/PARSER_OUTCOME_CONTRACT.md unchanged. OCR output is just another `userInput` string.

## Doc references

- APP_BLUEPRINT.md §9.1 (Receipt attachments), §9.3 (Bill splitting via camera)
- docs/internal/MONETIZATION_EXECUTION.md (Plus features, receipt paywall)
- docs/features/PARSER_OUTCOME_CONTRACT.md (parser outcomes; applies to Groq whether input is typed or from OCR)
