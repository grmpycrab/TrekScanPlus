# Email Service Setup Guide

This guide explains how to configure email sending for verification codes in TrekScanPlus.

## Current Status

✅ **Implemented:**
- Email verification code generation (6 digits)
- Firestore storage of verification codes
- Cloud Function trigger on `/mail` collection
- Code expiration (15 minutes)
- Attempt limiting (5 attempts max)

⏳ **Pending:**
- Actual email delivery (requires email service provider)

## Quick Start (Development)

For development/testing, the Cloud Function currently **logs** the verification codes to the console instead of sending emails.

### To test the verification flow:

1. **Deploy the Cloud Function:**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions:sendVerificationEmail
   ```

2. **Monitor Firebase Console:**
   - Go to Firebase Console → Functions → Logs
   - When a user signs up, check the logs for the 6-digit code
   - Manually enter the code in the app for testing

3. **Check Firestore:**
   - Collection: `mail`
   - Look for documents with the verification code
   - Status will be `pending_email_service`

## Production Setup

For production, you need to integrate an email service provider. Here are the recommended options:

### Option 1: SendGrid (Recommended)

**Pros:** Easy setup, generous free tier (100 emails/day), reliable

1. **Create SendGrid Account:**
   - Go to https://sendgrid.com
   - Sign up for free account
   - Verify your email

2. **Get API Key:**
   - Dashboard → Settings → API Keys
   - Create API Key with "Mail Send" permissions
   - Copy the key (you won't see it again!)

3. **Install SendGrid SDK:**
   ```bash
   cd functions
   npm install @sendgrid/mail
   ```

4. **Configure Firebase Functions:**
   ```bash
   firebase functions:config:set sendgrid.key="YOUR_API_KEY_HERE"
   ```

5. **Verify Sender Email:**
   - Settings → Sender Authentication
   - Verify your "From" email address (e.g., noreply@trekscanplus.app)

6. **Update Cloud Function:**
   Uncomment the SendGrid code in `functions/index.js` (lines marked with `// TODO`)

7. **Deploy:**
   ```bash
   firebase deploy --only functions:sendVerificationEmail
   ```

### Option 2: AWS SES

**Pros:** Very cheap, highly scalable, good for high volume

1. **Setup AWS Account & SES:**
   - Create AWS account
   - Go to Amazon SES console
   - Verify domain or email address

2. **Install AWS SDK:**
   ```bash
   cd functions
   npm install @aws-sdk/client-ses
   ```

3. **Configure AWS Credentials:**
   ```bash
   firebase functions:config:set aws.access_key="YOUR_ACCESS_KEY"
   firebase functions:config:set aws.secret_key="YOUR_SECRET_KEY"
   firebase functions:config:set aws.region="us-east-1"
   ```

4. **Add to Cloud Function:**
   ```javascript
   const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");
   
   const sesClient = new SESClient({
     region: functions.config().aws.region,
     credentials: {
       accessKeyId: functions.config().aws.access_key,
       secretAccessKey: functions.config().aws.secret_key,
     },
   });
   
   const params = {
     Source: "noreply@trekscanplus.app",
     Destination: { ToAddresses: [mailData.to] },
     Message: {
       Subject: { Data: mailData.subject },
       Body: {
         Html: { Data: `Your code: <strong>${mailData.code}</strong>` },
       },
     },
   };
   
   await sesClient.send(new SendEmailCommand(params));
   ```

### Option 3: Mailgun

**Pros:** Developer-friendly, good documentation

1. **Create Mailgun Account:**
   - Go to https://mailgun.com
   - Sign up (free tier: 5,000 emails/month for 3 months)

2. **Install Mailgun SDK:**
   ```bash
   cd functions
   npm install mailgun.js form-data
   ```

3. **Configure:**
   ```bash
   firebase functions:config:set mailgun.key="YOUR_API_KEY"
   firebase functions:config:set mailgun.domain="YOUR_DOMAIN"
   ```

