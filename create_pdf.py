from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.enums import TA_LEFT, TA_CENTER
import markdown2

# Read the markdown file
with open("docs/PROJECT_DOCUMENTATION.md", "r", encoding="utf-8") as f:
    content = f.read()

# Create PDF
pdf_path = "docs/PROJECT_DOCUMENTATION.pdf"
doc = SimpleDocTemplate(pdf_path, pagesize=letter,
                       topMargin=0.75*inch, bottomMargin=0.75*inch)

# Styles
styles = getSampleStyleSheet()
title_style = ParagraphStyle(
    'CustomTitle',
    parent=styles['Heading1'],
    fontSize=24,
    textColor='#2196F3',
    spaceAfter=30,
    alignment=TA_CENTER
)

heading_style = ParagraphStyle(
    'CustomHeading',
    parent=styles['Heading2'],
    fontSize=16,
    textColor='#1976D2',
    spaceAfter=12,
    spaceBefore=12
)

code_style = ParagraphStyle(
    'Code',
    parent=styles['Code'],
    fontSize=9,
    leftIndent=20,
    textColor='#333333',
    backColor='#F5F5F5'
)

# Build PDF content
story = []

# Title
story.append(Paragraph("Interview Prep AI", title_style))
story.append(Paragraph("Complete Project Documentation", styles['Heading2']))
story.append(Paragraph("Week 1 Progress Report & Continuation Guide", styles['Normal']))
story.append(Spacer(1, 0.5*inch))

# Process markdown content
lines = content.split('\n')
for line in lines:
    if line.startswith('# '):
        story.append(PageBreak())
        story.append(Paragraph(line[2:], title_style))
    elif line.startswith('## '):
        story.append(Spacer(1, 0.2*inch))
        story.append(Paragraph(line[3:], heading_style))
    elif line.startswith('```'):
        continue
    elif line.strip():
        try:
            story.append(Paragraph(line, styles['Normal']))
        except:
            story.append(Preformatted(line, code_style))
    else:
        story.append(Spacer(1, 0.1*inch))

# Build PDF
doc.build(story)
print(f"✅ PDF created: {pdf_path}")
