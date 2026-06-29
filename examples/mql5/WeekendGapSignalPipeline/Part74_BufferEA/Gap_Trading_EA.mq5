//+------------------------------------------------------------------+
//|                                               Gap_Trading_EA.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                           https://www.mql5.com/en/users/lynchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynchris"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input string   InpIndicatorName          = "WeekendGapMultiSignal";
input double   InpLotSize                = 1.0;
input int      InpSlippage               = 30;
input long     InpMagicNumber            = 20260609;
input bool     InpUseIndicatorSLTP       = true;
input bool     InpRequireClosedBar       = true;
input bool     InpAllowMultipleSameSignal = false;
input bool     InpCloseOppositePosition   = false;

//+------------------------------------------------------------------+
//| Midpoint stop-loss management                                    |
//+------------------------------------------------------------------+
input bool     InpEnableMidpointSLMove   = true;
input int      InpMidpointSLBufferPoints = 5;

//+------------------------------------------------------------------+
//| Global objects and variables                                     |
//+------------------------------------------------------------------+
CTrade   trade;
int      indHandle = INVALID_HANDLE;

double   buyArrowBuffer[];
double   sellArrowBuffer[];
double   buyTPBuffer[];
double   buySLBuffer[];
double   sellTPBuffer[];
double   sellSLBuffer[];

datetime lastProcessedSignalBar = 0;
datetime lastBarTime             = 0;
datetime readyBarTime            = 0;
bool     indicatorReady          = false;

//+------------------------------------------------------------------+
//| Check whether a buffer value is empty                            |
//+------------------------------------------------------------------+
bool IsEmptyBufferValue(const double value)
  {
   return (value == EMPTY_VALUE || value == 0.0 || value == DBL_MAX || value == -DBL_MAX);
  }

