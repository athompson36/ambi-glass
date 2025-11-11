#!/usr/bin/env bash
# Generate PDF from markdown feature summary
# Uses macOS built-in tools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MD_FILE="$PROJECT_ROOT/FEATURE_SUMMARY.md"
HTML_FILE="$PROJECT_ROOT/FEATURE_SUMMARY.html"
PDF_FILE="$PROJECT_ROOT/FEATURE_SUMMARY.pdf"

echo "📄 Generating PDF from Feature Summary..."
echo ""

# Check if markdown file exists
if [ ! -f "$MD_FILE" ]; then
    echo "❌ Error: FEATURE_SUMMARY.md not found"
    exit 1
fi

# Method 1: Try using pandoc if available
if command -v pandoc &> /dev/null; then
    echo "✅ Using pandoc to convert markdown to PDF..."
    pandoc "$MD_FILE" -o "$PDF_FILE" \
        --pdf-engine=pdflatex \
        -V geometry:margin=1in \
        -V fontsize=11pt \
        -V documentclass=article \
        --toc \
        --toc-depth=2
    echo "✅ PDF generated: $PDF_FILE"
    exit 0
fi

# Method 2: Convert to HTML first, then use macOS tools
echo "📝 Converting markdown to HTML..."

# Create HTML with proper styling
cat > "$HTML_FILE" << 'HTMLHEAD'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>AmbiGlass Feature Summary</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #0066cc;
            border-bottom: 3px solid #0066cc;
            padding-bottom: 10px;
        }
        h2 {
            color: #0066cc;
            margin-top: 30px;
            border-bottom: 2px solid #e0e0e0;
            padding-bottom: 5px;
        }
        h3 {
            color: #333;
            margin-top: 20px;
        }
        code {
            background-color: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: "SF Mono", Monaco, monospace;
        }
        pre {
            background-color: #f4f4f4;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        ul, ol {
            margin-left: 20px;
        }
        li {
            margin-bottom: 8px;
        }
        hr {
            border: none;
            border-top: 1px solid #e0e0e0;
            margin: 30px 0;
        }
        @media print {
            body { margin: 0; padding: 15px; }
            h1 { page-break-after: avoid; }
            h2 { page-break-after: avoid; }
        }
    </style>
</head>
<body>
HTMLHEAD

# Convert markdown to HTML (basic conversion)
# Replace markdown syntax with HTML
sed -E '
    s/^# (.*)$/<h1>\1<\/h1>/
    s/^## (.*)$/<h2>\1<\/h2>/
    s/^### (.*)$/<h3>\1<\/h3>/
    s/^#### (.*)$/<h4>\1<\/h4>/
    s/\*\*(.*)\*\*/<strong>\1<\/strong>/g
    s/\*(.*)\*/<em>\1<\/em>/g
    s/`([^`]*)`/<code>\1<\/code>/g
    s/^---$/<hr>/
    s/^$/<\/p><p>/' "$MD_FILE" | \
    sed '1s/^/<p>/' | \
    sed '$s/$/<\/p>/' >> "$HTML_FILE"

echo "</body></html>" >> "$HTML_FILE"

echo "✅ HTML generated: $HTML_FILE"
echo ""
echo "📄 To generate PDF:"
echo "   1. Open $HTML_FILE in Safari or Chrome"
echo "   2. Press ⌘P (Print)"
echo "   3. Choose 'Save as PDF'"
echo ""
echo "   Or use command line:"
echo "   open $HTML_FILE"
echo ""

# Try to use textutil or cupsfilter if available
if command -v cupsfilter &> /dev/null; then
    echo "🖨️  Attempting to convert HTML to PDF using cupsfilter..."
    cupsfilter "$HTML_FILE" > "$PDF_FILE" 2>/dev/null && echo "✅ PDF generated: $PDF_FILE" || echo "⚠️  cupsfilter conversion failed, use manual method above"
fi

