# MACD Hedging Expert Advisor (MQL5)

## Overview

This Expert Advisor implements a sophisticated MACD-based trading strategy with advanced hedging logic and risk management features. It automatically detects entry signals based on MACD crossovers and manages positions through a multi-level hedging system.

## Key Features

### Trading Strategy
- **Entry Conditions:**
  - **Buy Signal:** New candle opens AND MACD main line > 0 AND MACD signal line < MACD main line
  - **Sell Signal:** New candle opens AND MACD main line < 0 AND MACD signal line > MACD main line
- **Automatic symbol detection** from current chart
- **Configurable timeframes** (M1, M5, M15, M30, H1, H4, D1)

### Hedging Logic
- **Smart hedging system** that opens opposite trades when positions move against you
- **Configurable pip offset** for hedging triggers (default: 20 pips)
- **Progressive lot sizing** with adjustable multiplier (default: 2x)
- **Maximum hedged trades limit** (default: 20 levels)
- **Automatic closure** when net profit target is reached

### Risk Management
- **Daily loss limits** with automatic trading suspension
- **Maximum spread filtering** to avoid high-cost trades
- **Trading time windows** with configurable start/end hours
- **Position sizing validation** with broker limits
- **Real-time profit monitoring** with automatic closure at target

### Visual Dashboard
- **Real-time performance metrics** display
- **Active trades counter** and status
- **Profit/loss tracking** (total and daily)
- **Current spread display**
- **MACD indicator values**
- **System status indicators**

### Alert System
- **Email notifications** for important events
- **SMS alerts** (if configured in MT5)
- **Popup alerts** in MetaTrader
- **Trade execution confirmations**
- **Risk management warnings**

## Installation Instructions

### 1. Download and Setup
1. Save the `MACD_Hedging_EA.mq5` file to your MetaTrader 5 installation directory:
   ```
   MetaTrader 5/MQL5/Experts/
   ```

2. Open MetaEditor in MetaTrader 5 (F4 or Tools → MetaQuotes Language Editor)

3. Open the `MACD_Hedging_EA.mq5` file in MetaEditor

4. Compile the Expert Advisor (F7 or Compile button)
   - Ensure there are no compilation errors
   - Check the "Errors" tab at the bottom for any issues

### 2. Attach to Chart
1. In MetaTrader 5, open the chart for your desired currency pair
2. In the Navigator window, expand "Expert Advisors"
3. Double-click on "MACD_Hedging_EA" or drag it to the chart
4. Configure the input parameters (see below)
5. Enable "Allow automated trading" in the EA dialog
6. Click "OK" to start the EA

### 3. Enable Automated Trading
- Ensure the "AutoTrading" button in MT5 toolbar is enabled (should be green)
- Check that your broker allows automated trading
- Verify sufficient account balance for trading

## Input Parameters

### Trading Strategy Settings
- **Trading Timeframe:** Select timeframe for analysis (M1, M5, M15, M30, H1, H4, D1)
- **Initial Lot Size:** Starting position size (default: 0.01)
- **Maximum Hedged Trades:** Maximum number of hedge levels (default: 20)
- **Pip Offset for Hedging:** Distance in pips to trigger hedge (default: 20)
- **Lot Size Multiplier:** Multiplication factor for hedge positions (default: 2.0)
- **Net Profit Target:** Profit target in USD to close all trades (default: 2.0)

### MACD Settings
- **MACD Fast EMA Period:** Fast moving average period (default: 12)
- **MACD Slow EMA Period:** Slow moving average period (default: 26)
- **MACD Signal SMA Period:** Signal line period (default: 9)
- **MACD Applied Price:** Price type for calculation (default: Close)

### Risk Management
- **Daily Loss Limit:** Maximum daily loss in USD (default: 100.0)
- **Maximum Spread:** Maximum allowed spread in pips (default: 3.0)
- **Trading Start Hour:** Start of trading window (0-23, default: 0)
- **Trading End Hour:** End of trading window (0-23, default: 23)

### Alert Settings
- **Enable Email Alerts:** Send email notifications (default: false)
- **Enable SMS Alerts:** Send SMS notifications (default: false)
- **Enable Popup Alerts:** Show popup messages (default: true)

### Dashboard Settings
- **Show Dashboard:** Display visual dashboard (default: true)
- **Dashboard X Position:** Horizontal position on chart (default: 20)
- **Dashboard Y Position:** Vertical position on chart (default: 50)

## How It Works

### 1. Signal Detection
The EA continuously monitors the MACD indicator on the specified timeframe. When a new candle opens, it checks for entry conditions:
- For buy signals: MACD main line must be above zero and signal line below main line
- For sell signals: MACD main line must be below zero and signal line above main line

### 2. Position Management
Once a position is opened, the EA monitors its performance:
- If the position moves favorably, it waits for profit target
- If the position moves against by the specified pip offset, it opens a hedge trade
- Hedge trades use progressively larger lot sizes based on the multiplier

### 3. Hedging System
The hedging system works in levels:
- **Level 0:** Initial trade (e.g., 0.01 lots)
- **Level 1:** First hedge (e.g., 0.02 lots in opposite direction)
- **Level 2:** Second hedge (e.g., 0.04 lots)
- **Level N:** Continues until maximum level or profit target reached

### 4. Exit Strategy
All positions are closed when:
- Net profit of all open trades reaches the target amount
- Daily loss limit is exceeded (optional safety measure)
- Manual intervention by trader

## Performance Monitoring

The dashboard displays real-time information:
- **Symbol:** Currently traded instrument
- **Active Trades:** Number of open positions
- **Total Profit:** Combined profit/loss of all positions
- **Daily Profit:** Today's cumulative results
- **Spread:** Current bid-ask spread
- **MACD Values:** Real-time indicator readings
- **Status:** System operational status

## Risk Warnings

⚠️ **Important Risk Disclosures:**

1. **High Risk Strategy:** Hedging systems can accumulate large positions during adverse market conditions
2. **Account Management:** Ensure sufficient account balance (recommend 10x the maximum potential exposure)
3. **Broker Requirements:** Verify your broker allows hedging and has competitive spreads
4. **Market Conditions:** Performance may vary significantly across different market conditions
5. **Backtesting:** Always backtest thoroughly before live trading
6. **Monitoring:** Regularly monitor the EA's performance and adjust parameters as needed

## Troubleshooting

### Common Issues:
1. **EA not trading:** Check if automated trading is enabled and markets are open
2. **Compilation errors:** Ensure you have the latest MQL5 version
3. **No signals:** Verify MACD parameters and timeframe settings
4. **Spread too high:** Adjust maximum spread parameter
5. **Email/SMS not working:** Configure MT5 email/notification settings

### Performance Optimization:
- Backtest different MACD parameters for your trading pair
- Adjust pip offset based on pair's volatility
- Consider different timeframes for various market conditions
- Monitor correlation between hedging levels and market volatility

## Support and Updates

For questions, issues, or suggestions:
- Review the code comments for detailed implementation logic
- Test thoroughly in demo account before live trading
- Keep the EA updated with latest market conditions
- Monitor performance and adjust parameters as needed

---

**Disclaimer:** Trading involves substantial risk. Past performance does not guarantee future results. Only trade with money you can afford to lose.