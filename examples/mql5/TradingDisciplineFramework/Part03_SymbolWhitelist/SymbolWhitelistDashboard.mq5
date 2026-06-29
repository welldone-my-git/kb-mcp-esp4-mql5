//+------------------------------------------------------------------+
//|                                     SymbolWhitelistDashboard.mq5 |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <SymbolWhitelist.mqh>

//--- input parameters
input string InpWhitelist = "EURUSD,GBPUSD,XAUUSD";  // Allowed symbols (comma separated)
input int    InpX         = 20;                       // Panel X offset
input int    InpY         = 20;                       // Panel Y offset
input int    InpWidth     = 500;                      // Panel width
input int    InpHeight    = 300;                      // Panel height

//--- colors
input color  InpBgColor       = C'30,30,30';          // Background
input color  InpBorderColor   = C'80,80,80';          // Border
input color  InpChipBg        = C'70,70,70';          // Chip background
input color  InpChipBorder    = C'120,120,120';       // Chip border
input color  InpTextColor     = clrWhite;              // Text
input color  InpAllowedColor  = clrLimeGreen;          // Allowed indicator
input color  InpBlockedColor  = clrTomato;             // Blocked indicator
input color  InpActiveColor   = clrLimeGreen;          // Enforcement active
input color  InpPausedColor   = clrOrange;             // Enforcement paused

//--- global prefixes
string PREFIX = "SWL_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Save initial whitelist to file
   SWL::SaveWhitelist(InpWhitelist);

   CreatePanel();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteObjectsByPrefix(PREFIX);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Custom indicator iteration function (required)                   |
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

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDashboard();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Creates the entire panel                                         |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   DeleteObjectsByPrefix(PREFIX);

//--- Background
   ObjectCreate(0,PREFIX+"BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_XDISTANCE,InpX);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_YDISTANCE,InpY);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_XSIZE,InpWidth);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_YSIZE,InpHeight);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BGCOLOR,InpBgColor);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_COLOR,InpBorderColor);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BACK,false);

//--- Header
   ObjectCreate(0,PREFIX+"HEADER",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_YDISTANCE,InpY+8);
   ObjectSetString(0,PREFIX+"HEADER",OBJPROP_TEXT,"🔒 SYMBOL WHITELIST ENFORCER");
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_FONTSIZE,12);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_SELECTABLE,false);

//--- Separator line
   ObjectCreate(0,PREFIX+"SEP1",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_YDISTANCE,InpY+30);
   ObjectSetString(0,PREFIX+"SEP1",OBJPROP_TEXT,"────────────────────");
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_COLOR,InpBorderColor);
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_SELECTABLE,false);

//--- Allowed symbols section header
   ObjectCreate(0,PREFIX+"ALLOWED_TITLE",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"ALLOWED_TITLE",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"ALLOWED_TITLE",OBJPROP_YDISTANCE,InpY+40);
   ObjectSetString(0,PREFIX+"ALLOWED_TITLE",OBJPROP_TEXT,"ALLOWED SYMBOLS");
   ObjectSetInteger(0,PREFIX+"ALLOWED_TITLE",OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,PREFIX+"ALLOWED_TITLE",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"ALLOWED_TITLE",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"ALLOWED_TITLE",OBJPROP_SELECTABLE,false);

//--- Current chart section header
   ObjectCreate(0,PREFIX+"CURRENT_TITLE",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"CURRENT_TITLE",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"CURRENT_TITLE",OBJPROP_YDISTANCE,InpY+95);
   ObjectSetString(0,PREFIX+"CURRENT_TITLE",OBJPROP_TEXT,"CURRENT CHART");
   ObjectSetInteger(0,PREFIX+"CURRENT_TITLE",OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,PREFIX+"CURRENT_TITLE",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"CURRENT_TITLE",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"CURRENT_TITLE",OBJPROP_SELECTABLE,false);

//--- Log section header
   ObjectCreate(0,PREFIX+"LOG_TITLE",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"LOG_TITLE",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"LOG_TITLE",OBJPROP_YDISTANCE,InpY+150);
   ObjectSetString(0,PREFIX+"LOG_TITLE",OBJPROP_TEXT,"TODAY'S BLOCKED ATTEMPTS");
   ObjectSetInteger(0,PREFIX+"LOG_TITLE",OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,PREFIX+"LOG_TITLE",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"LOG_TITLE",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"LOG_TITLE",OBJPROP_SELECTABLE,false);

//--- Footer (enforcement status)
   ObjectCreate(0,PREFIX+"FOOTER",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_YDISTANCE,InpY+InpHeight-25);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_COLOR,InpActiveColor);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_FONTSIZE,11);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_SELECTABLE,false);

//--- Dynamic elements (chips, status, log lines)
   for(int i=0; i<10; i++)
     {
      string name = PREFIX+"CHIP_"+IntegerToString(i);
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,InpChipBg);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpChipBorder);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);

      name = PREFIX+"CHIPTXT_"+IntegerToString(i);
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpTextColor);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);

      name = PREFIX+"LOG_"+IntegerToString(i);
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpTextColor);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
     }

