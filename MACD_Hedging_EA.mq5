//+------------------------------------------------------------------+
//|                                            MACD_Hedging_EA.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "MACD-based Expert Advisor with Hedging Logic"
#property strict

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "=== Trading Strategy Settings ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;           // Trading Timeframe
input double InpInitialLot = 0.01;                        // Initial Lot Size
input int InpMaxHedgedTrades = 20;                        // Maximum Hedged Trades
input int InpPipOffset = 20;                              // Pip Offset for Hedging
input double InpLotMultiplier = 2.0;                      // Lot Size Multiplier
input double InpProfitTarget = 2.0;                       // Net Profit Target (USD)

input group "=== MACD Settings ==="
input int InpMACDFastEMA = 12;                            // MACD Fast EMA Period
input int InpMACDSlowEMA = 26;                            // MACD Slow EMA Period
input int InpMACDSignalSMA = 9;                           // MACD Signal SMA Period
input ENUM_APPLIED_PRICE InpMACDPrice = PRICE_CLOSE;       // MACD Applied Price

input group "=== Risk Management ==="
input double InpDailyLossLimit = 100.0;                  // Daily Loss Limit (USD)
input double InpMaxSpread = 3.0;                          // Maximum Spread (Pips)
input int InpTradingStartHour = 0;                        // Trading Start Hour (0-23)
input int InpTradingEndHour = 23;                         // Trading End Hour (0-23)

input group "=== Alert Settings ==="
input bool InpEmailAlerts = false;                        // Enable Email Alerts
input bool InpSMSAlerts = false;                          // Enable SMS Alerts
input bool InpPopupAlerts = true;                         // Enable Popup Alerts

input group "=== Dashboard Settings ==="
input bool InpShowDashboard = true;                       // Show Dashboard
input int InpDashboardX = 20;                             // Dashboard X Position
input int InpDashboardY = 50;                             // Dashboard Y Position

//--- Global variables
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;

int macdHandle = INVALID_HANDLE;
double macdMain[], macdSignal[];
string symbol = "";
double point = 0.0;
double tickSize = 0.0; 
double tickValue = 0.0;
int digits = 0;

//--- Dashboard objects
string dashboardObjects[50];
int totalDashboardObjects = 0;

//--- Trading variables
struct TradeInfo
{
    ulong ticket;
    int level;
    double lot;
    double openPrice;
    ENUM_POSITION_TYPE type;
    datetime openTime;
};

