/*
  # Cookie Policy Document
  
  Comprehensive cookie and tracking technology policy.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Cookie Policy',
  '# Cookie Policy

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Introduction

This Cookie Policy explains how Shark Trades ("we", "us", "our") uses cookies and similar tracking technologies when you visit our platform. This policy should be read alongside our Privacy Policy.

---

## 2. What Are Cookies?

Cookies are small text files stored on your device (computer, tablet, or mobile) when you visit websites. They help websites remember your preferences and improve your browsing experience.

---

## 3. Types of Cookies We Use

### 3.1 Essential Cookies (Strictly Necessary)

These cookies are required for the platform to function and cannot be disabled.

| Cookie Name | Purpose | Duration |
|------------|---------|----------|
| session_id | Maintains your login session | Session |
| auth_token | Authenticates your account | 24 hours |
| csrf_token | Prevents cross-site request forgery | Session |
| security_check | Fraud prevention and security | 30 days |

### 3.2 Functional Cookies

These cookies remember your preferences and settings.

| Cookie Name | Purpose | Duration |
|------------|---------|----------|
| language | Stores language preference | 1 year |
| timezone | Stores timezone setting | 1 year |
| theme | Stores dark/light mode preference | 1 year |
| trading_layout | Remembers trading interface layout | 1 year |
| chart_settings | Saves chart preferences | 1 year |

### 3.3 Performance/Analytics Cookies

These cookies help us understand how visitors use our platform.

| Cookie Name | Purpose | Duration |
|------------|---------|----------|
| _ga | Google Analytics - distinguishes users | 2 years |
| _gid | Google Analytics - distinguishes users | 24 hours |
| _gat | Google Analytics - throttles requests | 1 minute |
| analytics_session | Tracks page views and interactions | Session |

### 3.4 Marketing Cookies

These cookies track your activity to deliver relevant advertisements.

| Cookie Name | Purpose | Duration |
|------------|---------|----------|
| _fbp | Facebook Pixel tracking | 90 days |
| ads_consent | Stores advertising consent | 1 year |
| referral_source | Tracks referral attribution | 30 days |

---

## 4. Third-Party Cookies

We may use services that set their own cookies:

- **Google Analytics:** Website analytics and usage statistics
- **Cloudflare:** Security and performance optimization
- **Intercom/Zendesk:** Customer support chat functionality
- **Facebook Pixel:** Marketing attribution (with consent)

These third parties have their own privacy policies governing cookie use.

---

## 5. Similar Technologies

We also use:

### 5.1 Local Storage
Stores data in your browser for:
- User preferences
- Trading interface settings
- Cached market data

### 5.2 Session Storage
Temporary storage for:
- Current session data
- Form inputs
- Navigation state

### 5.3 Web Beacons
Small graphics used for:
- Email open tracking
- Page view tracking
- Conversion tracking

---

## 6. How to Manage Cookies

### 6.1 Browser Settings

You can control cookies through your browser settings:

**Chrome:** Settings > Privacy and Security > Cookies
**Firefox:** Options > Privacy & Security > Cookies
**Safari:** Preferences > Privacy > Cookies
**Edge:** Settings > Privacy & Security > Cookies

### 6.2 Opt-Out Links

- **Google Analytics:** https://tools.google.com/dlpage/gaoptout
- **Facebook:** https://www.facebook.com/settings?tab=ads

### 6.3 Platform Settings

You can manage cookie preferences in your account settings under Privacy Preferences.

---

## 7. Impact of Disabling Cookies

If you disable certain cookies:

**Essential Cookies:** You will not be able to use the platform
**Functional Cookies:** Your preferences may not be saved
**Analytics Cookies:** We cannot improve our services based on usage
**Marketing Cookies:** You may see less relevant advertisements

---

## 8. Cookie Consent

When you first visit our platform, you will see a cookie consent banner. You can:

- **Accept All:** Enable all cookie categories
- **Reject Non-Essential:** Only essential cookies enabled
- **Customize:** Choose which categories to enable

You can change your preferences at any time in account settings.

---

## 9. Do Not Track

Some browsers have a "Do Not Track" (DNT) feature. We currently do not respond to DNT signals, but you can manage tracking through cookie settings.

---

## 10. Updates to This Policy

We may update this Cookie Policy periodically. The "Last Updated" date at the top indicates the most recent revision.

---

## 11. Contact Us

For questions about our use of cookies, contact us through the support portal.

---

**BY CONTINUING TO USE OUR PLATFORM, YOU CONSENT TO OUR USE OF COOKIES AS DESCRIBED IN THIS POLICY.**',
  'cookie_policy',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();