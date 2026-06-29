//+------------------------------------------------------------------+
//|                                    TradingHoursNewsDashboard.mq5 |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <TradingDiscipline/TradingHoursNews.mqh>

//--- input parameters
input string InpAllowedSessions = "08:00-12:00,14:00-18:00"; // Allowed trading sessions
input int    InpX               = 20;                       // Panel X offset
input int    InpY               = 20;                       // Panel Y offset
input int    InpWidth           = 400;                      // Panel width
input int    InpHeight          = 350;                      // Panel height

//--- colors
input color InpShadowColor  = C'80,80,80';   // Drop shadow
input color InpBgColor      = C'250,250,250';// Main background
input color InpBorderColor  = C'200,200,200';// Light border
input color InpTextColor    = C'50,50,50';   // Dark text
input color InpAllowedColor = clrForestGreen;
input color InpBlockedColor = clrCrimson;
input color InpProgressBg   = C'220,220,220';
input color InpProgressFill = clrDodgerBlue;

string PREFIX = "THN_";

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   THN::SaveSessions(InpAllowedSessions);
   CreatePanel();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteObjectsByPrefix(PREFIX);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDashboard();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CreatePanel                                                      |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   DeleteObjectsByPrefix(PREFIX);

//--- Drop shadow
   ObjectCreate(0,PREFIX+"SHADOW",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"SHADOW",OBJPROP_XDISTANCE,InpX+3);
   ObjectSetInteger(0,PREFIX+"SHADOW",OBJPROP_YDISTANCE,InpY+3);
   ObjectSetInteger(0,PREFIX+"SHADOW",OBJPROP_XSIZE,InpWidth);
   ObjectSetInteger(0,PREFIX+"SHADOW",OBJPROP_YSIZE,InpHeight);
   ObjectSetInteger(0,PREFIX+"SHADOW",OBJPROP_BGCOLOR,InpShadowColor);
   ObjectSetInteger(0,PREFIX+"SHADOW",OBJPROP_BACK,true);

//--- Main panel
   ObjectCreate(0,PREFIX+"BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_XDISTANCE,InpX);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_YDISTANCE,InpY);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_XSIZE,InpWidth);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_YSIZE,InpHeight);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BGCOLOR,InpBgColor);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_COLOR,InpBorderColor);
   ObjectSetInteger(0,PREFIX+"BG",OBJPROP_BACK,false);

//--- Header (no emoji)
   ObjectCreate(0,PREFIX+"HEADER",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_XDISTANCE,InpX+15);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_YDISTANCE,InpY+10);
   ObjectSetString(0,PREFIX+"HEADER",OBJPROP_TEXT,"Trading Hours & News Protection");
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,PREFIX+"HEADER",OBJPROP_FONTSIZE,14);
   ObjectSetString(0,PREFIX+"HEADER",OBJPROP_FONT,"Segoe UI");

//--- Separator
   ObjectCreate(0,PREFIX+"SEP1",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_XDISTANCE,InpX+10);
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_YDISTANCE,InpY+35);
   ObjectSetString(0,PREFIX+"SEP1",OBJPROP_TEXT,"────────────────────");
   ObjectSetInteger(0,PREFIX+"SEP1",OBJPROP_COLOR,InpBorderColor);

//--- Dynamic labels (8 lines)
   for(int i=0; i<8; i++)
     {
      string name = PREFIX+"LINE_"+IntegerToString(i);
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpTextColor);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
      ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI");
     }

