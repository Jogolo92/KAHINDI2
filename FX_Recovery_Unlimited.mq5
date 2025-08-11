//+------------------------------------------------------------------+
//|                                         FX_Recovery_Unlimited.mq5 |
//|                        Copyright 2025, Unlimited Trading Systems |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Unlimited Trading Systems"
#property link      ""
#property version   "2.00"
#property description "Advanced Recovery Trading System - No Account Restrictions"
#property strict

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "=== Recovery Strategy Settings ==="
input double InpInitialLot = 0.01;                        // Initial Lot Size
input double InpLotMultiplier = 2.0;                      // Lot Multiplier for Recovery
input int InpMaxRecoveryLevels = 10;                      // Maximum Recovery Levels
input int InpRecoveryDistance = 20;                       // Recovery Distance (Pips)
input double InpNetTakeProfit = 5.0;                      // Net Take Profit (USD)

input group "=== Entry Strategy ==="
input bool InpUseMACD = true;                             // Use MACD for Entry
input bool InpUseRSI = true;                              // Use RSI for Entry
input bool InpUseBollinger = false;                       // Use Bollinger Bands
input int InpMACDFast = 12;                               // MACD Fast EMA
input int InpMACDSlow = 26;                               // MACD Slow EMA
input int InpMACDSignal = 9;                              // MACD Signal
input int InpRSIPeriod = 14;                              // RSI Period
input int InpRSIOverSold = 30;                            // RSI Oversold Level
input int InpRSIOverBought = 70;                          // RSI Overbought Level

input group "=== Risk Management ==="
input double InpMaxDailyLoss = 100.0;                    // Maximum Daily Loss (USD)
input double InpMaxDrawdown = 500.0;                     // Maximum Drawdown (USD)
input double InpMaxSpread = 5.0;                         // Maximum Spread (Pips)
input bool InpCloseOnFriday = true;                       // Close All on Friday

input group "=== Time Filters ==="
input int InpStartHour = 0;                               // Trading Start Hour
input int InpEndHour = 23;                                // Trading End Hour
input bool InpTradeMonday = true;                         // Trade on Monday
input bool InpTradeTuesday = true;                        // Trade on Tuesday
input bool InpTradeWednesday = true;                      // Trade on Wednesday
input bool InpTradeThursday = true;                       // Trade on Thursday
input bool InpTradeFriday = true;                         // Trade on Friday

input group "=== Dashboard & Alerts ==="
input bool InpShowDashboard = true;                       // Show Dashboard
input bool InpShowComments = true;                        // Show Comments
input bool InpEmailAlerts = false;                        // Email Alerts
input bool InpPushAlerts = true;                          // Push Notifications
input int InpMagicNumber = 2025;                          // Magic Number

//--- Global variables
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;

// Indicators
int macdHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;

// Indicator buffers
double macdMain[], macdSignal[], rsiBuffer[], bbUpper[], bbLower[], bbMiddle[];

// Trading variables
string currentSymbol = "";
double symbolPoint = 0.0;
int symbolDigits = 0;
double symbolTickSize = 0.0;

// Recovery system
struct RecoveryLevel
{
    ulong ticket;
    int level;
    double lotSize;
    double openPrice;
    ENUM_POSITION_TYPE direction;
    datetime openTime;
    bool isActive;
};

RecoveryLevel recoveryLevels[50];
int totalRecoveryLevels = 0;
double totalRecoveryProfit = 0.0;

// Statistics
double dailyProfit = 0.0;
double maxDrawdown = 0.0;
datetime lastResetTime = 0;
int totalTrades = 0;
int winningTrades = 0;

