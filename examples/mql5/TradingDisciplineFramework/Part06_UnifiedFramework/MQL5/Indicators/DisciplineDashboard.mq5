//+------------------------------------------------------------------+
//|                                        DisciplineDashboard.mq5   |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property indicator_chart_window
#property indicator_plots 0

#include <DisciplineFramework/CDisciplineEngine.mqh>

//--- input parameters
input int      RefreshSeconds    = 2;
input color    PanelBackColor    = C'25,30,45';
input color    PanelBorderColor  = C'80,90,110';
input color    TextMainColor     = clrWhite;
input color    TextLabelColor    = C'160,170,190';
input color    AllowedColor      = C'50,205,50';
input color    BlockedColor      = C'255,70,70';
input color    CautionColor      = C'255,180,50';
input int      PanelX            = 20;
input int      PanelY            = 40;
input int      PanelWidth        = 340;

CDisciplineEngine g_engine;
string            g_prefix = "DisciplinePanel_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!g_engine.Init())
     {
      Print("Dashboard: Engine init failed.");
      return INIT_FAILED;
     }
   EventSetTimer(RefreshSeconds);
   CreatePanel();
   UpdateDashboard();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, g_prefix) == 0)
         ObjectDelete(0, name);
     }
   Comment("");
  }

//+------------------------------------------------------------------+
//| Create static panel elements                                     |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   string prefix = g_prefix;
   int yOff = PanelY;
   int rowH = 24;
   int y = yOff + 32;

//--- background (taller to fit news)
   ObjectCreate(0, prefix+"Bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_YDISTANCE, yOff);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_XSIZE, PanelWidth);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_YSIZE, 230);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_BGCOLOR, PanelBackColor);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_BORDER_COLOR, PanelBorderColor);
   ObjectSetInteger(0, prefix+"Bg", OBJPROP_WIDTH, 2);

//--- title bar
   ObjectCreate(0, prefix+"TitleBar", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"TitleBar", OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, prefix+"TitleBar", OBJPROP_YDISTANCE, yOff);
   ObjectSetInteger(0, prefix+"TitleBar", OBJPROP_XSIZE, PanelWidth);
   ObjectSetInteger(0, prefix+"TitleBar", OBJPROP_YSIZE, 28);
   ObjectSetInteger(0, prefix+"TitleBar", OBJPROP_BGCOLOR, C'45,55,75');

//--- title text
   ObjectCreate(0, prefix+"TitleText", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"TitleText", OBJPROP_XDISTANCE, PanelX+10);
   ObjectSetInteger(0, prefix+"TitleText", OBJPROP_YDISTANCE, yOff+6);
   ObjectSetInteger(0, prefix+"TitleText", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, prefix+"TitleText", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, prefix+"TitleText", OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, prefix+"TitleText", OBJPROP_TEXT, "TRADING GATE");

//--- labels
   CreateLabel(prefix+"LblSymbol",    PanelX+10, y,    "Symbol:", TextLabelColor, 9);
   CreateLabel(prefix+"LblTime",      PanelX+180, y,   "Time:", TextLabelColor, 9);
   CreateLabel(prefix+"LblWhitelist", PanelX+10, y+rowH*1, "Whitelist:", TextLabelColor, 9);
   CreateLabel(prefix+"LblHours",     PanelX+10, y+rowH*2, "Trading Hours:", TextLabelColor, 9);
   CreateLabel(prefix+"LblDaily",     PanelX+10, y+rowH*3, "Daily Limit:", TextLabelColor, 9);
   CreateLabel(prefix+"LblNextSess",  PanelX+10, y+rowH*4, "Next Session:", TextLabelColor, 9);
   CreateLabel(prefix+"LblNextNews",  PanelX+10, y+rowH*5, "Next News:", TextLabelColor, 9);

//--- value fields
   CreateLabel(prefix+"SymbolVal",    PanelX+70,  y,    "", TextMainColor, 9);
   CreateLabel(prefix+"TimeVal",      PanelX+220, y,    "", TextMainColor, 9);
   CreateLabel(prefix+"WhitelistVal", PanelX+100, y+rowH*1, "", TextMainColor, 9);
   CreateLabel(prefix+"HoursVal",     PanelX+120, y+rowH*2, "", TextMainColor, 9);
   CreateLabel(prefix+"DailyVal",     PanelX+100, y+rowH*3, "", TextMainColor, 9);
   CreateLabel(prefix+"NextSessVal",  PanelX+100, y+rowH*4, "", TextMainColor, 9);
   CreateLabel(prefix+"NextNewsVal",  PanelX+100, y+rowH*5, "", TextMainColor, 9);

//--- overall status bar
   int overallY = yOff + 32 + rowH*6 + 10;
   ObjectCreate(0, prefix+"OverallBg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"OverallBg", OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, prefix+"OverallBg", OBJPROP_YDISTANCE, overallY);
   ObjectSetInteger(0, prefix+"OverallBg", OBJPROP_XSIZE, PanelWidth);
   ObjectSetInteger(0, prefix+"OverallBg", OBJPROP_YSIZE, 38);
   ObjectSetInteger(0, prefix+"OverallBg", OBJPROP_BGCOLOR, C'45,55,75');

   ObjectCreate(0, prefix+"OverallText", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"OverallText", OBJPROP_XDISTANCE, PanelX+PanelWidth/2-60);
   ObjectSetInteger(0, prefix+"OverallText", OBJPROP_YDISTANCE, overallY+10);
   ObjectSetInteger(0, prefix+"OverallText", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, prefix+"OverallText", OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, prefix+"OverallText", OBJPROP_TEXT, "TRADING BLOCKED");
   ObjectSetInteger(0, prefix+"OverallText", OBJPROP_COLOR, BlockedColor);
  }

//+------------------------------------------------------------------+
//| CreateLabel                                                                 |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string txt, color clr, int size)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
  }

