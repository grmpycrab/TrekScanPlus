# Environment Configuration Setup

This guide explains how to set up environment variables for the TrekScan Plus app, particularly for the email certificate delivery feature.

## Quick Setup

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` and add your credentials:**
   ```bash
   SMTP_EMAIL=your-email@gmail.com
   SMTP_PASSWORD=your-app-password
   ```

3. **Never commit `.env` to version control** - it's already in `.gitignore`

---

## Gmail App Password Setup (Recommended)

To send emails via Gmail, you need to generate an **App Password**:

### Step 1: Enable 2-Factor Authentication
1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable **2-Step Verification** if not already enabled

### Step 2: Generate App Password
1. Visit [App Passwords](https://myaccount.google.com/apppasswords)
2. Select **Mail** as the app
3. Select your device (e.g., Windows, Mac, Other)
4. Click **Generate**
5. Copy the 16-character password (format: `xxxx xxxx xxxx xxxx`)

### Step 3: Add to .env
```env
SMTP_EMAIL=your-email@gmail.com
SMTP_PASSWORD=abcdabcdabcdabcd  # Paste without spaces
```

---

## Alternative Email Services (Production)

For production apps, consider using professional email services:

### SendGrid
```env
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
```

### AWS SES (Simple Email Service)
```env
AWS_SES_ACCESS_KEY=AKIAXXXXXXXXXXXXX
AWS_SES_SECRET_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_SES_REGION=us-east-1
```

### Mailgun
```env
MAILGUN_API_KEY=key-xxxxxxxxxxxxx
MAILGUN_DOMAIN=mg.yourdomain.com
```

---

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SMTP_EMAIL` | Email address for sending certificates | - | ✅ Yes |
| `SMTP_PASSWORD` | App password or API key | - | ✅ Yes |
| `APP_NAME` | Application name in emails | Mt. Hamiguitan TrekScan | ❌ No |
| `APP_EMAIL_FROM` | "From" email address | noreply@hamiguitan-trek.com | ❌ No |

---

## Security Best Practices

### ✅ DO:
- Use App Passwords, not regular passwords
- Keep `.env` in `.gitignore`
- Use different credentials for development/production
- Rotate credentials regularly
- Share `.env.example` (without actual credentials)

### ❌ DON'T:
- Commit `.env` to Git
- Share credentials in Slack/Discord/Email
- Use your personal Gmail password
- Hardcode credentials in source code

---

## Troubleshooting

### "SMTP credentials not configured"
**Problem:** The `.env` file is missing or not loaded.

**Solution:**
1. Ensure `.env` exists in the project root
2. Verify credentials are set correctly
3. Restart the app to reload environment variables

### "Authentication failed"
**Problem:** Invalid credentials or App Password not generated.

**Solution:**
1. Regenerate App Password from Google Account
2. Ensure you're using App Password, not regular password
3. Check for extra spaces in password

### Emails not sending
**Problem:** Gmail security blocking app access.

**Solution:**
1. Enable 2-Factor Authentication
2. Use App Password (not regular password)
3. Check [Less Secure App Access](https://myaccount.google.com/lesssecureapps) is OFF (use App Passwords instead)

---

## Testing Email Configuration

After setup, test the email feature by:
1. Launch the app
2. Earn a certificate (visit required stations)
3. Check console logs for:
   ```
   📧 Attempting to send certificate email...
   ✅ Certificate email sent successfully
   ```
4. Check your email inbox for the certificate

---

## Production Deployment

Before deploying to production:

1. **Use production email service** (SendGrid/AWS SES recommended)
2. **Set up DNS records** (SPF, DKIM, DMARC) for better deliverability
3. **Use custom domain** instead of gmail.com
4. **Monitor email sending** with proper logging
5. **Handle bounces and failures** gracefully

---

## Support

If you encounter issues:
- Check logs in VS Code Debug Console
- Verify `.env` file exists and is loaded
- Ensure Firebase Authentication is configured
- Test with your own email first

For production support, consider professional email services with better deliverability and support.
