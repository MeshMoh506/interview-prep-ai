import re
from typing import Dict, List

class FormatCheckerService:
    """Check resume for ATS-killing formatting issues"""
    
    def check_format(self, resume_text: str) -> Dict:
        """
        Analyze resume text for formatting issues
        Returns detailed format report
        """
        issues = []
        warnings = []
        passed = []
        score = 100 # Start with a perfect score, then your score will be reduced if there are any problems or warnings
        
        # Check 1: Length
        words = len(resume_text.split())
        if words < 200:
            issues.append({
                "type": "critical",
                "issue": "Resume too short",
                "detail": f"Only {words} words. Aim for 400-800 words.",
                "fix": "Add more details to experience and projects sections, and consider adding a summary or skills section if missing, also add any volunteering or initiatives you participated in or subjects you excelled in during your studies"
            })
            score -= 15
        elif words > 1000:
            warnings.append({
                "type": "warning",
                "issue": "Resume might be too long",
                "detail": f"{words} words. Keep to 1 page (400-800 words).",
                "fix": "Remove less relevant experience or condense descriptions and focus on most recent and impactful roles, also remove any irrelevant or outdated information that doesn't add value to your current job search goals"
            })
            score -= 5
        else:
            passed.append(f"✅ Good length: {words} words")
        
        # Check 2: Contact Information
        has_email = bool(re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', resume_text))
        has_phone = bool(re.search(r'(\+966|05)\d[\d\s]{8,}', resume_text))
        
        if not has_email:
            issues.append({
                "type": "critical",
                "issue": "Missing email address",
                "detail": "ATS systems need email to identify candidates",
                "fix": "Add your professional email address"
            })
            score -= 20
        else:
            passed.append("✅ Email address found")
        
        if not has_phone:
            warnings.append({
                "type": "warning",
                "issue": "Phone number not detected",
                "detail": "Make sure your phone number is clearly formatted",
                "fix": "Add phone in format: +966 5X XXX XXXX"
            })
            score -= 10
        else:
            passed.append("✅ Phone number found")
        
        # Check 3: Essential Sections
        essential_sections = {
            'education': ['education', 'academic', 'university', 'degree'],
            'experience': ['experience', 'employment', 'work', 'cooperative', 'training'],
            'skills': ['skills', 'technical', 'technologies', 'competencies'],
        }
        
        for section, keywords in essential_sections.items():
            found = any(kw in resume_text.lower() for kw in keywords)
            if not found:
                issues.append({
                    "type": "critical",
                    "issue": f"Missing {section.upper()} section",
                    "detail": f"ATS systems look for standard section headers",
                    "fix": f"Add a clear '{section.capitalize()}' section header"
                })
                score -= 15
            else:
                passed.append(f"✅ {section.capitalize()} section found")
        
        # Check 4: Summary/Objective
        has_summary = any(kw in resume_text.lower() for kw in ['summary', 'objective', 'profile', 'about'])
        if not has_summary:
            warnings.append({
                "type": "warning",
                "issue": "Missing professional summary",
                "detail": "Summary helps ATS match you to positions",
                "fix": "Add 2-3 sentence professional summary at top"
            })
            score -= 5
        else:
            passed.append("✅ Professional summary found")
        
        # Check 5: Keywords Density
        tech_keywords = ['python', 'javascript', 'react', 'sql', 'git', 'api', 'database', 'development']
        found_keywords = [kw for kw in tech_keywords if kw in resume_text.lower()]
        keyword_density = len(found_keywords) / len(tech_keywords) * 100
        
        if keyword_density < 30:
            warnings.append({
                "type": "warning",
                "issue": "Low keyword density",
                "detail": f"Only {len(found_keywords)}/{len(tech_keywords)} common tech keywords found",
                "fix": "Add more relevant technical keywords throughout resume"
            })
            score -= 10
        else:
            passed.append(f"✅ Good keyword density: {keyword_density:.0f}%")
        
        # Check 6: Action Verbs
        weak_verbs = ['worked', 'helped', 'assisted', 'was responsible', 'did', 'made', 'got']
        weak_found = [v for v in weak_verbs if v in resume_text.lower()]
        
        if weak_found:
            warnings.append({
                "type": "warning",
                "issue": f"Weak action verbs detected: {', '.join(weak_found)}",
                "detail": "Weak verbs reduce resume impact",
                "fix": "Replace with: Developed, Built, Led, Optimized, Achieved, Created"
            })
            score -= 5
        else:
            passed.append("✅ No weak verbs detected")
        
        # Check 7: Quantification
        has_numbers = bool(re.search(r'\d+%|\d+ (users|clients|team|projects|systems)', resume_text.lower()))
        if not has_numbers:
            warnings.append({
                "type": "warning",
                "issue": "Missing quantifiable achievements",
                "detail": "Numbers make achievements more credible",
                "fix": "Add metrics: 'Improved performance by 30%', 'Led team of 5'"
            })
            score -= 10
        else:
            passed.append("✅ Quantifiable achievements found")
        
        # Calculate grade
        if score >= 90:
            grade = "A"
            grade_label = "Excellent"
        elif score >= 80:
            grade = "B"
            grade_label = "Good"
        elif score >= 70:
            grade = "C"
            grade_label = "Fair"
        elif score >= 60:
            grade = "D"
            grade_label = "Needs Work"
        else:
            grade = "F"
            grade_label = "Poor"
        
        return {
            'format_score': max(0, score),
            'grade': grade,
            'grade_label': grade_label,
            'total_issues': len(issues),
            'total_warnings': len(warnings),
            'total_passed': len(passed),
            'critical_issues': issues,
            'warnings': warnings,
            'passed_checks': passed,
            'summary': f"Your resume scored {max(0, score)}/100 for ATS compatibility ",
            'top_priority': issues[0]['fix'] if issues else (warnings[0]['fix'] if warnings else "Resume looks good!"),
            'recommendations': {
                'immediate': [i['fix'] for i in issues],
                'suggested': [w['fix'] for w in warnings[:3]]
            }
        }
