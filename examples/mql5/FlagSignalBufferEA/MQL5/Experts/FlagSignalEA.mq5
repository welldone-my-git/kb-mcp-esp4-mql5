//+------------------------------------------------------------------+
//|                                                 FlagSignalEA.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"

#include <Trade\Trade.mqh>

//--- Trade settings
input double   LotSize            = 0.1;          // Fixed lot size
input int      Slippage           = 30;           // Slippage in points
input long     MagicNumber        = 20260513;     // Unique EA identifier

//--- Dynamic SL/TP based on flagpole height
input bool     UseDynamicSLTP     = true;         // Use flagpole height for SL/TP
input double   SL_Multiplier      = 1.0;          // SL = pole height * this (1.0 = same as pole)
input double   TP_Multiplier      = 1.5;          // TP = pole height * this (1.5 × pole)
input int      FixedStopLoss      = 500;          // Fixed SL (points) if not dynamic
input int      FixedTakeProfit    = 0;            // Fixed TP (0 = use dynamic only)

//--- Trend filter (entry condition)
input bool     UseTrendFilter     = true;         // Only trade with 200‑SMA direction
input int      MA_Period          = 200;          // SMA period for trend filter
input ENUM_TIMEFRAMES MA_Timeframe = PERIOD_CURRENT; // Timeframe for SMA

//--- Volume confirmation (optional, off by default)
input bool     UseVolumeConfirmation = false;     // Require high breakout volume
input int      VolumeMA_Period       = 20;        // Volume MA period
input double   VolumeMultiplier      = 1.5;       // Breakout vol > avg * this

//--- EMA Exit (dynamic safety net)
input bool     UseEMAExit          = true;        // Close position if price crosses EMA
input int      EMAExitPeriod       = 50;          // EMA period for exit
input ENUM_MA_METHOD EMAExitMethod = MODE_EMA;     // EMA calculation method
input ENUM_TIMEFRAMES EMAExitTimeframe = PERIOD_CURRENT; // EMA timeframe

//--- Global objects
CTrade         trade;              // Trade object for order operations
int            indiHandle;         // Handle for the flag detector indicator
double         bufBuy[], bufSell[], bufPoleHeight[]; // Buffers for indicator data
int            maHandle, volMAHandle, emaExitHandle; // Handles for filters

//--- Signal tracking
datetime       lastBuyBarTime  = 0;   // Time of last bought signal bar
datetime       lastSellBarTime = 0;   // Time of last sold signal bar
datetime       eaStartTime     = 0;   // Bar time when EA first started (prevents history trading)
bool           hasPosition     = false; // Flag indicating an open position
ulong          currentTicket   = 0;   // Ticket of the current open position

//+------------------------------------------------------------------+
//| Expert initialization – load indicator and filter handles        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Load the custom flag pattern detector
   indiHandle = iCustom(_Symbol, _Period, "Flag_Pattern_Detector");
   if(indiHandle == INVALID_HANDLE)
      return INIT_FAILED;

//--- Set the magic number for trade identification
   trade.SetExpertMagicNumber(MagicNumber);

//--- Create trend filter handle (if enabled)
   if(UseTrendFilter)
      maHandle = iMA(_Symbol, MA_Timeframe, MA_Period, 0, MODE_SMA, PRICE_CLOSE);

//--- Create volume confirmation handle (if enabled)
   if(UseVolumeConfirmation)
      volMAHandle = iMA(_Symbol, _Period, VolumeMA_Period, 0, MODE_SMA, VOLUME_TICK);

//--- Create EMA exit handle (if enabled)
   if(UseEMAExit)
      emaExitHandle = iMA(_Symbol, EMAExitTimeframe, EMAExitPeriod, 0, EMAExitMethod, PRICE_CLOSE);

//--- Reset internal state
   eaStartTime = 0;
   hasPosition = false;
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//| Expert deinitialization – release indicator handles              |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
  {
//--- Release all indicator handles to free resources
   IndicatorRelease(indiHandle);
   if(maHandle)
      IndicatorRelease(maHandle);
   if(volMAHandle)
      IndicatorRelease(volMAHandle);
   if(emaExitHandle)
      IndicatorRelease(emaExitHandle);
  }