//--- Progress bar
   ObjectCreate(0,PREFIX+"PROGRESS_BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"PROGRESS_BG",OBJPROP_BGCOLOR,InpProgressBg);
   ObjectCreate(0,PREFIX+"PROGRESS_FILL",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"PROGRESS_FILL",OBJPROP_BGCOLOR,InpProgressFill);

//--- Footer (no emoji)
   ObjectCreate(0,PREFIX+"FOOTER",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,PREFIX+"FOOTER",OBJPROP_FONTSIZE,11);
   ObjectSetString(0,PREFIX+"FOOTER",OBJPROP_FONT,"Segoe UI");

   UpdateDashboard();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| UpdateDashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   THN::Refresh();
   bool   allowed    = THN::IsAllowedNow();
   string nextSession= THN::GetNextSession();
   string nextNews   = THN::GetNextNews();

   color  statusColor = allowed ? InpAllowedColor : InpBlockedColor;
   string statusText  = allowed ? "ALLOWED" : "BLOCKED";

   int y = InpY + 50;

   SetText(PREFIX+"LINE_0", InpX+15, y,     "Status: " + statusText, statusColor);
   SetText(PREFIX+"LINE_1", InpX+15, y+25,  "Sessions: " + InpAllowedSessions);
   SetText(PREFIX+"LINE_2", InpX+15, y+45,  "Next session: " + (nextSession != "" ? nextSession : "none"));
   SetText(PREFIX+"LINE_3", InpX+15, y+65,  "Next news: " + nextNews);

//--- Progress bar
   if(nextSession != "")
     {
      MqlDateTime now;
      TimeToStruct(TimeCurrent(),now);
      int currentMin = now.hour*60 + now.min;

      string parts[];
      StringSplit(nextSession,':',parts);
      int targetHour = (int)StringToInteger(parts[0]);
      int targetMin  = (int)StringToInteger(parts[1]);
      int targetTime = targetHour*60 + targetMin;

      int diff = (targetTime > currentMin) ? targetTime-currentMin : (24*60-currentMin)+targetTime;

      int maxWait     = 720;
      double percent  = 1.0 - ((double)diff / maxWait);
      if(percent < 0)
         percent = 0;
      if(percent > 1)
         percent = 1;

      int barX = InpX+15;
      int barY = InpY+135;
      int barWidth = 200;
      int barHeight= 12;

      ObjectSetInteger(0,PREFIX+"PROGRESS_BG",  OBJPROP_XDISTANCE,barX);
      ObjectSetInteger(0,PREFIX+"PROGRESS_BG",  OBJPROP_YDISTANCE,barY);
      ObjectSetInteger(0,PREFIX+"PROGRESS_BG",  OBJPROP_XSIZE,barWidth);
      ObjectSetInteger(0,PREFIX+"PROGRESS_BG",  OBJPROP_YSIZE,barHeight);

      ObjectSetInteger(0,PREFIX+"PROGRESS_FILL",OBJPROP_XDISTANCE,barX);
      ObjectSetInteger(0,PREFIX+"PROGRESS_FILL",OBJPROP_YDISTANCE,barY);
      ObjectSetInteger(0,PREFIX+"PROGRESS_FILL",OBJPROP_XSIZE,(int)(barWidth*percent));
      ObjectSetInteger(0,PREFIX+"PROGRESS_FILL",OBJPROP_YSIZE,barHeight);
     }
   else
     {
      ObjectSetInteger(0,PREFIX+"PROGRESS_BG",  OBJPROP_XSIZE,0);
      ObjectSetInteger(0,PREFIX+"PROGRESS_FILL",OBJPROP_XSIZE,0);
     }

//--- Recent logs (no emojis)
   string times[],symbols[],reasons[],sources[];
   int logCount = THN::ReadLog(times,symbols,reasons,sources,5);

   int logY = InpY + 165;
   for(int i=0; i<5; i++)
     {
      string name = PREFIX+"LINE_" + IntegerToString(6+i);
      if(i < logCount)
        {
         string timePart = StringSubstr(times[i],11,5);
         string sourceText = (sources[i] == "manual" ? "MANUAL" : "EA");
         string text = StringFormat("%s %s %s %s", timePart, symbols[i], reasons[i], sourceText);
         SetText(name, InpX+15, logY+i*20, text, InpTextColor);
        }
      else
         SetText(name, InpX+15, logY+i*20, "", InpTextColor);
     }

//--- Footer
   ObjectSetString(0, PREFIX+"FOOTER", OBJPROP_TEXT, "ENFORCEMENT ACTIVE");
   ObjectSetInteger(0, PREFIX+"FOOTER", OBJPROP_XDISTANCE, InpX+15);
   ObjectSetInteger(0, PREFIX+"FOOTER", OBJPROP_YDISTANCE, InpY+InpHeight-25);
   ObjectSetInteger(0, PREFIX+"FOOTER", OBJPROP_COLOR, InpAllowedColor);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SetText                                                          |
//+------------------------------------------------------------------+
void SetText(string name,int x,int y,string text,color clr=clrBlack)
  {
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DeleteObjectsByPrefix                                            |
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
