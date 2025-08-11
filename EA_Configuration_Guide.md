# MACD Hedging EA - Parameter Configuration Guide

## Recommended Parameter Sets

### Conservative Setup (Low Risk)
```
Trading Strategy Settings:
- Trading Timeframe: H1 or H4
- Initial Lot Size: 0.01
- Maximum Hedged Trades: 10
- Pip Offset for Hedging: 30
- Lot Size Multiplier: 1.5
- Net Profit Target: 5.0

Risk Management:
- Daily Loss Limit: 50.0
- Maximum Spread: 2.0
- Trading Start Hour: 8
- Trading End Hour: 18

MACD Settings:
- MACD Fast EMA Period: 12
- MACD Slow EMA Period: 26
- MACD Signal SMA Period: 9
```

### Moderate Setup (Balanced Risk/Reward)
```
Trading Strategy Settings:
- Trading Timeframe: M30 or H1
- Initial Lot Size: 0.01
- Maximum Hedged Trades: 15
- Pip Offset for Hedging: 25
- Lot Size Multiplier: 2.0
- Net Profit Target: 3.0

Risk Management:
- Daily Loss Limit: 100.0
- Maximum Spread: 3.0
- Trading Start Hour: 6
- Trading End Hour: 20

MACD Settings:
- MACD Fast EMA Period: 12
- MACD Slow EMA Period: 26
- MACD Signal SMA Period: 9
```

### Aggressive Setup (Higher Risk/Reward)
```
Trading Strategy Settings:
- Trading Timeframe: M15 or M30
- Initial Lot Size: 0.02
- Maximum Hedged Trades: 20
- Pip Offset for Hedging: 20
- Lot Size Multiplier: 2.5
- Net Profit Target: 2.0

Risk Management:
- Daily Loss Limit: 200.0
- Maximum Spread: 4.0
- Trading Start Hour: 0
- Trading End Hour: 23

MACD Settings:
- MACD Fast EMA Period: 8
- MACD Slow EMA Period: 21
- MACD Signal SMA Period: 5
```

### Scalping Setup (High Frequency)
```
Trading Strategy Settings:
- Trading Timeframe: M5 or M15
- Initial Lot Size: 0.01
- Maximum Hedged Trades: 8
- Pip Offset for Hedging: 15
- Lot Size Multiplier: 1.8
- Net Profit Target: 1.0

Risk Management:
- Daily Loss Limit: 30.0
- Maximum Spread: 1.5
- Trading Start Hour: 8
- Trading End Hour: 17

MACD Settings:
- MACD Fast EMA Period: 5
- MACD Slow EMA Period: 13
- MACD Signal SMA Period: 3
```

## Currency Pair Specific Recommendations

### Major Pairs (EURUSD, GBPUSD, USDJPY)
- Standard MACD settings work well
- Pip Offset: 20-30 pips
- Maximum Spread: 2-3 pips
- Higher timeframes (H1, H4) recommended

### Minor Pairs (EURGBP, EURJPY, GBPJPY)
- Slightly wider pip offset: 25-40 pips
- Maximum Spread: 3-5 pips
- Consider lower lot multiplier (1.5-2.0)

### Exotic Pairs (USDTRY, USDZAR, etc.)
- Much wider pip offset: 50-100 pips
- Maximum Spread: 10-20 pips
- Lower lot multiplier: 1.3-1.8
- Higher timeframes only (H4, D1)

## Market Condition Adjustments

### Trending Markets
- Wider pip offset (30-50 pips)
- Higher lot multiplier (2.0-2.5)
- Longer timeframes (H1-H4)

### Ranging Markets
- Tighter pip offset (15-25 pips)
- Lower lot multiplier (1.5-2.0)
- Shorter timeframes (M15-M30)

### High Volatility Periods
- Increase maximum spread limit
- Wider pip offset
- Reduce maximum hedged trades
- Consider trading time restrictions

### Low Volatility Periods
- Tighter pip offset
- Lower profit targets
- Consider shorter timeframes
- May increase position size slightly

## Account Size Recommendations

### Small Account ($500-$1000)
- Initial Lot: 0.01
- Maximum Hedged Trades: 5-8
- Daily Loss Limit: $20-50
- Conservative parameters only

### Medium Account ($1000-$5000)
- Initial Lot: 0.01-0.02
- Maximum Hedged Trades: 8-15
- Daily Loss Limit: $50-150
- Moderate to aggressive parameters

### Large Account ($5000+)
- Initial Lot: 0.02-0.05
- Maximum Hedged Trades: 15-20
- Daily Loss Limit: $150-500
- All parameter sets suitable

## Backtesting Guidelines

### Essential Tests
1. **Timeframe Analysis:** Test on M1, M5, M15, M30, H1, H4
2. **Parameter Sensitivity:** Vary MACD periods ±20%
3. **Market Conditions:** Test trending vs ranging periods
4. **Spread Impact:** Simulate different spread conditions
5. **Drawdown Analysis:** Monitor maximum consecutive losses

### Key Metrics to Monitor
- **Maximum Drawdown:** Should not exceed 20% of account
- **Profit Factor:** Target > 1.3 for sustainable trading
- **Win Rate:** Aim for > 60% with hedging system
- **Average Trade Duration:** Monitor holding periods
- **Recovery Factor:** Ratio of profit to maximum drawdown

### Optimization Process
1. Start with conservative parameters
2. Gradually increase aggressiveness if profitable
3. Always maintain risk management limits
4. Test across multiple market conditions
5. Forward test before live implementation

## Live Trading Checklist

### Before Going Live
- [ ] Thorough backtesting completed
- [ ] Demo trading for at least 1 month
- [ ] Broker allows hedging strategies
- [ ] Sufficient account balance (10x max exposure)
- [ ] Email/SMS alerts configured
- [ ] Regular monitoring schedule established

### Daily Monitoring Tasks
- [ ] Check dashboard for system status
- [ ] Review overnight positions
- [ ] Monitor daily P&L vs limits
- [ ] Verify spread conditions
- [ ] Check for any error messages

### Weekly Review Items
- [ ] Analyze weekly performance
- [ ] Review parameter effectiveness
- [ ] Check for market condition changes
- [ ] Update risk management limits if needed
- [ ] Review and adjust profit targets

## Risk Management Best Practices

### Position Sizing Rules
- Never risk more than 2% per trade sequence
- Maintain 10:1 ratio of account to maximum exposure
- Use fixed fractional position sizing
- Consider correlation between currency pairs

### Stop Loss Alternatives
- Use daily loss limits instead of individual stop losses
- Implement maximum drawdown limits
- Time-based exits for prolonged positions
- Manual intervention protocols

### Portfolio Management
- Limit number of currency pairs traded simultaneously
- Avoid highly correlated pairs
- Diversify across different timeframes
- Consider fundamental analysis for major decisions

---

**Note:** These are suggested starting points. Always adapt parameters based on your risk tolerance, account size, and market conditions. Regular monitoring and adjustment are essential for long-term success.