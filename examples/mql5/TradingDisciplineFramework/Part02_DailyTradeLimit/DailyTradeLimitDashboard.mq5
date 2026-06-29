//+------------------------------------------------------------------+
//|                                      DailyTradeLimitDashboard.mq5|
//|                                   Copyright 2026, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict
#property indicator_chart_window
#property indicator_buffers 1        // dummy buffer
#property indicator_plots   1        // dummy plot

//--- dummy plot (not used)
#property indicator_label1  "Dummy"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrNONE

#include <DailyTradeLimit.mqh>

//=========================== INPUTS =================================
input int    InpDailyTradeLimit      = 5;        // Max trades per trading day
input string InpDayStartTime         = "00:00";  // Trading-day start (HH:MM, broker time)
input int    InpAmberRemainingTrades = 1;        // Amber when remaining trades <= this

input bool   InpShowAlerts           = true;     // Terminal alerts
input bool   InpUsePushNotifications = false;    // Push notifications to phone
input bool   InpPlaySound            = false;    // Sound on state change
input string InpSoundFile            = "alert.wav";

// Dashboard
input ENUM_BASE_CORNER InpCorner     = CORNER_LEFT_UPPER;
input int    InpX                    = 10;
input int    InpY                    = 20;
input int    InpWidth                = 300;
input int    InpHeight               = 120;

//=========================== GLOBALS ================================
string PREFIX = "DTL_";
DTL::ENUM_DTL_STATE prevState = DTL::STATE_ALLOWED;

double dummyBuffer[];   // dummy buffer (required)

//+------------------------------------------------------------------+
//| Delete all objects with given prefix                            |
//+------------------------------------------------------------------+
void DeleteByPrefix(string pref)
  {
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
     {
      string name = ObjectName(0,i);
      if(StringFind(name,pref)==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//| Create dashboard panel                                          |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   DeleteByPrefix(PREFIX);

   ObjectCreate(0,PREFIX+"BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_CORNER,InpCorner);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_XDISTANCE,InpX);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_YDISTANCE,InpY);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_XSIZE,InpWidth);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_YSIZE,InpHeight);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_SELECTABLE,false);

   string labels[4]= {"TITLE","L1","L2","L3"};
   int y[4]= {8,32,52,78};

   for(int i=0;i<4;i++)
     {
      ObjectCreate(0,PREFIX+labels[i],OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,PREFIX+labels[i],OBJPROP_CORNER,InpCorner);
      ObjectSetInteger(0,PREFIX+labels[i],OBJPROP_XDISTANCE,InpX+10);
      ObjectSetInteger(0,PREFIX+labels[i],OBJPROP_YDISTANCE,InpY+y[i]);
      ObjectSetInteger(0,PREFIX+labels[i],OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,PREFIX+labels[i],OBJPROP_SELECTABLE,false);
     }

   ObjectSetInteger(0,PREFIX+"TITLE",OBJPROP_FONTSIZE,11);
   ObjectSetString(0,PREFIX+"TITLE",OBJPROP_TEXT,"DAILY TRADE LIMIT");

   ObjectSetInteger(0,PREFIX+"L1",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"L2",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"L3",OBJPROP_FONTSIZE,10);
  }

//+------------------------------------------------------------------+
//| Update panel with current data                                  |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   int trades = DTL::TradesToday();
   int limit  = DTL::GetParamLimit();
   int remaining = DTL::Remaining();
   DTL::ENUM_DTL_STATE state = DTL::GetState();

   ObjectSetString(0,PREFIX+"L1",OBJPROP_TEXT,
                   StringFormat("Trades today: %d / %d",trades,limit));
   ObjectSetString(0,PREFIX+"L2",OBJPROP_TEXT,
                   StringFormat("Remaining today: %d",remaining));
   ObjectSetString(0,PREFIX+"L3",OBJPROP_TEXT,
                   StringFormat("STATUS: %s",DTL::StateToString(state)));

   color bg = clrNONE;   // initialize to avoid compiler warning
   switch(state)
     {
      case DTL::STATE_ALLOWED:
         bg = clrDarkGreen;
         break;
      case DTL::STATE_CAUTION:
         bg = clrOrange;
         break;
      case DTL::STATE_LIMIT:
         bg = clrMaroon;
         break;
     }
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BGCOLOR,bg);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                        |
//+------------------------------------------------------------------+
int OnInit()
  {
// Set indicator buffers (dummy)
   SetIndexBuffer(0,dummyBuffer,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_NONE);

// Store parameters in global variables for all programs
   DTL::SetParameters(InpDailyTradeLimit, InpDayStartTime, InpAmberRemainingTrades);

// Initial refresh
   DTL::Refresh();
   prevState = DTL::GetState();

   CreatePanel();
   UpdatePanel();

   EventSetTimer(1);   // update every second
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteByPrefix(PREFIX);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function (dummy)                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   bool changed = DTL::Refresh();
   UpdatePanel();

   if(changed && InpShowAlerts)
     {
      string msg;
      switch(DTL::GetState())
        {
         case DTL::STATE_ALLOWED:
            msg = "Trading allowed: within daily trade limit.";
            break;
         case DTL::STATE_CAUTION:
            msg = "Caution: approaching daily trade limit.";
            break;
         case DTL::STATE_LIMIT:
            msg = "Trading limit reached: no trades remaining today.";
            break;
        }
      Alert(msg);
      if(InpUsePushNotifications)
         SendNotification(msg);
      if(InpPlaySound)
         PlaySound(InpSoundFile);
     }
  }

//+------------------------------------------------------------------+
//| Trade transaction – refresh immediately on new deal             |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      DTL::Refresh();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