4. **Add to Cloud Function:**
   ```javascript
   const formData = require('form-data');
   const Mailgun = require('mailgun.js');
   const mailgun = new Mailgun(formData);
   
   const mg = mailgun.client({
     username: 'api',
     key: functions.config().mailgun.key,
   });
   
   await mg.messages.create(functions.config().mailgun.domain, {
     from: "TrekScan Plus <noreply@trekscanplus.app>",
     to: [mailData.to],
     subject: mailData.subject,
     html: `Your verification code: <strong>${mailData.code}</strong>`,
   });
   ```

## Email Template

Here's a professional HTML email template you can use:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #f4f4f4; font-family: Arial, sans-serif;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden;">
                    <!-- Header -->
                    <tr>
                        <td style="background-color: #252B30; padding: 30px; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 24px;">TrekScan Plus</h1>
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px 30px;">
                            <h2 style="color: #252B30; margin: 0 0 20px; font-size: 20px;">Email Verification</h2>
                            <p style="color: #666; margin: 0 0 20px; font-size: 16px; line-height: 1.5;">
                                Thank you for signing up! Please use the verification code below to complete your registration:
                            </p>
                            
                            <!-- Verification Code Box -->
                            <div style="background-color: #f8f9fa; border: 2px solid #252B30; border-radius: 8px; padding: 30px; text-align: center; margin: 30px 0;">
                                <p style="color: #666; margin: 0 0 10px; font-size: 14px; text-transform: uppercase; letter-spacing: 1px;">Verification Code</p>
                                <p style="color: #252B30; margin: 0; font-size: 36px; font-weight: bold; letter-spacing: 8px; font-family: 'Courier New', monospace;">
                                    {{CODE}}
                                </p>
                            </div>
                            
                            <p style="color: #666; margin: 20px 0; font-size: 14px; line-height: 1.5;">
                                ⏱️ <strong>This code will expire in 15 minutes.</strong>
                            </p>
                            
                            <p style="color: #666; margin: 20px 0; font-size: 14px; line-height: 1.5;">
                                If you didn't request this code, please ignore this email.
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #e0e0e0;">
                            <p style="color: #999; margin: 0; font-size: 12px;">
                                © 2025 TrekScan Plus - Hamiguitan Mountain Range
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
```

## Security Best Practices

1. **Rate Limiting:**
   - Limit verification emails per IP/user
   - Add cooldown between resend attempts (already implemented: 60s)

2. **Email Validation:**
   - Validate email format before sending
   - Check for disposable email domains

3. **Monitoring:**
   - Set up alerts for high email volume
   - Monitor bounce rates and spam reports

4. **Domain Authentication:**
   - Set up SPF, DKIM, and DMARC records
   - Use a verified domain (not @gmail.com)

## Testing Checklist

- [ ] Deploy Cloud Function
- [ ] Test signup flow
- [ ] Check Firebase logs for email trigger
- [ ] Verify code appears in Firestore
- [ ] Test code expiration (15 minutes)
- [ ] Test attempt limiting (5 max)
- [ ] Test resend cooldown (60 seconds)
- [ ] Verify email delivery (production)
- [ ] Test invalid code handling
- [ ] Test expired code handling

## Troubleshooting

**Emails not sending:**
- Check Cloud Function logs in Firebase Console
- Verify API keys are correctly configured
- Check email service provider dashboard for errors
- Ensure sender email is verified

**Code not being generated:**
- Check `email_verifications` collection in Firestore
- Verify EmailVerificationService is being called
- Check Flutter app logs

**Users not receiving emails:**
- Check spam folder
- Verify email address is correct
- Check email service provider's delivery logs
- Ensure domain/sender is verified

## Cost Estimates

**SendGrid Free Tier:**
- 100 emails/day = ~3,000/month
- Good for: Small apps, testing

**AWS SES:**
- $0.10 per 1,000 emails
- 62,000 emails/month = ~$6/month
- Good for: Growing apps

**Mailgun:**
- First 3 months: 5,000 emails/month free
- After: $35/month for 50,000 emails
- Good for: Established apps

## Next Steps

1. Choose an email service provider (SendGrid recommended for getting started)
2. Set up account and get API credentials
3. Update Cloud Function with email sending code
4. Deploy and test
5. Monitor delivery rates and adjust as needed

For questions or issues, check the Firebase Functions logs or the email service provider's documentation.
