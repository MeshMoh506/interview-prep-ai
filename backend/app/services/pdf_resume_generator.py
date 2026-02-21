from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.pdfgen import canvas
from typing import Dict, List
import os

class PDFResumeGenerator:
    """Generate professional PDF resumes using ReportLab"""
    
    TEMPLATES = {
        "professional": {
            "name": "Professional",
            "description": "Clean corporate format with blue accents",
            "primary_color": colors.HexColor("#2C3E50"),
            "accent_color": colors.HexColor("#3498DB"),
        },
        "modern": {
            "name": "Modern",
            "description": "Contemporary tech design with green highlights",
            "primary_color": colors.HexColor("#2980B9"),
            "accent_color": colors.HexColor("#27AE60"),
        },
        "minimal": {
            "name": "Minimal",
            "description": "Simple black & white ATS-friendly",
            "primary_color": colors.black,
            "accent_color": colors.HexColor("#666666"),
        },
        "creative": {
            "name": "Creative",
            "description": "Bold design for creative roles",
            "primary_color": colors.HexColor("#9B59B6"),
            "accent_color": colors.HexColor("#E74C3C"),
        },
        "executive": {
            "name": "Executive",
            "description": "Elegant style for senior roles",
            "primary_color": colors.HexColor("#1A237E"),
            "accent_color": colors.HexColor("#C0A872"),
        }
    }
    
    def __init__(self):
        self.output_dir = "generated_resumes"
        os.makedirs(self.output_dir, exist_ok=True)
    
    def generate_pdf(
        self,
        resume_data: Dict,
        template_id: str = "professional",
        user_id: int = 0
    ) -> Dict:
        """Generate PDF resume"""
        
        template = self.TEMPLATES.get(template_id, self.TEMPLATES["professional"])
        filename = f"resume_{user_id}_{template_id}.pdf"
        filepath = os.path.join(self.output_dir, filename)
        
        try:
            doc = SimpleDocTemplate(
                filepath,
                pagesize=letter,
                rightMargin=0.75*inch,
                leftMargin=0.75*inch,
                topMargin=0.6*inch,
                bottomMargin=0.6*inch,
            )
            
            story = []
            styles = self._create_styles(template)
            
            # Build resume
            contact = resume_data.get("contact_info") or {}
            
            # Header (Name + Contact)
            story.extend(self._add_header(contact, styles))
            story.append(Spacer(1, 0.2*inch))
            
            # Summary
            if resume_data.get("summary"):
                story.extend(self._add_section("PROFESSIONAL SUMMARY", resume_data["summary"], styles))
                story.append(Spacer(1, 0.15*inch))
            
            # Experience
            if resume_data.get("experience"):
                story.extend(self._add_experience(resume_data["experience"], styles))
                story.append(Spacer(1, 0.15*inch))
            
            # Education
            if resume_data.get("education"):
                story.extend(self._add_education(resume_data["education"], styles))
                story.append(Spacer(1, 0.15*inch))
            
            # Skills
            if resume_data.get("skills"):
                story.extend(self._add_skills(resume_data["skills"], styles))
                story.append(Spacer(1, 0.15*inch))
            
            # Projects
            if resume_data.get("projects"):
                story.extend(self._add_projects(resume_data["projects"], styles))
                story.append(Spacer(1, 0.15*inch))
            
            # Certifications
            if resume_data.get("certifications"):
                story.extend(self._add_certifications(resume_data["certifications"], styles))
            
            doc.build(story)
            
            return {
                "success": True,
                "file_path": filepath,
                "filename": filename,
                "template_used": template["name"]
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": f"PDF generation failed: {str(e)}"
            }
    
    def _create_styles(self, template):
        """Create custom styles"""
        styles = getSampleStyleSheet()
        
        # Name style
        styles.add(ParagraphStyle(
            name='CustomName',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=template["primary_color"],
            spaceAfter=6,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold'
        ))
        
        # Contact style
        styles.add(ParagraphStyle(
            name='CustomContact',
            parent=styles['Normal'],
            fontSize=9,
            textColor=template["accent_color"],
            alignment=TA_CENTER,
            spaceAfter=12
        ))
        
        # Section header
        styles.add(ParagraphStyle(
            name='CustomSection',
            parent=styles['Heading2'],
            fontSize=12,
            textColor=template["primary_color"],
            spaceAfter=6,
            borderPadding=(0, 0, 2, 0),
            borderColor=template["accent_color"],
            borderWidth=1,
            fontName='Helvetica-Bold'
        ))
        
        # Job title
        styles.add(ParagraphStyle(
            name='CustomJobTitle',
            parent=styles['Normal'],
            fontSize=11,
            textColor=template["primary_color"],
            spaceAfter=4,
            fontName='Helvetica-Bold'
        ))
        
        # Company/School
        styles.add(ParagraphStyle(
            name='CustomCompany',
            parent=styles['Normal'],
            fontSize=10,
            textColor=template["accent_color"],
            spaceAfter=6,
            fontName='Helvetica-Bold'
        ))
        
        return styles
    
    def _add_header(self, contact, styles):
        """Add name and contact info"""
        elements = []
        
        # Name
        name = contact.get("name", "YOUR NAME")
        elements.append(Paragraph(name.upper(), styles['CustomName']))
        
        # Contact line
        contact_parts = []
        if contact.get("email"):
            contact_parts.append(f"✉ {contact['email']}")
        if contact.get("phone"):
            contact_parts.append(f"☎ {contact['phone']}")
        if contact.get("linkedin"):
            contact_parts.append(f"LinkedIn")
        if contact.get("github"):
            contact_parts.append(f"GitHub")
        
        if contact_parts:
            elements.append(Paragraph(
                " | ".join(contact_parts),
                styles['CustomContact']
            ))
        
        return elements
    
    def _add_section(self, title, content, styles):
        """Add section with title and content"""
        elements = []
        elements.append(Paragraph(title, styles['CustomSection']))
        if content:
            elements.append(Paragraph(str(content), styles['Normal']))
        return elements
    
    def _add_experience(self, experience, styles):
        """Add work experience"""
        elements = []
        elements.append(Paragraph("WORK EXPERIENCE", styles['CustomSection']))
        
        for exp in experience:
            if not isinstance(exp, dict):
                continue
            
            # Title | Company
            title_text = f"{exp.get('title', 'Position')} | {exp.get('company', 'Company')}"
            elements.append(Paragraph(title_text, styles['CustomJobTitle']))
            
            # Date
            if exp.get("duration"):
                elements.append(Paragraph(
                    f"📅 {exp['duration']}",
                    styles['CustomCompany']
                ))
            
            # Description bullets
            desc = exp.get("description", "")
            if isinstance(desc, list):
                for bullet in desc:
                    elements.append(Paragraph(
                        f"• {bullet}",
                        styles['Normal']
                    ))
            elif desc:
                for line in str(desc).split("\n"):
                    if line.strip():
                        elements.append(Paragraph(
                            f"• {line.strip('• ').strip()}",
                            styles['Normal']
                        ))
            
            elements.append(Spacer(1, 0.1*inch))
        
        return elements
    
    def _add_education(self, education, styles):
        """Add education"""
        elements = []
        elements.append(Paragraph("EDUCATION", styles['CustomSection']))
        
        for edu in education:
            if not isinstance(edu, dict):
                continue
            
            degree = f"{edu.get('degree', '')} | {edu.get('institution', edu.get('university', ''))}"
            elements.append(Paragraph(degree, styles['CustomJobTitle']))
            
            details = []
            if edu.get("year"):
                details.append(f"📅 {edu['year']}")
            if edu.get("gpa"):
                details.append(f"GPA: {edu['gpa']}")
            
            if details:
                elements.append(Paragraph(
                    " | ".join(details),
                    styles['CustomCompany']
                ))
            
            elements.append(Spacer(1, 0.1*inch))
        
        return elements
    
    def _add_skills(self, skills, styles):
        """Add skills"""
        elements = []
        elements.append(Paragraph("TECHNICAL SKILLS", styles['CustomSection']))
        
        # Group by category
        categorized = {}
        for skill in skills:
            if isinstance(skill, dict):
                cat = skill.get("category", "Technical Skills")
                name = skill.get("name", str(skill))
            else:
                cat = "Technical Skills"
                name = str(skill)
            
            if cat not in categorized:
                categorized[cat] = []
            categorized[cat].append(name)
        
        for category, skill_list in categorized.items():
            text = f"<b>{category}:</b> {', '.join(skill_list)}"
            elements.append(Paragraph(text, styles['Normal']))
        
        return elements
    
    def _add_projects(self, projects, styles):
        """Add projects"""
        elements = []
        elements.append(Paragraph("PROJECTS", styles['CustomSection']))
        
        for proj in projects:
            if not isinstance(proj, dict):
                continue
            
            elements.append(Paragraph(
                proj.get("name", "Project"),
                styles['CustomJobTitle']
            ))
            
            if proj.get("technologies"):
                tech = proj["technologies"]
                if isinstance(tech, list):
                    tech = ", ".join(tech)
                elements.append(Paragraph(
                    f"🛠️ {tech}",
                    styles['CustomCompany']
                ))
            
            if proj.get("description"):
                elements.append(Paragraph(
                    f"• {proj['description'][:200]}",
                    styles['Normal']
                ))
            
            elements.append(Spacer(1, 0.1*inch))
        
        return elements
    
    def _add_certifications(self, certifications, styles):
        """Add certifications"""
        elements = []
        elements.append(Paragraph("CERTIFICATIONS", styles['CustomSection']))
        
        for cert in certifications:
            if isinstance(cert, dict):
                text = cert.get("name", "Certification")
                if cert.get("issuer"):
                    text += f" | {cert['issuer']}"
                if cert.get("year"):
                    text += f" ({cert['year']})"
            else:
                text = str(cert)
            
            elements.append(Paragraph(f"• {text}", styles['Normal']))
        
        return elements
