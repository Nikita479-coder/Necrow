# Promotional Events & Terms System

## Overview

A comprehensive system for managing promotional trading events and their terms & conditions. All email template links are now fully functional and dynamically load content from the database.

## Database Tables

### `promotional_events`
Stores information about trading challenges and competitions:
- Event details (title, description, dates)
- Requirements and rules
- Prize structures
- Participation instructions
- Disqualification conditions

### `terms_pages`
Stores legal terms and conditions:
- Full terms content (supports markdown-style formatting)
- Version tracking
- Effective dates
- Related event associations

## Available Events

### 1. The Gauntlet Challenge
- **Slug**: `gauntlet`
- **Prize**: 5,000 USDT
- **Type**: 5-day discipline test
- **Requirement**: 15% profit with zero losing days
- **Terms**: `gauntlet-challenge`

### 2. Win-Streak Bonus Challenge
- **Slug**: `win-streak`
- **Prize**: 50 USDT
- **Type**: 24-hour skill test
- **Requirement**: 5 profitable futures trades
- **Terms**: `win-streak-challenge`

### 3. Futures Frenzy 24-Hour Blitz
- **Slug**: `frenzy`
- **Prize Pool**: 26,300 USDT
- **Type**: Volume competition + lottery
- **Features**: Leaderboard (16,300 USDT) + Lottery (10,000 USDT)
- **Terms**: `frenzy`

## Frontend Pages

### Event Details Page
**Route**: `navigateTo('event', { slug: 'event-slug' })`

Displays:
- Event title, subtitle, and description
- Prize pool and timeline
- Requirements (formatted from JSON)
- Prizes breakdown
- Rules and participation steps
- Disqualification conditions
- Call-to-action buttons

### Terms Page
**Route**: `navigateTo('terms', { slug: 'terms-slug' })`

Displays:
- Full terms and conditions
- Version and effective date
- Formatted content with headings, lists, and paragraphs
- Category badge

## Email Template Integration

### Variable Substitution
Email templates support these URL variables:
- `{{website_url}}` - Base platform URL
- Can be used to construct full URLs

### Example Links in Email Templates

**Event Pages:**
```
[VIEW FULL GAUNTLET RULES] → {{website_url}}/events/gauntlet
[VIEW FULL CHALLENGE RULES] → {{website_url}}/events/win-streak
[VIEW THE FULL FRENZY RULES] → {{website_url}}/events/frenzy
```

**Terms Pages:**
```
Full Terms: {{website_url}}/terms/gauntlet-challenge
Full Terms: {{website_url}}/terms/win-streak-challenge
Full Terms: {{website_url}}/terms/frenzy
```

**Support:**
```
[CONTACT SUPPORT TO ENTER] → {{website_url}}/support
```

## How Links Work

When a user clicks an email link like `{{website_url}}/events/gauntlet`:

1. The link resolves to your actual domain (e.g., `https://yourplatform.com/events/gauntlet`)
2. Your web server should route `/events/*` to navigate to the `event` page with the slug
3. The EventDetails component loads the event data from `promotional_events` table
4. Content is dynamically rendered based on the database data

**Note**: This system uses client-side routing. You'll need to configure your web server to route all paths to `index.html` for the React app to handle routing.

## Adding New Events

### Step 1: Insert Event Data

```sql
INSERT INTO promotional_events (
  slug, title, subtitle, description, event_type,
  prize_pool, is_recurring, metadata,
  requirements, rules, prizes, disqualifications, how_to_participate
) VALUES (
  'your-event-slug',
  'Your Event Title',
  'Subtitle',
  'Description of the event',
  'challenge',  -- or 'competition', 'skill_test', 'lottery', 'leaderboard'
  1000.00,
  true,
  '{"key": "value"}'::jsonb,
  '{"min_capital": 100, "duration": "24 hours"}'::jsonb,
  '["Rule 1", "Rule 2"]'::jsonb,
  '[{"prize": 1000, "currency": "USDT"}]'::jsonb,
  '["Disqualification 1"]'::jsonb,
  '["Step 1", "Step 2"]'::jsonb
);
```

### Step 2: Insert Terms

```sql
INSERT INTO terms_pages (slug, title, content, category, related_event_id) VALUES (
  'your-event-terms',
  'Your Event - Terms and Conditions',
  E'# Title\n\n## Section\n\nContent with markdown-style formatting.',
  'challenge',
  (SELECT id FROM promotional_events WHERE slug = 'your-event-slug')
);
```

### Step 3: Update Email Template

Add links in your email template:
```
[VIEW EVENT DETAILS] → {{website_url}}/events/your-event-slug
Full Terms: {{website_url}}/terms/your-event-terms
```

## Content Formatting

### Terms Content Supports:
- `# Heading 1` - Large headers
- `## Heading 2` - Section headers
- `### Heading 3` - Subsection headers
- `- List item` - Bullet points
- Regular paragraphs

The TermsPage component automatically formats this into styled HTML.

## Security

### RLS Policies
- **Public Read**: Anyone can view active events and terms
- **Admin Write**: Only admins can create/modify events and terms
- Uses JWT metadata for admin detection

### Data Validation
- Event types are constrained to valid values
- Terms categories are constrained
- All foreign keys properly enforced

## API Usage

### Fetching Events
```typescript
const { data, error } = await supabase
  .from('promotional_events')
  .select('*')
  .eq('slug', 'gauntlet')
  .eq('is_active', true)
  .maybeSingle();
```

### Fetching Terms
```typescript
const { data, error } = await supabase
  .from('terms_pages')
  .select('*')
  .eq('slug', 'gauntlet-challenge')
  .eq('is_active', true)
  .maybeSingle();
```

## Testing Links

All email template links are now functional:

1. **The Gauntlet Challenge**
   - Event: `/events/gauntlet` ✓
   - Terms: `/terms/gauntlet-challenge` ✓

2. **Win-Streak Challenge**
   - Event: `/events/win-streak` ✓
   - Terms: `/terms/win-streak-challenge` ✓

3. **Futures Frenzy**
   - Event: `/events/frenzy` ✓
   - Terms: `/terms/frenzy` ✓

## Migration Files

- `create_events_and_terms_system.sql` - Creates tables and RLS
- Database inserts performed via SQL queries for event and terms data

## Components

- `src/pages/EventDetails.tsx` - Event display page
- `src/pages/TermsPage.tsx` - Terms display page
- `src/App.tsx` - Updated with new routes

## Benefits

1. **Dynamic Content**: Change event details without code deployment
2. **Versioned Terms**: Track changes to legal terms over time
3. **Consistent Design**: All events use the same professional template
4. **SEO Ready**: Each event has its own URL
5. **Admin Control**: Manage events through database or future admin panel
6. **Email Integration**: All email links automatically resolve to correct pages

## Future Enhancements

Consider adding:
- Admin UI for creating/editing events
- Event scheduling system
- User registration tracking
- Automated event status updates (upcoming, active, ended)
- Event analytics and participant tracking
- Email notification triggers based on event lifecycle
