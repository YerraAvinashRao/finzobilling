# Security Policy

## Reporting a Vulnerability

We take the security of FinzoBilling seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Email:** yerraavinashrao@gmail.com (or create a dedicated security email)

**Please include:**
- Description of the vulnerability
- Steps to reproduce the issue
- Affected versions (Android/Web)
- Potential impact on user data or GST compliance
- Any screenshots or logs (remove sensitive data first)

### What NOT to Include
- Do NOT post vulnerabilities publicly in issues
- Do NOT include actual Firebase credentials or API keys
- Do NOT share real customer/business data

## Response Timeline

- **Initial Response:** Within 48 hours of report
- **Issue Confirmation:** Within 5 business days
- **Fix Timeline:** Depends on severity
  - Critical (data breach risk): 24-72 hours
  - High (GST compliance impact): 1 week
  - Medium: 2-4 weeks
  - Low: Next release cycle

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Web (Latest) | ✅ Yes        |
| Android (Latest) | ✅ Yes    |
| Older versions | ❌ No      |

We only support the latest production version. Please update to the newest release.

## Security Best Practices for Users

1. **Keep your credentials secure** - Never share your login
2. **Use strong passwords** - Minimum 8 characters with mixed case
3. **Review Firebase Rules** - Ensure proper access controls
4. **Regular backups** - Export your data periodically
5. **Update regularly** - Always use the latest version

## Scope

This policy covers:
- FinzoBilling Android App
- FinzoBilling Web App (https://yerraavinashrao.github.io/finzobilling/)
- Firebase backend services
- GST data handling and compliance features

## Out of Scope

- Third-party services (Firebase, GitHub Pages)
- User's local device security
- GST Portal (government website)

## Disclosure Policy

1. Reporter submits vulnerability privately
2. We validate and develop a fix
3. We notify the reporter when fix is ready
4. We deploy the fix to production
5. We publicly disclose the issue after users have had time to update (30 days minimum)

## Recognition

Security researchers who responsibly report valid vulnerabilities will be acknowledged in our release notes (with permission).

Thank you for helping keep FinzoBilling and our users' financial data secure!
