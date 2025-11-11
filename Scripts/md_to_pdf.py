#!/usr/bin/env python3
"""
Convert Markdown to PDF using available Python libraries
"""

import sys
import os
from pathlib import Path

def convert_with_markdown2():
    """Convert using markdown2 library"""
    try:
        import markdown2
        from weasyprint import HTML
        
        md_file = Path(__file__).parent.parent / "FEATURE_SUMMARY.md"
        pdf_file = Path(__file__).parent.parent / "FEATURE_SUMMARY.pdf"
        
        with open(md_file, 'r', encoding='utf-8') as f:
            html_content = markdown2.markdown(f.read(), extras=['fenced-code-blocks', 'tables'])
        
        html_doc = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: -apple-system, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }}
                h1 {{ color: #0066cc; border-bottom: 3px solid #0066cc; }}
                h2 {{ color: #0066cc; margin-top: 30px; border-bottom: 2px solid #e0e0e0; }}
                code {{ background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }}
                pre {{ background: #f4f4f4; padding: 15px; border-radius: 5px; }}
            </style>
        </head>
        <body>
        {html_content}
        </body>
        </html>
        """
        
        HTML(string=html_doc).write_pdf(pdf_file)
        print(f"✅ PDF generated: {pdf_file}")
        return True
    except ImportError:
        return False

def convert_with_markdown():
    """Convert using markdown library and reportlab"""
    try:
        import markdown
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib.units import inch
        
        md_file = Path(__file__).parent.parent / "FEATURE_SUMMARY.md"
        pdf_file = Path(__file__).parent.parent / "FEATURE_SUMMARY.pdf"
        
        with open(md_file, 'r', encoding='utf-8') as f:
            md_content = f.read()
        
        html = markdown.markdown(md_content)
        
        # This is a simplified version - full conversion would need HTML parsing
        print("⚠️  Full PDF conversion requires additional libraries")
        print("   Install: pip install markdown2 weasyprint")
        print("   Or use: pip install markdown reportlab")
        return False
    except ImportError:
        return False

if __name__ == "__main__":
    if not convert_with_markdown2():
        if not convert_with_markdown():
            print("❌ No PDF conversion libraries found")
            print("")
            print("Install one of:")
            print("  pip install markdown2 weasyprint")
            print("  pip install markdown reportlab")
            print("  brew install pandoc")
            sys.exit(1)

