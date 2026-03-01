/*
  # Risk Disclosure Statement
  
  Comprehensive risk disclosure for cryptocurrency trading activities.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Risk Disclosure Statement',
  '# Risk Disclosure Statement

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## IMPORTANT WARNING

**CRYPTOCURRENCY TRADING INVOLVES SUBSTANTIAL RISK OF LOSS AND IS NOT SUITABLE FOR ALL INVESTORS. YOU SHOULD CAREFULLY CONSIDER WHETHER TRADING IS APPROPRIATE FOR YOU IN LIGHT OF YOUR FINANCIAL CONDITION. THE HIGH DEGREE OF LEVERAGE THAT IS OBTAINABLE IN CRYPTOCURRENCY TRADING CAN WORK AGAINST YOU AS WELL AS FOR YOU. YOU COULD SUSTAIN A TOTAL LOSS OF YOUR INITIAL INVESTMENT AND MAY BE REQUIRED TO DEPOSIT ADDITIONAL FUNDS TO MAINTAIN YOUR POSITIONS.**

---

## 1. General Market Risks

### 1.1 Volatility Risk
Cryptocurrency markets are highly volatile. Prices can fluctuate significantly within short periods, sometimes by 10-50% or more in a single day. This volatility can result in:

- Rapid and substantial losses
- Inability to exit positions at desired prices
- Stop-loss orders executing at significantly different prices than expected
- Total loss of invested capital

### 1.2 Liquidity Risk
Cryptocurrency markets may experience periods of low liquidity, which can:

- Make it difficult to execute trades at desired prices
- Cause significant slippage on large orders
- Result in inability to close positions during market stress
- Lead to wider bid-ask spreads

### 1.3 Market Manipulation Risk
Cryptocurrency markets may be subject to manipulation including:

- Pump and dump schemes
- Wash trading
- Spoofing and layering
- Whale manipulation
- Coordinated trading activities

---

## 2. Leverage and Margin Trading Risks

### 2.1 Amplified Losses
Leverage magnifies both gains and losses. A small adverse price movement can result in:

- Losses exceeding your initial margin deposit
- Complete liquidation of your position
- Substantial financial losses in a short time period

### 2.2 Liquidation Risk
If your account equity falls below maintenance margin requirements:

- Your positions may be automatically liquidated
- Liquidation may occur at unfavorable prices
- You may lose your entire margin deposit
- In extreme cases, you may owe additional funds

### 2.3 Margin Call Risk
You may be required to deposit additional funds on short notice to maintain positions. Failure to meet margin calls may result in position liquidation.

### 2.4 Funding Rate Risk
Perpetual futures contracts are subject to funding rates which:

- Can be positive or negative
- Are charged/paid every 8 hours
- Can significantly impact profitability of long-term positions
- May become extreme during volatile market conditions

---

## 3. Futures and Derivatives Specific Risks

### 3.1 Contract Specifications
Futures contracts have specific terms that may affect your position including:

- Contract size and tick value
- Maximum leverage limits
- Position size limits
- Settlement procedures

### 3.2 Auto-Deleveraging (ADL) Risk
During extreme market conditions, profitable positions may be automatically closed through ADL to offset losses from liquidated positions.

### 3.3 Insurance Fund Depletion
If the insurance fund is depleted during extreme market movements, socialized losses may be applied to profitable traders.

### 3.4 Overnight and Weekend Risk
Positions held overnight or over weekends are exposed to:

- Gap risk from news events
- Increased volatility at market opens
- Accumulated funding fees

---

## 4. Copy Trading Risks

### 4.1 Past Performance Disclaimer
**PAST PERFORMANCE IS NOT INDICATIVE OF FUTURE RESULTS.** A trader''s historical performance does not guarantee future profitability.

### 4.2 Copying Risk
When copy trading:

- You may suffer losses even if the lead trader is profitable
- Execution timing differences may affect your results
- Position sizing may not be optimal for your account
- You remain responsible for all trading decisions

### 4.3 Lead Trader Risk
Lead traders may:

- Change their trading strategy without notice
- Take excessive risks
- Experience significant drawdowns
- Close their accounts or stop trading

---

## 5. Staking and Earn Product Risks

### 5.1 APY Disclaimer
Advertised APY rates:

- Are variable and not guaranteed
- May change based on market conditions
- Represent historical or projected returns, not guaranteed outcomes

### 5.2 Lock-Up Risk
Staked assets:

- May be locked for specified periods
- Early withdrawal may incur penalties
- May not be accessible during market volatility

### 5.3 Protocol Risk
Staking involves exposure to:

- Smart contract vulnerabilities
- Protocol failures or exploits
- Slashing events for proof-of-stake assets
- Validator downtime or penalties

---

## 6. Technology and Operational Risks

### 6.1 System Failures
You may experience losses due to:

- Platform downtime or outages
- Order execution delays
- Software bugs or errors
- Network congestion

### 6.2 Cybersecurity Risk
Despite security measures, risks include:

- Unauthorized access to accounts
- Phishing attacks
- Malware and keyloggers
- Exchange security breaches

### 6.3 Internet Connectivity
Trading requires reliable internet. Connectivity issues may:

- Prevent order placement or modification
- Delay execution of time-sensitive trades
- Result in inability to manage positions

---

## 7. Regulatory and Legal Risks

### 7.1 Regulatory Changes
Cryptocurrency regulations may change, potentially:

- Restricting or prohibiting trading activities
- Requiring asset seizure or freezing
- Affecting the value of digital assets
- Limiting access to certain services

### 7.2 Tax Implications
Cryptocurrency trading may have significant tax consequences:

- Capital gains taxes on profits
- Income taxes on staking rewards
- Reporting requirements
- Penalties for non-compliance

**You are solely responsible for understanding and complying with tax obligations.**

### 7.3 Legal Uncertainty
The legal status of cryptocurrencies varies by jurisdiction and may:

- Affect enforceability of contracts
- Limit legal remedies available
- Create compliance challenges

---

## 8. Counterparty and Custody Risks

### 8.1 Exchange Risk
Funds held on the exchange are subject to:

- Exchange insolvency risk
- Operational failures
- Regulatory actions against the exchange

### 8.2 Custody Risk
Your digital assets may be:

- Held in omnibus wallets
- Subject to potential loss from hacks
- Affected by custodian bankruptcy

---

## 9. Asset-Specific Risks

### 9.1 Project Failure
Individual cryptocurrencies may:

- Fail completely, becoming worthless
- Be abandoned by developers
- Suffer from security vulnerabilities
- Face regulatory bans

### 9.2 Fork Risk
Blockchain forks may:

- Create confusion about which chain to support
- Result in loss of funds on deprecated chains
- Affect the value of holdings

### 9.3 Delisting Risk
Trading pairs may be:

- Delisted with limited notice
- Subject to reduced liquidity before delisting
- Unavailable for trading without warning

---

## 10. No Investment Advice

**THE EXCHANGE DOES NOT PROVIDE INVESTMENT, FINANCIAL, TAX, OR LEGAL ADVICE.**

- All trading decisions are your own
- Educational content is for informational purposes only
- You should consult qualified professionals before trading
- No communication constitutes a recommendation to trade

---

## 11. Capital at Risk Warning

**ONLY TRADE WITH MONEY YOU CAN AFFORD TO LOSE.**

- Never invest borrowed money
- Never invest emergency funds
- Never invest more than you can afford to lose completely
- Consider your overall financial situation before trading

---

## 12. Acknowledgment

By using our Services, you acknowledge that:

- You have read and understood these risk disclosures
- You accept all risks associated with cryptocurrency trading
- You are solely responsible for your trading decisions
- Losses may exceed your initial investment
- Past performance does not guarantee future results
- You may lose your entire investment

---

**IF YOU DO NOT UNDERSTAND THESE RISKS OR CANNOT AFFORD TO LOSE YOUR INVESTMENT, DO NOT USE OUR SERVICES.**',
  'risk_disclosure',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();