//+------------------------------------------------------------------+
//| Update dashboard values                                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   if(!g_engine.IsInitialized())
      return;

   string symbol = Symbol();
   datetime now = TimeCurrent();

   bool symAllowed = g_engine.IsSymbolAllowed(symbol);
   bool hoursAllowed = g_engine.IsTradingHoursAllowed();
   int trades = g_engine.GetTradesToday();
   int limit = g_engine.GetDailyLimit();
   bool dailyAllowed = (trades < limit);
   string nextSession = g_engine.GetNextSession();
   string nextNews = g_engine.GetNextNews();
   if(nextNews == "")
      nextNews = "None";

//--- update text
   ObjectSetString(0, g_prefix+"SymbolVal", OBJPROP_TEXT, symbol);
   ObjectSetString(0, g_prefix+"TimeVal", OBJPROP_TEXT, TimeToString(now, TIME_MINUTES));

   ObjectSetString(0, g_prefix+"WhitelistVal", OBJPROP_TEXT, symAllowed ? "ALLOWED" : "BLOCKED");
   ObjectSetInteger(0, g_prefix+"WhitelistVal", OBJPROP_COLOR, symAllowed ? AllowedColor : BlockedColor);

   ObjectSetString(0, g_prefix+"HoursVal", OBJPROP_TEXT, hoursAllowed ? "OPEN" : "BLOCKED");
   ObjectSetInteger(0, g_prefix+"HoursVal", OBJPROP_COLOR, hoursAllowed ? AllowedColor : BlockedColor);

   string dailyText = StringFormat("%d/%d", trades, limit);
   color dailyColor = dailyAllowed ? ((limit - trades) <= g_engine.GetAmberZone() ? CautionColor : AllowedColor) : BlockedColor;
   ObjectSetString(0, g_prefix+"DailyVal", OBJPROP_TEXT, dailyText);
   ObjectSetInteger(0, g_prefix+"DailyVal", OBJPROP_COLOR, dailyColor);

   ObjectSetString(0, g_prefix+"NextSessVal", OBJPROP_TEXT, (nextSession!="" ? nextSession : "None"));
   ObjectSetString(0, g_prefix+"NextNewsVal", OBJPROP_TEXT, nextNews);

//--- overall status
   bool overallAllowed = symAllowed && hoursAllowed && dailyAllowed;
   string overallText = overallAllowed ? "TRADING ALLOWED" : "TRADING BLOCKED";
   color overallColor = overallAllowed ? AllowedColor : BlockedColor;
   ObjectSetString(0, g_prefix+"OverallText", OBJPROP_TEXT, overallText);
   ObjectSetInteger(0, g_prefix+"OverallText", OBJPROP_COLOR, overallColor);
   ObjectSetInteger(0, g_prefix+"OverallBg", OBJPROP_BGCOLOR, overallAllowed ? C'30,70,30' : C'70,30,30');
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDashboard();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| OnCalculate - minimal                                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   return(rates_total);
  }
//+------------------------------------------------------------------+