//--- Status lines
   ObjectCreate(0,PREFIX+"STATUS_SYM",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"STATUS_SYM",OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,PREFIX+"STATUS_SYM",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"STATUS_SYM",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"STATUS_SYM",OBJPROP_SELECTABLE,false);

   ObjectCreate(0,PREFIX+"STATUS_IND",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"STATUS_IND",OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,PREFIX+"STATUS_IND",OBJPROP_BACK,false);
   ObjectSetInteger(0,PREFIX+"STATUS_IND",OBJPROP_SELECTABLE,false);

   UpdateDashboard();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Updates all dynamic panel content                                |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   string whitelist = SWL::LoadWhitelist();
   string allowed[];
   int num = SWL::ParseWhitelist(whitelist,allowed);

//--- Hide all chips first
   for(int i=0; i<10; i++)
     {
      ObjectSetInteger(0,PREFIX+"CHIP_"+IntegerToString(i),OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,PREFIX+"CHIPTXT_"+IntegerToString(i),OBJPROP_HIDDEN,true);
     }

//--- Draw chips
   int x = InpX + 10;
   int y = InpY + 55;
   int chipHeight = 22;
   int margin = 8;
   for(int i=0; i<num && i<10; i++)
     {
      string sym = allowed[i];
      int textWidth = StringLen(sym) * 7;
      int chipWidth = textWidth + 16;

      if(x + chipWidth > InpX + InpWidth - 10)
        {
         x = InpX + 10;
         y += chipHeight + 5;
        }

      string chipName = PREFIX+"CHIP_"+IntegerToString(i);
      ObjectSetInteger(0,chipName,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,chipName,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,chipName,OBJPROP_XSIZE,chipWidth);
      ObjectSetInteger(0,chipName,OBJPROP_YSIZE,chipHeight);
      ObjectSetInteger(0,chipName,OBJPROP_HIDDEN,false);

      string txtName = PREFIX+"CHIPTXT_"+IntegerToString(i);
      ObjectSetInteger(0,txtName,OBJPROP_XDISTANCE,x+8);
      ObjectSetInteger(0,txtName,OBJPROP_YDISTANCE,y+3);
      ObjectSetString(0,txtName,OBJPROP_TEXT,sym);
      ObjectSetInteger(0,txtName,OBJPROP_HIDDEN,false);

      x += chipWidth + margin;
     }

//--- Current chart status with dynamic positioning
   string currSym = Symbol();
   bool allowedNow = SWL::IsSymbolAllowed(currSym);
   string statusText = allowedNow ? "● ALLOWED" : "● BLOCKED";
   color statusColor = allowedNow ? InpAllowedColor : InpBlockedColor;

   int statusWidth = StringLen(statusText) * 8;
   int statusX = InpX + InpWidth - statusWidth - 40;
   if(statusX < InpX + 10)
      statusX = InpX + 10;

   int maxSymbolWidth = statusX - (InpX + 10) - 10;
   int maxChars = maxSymbolWidth / 7;
   string prefix = "Symbol: ";
   int prefixLen = StringLen(prefix);
   int symLen = StringLen(currSym);

   string displaySym;
   if(prefixLen + symLen <= maxChars)
      displaySym = prefix + currSym;
   else
     {
      int availableForSym = maxChars - prefixLen - 3;
      if(availableForSym < 1)
         availableForSym = 1;
      string truncated = StringSubstr(currSym,0,availableForSym) + "...";
      displaySym = prefix + truncated;
     }

   ObjectSetInteger(0,PREFIX+"STATUS_SYM",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"STATUS_SYM",OBJPROP_YDISTANCE,InpY+110);
   ObjectSetString(0,PREFIX+"STATUS_SYM",OBJPROP_TEXT,displaySym);

   ObjectSetInteger(0,PREFIX+"STATUS_IND",OBJPROP_XDISTANCE,statusX);
   ObjectSetInteger(0,PREFIX+"STATUS_IND",OBJPROP_YDISTANCE,InpY+110);
   ObjectSetString(0,PREFIX+"STATUS_IND",OBJPROP_TEXT,statusText);
   ObjectSetInteger(0,PREFIX+"STATUS_IND",OBJPROP_COLOR,statusColor);

//--- Log entries with fixed‑width columns (monospaced font)
   string times[], symbols[], sources[];
   int logCount = SWL::ReadLog(times,symbols,sources,5);
   int logY = InpY + 165;
   for(int i=0; i<5; i++)
     {
      string name = PREFIX+"LOG_"+IntegerToString(i);
      if(i < logCount)
        {
         string timePart = StringSubstr(times[i],11,5);
         string symPart = symbols[i];
         string icon = (sources[i] == "manual" ? "👤" : "🤖");

         int symLen = StringLen(symPart);
         if(symLen < 30)
           {
            for(int j=symLen; j<30; j++)
               symPart += " ";
           }
         else
            if(symLen > 30)
               symPart = StringSubstr(symPart,0,30);

         string text = StringFormat("%s  %s  %s",timePart,symPart,icon);
         ObjectSetString(0,name,OBJPROP_TEXT,text);
         ObjectSetInteger(0,name,OBJPROP_XDISTANCE,InpX+10);
         ObjectSetInteger(0,name,OBJPROP_YDISTANCE,logY + i*16);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
        }
      else
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }

   ObjectSetString(0,PREFIX+"FOOTER",OBJPROP_TEXT,"ENFORCEMENT: ● ACTIVE");
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Deletes all objects with a given prefix                          |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
  {
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
     {
      string name = ObjectName(0,i);
      if(StringFind(name,prefix) == 0)
         ObjectDelete(0,name);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