//+------------------------------------------------------------------+
//| Main tick handler – entry signals and position management        |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- One‑time startup scan to catch signals that occurred right at attachment
   if(eaStartTime == 0)
     {
      eaStartTime = iTime(_Symbol, _Period, 0);
      ScanStartupSignals();
     }

//--- If a position is open, manage it (EMA exit). No new entries.
   if(hasPosition)
     {
      //--- Check if the position still exists
      if(!PositionSelectByTicket(currentTicket))
        {
         hasPosition = false;
         return;
        }
      //--- Apply EMA exit rule if enabled
      if(UseEMAExit)
         CheckEMAExit();
      return;
     }

//--- No open position: wait for a new bar to check for entry signals
   static datetime prevBarTime = 0;
   datetime currBarTime = iTime(_Symbol, _Period, 0);
   if(currBarTime == prevBarTime)
      return;   
   prevBarTime = currBarTime;

//--- Prevent trading bars before the EA started (avoids backtest future‑leak)
   if(currBarTime < eaStartTime)
      return;

//--- Copy the last two bars of each indicator buffer
   if(CopyBuffer(indiHandle, 0, 0, 2, bufBuy) != 2 ||
      CopyBuffer(indiHandle, 1, 0, 2, bufSell) != 2 ||
      CopyBuffer(indiHandle, 2, 0, 2, bufPoleHeight) != 2)
      return;

//--- Examine the just‑closed bar (index 1)
   datetime closedBarTime = iTime(_Symbol, _Period, 1);
   bool newBuy  = (bufBuy[1] != EMPTY_VALUE && bufBuy[1] != 0);
   bool newSell = (bufSell[1] != EMPTY_VALUE && bufSell[1] != 0);

//--- If a fresh signal is present and passes all filters, execute the trade
   if((newBuy || newSell) && closedBarTime >= eaStartTime)
     {
      if(newBuy && closedBarTime != lastBuyBarTime && PassesFilters(true, closedBarTime))
        {
         ExecuteTrade(true, bufPoleHeight[1]);
         lastBuyBarTime = closedBarTime;   
        }
      else
         if(newSell && closedBarTime != lastSellBarTime && PassesFilters(false, closedBarTime))
           {
            ExecuteTrade(false, bufPoleHeight[1]);
            lastSellBarTime = closedBarTime;
           }
     }
  }