//+------------------------------------------------------------------+
//| Copy indicator buffers                                           |
//+------------------------------------------------------------------+
bool CopyAllBuffers(const int shift,const int count)
  {
   if(CopyBuffer(indHandle,0,shift,count,buyArrowBuffer) != count)
      return false;

   if(CopyBuffer(indHandle,1,shift,count,sellArrowBuffer) != count)
      return false;

   if(CopyBuffer(indHandle,2,shift,count,buyTPBuffer) != count)
      return false;

   if(CopyBuffer(indHandle,3,shift,count,buySLBuffer) != count)
      return false;

   if(CopyBuffer(indHandle,4,shift,count,sellTPBuffer) != count)
      return false;

   if(CopyBuffer(indHandle,5,shift,count,sellSLBuffer) != count)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Check for an existing position by symbol and magic number        |
//+------------------------------------------------------------------+
bool HasOpenPositionByMagicSymbol()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check whether the signal bar has already been processed          |
//+------------------------------------------------------------------+
bool IsDuplicateSignalBar(const datetime signalBarTime)
  {
   return (signalBarTime == lastProcessedSignalBar);
  }

//+------------------------------------------------------------------+
//| Store the most recently processed signal bar                     |
//+------------------------------------------------------------------+
void MarkSignalBar(const datetime signalBarTime)
  {
   lastProcessedSignalBar = signalBarTime;
  }

//+------------------------------------------------------------------+
//| Close opposite positions when enabled                            |
//+------------------------------------------------------------------+
void CloseOppositeIfNeeded(const bool isBuy)
  {
   if(!InpCloseOppositePosition)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((isBuy && type == POSITION_TYPE_SELL) || (!isBuy && type == POSITION_TYPE_BUY))
         trade.PositionClose(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Validate and adjust stop-loss and take-profit levels             |
//+------------------------------------------------------------------+
bool StopsAreValidForTrade(const bool isBuy,const double entry,double &sl,double &tp)
  {
   if(!InpUseIndicatorSLTP)
      return true;

   if(sl <= 0.0 || tp <= 0.0)
      return false;

   double point = _Point;
   int stopsLevelPoints = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = (double)stopsLevelPoints * point;

   if(isBuy)
     {
      if(tp <= entry)
         return false;
      if(sl >= entry)
         return false;

      if(minDistance > 0.0)
        {
         if((tp - entry) < minDistance)
            tp = entry + minDistance;

         if((entry - sl) < minDistance)
            sl = entry - minDistance;
        }
     }
   else
     {
      if(tp >= entry)
         return false;
      if(sl <= entry)
         return false;

      if(minDistance > 0.0)
        {
         if((entry - tp) < minDistance)
            tp = entry - minDistance;

         if((sl - entry) < minDistance)
            sl = entry + minDistance;
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Midpoint stop-loss management                                    |
//+------------------------------------------------------------------+
void MoveSLToBreakevenOnMidpoint()
  {
   if(!InpEnableMidpointSLMove)
      return;

   double point       = _Point;
   double bufferPrice = InpMidpointSLBufferPoints * point;
   double epsilon     = point / 2.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry              = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp                 = PositionGetDouble(POSITION_TP);
      double currentSL          = PositionGetDouble(POSITION_SL);

      if(tp == 0.0)
         continue;

      double midpoint    = 0.0;
      double currentPrice = 0.0;
      double newSL       = 0.0;

      if(type == POSITION_TYPE_BUY)
        {
         if(tp <= entry)
            continue;

         midpoint     = entry + (tp - entry) / 2.0;
         currentPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);

         if(currentPrice < midpoint)
            continue;

         //--- Calculate new stop-loss above the entry price
         newSL = entry + bufferPrice;

         //--- Ensure broker minimum stop distance requirements are met
         double minStop = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * point;
         if((newSL - entry) < minStop)
            newSL = entry + minStop;

         //--- Prevent stop-loss from crossing the take-profit level
         if(newSL >= tp)
            newSL = tp - point;
        }
      else
         if(type == POSITION_TYPE_SELL)
           {
            if(entry <= tp)
               continue;

            midpoint     = entry - (entry - tp) / 2.0;
            currentPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

            if(currentPrice > midpoint)
               continue;

            //--- Calculate new stop-loss below the entry price
            newSL = entry - bufferPrice;

            //--- Ensure broker minimum stop distance requirements are met
            double minStop = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * point;
            if((entry - newSL) < minStop)
               newSL = entry - minStop;

            //--- Prevent stop-loss from crossing the take-profit level
            if(newSL <= tp)
               newSL = tp + point;
           }
         else
            continue;

      //--- Skip if stop-loss already matches target level
      if(MathAbs(currentSL - newSL) <= epsilon)
         continue;

      if(trade.PositionModify(ticket,newSL,tp))
        {
         Print("Midpoint reached for ",(type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " #",ticket,
               " - SL moved from ",DoubleToString(currentSL,_Digits),
               " to ",DoubleToString(newSL,_Digits));
        }
      else
        {
         Print("Failed to modify SL for #",ticket,", error: ",GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);

   indHandle = iCustom(_Symbol,_Period,InpIndicatorName);
   if(indHandle == INVALID_HANDLE)
     {
      Print("Failed to load indicator '",InpIndicatorName,"'. Error: ",GetLastError());
      return INIT_FAILED;
     }

   ArraySetAsSeries(buyArrowBuffer,true);
   ArraySetAsSeries(sellArrowBuffer,true);
   ArraySetAsSeries(buyTPBuffer,true);
   ArraySetAsSeries(buySLBuffer,true);
   ArraySetAsSeries(sellTPBuffer,true);
   ArraySetAsSeries(sellSLBuffer,true);

   Print("EA initialized. Waiting for indicator signals...");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(indHandle != INVALID_HANDLE)
      IndicatorRelease(indHandle);

   Comment("");
  }

//+------------------------------------------------------------------+
//| Main tick                                                        |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(indHandle == INVALID_HANDLE)
      return;

   if(!indicatorReady)
     {
      double testBuffer[1];
      if(CopyBuffer(indHandle,0,0,1,testBuffer) == 1)
        {
         indicatorReady = true;
         readyBarTime = iTime(_Symbol,_Period,1);
         Print("Indicator ready. Monitoring WeekendGapMultiSignal...");
        }
      else
         return;
     }

   datetime currentBarTime = iTime(_Symbol,_Period,0);
   if(currentBarTime == 0)
      return;

   if(currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   const int signalShift = (InpRequireClosedBar ? 1 : 0);
   datetime signalBarTime = iTime(_Symbol,_Period,signalShift);
   if(signalBarTime == 0)
      return;

   if(signalBarTime <= readyBarTime)
      return;

   if(!CopyAllBuffers(signalShift,1))
      return;

   bool buySignal  = !IsEmptyBufferValue(buyArrowBuffer[0]);
   bool sellSignal = !IsEmptyBufferValue(sellArrowBuffer[0]);

   if(!buySignal && !sellSignal)
      return;

   if(!InpAllowMultipleSameSignal && IsDuplicateSignalBar(signalBarTime))
      return;

   if(HasOpenPositionByMagicSymbol())
      return;

   bool isBuy = buySignal && !sellSignal;
   if(buySignal && sellSignal)
     {
      Print("Both buy and sell signals detected on the same bar. Skipping to avoid conflict.");
      return;
     }

   CloseOppositeIfNeeded(isBuy);

   double entryPrice = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double sl = 0.0;
   double tp = 0.0;

   if(InpUseIndicatorSLTP)
     {
      if(isBuy)
        {
         tp = buyTPBuffer[0];
         sl = buySLBuffer[0];
        }
      else
        {
         tp = sellTPBuffer[0];
         sl = sellSLBuffer[0];
        }

      if(IsEmptyBufferValue(tp))
         tp = 0.0;

      if(IsEmptyBufferValue(sl))
         sl = 0.0;
     }

   if(!StopsAreValidForTrade(isBuy,entryPrice,sl,tp))
     {
      Print("Signal ignored because SL/TP are invalid for the current entry price. ",
            "Entry=",DoubleToString(entryPrice,_Digits),
            " SL=",DoubleToString(sl,_Digits),
            " TP=",DoubleToString(tp,_Digits),
            " SignalBar=",TimeToString(signalBarTime,TIME_DATE | TIME_MINUTES));
      MarkSignalBar(signalBarTime);
      return;
     }

   string comment = isBuy ? "Weekend Gap Buy" : "Weekend Gap Sell";
   bool success   = false;

   if(isBuy)
      success = trade.Buy(InpLotSize,_Symbol,entryPrice,sl,tp,comment);
   else
      success = trade.Sell(InpLotSize,_Symbol,entryPrice,sl,tp,comment);

   if(success)
     {
      MarkSignalBar(signalBarTime);
      Print((isBuy ? "BUY" : "SELL"),
            " | Entry: ",DoubleToString(entryPrice,_Digits),
            " | SL: ",DoubleToString(sl,_Digits),
            " | TP: ",DoubleToString(tp,_Digits),
            " | Signal bar: ",TimeToString(signalBarTime,TIME_DATE | TIME_MINUTES));
     }
   else
     {
      Print("Order failed. Error: ",GetLastError());
     }

//--- Midpoint stop-loss management
   MoveSLToBreakevenOnMidpoint();
  }
//+------------------------------------------------------------------+