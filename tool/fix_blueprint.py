import re

with open("APP_BLUEPRINT.md", "r", encoding="utf-8") as f:  # run from repo root
    s = f.read()

# Remove orphaned legacy text: from "Settle now" through "at ₹0."
pattern = r' [\u201c"]Settle now[\u201d"].*?at ₹0\.'
s = re.sub(pattern, ".", s, count=1)

with open("APP_BLUEPRINT.md", "w", encoding="utf-8") as f:
    f.write(s)

print("Done")