//+------------------------------------------------------------------+
//| Scan the last 50 bars for a signal that appeared before EA start |
//+------------------------------------------------------------------+
void ScanStartupSignals()
  {
   int bars = Bars(_Symbol, _Period);
   int lookBack = MathMin(bars - 2, 50);   
   if(lookBack < 1)
      return;

//--- Temporarily reverse series order for easy backward iteration
   ArraySetAsSeries(bufBuy, true);
   ArraySetAsSeries(bufSell, true);
   ArraySetAsSeries(bufPoleHeight, true);

//--- Copy enough history
   if(CopyBuffer(indiHandle, 0, 0, lookBack+1, bufBuy) < lookBack+1 ||
      CopyBuffer(indiHandle, 1, 0, lookBack+1, bufSell) < lookBack+1 ||
      CopyBuffer(indiHandle, 2, 0, lookBack+1, bufPoleHeight) < lookBack+1)
     {
      ArraySetAsSeries(bufBuy, false);
      ArraySetAsSeries(bufSell, false);
      ArraySetAsSeries(bufPoleHeight, false);
      return;
     }

//--- Restore standard indexing
   ArraySetAsSeries(bufBuy, false);
   ArraySetAsSeries(bufSell, false);
   ArraySetAsSeries(bufPoleHeight, false);

//--- Iterate from older to newer bar (i = lookBack = oldest, downto 1 = last closed)
   for(int i = lookBack; i >= 1; i--)
     {
      datetime barTime = iTime(_Symbol, _Period, i);
      if(barTime < eaStartTime)
         continue;   

      bool buySignal  = (bufBuy[i] != EMPTY_VALUE && bufBuy[i] != 0);
      bool sellSignal = (bufSell[i] != EMPTY_VALUE && bufSell[i] != 0);

      //--- Trade the most recent valid, filtered signal and stop scanning
      if(buySignal && barTime != lastBuyBarTime && PassesFilters(true, barTime))
        {
         ExecuteTrade(true, bufPoleHeight[i]);
         lastBuyBarTime = barTime;
         break;
        }
      if(sellSignal && barTime != lastSellBarTime && PassesFilters(false, barTime))
        {
         ExecuteTrade(false, bufPoleHeight[i]);
         lastSellBarTime = barTime;
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//| Entry filters (trend, volume) – returns true if signal valid     |
//+------------------------------------------------------------------+
bool PassesFilters(bool isBuy, datetime barTime)
  {
//--- 1. Trend filter: price must be on the correct side of the 200 SMA
   if(UseTrendFilter)
     {
      double ma[1];
      if(CopyBuffer(maHandle, 0, iBarShift(_Symbol, MA_Timeframe, barTime), 1, ma) != 1)
         return false;
      double closePrice = iClose(_Symbol, _Period, iBarShift(_Symbol, _Period, barTime));
      if(isBuy  && closePrice < ma[0])  
         return false;
      if(!isBuy && closePrice > ma[0])   
         return false;
     }

//--- 2. Volume confirmation (optional, off by default)
   if(UseVolumeConfirmation)
     {
      int barIdx = iBarShift(_Symbol, _Period, barTime);
      if(barIdx < 0)
         return false;
      long vol[1];
      double avgVol[1];
      if(CopyTickVolume(_Symbol, _Period, barIdx, 1, vol) != 1)
         return false;
      if(CopyBuffer(volMAHandle, 0, barIdx, 1, avgVol) != 1)
         return false;
      if(vol[0] < avgVol[0] * VolumeMultiplier)   
         return false;
     }

//--- All filters passed
   return true;
  }
//+------------------------------------------------------------------+
//| Execute a buy or sell trade with dynamic or fixed SL/TP          |
//+------------------------------------------------------------------+
void ExecuteTrade(bool isBuy, double poleHeight)
  {
//--- Close any existing position first (only one trade at a time)
   if(hasPosition && PositionSelectByTicket(currentTicket))
      trade.PositionClose(currentTicket, Slippage);
   hasPosition = false;

//--- Determine entry price (ask for buy, bid for sell)
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;

//--- Calculate dynamic stop and take profit from flagpole height
   if(UseDynamicSLTP && poleHeight > 0)
     {
      sl = isBuy ? price - poleHeight * SL_Multiplier : price + poleHeight * SL_Multiplier;
      tp = isBuy ? price + poleHeight * TP_Multiplier : price - poleHeight * TP_Multiplier;
     }
   else
     {
      //--- Fallback to fixed values if dynamic mode is off or pole data missing
      if(FixedStopLoss > 0)
         sl = isBuy ? price - FixedStopLoss * _Point : price + FixedStopLoss * _Point;
      if(FixedTakeProfit > 0)
         tp = isBuy ? price + FixedTakeProfit * _Point : price - FixedTakeProfit * _Point;
     }

//--- Send the order
   if(isBuy)
      trade.Buy(LotSize, _Symbol, price, sl, tp, "Flag Buy");
   else
      trade.Sell(LotSize, _Symbol, price, sl, tp, "Flag Sell");

//--- Store position details for the EMA exit monitor
   if(PositionSelect(_Symbol))
     {
      currentTicket = PositionGetInteger(POSITION_TICKET);
      hasPosition = true;
     }
  }
//+------------------------------------------------------------------+
//| Check if open position should be closed by the EMA exit rule     |
//+------------------------------------------------------------------+
void CheckEMAExit()
  {
//--- Ensure the position still exists
   if(!PositionSelectByTicket(currentTicket))
      return;

//--- Get the current EMA value for the exit period
   double ema[1];
   if(CopyBuffer(emaExitHandle, 0, 0, 1, ema) != 1)
      return;

   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   bool closeTrade = false;
   long type = PositionGetInteger(POSITION_TYPE);

//--- Exit rule: long closes below EMA, short closes above EMA
   if(type == POSITION_TYPE_BUY  && currentPrice < ema[0])
      closeTrade = true;
   if(type == POSITION_TYPE_SELL && currentPrice > ema[0])
      closeTrade = true;

//--- Close if condition met
   if(closeTrade)
     {
      trade.PositionClose(currentTicket, Slippage);
      hasPosition = false;
     }
  }
//+------------------------------------------------------------------+