//+------------------------------------------------------------------+
//|                                       WeekendGapSignalTestEA.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                           https://www.mql5.com/en/users/lynchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynchris"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input double   InpLotSize         = 0.10;
input int      InpSlippage        = 30;
input long     InpMagicNumber     = 20260520;
input int      InpMaxOrdersToPlace = 2;

//--- Trade object
CTrade trade;

//--- Indicator handle
int indHandle = INVALID_HANDLE;

//--- Buffer arrays
double   buyBuffer[2];
double   sellBuffer[2];
double   stateBuffer[2];
double   fillPriceBuffer[2];

//--- Control variables
datetime lastSignalBar = 0;
int      ordersPlaced  = 0;
bool     indicatorReady = false;
datetime lastBarTime    = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   indHandle = iCustom(_Symbol, _Period, "WeekendGapSignalIndicator");
   if(indHandle == INVALID_HANDLE)
     {
      Print("Failed to load indicator. Error: ", GetLastError());
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);

   return(INIT_SUCCEEDED);
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
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(indicatorReady == false)
     {
      double testBuffer[1];
      if(CopyBuffer(indHandle, 0, 0, 1, testBuffer) == 1)
        {
         indicatorReady = true;
         Print("Indicator ready. Monitoring gap-fill signals...");
        }
      return;
     }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

   if(CopyBuffer(indHandle, 0, 0, 2, buyBuffer)       != 2 ||
      CopyBuffer(indHandle, 1, 0, 2, sellBuffer)      != 2 ||
      CopyBuffer(indHandle, 2, 0, 2, stateBuffer)     != 2 ||
      CopyBuffer(indHandle, 3, 0, 2, fillPriceBuffer) != 2)
     {
      return;
     }

   datetime closedBarTime = iTime(_Symbol, _Period, 1);

   bool isFilled = (stateBuffer[1] == 3.0);
   bool isBuySignal  = (buyBuffer[1]  != EMPTY_VALUE);
   bool isSellSignal = (sellBuffer[1] != EMPTY_VALUE);

   if(!isFilled || (!isBuySignal && !isSellSignal) || closedBarTime == lastSignalBar)
      return;

   if(InpMaxOrdersToPlace > 0 && ordersPlaced >= InpMaxOrdersToPlace)
     {
      if(ordersPlaced == InpMaxOrdersToPlace)
         Print("Maximum order limit reached (", InpMaxOrdersToPlace, "). Trading stopped.");

      return;
     }

   double price   = isBuySignal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   string comment = isBuySignal ? "Gap Fill Buy" : "Gap Fill Sell";
   bool   success = false;

   if(isBuySignal)
      success = trade.Buy(InpLotSize, _Symbol, price, 0.0, 0.0, comment);
   else
      success = trade.Sell(InpLotSize, _Symbol, price, 0.0, 0.0, comment);

   if(success)
     {
      ordersPlaced++;
      lastSignalBar = closedBarTime;

      Print("Order #", ordersPlaced,
            ": ", (isBuySignal ? "BUY" : "SELL"),
            " at ", DoubleToString(price, _Digits),
            " | Gap filled on ", TimeToString(closedBarTime));
     }
   else
     {
      Print("Order failed. Error: ", GetLastError());
     }
  }
//+------------------------------------------------------------------+