TradeInfo activeTrades[100];
int totalActiveTrades = 0;
double dailyProfit = 0.0;
datetime lastDayReset = 0;
bool newBarFlag = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Get current symbol information
    symbol = Symbol();
    point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    //--- Validate inputs
    if(InpInitialLot <= 0.0)
    {
        Print("Error: Initial lot size must be positive");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(InpMaxHedgedTrades <= 0)
    {
        Print("Error: Maximum hedged trades must be positive");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(InpPipOffset <= 0)
    {
        Print("Error: Pip offset must be positive");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    //--- Initialize MACD indicator
    macdHandle = iMACD(symbol, InpTimeframe, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, InpMACDPrice);
    if(macdHandle == INVALID_HANDLE)
    {
        Print("Failed to create MACD indicator handle");
        return INIT_FAILED;
    }
    
    //--- Initialize arrays
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArrayResize(macdMain, 10);
    ArrayResize(macdSignal, 10);
    ArrayInitialize(macdMain, 0.0);
    ArrayInitialize(macdSignal, 0.0);
    
    //--- Initialize trading
    trade.SetExpertMagicNumber(12345);
    trade.SetMarginMode();
    if(!trade.SetTypeFillingBySymbol(symbol))
    {
        Print("Warning: Could not set filling type for symbol ", symbol);
    }
    
    //--- Initialize daily tracking
    lastDayReset = TimeCurrent();
    
    //--- Initialize active trades array
    ArrayInitialize(activeTrades, {0, 0, 0.0, 0.0, POSITION_TYPE_BUY, 0});
    
    //--- Create dashboard if enabled
    if(InpShowDashboard)
    {
        CreateDashboard();
    }
    
    //--- Send initialization alert
    SendAlert("MACD Hedging EA initialized successfully", "EA Started");
    
    Print("MACD Hedging EA initialized successfully for ", symbol);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handle
    if(macdHandle != INVALID_HANDLE)
        IndicatorRelease(macdHandle);
    
    //--- Remove dashboard objects
    RemoveDashboard();
    
    //--- Send deinitialization alert
    string msg = StringFormat("MACD Hedging EA stopped. Reason: %s", GetDeinitReason(reason));
    SendAlert(msg, "EA Stopped");
    
    Print("MACD Hedging EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check for new bar
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(symbol, InpTimeframe, 0);
    newBarFlag = (currentBarTime != lastBarTime);
    if(newBarFlag)
        lastBarTime = currentBarTime;
    
    //--- Check daily reset
    CheckDailyReset();
    
    //--- Update active trades
    UpdateActiveTrades();
    
    //--- Check risk management
    if(!CheckRiskManagement())
        return;
    
    //--- Check profit target
    if(CheckProfitTarget())
        return;
    
    //--- Main trading logic (only on new bar)
    if(newBarFlag)
    {
        //--- Get MACD values
        if(!GetMACDValues())
            return;
        
        //--- Check for entry signals
        CheckEntrySignals();
    }
    
    //--- Check for hedging opportunities
    CheckHedgingOpportunities();
    
    //--- Update dashboard
    if(InpShowDashboard)
    {
        UpdateDashboard();
    }
}

//+------------------------------------------------------------------+
//| Get MACD indicator values                                        |
//+------------------------------------------------------------------+
bool GetMACDValues()
{
    ArrayInitialize(macdMain, 0.0);
    ArrayInitialize(macdSignal, 0.0);
    
    int copied1 = CopyBuffer(macdHandle, 0, 0, 3, macdMain);
    if(copied1 <= 0)
    {
        Print("Error copying MACD main buffer: ", GetLastError());
        return false;
    }
    
    int copied2 = CopyBuffer(macdHandle, 1, 0, 3, macdSignal);
    if(copied2 <= 0)
    {
        Print("Error copying MACD signal buffer: ", GetLastError());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
    //--- Check array size
    if(ArraySize(macdMain) < 2 || ArraySize(macdSignal) < 2)
        return;
        
    //--- Avoid multiple trades in same direction
    if(HasOpenPositions())
        return;
    
    //--- Buy signal: MACD main > 0 AND MACD signal < MACD main
    if(macdMain[0] > 0.0 && macdSignal[0] < macdMain[0])
    {
        if(macdSignal[1] >= macdMain[1]) // Signal crossing
        {
            if(!OpenTrade(ORDER_TYPE_BUY, InpInitialLot, 0))
            {
                Print("Failed to open BUY trade");
            }
        }
    }
    
    //--- Sell signal: MACD main < 0 AND MACD signal > MACD main
    if(macdMain[0] < 0.0 && macdSignal[0] > macdMain[0])
    {
        if(macdSignal[1] <= macdMain[1]) // Signal crossing
        {
            if(!OpenTrade(ORDER_TYPE_SELL, InpInitialLot, 0))
            {
                Print("Failed to open SELL trade");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open a trade                                                     |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType, double lot, int level)
{
    double price = 0.0;
    double sl = 0.0;
    double tp = 0.0;
    
    if(orderType == ORDER_TYPE_BUY)
        price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    else if(orderType == ORDER_TYPE_SELL)
        price = SymbolInfoDouble(symbol, SYMBOL_BID);
    else
    {
        Print("Error: Invalid order type");
        return false;
    }
    
    if(price <= 0.0)
    {
        Print("Error: Invalid price for order");
        return false;
    }
    
    //--- Validate lot size
    lot = NormalizeLot(lot);
    if(lot <= 0.0)
    {
        Print("Error: Invalid lot size after normalization");
        return false;
    }
    
    bool result = false;
    string comment = StringFormat("MACD_EA_Level_%d", level);
    
    if(orderType == ORDER_TYPE_BUY)
        result = trade.Buy(lot, symbol, price, sl, tp, comment);
    else if(orderType == ORDER_TYPE_SELL)
        result = trade.Sell(lot, symbol, price, sl, tp, comment);
    
    if(result)
    {
        ulong ticket = trade.ResultOrder();
        if(ticket > 0)
        {
            AddTradeToList(ticket, level, lot, price, (ENUM_POSITION_TYPE)orderType);
            
            string msg = StringFormat("Trade opened: %s %.2f lots at %.*f (Level %d)", 
                                      orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", 
                                      lot, digits, price, level);
            SendAlert(msg, "Trade Opened");
            Print(msg);
        }
        else
        {
            Print("Error: Invalid ticket returned");
            return false;
        }
    }
    else
    {
        Print("Failed to open trade: ", trade.ResultRetcodeDescription(), " Code: ", trade.ResultRetcode());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for hedging opportunities                                  |
//+------------------------------------------------------------------+
void CheckHedgingOpportunities()
{
    if(point <= 0.0) return;
    
    for(int i = 0; i < totalActiveTrades; i++)
    {
        if(!PositionSelectByTicket(activeTrades[i].ticket))
            continue;
        
        double currentPrice = positionInfo.PriceCurrent();
        double openPrice = activeTrades[i].openPrice;
        double pipsDiff = 0.0;
        
        if(currentPrice <= 0.0 || openPrice <= 0.0)
            continue;
        
        if(activeTrades[i].type == POSITION_TYPE_BUY)
        {
            pipsDiff = (openPrice - currentPrice) / point;
        }
        else if(activeTrades[i].type == POSITION_TYPE_SELL)
        {
            pipsDiff = (currentPrice - openPrice) / point;
        }
        else
        {
            continue; // Invalid position type
        }
        
        //--- Check if hedge is needed
        if(pipsDiff >= (double)InpPipOffset && activeTrades[i].level < InpMaxHedgedTrades)
        {
            //--- Calculate hedge lot size
            double hedgeLot = activeTrades[i].lot * MathPow(InpLotMultiplier, (double)(activeTrades[i].level + 1));
            
            //--- Open hedge trade
            ENUM_ORDER_TYPE hedgeType = (activeTrades[i].type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            
            if(OpenTrade(hedgeType, hedgeLot, activeTrades[i].level + 1))
            {
                string msg = StringFormat("Hedge trade opened: Level %d, Lot %.2f", 
                                          activeTrades[i].level + 1, hedgeLot);
                SendAlert(msg, "Hedge Opened");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check profit target                                              |
//+------------------------------------------------------------------+
bool CheckProfitTarget()
{
    double totalProfit = GetTotalProfit();
    
    if(totalProfit >= InpProfitTarget)
    {
        CloseAllTrades();
        string msg = StringFormat("Profit target reached: $%.2f. All trades closed.", totalProfit);
        SendAlert(msg, "Profit Target Reached");
        Print(msg);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get total profit of all open positions                          |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
    double totalProfit = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == symbol && positionInfo.Magic() == 12345)
            {
                totalProfit += positionInfo.Profit() + positionInfo.Swap() + positionInfo.Commission();
            }
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Close all trades                                                 |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
    int totalPositions = PositionsTotal();
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == symbol && positionInfo.Magic() == 12345)
            {
                if(!trade.PositionClose(positionInfo.Ticket()))
                {
                    Print("Failed to close position: ", trade.ResultRetcodeDescription());
                }
            }
        }
    }
    
    //--- Clear active trades list
    totalActiveTrades = 0;
    ArrayInitialize(activeTrades, {0, 0, 0.0, 0.0, POSITION_TYPE_BUY, 0});
}

//+------------------------------------------------------------------+
//| Update active trades list                                        |
//+------------------------------------------------------------------+
void UpdateActiveTrades()
{
    totalActiveTrades = 0;
    
    int totalPositions = PositionsTotal();
    for(int i = 0; i < totalPositions && totalActiveTrades < 100; i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == symbol && positionInfo.Magic() == 12345)
            {
                activeTrades[totalActiveTrades].ticket = positionInfo.Ticket();
                activeTrades[totalActiveTrades].type = positionInfo.PositionType();
                activeTrades[totalActiveTrades].lot = positionInfo.Volume();
                activeTrades[totalActiveTrades].openPrice = positionInfo.PriceOpen();
                activeTrades[totalActiveTrades].openTime = positionInfo.Time();
                
                //--- Extract level from comment
                string comment = positionInfo.Comment();
                string search = "Level_";
                int pos = StringFind(comment, search);
                if(pos >= 0)
                {
                    string levelStr = StringSubstr(comment, pos + StringLen(search));
                    activeTrades[totalActiveTrades].level = (int)StringToInteger(levelStr);
                }
                else
                {
                    activeTrades[totalActiveTrades].level = 0;
                }
                
                totalActiveTrades++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Add trade to active trades list                                  |
//+------------------------------------------------------------------+
void AddTradeToList(ulong ticket, int level, double lot, double price, ENUM_POSITION_TYPE type)
{
    if(totalActiveTrades < 100 && ticket > 0)
    {
        activeTrades[totalActiveTrades].ticket = ticket;
        activeTrades[totalActiveTrades].level = level;
        activeTrades[totalActiveTrades].lot = lot;
        activeTrades[totalActiveTrades].openPrice = price;
        activeTrades[totalActiveTrades].type = type;
        activeTrades[totalActiveTrades].openTime = TimeCurrent();
        totalActiveTrades++;
    }
    else
    {
        Print("Warning: Cannot add trade to list - array full or invalid ticket");
    }
}

//+------------------------------------------------------------------+
//| Check if there are open positions                               |
//+------------------------------------------------------------------+
bool HasOpenPositions()
{
    int totalPositions = PositionsTotal();
    for(int i = 0; i < totalPositions; i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Symbol() == symbol && positionInfo.Magic() == 12345)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check risk management conditions                                 |
//+------------------------------------------------------------------+
bool CheckRiskManagement()
{
    //--- Check daily loss limit
    if(InpDailyLossLimit > 0.0 && MathAbs(dailyProfit) >= InpDailyLossLimit)
    {
        static bool dailyLimitWarned = false;
        if(!dailyLimitWarned)
        {
            SendAlert("Daily loss limit reached. Trading stopped.", "Risk Management");
            dailyLimitWarned = true;
        }
        return false;
    }
    
    //--- Check spread
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
        return false;
        
    double spread = (ask - bid) / point;
    if(spread > InpMaxSpread)
        return false;
    
    //--- Check trading time window
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    if(!TimeToStruct(currentTime, dt))
        return false;
    
    if(InpTradingStartHour <= InpTradingEndHour)
    {
        if(dt.hour < InpTradingStartHour || dt.hour > InpTradingEndHour)
            return false;
    }
    else
    {
        if(dt.hour > InpTradingEndHour && dt.hour < InpTradingStartHour)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check for daily reset                                            |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime lastDt, currentDt;
    
    if(!TimeToStruct(lastDayReset, lastDt) || !TimeToStruct(currentTime, currentDt))
        return;
    
    if(currentDt.day != lastDt.day || currentDt.mon != lastDt.mon || currentDt.year != lastDt.year)
    {
        dailyProfit = 0.0;
        lastDayReset = currentTime;
        
        SendAlert("Daily reset performed", "Daily Reset");
    }
    
    //--- Update daily profit
    dailyProfit += GetTotalProfit();
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    lot = MathRound(lot / stepLot) * stepLot;
    
    return lot;
}

//+------------------------------------------------------------------+
//| Create dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    string prefix = "MACD_EA_Dashboard_";
    
    //--- Clear any existing objects first
    RemoveDashboard();
    
    //--- Background panel
    if(ObjectCreate(0, prefix + "Background", OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, prefix + "Background", OBJPROP_XDISTANCE, InpDashboardX);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_YDISTANCE, InpDashboardY);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_XSIZE, 300);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_YSIZE, 200);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_BGCOLOR, clrDarkSlateGray);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_STATE, false);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, prefix + "Background", OBJPROP_FONTSIZE, 8);
        
        if(totalDashboardObjects < ArraySize(dashboardObjects))
            dashboardObjects[totalDashboardObjects++] = prefix + "Background";
    }
    
    //--- Title
    if(ObjectCreate(0, prefix + "Title", OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, prefix + "Title", OBJPROP_XDISTANCE, InpDashboardX + 10);
        ObjectSetInteger(0, prefix + "Title", OBJPROP_YDISTANCE, InpDashboardY + 10);
        ObjectSetInteger(0, prefix + "Title", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, prefix + "Title", OBJPROP_FONTSIZE, 12);
        ObjectSetString(0, prefix + "Title", OBJPROP_FONT, "Arial Bold");
        ObjectSetString(0, prefix + "Title", OBJPROP_TEXT, "MACD Hedging EA Dashboard");
        
        if(totalDashboardObjects < ArraySize(dashboardObjects))
            dashboardObjects[totalDashboardObjects++] = prefix + "Title";
    }
    
    //--- Create labels for data
    string labels[] = {"Symbol:", "Active Trades:", "Total Profit:", "Daily Profit:", "Spread:", "MACD Main:", "MACD Signal:", "Status:"};
    int labelCount = ArraySize(labels);
    
    for(int i = 0; i < labelCount; i++)
    {
        string labelName = prefix + "Label_" + IntegerToString(i);
        if(ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
        {
            ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, InpDashboardX + 10);
            ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, InpDashboardY + 35 + (i * 18));
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLightGray);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, labelName, OBJPROP_TEXT, labels[i]);
            
            if(totalDashboardObjects < ArraySize(dashboardObjects))
                dashboardObjects[totalDashboardObjects++] = labelName;
        }
        
        string valueName = prefix + "Value_" + IntegerToString(i);
        if(ObjectCreate(0, valueName, OBJ_LABEL, 0, 0, 0))
        {
            ObjectSetInteger(0, valueName, OBJPROP_XDISTANCE, InpDashboardX + 120);
            ObjectSetInteger(0, valueName, OBJPROP_YDISTANCE, InpDashboardY + 35 + (i * 18));
            ObjectSetInteger(0, valueName, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, valueName, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, valueName, OBJPROP_TEXT, "---");
            
            if(totalDashboardObjects < ArraySize(dashboardObjects))
                dashboardObjects[totalDashboardObjects++] = valueName;
        }
    }
}

//+------------------------------------------------------------------+
//| Update dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    string prefix = "MACD_EA_Dashboard_";
    
    //--- Update values with error checking
    if(ObjectFind(0, prefix + "Value_0") >= 0)
        ObjectSetString(0, prefix + "Value_0", OBJPROP_TEXT, symbol);
        
    if(ObjectFind(0, prefix + "Value_1") >= 0)
        ObjectSetString(0, prefix + "Value_1", OBJPROP_TEXT, IntegerToString(totalActiveTrades));
        
    if(ObjectFind(0, prefix + "Value_2") >= 0)
        ObjectSetString(0, prefix + "Value_2", OBJPROP_TEXT, StringFormat("$%.2f", GetTotalProfit()));
        
    if(ObjectFind(0, prefix + "Value_3") >= 0)
        ObjectSetString(0, prefix + "Value_3", OBJPROP_TEXT, StringFormat("$%.2f", dailyProfit));
    
    //--- Update spread
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(ask > 0.0 && bid > 0.0 && point > 0.0)
    {
        double spread = (ask - bid) / point;
        if(ObjectFind(0, prefix + "Value_4") >= 0)
            ObjectSetString(0, prefix + "Value_4", OBJPROP_TEXT, StringFormat("%.1f pips", spread));
    }
    
    //--- Update MACD values
    if(ArraySize(macdMain) > 0 && ArraySize(macdSignal) > 0)
    {
        if(ObjectFind(0, prefix + "Value_5") >= 0)
            ObjectSetString(0, prefix + "Value_5", OBJPROP_TEXT, StringFormat("%.5f", macdMain[0]));
            
        if(ObjectFind(0, prefix + "Value_6") >= 0)
            ObjectSetString(0, prefix + "Value_6", OBJPROP_TEXT, StringFormat("%.5f", macdSignal[0]));
    }
    
    //--- Update status
    string status = "Active";
    if(!CheckRiskManagement())
        status = "Risk Limit";
    else if(InpDailyLossLimit > 0.0 && MathAbs(dailyProfit) >= InpDailyLossLimit)
        status = "Daily Limit";
    
    if(ObjectFind(0, prefix + "Value_7") >= 0)
        ObjectSetString(0, prefix + "Value_7", OBJPROP_TEXT, status);
    
    //--- Color coding for profit
    color profitColor = (GetTotalProfit() >= 0.0) ? clrLimeGreen : clrRed;
    if(ObjectFind(0, prefix + "Value_2") >= 0)
        ObjectSetInteger(0, prefix + "Value_2", OBJPROP_COLOR, profitColor);
    
    color dailyColor = (dailyProfit >= 0.0) ? clrLimeGreen : clrRed;
    if(ObjectFind(0, prefix + "Value_3") >= 0)
        ObjectSetInteger(0, prefix + "Value_3", OBJPROP_COLOR, dailyColor);
}

//+------------------------------------------------------------------+
//| Remove dashboard                                                 |
//+------------------------------------------------------------------+
void RemoveDashboard()
{
    for(int i = 0; i < totalDashboardObjects; i++)
    {
        ObjectDelete(0, dashboardObjects[i]);
    }
    totalDashboardObjects = 0;
}

//+------------------------------------------------------------------+
//| Send alert message                                               |
//+------------------------------------------------------------------+
void SendAlert(string message, string subject)
{
    if(InpPopupAlerts)
        Alert(message);
    
    if(InpEmailAlerts)
        SendMail(subject, message);
    
    if(InpSMSAlerts)
        SendNotification(message);
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
        case REASON_CHARTCHANGE: return "Chart symbol or period changed";
        case REASON_CHARTCLOSE: return "Chart closed";
        case REASON_PARAMETERS: return "Input parameters changed";
        case REASON_ACCOUNT: return "Account changed";
        case REASON_TEMPLATE: return "New template applied";
        case REASON_INITFAILED: return "Initialization failed";
        case REASON_CLOSE: return "Terminal closed";
        default: return "Unknown reason";
    }
}

//+------------------------------------------------------------------+