// Dashboard
string dashboardLines[20];
int dashboardCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Get symbol information
    currentSymbol = Symbol();
    symbolPoint = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
    symbolDigits = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
    symbolTickSize = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Validate inputs
    if(InpInitialLot <= 0.0 || InpLotMultiplier <= 1.0)
    {
        Print("Error: Invalid lot settings");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(InpMaxRecoveryLevels <= 0 || InpMaxRecoveryLevels > 50)
    {
        Print("Error: Invalid recovery levels (1-50)");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialize indicators
    if(InpUseMACD)
    {
        macdHandle = iMACD(currentSymbol, PERIOD_CURRENT, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
        if(macdHandle == INVALID_HANDLE)
        {
            Print("Error: Failed to create MACD indicator");
            return INIT_FAILED;
        }
    }
    
    if(InpUseRSI)
    {
        rsiHandle = iRSI(currentSymbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
        if(rsiHandle == INVALID_HANDLE)
        {
            Print("Error: Failed to create RSI indicator");
            return INIT_FAILED;
        }
    }
    
    if(InpUseBollinger)
    {
        bbHandle = iBands(currentSymbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
        if(bbHandle == INVALID_HANDLE)
        {
            Print("Error: Failed to create Bollinger Bands indicator");
            return INIT_FAILED;
        }
    }
    
    // Initialize arrays
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(bbUpper, true);
    ArraySetAsSeries(bbLower, true);
    ArraySetAsSeries(bbMiddle, true);
    
    // Initialize trading
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(currentSymbol);
    
    // Initialize recovery levels
    for(int i = 0; i < ArraySize(recoveryLevels); i++)
    {
        recoveryLevels[i].ticket = 0;
        recoveryLevels[i].level = 0;
        recoveryLevels[i].lotSize = 0.0;
        recoveryLevels[i].openPrice = 0.0;
        recoveryLevels[i].direction = POSITION_TYPE_BUY;
        recoveryLevels[i].openTime = 0;
        recoveryLevels[i].isActive = false;
    }
    
    lastResetTime = TimeCurrent();
    
    Print("FX Recovery Unlimited EA initialized successfully for ", currentSymbol);
    if(InpPushAlerts) SendNotification("FX Recovery EA Started on " + currentSymbol);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
    if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
    if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
    
    // Clean up dashboard
    Comment("");
    
    Print("FX Recovery EA deinitialized. Reason: ", GetDeinitReason(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update recovery system
    UpdateRecoveryLevels();
    
    // Check for daily reset
    CheckDailyReset();
    
    // Check risk management
    if(!CheckRiskManagement()) return;
    
    // Check net take profit
    if(CheckNetTakeProfit()) return;
    
    // Check for recovery opportunities
    CheckRecoveryOpportunities();
    
    // Check for new entry signals (only if no active recovery)
    if(totalRecoveryLevels == 0)
    {
        CheckEntrySignals();
    }
    
    // Update dashboard
    if(InpShowDashboard) UpdateDashboard();
    if(InpShowComments) UpdateComments();
}

//+------------------------------------------------------------------+
//| Check entry signals                                              |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
    if(!IsTimeToTrade()) return;
    if(HasActivePositions()) return;
    
    bool buySignal = false;
    bool sellSignal = false;
    
    // MACD Signal
    if(InpUseMACD && GetMACDSignal(buySignal, sellSignal))
    {
        // Continue with other indicators
    }
    else if(InpUseMACD)
    {
        return; // MACD required but no signal
    }
    
    // RSI Signal
    if(InpUseRSI)
    {
        bool rsiBuy, rsiSell;
        if(!GetRSISignal(rsiBuy, rsiSell)) return;
        
        buySignal = buySignal && rsiBuy;
        sellSignal = sellSignal && rsiSell;
    }
    
    // Bollinger Bands Signal
    if(InpUseBollinger)
    {
        bool bbBuy, bbSell;
        if(!GetBollingerSignal(bbBuy, bbSell)) return;
        
        buySignal = buySignal && bbBuy;
        sellSignal = sellSignal && bbSell;
    }
    
    // Execute trade
    if(buySignal)
    {
        OpenRecoveryTrade(ORDER_TYPE_BUY, InpInitialLot, 0);
    }
    else if(sellSignal)
    {
        OpenRecoveryTrade(ORDER_TYPE_SELL, InpInitialLot, 0);
    }
}

//+------------------------------------------------------------------+
//| Get MACD signal                                                  |
//+------------------------------------------------------------------+
bool GetMACDSignal(bool &buySignal, bool &sellSignal)
{
    if(macdHandle == INVALID_HANDLE) return false;
    
    if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) <= 0 ||
       CopyBuffer(macdHandle, 1, 0, 3, macdSignal) <= 0)
        return false;
    
    // MACD crossover signals
    buySignal = (macdMain[0] > macdSignal[0] && macdMain[1] <= macdSignal[1] && macdMain[0] < 0);
    sellSignal = (macdMain[0] < macdSignal[0] && macdMain[1] >= macdSignal[1] && macdMain[0] > 0);
    
    return true;
}

//+------------------------------------------------------------------+
//| Get RSI signal                                                   |
//+------------------------------------------------------------------+
bool GetRSISignal(bool &buySignal, bool &sellSignal)
{
    if(rsiHandle == INVALID_HANDLE) return true; // Skip if not available
    
    if(CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) <= 0)
        return false;
    
    buySignal = (rsiBuffer[1] < InpRSIOverSold && rsiBuffer[0] > InpRSIOverSold);
    sellSignal = (rsiBuffer[1] > InpRSIOverBought && rsiBuffer[0] < InpRSIOverBought);
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands signal                                      |
//+------------------------------------------------------------------+
bool GetBollingerSignal(bool &buySignal, bool &sellSignal)
{
    if(bbHandle == INVALID_HANDLE) return true; // Skip if not available
    
    if(CopyBuffer(bbHandle, 0, 0, 2, bbMiddle) <= 0 ||
       CopyBuffer(bbHandle, 1, 0, 2, bbUpper) <= 0 ||
       CopyBuffer(bbHandle, 2, 0, 2, bbLower) <= 0)
        return false;
    
    double currentPrice = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
    
    buySignal = (currentPrice <= bbLower[0]);
    sellSignal = (currentPrice >= bbUpper[0]);
    
    return true;
}

//+------------------------------------------------------------------+
//| Open recovery trade                                              |
//+------------------------------------------------------------------+
bool OpenRecoveryTrade(ENUM_ORDER_TYPE orderType, double lotSize, int level)
{
    double price = 0.0;
    
    if(orderType == ORDER_TYPE_BUY)
        price = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
    else
        price = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
    
    // Normalize lot size
    lotSize = NormalizeLot(lotSize);
    if(lotSize <= 0.0) return false;
    
    string comment = StringFormat("Recovery_L%d", level);
    bool result = false;
    
    if(orderType == ORDER_TYPE_BUY)
        result = trade.Buy(lotSize, currentSymbol, price, 0, 0, comment);
    else
        result = trade.Sell(lotSize, currentSymbol, price, 0, 0, comment);
    
    if(result)
    {
        ulong ticket = trade.ResultOrder();
        
        // Add to recovery levels
        if(totalRecoveryLevels < ArraySize(recoveryLevels))
        {
            recoveryLevels[totalRecoveryLevels].ticket = ticket;
            recoveryLevels[totalRecoveryLevels].level = level;
            recoveryLevels[totalRecoveryLevels].lotSize = lotSize;
            recoveryLevels[totalRecoveryLevels].openPrice = price;
            recoveryLevels[totalRecoveryLevels].direction = (ENUM_POSITION_TYPE)orderType;
            recoveryLevels[totalRecoveryLevels].openTime = TimeCurrent();
            recoveryLevels[totalRecoveryLevels].isActive = true;
            totalRecoveryLevels++;
        }
        
        totalTrades++;
        
        string msg = StringFormat("Recovery trade opened: %s %.2f lots at %.5f (Level %d)",
                                  orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                                  lotSize, price, level);
        Print(msg);
        if(InpPushAlerts) SendNotification(msg);
        
        return true;
    }
    else
    {
        Print("Failed to open recovery trade: ", trade.ResultRetcodeDescription());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check recovery opportunities                                     |
//+------------------------------------------------------------------+
void CheckRecoveryOpportunities()
{
    if(totalRecoveryLevels == 0) return;
    
    for(int i = 0; i < totalRecoveryLevels; i++)
    {
        if(!recoveryLevels[i].isActive) continue;
        if(recoveryLevels[i].level >= InpMaxRecoveryLevels) continue;
        
        if(!PositionSelectByTicket(recoveryLevels[i].ticket)) continue;
        
        double currentPrice = SymbolInfoDouble(currentSymbol, 
            recoveryLevels[i].direction == POSITION_TYPE_BUY ? SYMBOL_BID : SYMBOL_ASK);
        double openPrice = recoveryLevels[i].openPrice;
        
        double pipsDifference = 0.0;
        
        if(recoveryLevels[i].direction == POSITION_TYPE_BUY)
            pipsDifference = (openPrice - currentPrice) / symbolPoint;
        else
            pipsDifference = (currentPrice - openPrice) / symbolPoint;
        
        // Check if recovery distance reached
        if(pipsDifference >= InpRecoveryDistance)
        {
            double nextLotSize = recoveryLevels[i].lotSize * InpLotMultiplier;
            ENUM_ORDER_TYPE nextOrderType = (recoveryLevels[i].direction == POSITION_TYPE_BUY) ? 
                                           ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            
            if(OpenRecoveryTrade(nextOrderType, nextLotSize, recoveryLevels[i].level + 1))
            {
                // Mark this level as processed
                recoveryLevels[i].isActive = false;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check net take profit                                            |
//+------------------------------------------------------------------+
bool CheckNetTakeProfit()
{
    double totalProfit = GetTotalProfit();
    
    if(totalProfit >= InpNetTakeProfit)
    {
        CloseAllPositions();
        
        dailyProfit += totalProfit;
        winningTrades++;
        
        string msg = StringFormat("Net take profit reached: $%.2f - All positions closed", totalProfit);
        Print(msg);
        if(InpPushAlerts) SendNotification(msg);
        if(InpEmailAlerts) SendMail("Recovery TP Hit", msg);
        
        // Reset recovery system
        ResetRecoverySystem();
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get total profit                                                 |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
    double totalProfit = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == currentSymbol && positionInfo.Magic() == InpMagicNumber)
            {
                totalProfit += positionInfo.Profit() + positionInfo.Swap() + positionInfo.Commission();
            }
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == currentSymbol && positionInfo.Magic() == InpMagicNumber)
            {
                trade.PositionClose(positionInfo.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Reset recovery system                                            |
//+------------------------------------------------------------------+
void ResetRecoverySystem()
{
    for(int i = 0; i < ArraySize(recoveryLevels); i++)
    {
        recoveryLevels[i].ticket = 0;
        recoveryLevels[i].level = 0;
        recoveryLevels[i].lotSize = 0.0;
        recoveryLevels[i].openPrice = 0.0;
        recoveryLevels[i].direction = POSITION_TYPE_BUY;
        recoveryLevels[i].openTime = 0;
        recoveryLevels[i].isActive = false;
    }
    
    totalRecoveryLevels = 0;
    totalRecoveryProfit = 0.0;
}

//+------------------------------------------------------------------+
//| Update recovery levels                                           |
//+------------------------------------------------------------------+
void UpdateRecoveryLevels()
{
    // Remove inactive levels
    for(int i = totalRecoveryLevels - 1; i >= 0; i--)
    {
        if(recoveryLevels[i].isActive && !PositionSelectByTicket(recoveryLevels[i].ticket))
        {
            // Position closed - remove from recovery levels
            for(int j = i; j < totalRecoveryLevels - 1; j++)
            {
                recoveryLevels[j] = recoveryLevels[j + 1];
            }
            totalRecoveryLevels--;
        }
    }
    
    // Update total recovery profit
    totalRecoveryProfit = GetTotalProfit();
}

//+------------------------------------------------------------------+
//| Check risk management                                            |
//+------------------------------------------------------------------+
bool CheckRiskManagement()
{
    // Check daily loss
    if(InpMaxDailyLoss > 0.0 && (-dailyProfit) >= InpMaxDailyLoss)
    {
        static bool dailyLossWarned = false;
        if(!dailyLossWarned)
        {
            string msg = "Daily loss limit reached. Trading stopped.";
            Print(msg);
            if(InpPushAlerts) SendNotification(msg);
            dailyLossWarned = true;
        }
        return false;
    }
    
    // Check drawdown
    double currentDrawdown = -GetTotalProfit();
    if(currentDrawdown > maxDrawdown) maxDrawdown = currentDrawdown;
    
    if(InpMaxDrawdown > 0.0 && maxDrawdown >= InpMaxDrawdown)
    {
        CloseAllPositions();
        string msg = "Maximum drawdown reached. All positions closed.";
        Print(msg);
        if(InpPushAlerts) SendNotification(msg);
        ResetRecoverySystem();
        return false;
    }
    
    // Check spread
    double spread = (SymbolInfoDouble(currentSymbol, SYMBOL_ASK) - 
                    SymbolInfoDouble(currentSymbol, SYMBOL_BID)) / symbolPoint;
    if(spread > InpMaxSpread)
        return false;
    
    // Check Friday close
    if(InpCloseOnFriday)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if(dt.day_of_week == 5 && dt.hour >= 20) // Friday 8 PM
        {
            CloseAllPositions();
            ResetRecoverySystem();
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if it's time to trade                                     |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Check day of week
    switch(dt.day_of_week)
    {
        case 1: if(!InpTradeMonday) return false; break;
        case 2: if(!InpTradeTuesday) return false; break;
        case 3: if(!InpTradeWednesday) return false; break;
        case 4: if(!InpTradeThursday) return false; break;
        case 5: if(!InpTradeFriday) return false; break;
        default: return false; // Weekend
    }
    
    // Check hour
    if(dt.hour < InpStartHour || dt.hour > InpEndHour)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if has active positions                                   |
//+------------------------------------------------------------------+
bool HasActivePositions()
{
    return (PositionsTotal() > 0);
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double minLot = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    lot = NormalizeDouble(lot / stepLot, 0) * stepLot;
    
    return lot;
}

//+------------------------------------------------------------------+
//| Check daily reset                                                |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    MqlDateTime lastDt, currentDt;
    TimeToStruct(lastResetTime, lastDt);
    TimeToStruct(TimeCurrent(), currentDt);
    
    if(currentDt.day != lastDt.day)
    {
        dailyProfit = 0.0;
        maxDrawdown = 0.0;
        lastResetTime = TimeCurrent();
        
        Print("Daily reset performed");
    }
}

//+------------------------------------------------------------------+
//| Update dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    dashboardCount = 0;
    
    dashboardLines[dashboardCount++] = "═══ FX RECOVERY UNLIMITED ═══";
    dashboardLines[dashboardCount++] = "Symbol: " + currentSymbol;
    dashboardLines[dashboardCount++] = "Recovery Levels: " + IntegerToString(totalRecoveryLevels);
    dashboardLines[dashboardCount++] = "Total Profit: $" + DoubleToString(GetTotalProfit(), 2);
    dashboardLines[dashboardCount++] = "Daily Profit: $" + DoubleToString(dailyProfit, 2);
    dashboardLines[dashboardCount++] = "Max Drawdown: $" + DoubleToString(maxDrawdown, 2);
    dashboardLines[dashboardCount++] = "Total Trades: " + IntegerToString(totalTrades);
    dashboardLines[dashboardCount++] = "Win Rate: " + DoubleToString(totalTrades > 0 ? (winningTrades * 100.0 / totalTrades) : 0, 1) + "%";
    
    double spread = (SymbolInfoDouble(currentSymbol, SYMBOL_ASK) - 
                    SymbolInfoDouble(currentSymbol, SYMBOL_BID)) / symbolPoint;
    dashboardLines[dashboardCount++] = "Spread: " + DoubleToString(spread, 1) + " pips";
    
    string status = IsTimeToTrade() ? "ACTIVE" : "INACTIVE";
    dashboardLines[dashboardCount++] = "Status: " + status;
}

//+------------------------------------------------------------------+
//| Update comments                                                  |
//+------------------------------------------------------------------+
void UpdateComments()
{
    string comment = "";
    
    for(int i = 0; i < dashboardCount; i++)
    {
        comment += dashboardLines[i] + "\n";
    }
    
    Comment(comment);
}

//+------------------------------------------------------------------+
//| Get deinitialization reason                                      |
//+------------------------------------------------------------------+
string GetDeinitReason(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM: return "EA stopped manually";
        case REASON_REMOVE: return "EA removed from chart";
        case REASON_RECOMPILE: return "EA recompiled";
        case REASON_CHARTCHANGE: return "Chart changed";
        case REASON_CHARTCLOSE: return "Chart closed";
        case REASON_PARAMETERS: return "Parameters changed";
        case REASON_ACCOUNT: return "Account changed";
        default: return "Unknown reason";
    }
}

//+------------------------------------------------------------------+