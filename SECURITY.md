# Security Policy

## Supported Versions

We currently support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in AmbiGlass, please report it responsibly:

1. **Do NOT** open a public issue
2. Email security details to: [your-email@example.com] (replace with actual contact)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Considerations

### Audio Data
- AmbiGlass processes audio data locally
- No audio data is transmitted over the network
- Recorded files are stored locally on the device

### Permissions
- **macOS**: Requires microphone access permission
- **iPadOS**: Requires microphone access permission
- No network permissions required

### Dependencies
- Core Audio frameworks (Apple-provided)
- Swift standard library
- vDSP (Apple-provided)

### Best Practices
- Keep your macOS/iPadOS system updated
- Only use trusted audio interfaces
- Review mic profile JSON files before loading
- Use calibration profiles from trusted sources

## Disclosure Policy

We will:
1. Acknowledge receipt of the vulnerability report within 48 hours
2. Provide an initial assessment within 7 days
3. Keep you informed of our progress
4. Notify you when the vulnerability is fixed
5. Credit you in the release notes (unless you prefer to remain anonymous)

## Known Issues

None at this time.

