//+------------------------------------------------------------------+
//|                                               TrendMonitor_EA.mq5|
//|                                 Copyright 2026,Christian Benjamin|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input bool   AlertPopup         = true;        // Show popup alert on events
input bool   AlertSound         = true;        // Play sound on events
input string SoundFile          = "alert.wav"; // Sound file name (must be in Sounds folder)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input color  MonitorColor       = clrBlue;     // Colour for synced (monitored) lines
input int    LineWidth          = 2;           // Line thickness after syncing
input color  PendingColor       = clrGray;     // Colour for newly drawn line (waiting for Synch)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double TouchTolerancePips = 0.5;         // Tolerance for detecting a touch (in pips)
input double ApproachZonePips   = 10.0;        // Distance from line to trigger "approaching" alert (pips)

//--- Panel settings
input int    PanelX             = 10;          // Panel left position (pixels)
input int    PanelY             = 150;         // Panel top position (pixels)
input color  PanelBgColor       = clrWhite;    // Background colour of panel
input color  PanelHeaderColor   = clrLightGray;// Header background colour
input color  PanelTextColor     = clrBlack;    // Text colour in panel
input int    PanelPadding       = 4;           // Extra right padding (pixels) – left side is flush

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define PREFIX      "TrendTool_"                // Prefix for all EA objects (buttons)
#define PANEL_PREFIX "TrendTool_Panel_"         // Prefix for panel objects
#define HEADER_HEIGHT 20                         // Height of the panel header

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum EMode
  {
   MODE_IDLE,
   MODE_DRAWING,
   MODE_SYNC_READY
  };

enum EAlertState
  {
   ALERT_NONE,
   ALERT_APPROACH_SENT,
   ALERT_TOUCH_SENT,
   ALERT_BREAKOUT_SENT,
   ALERT_REVERSAL_SENT
  };

//+------------------------------------------------------------------+
//| Structure for monitored lines                                    |
//+------------------------------------------------------------------+
struct SMonitoredLine
  {
   string            name;               // Object name of the trendline
   int               lastSide;           // 1 = normal side, -1 = breakout side, 0 = unknown
   bool              alertedBreak;       // True if a breakout alert was already sent for this cross
   datetime          lastTouchBarTime;   // Time of the last bar checked for touches
   EAlertState       alertState;         // Current alert state for this line
  };

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
EMode          g_mode       = MODE_IDLE;
string         g_pendingLine = "";
SMonitoredLine g_monitored[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int            g_panelX, g_panelY;     // Current panel position (updated by dragging)
string         g_panelBGName = "";      // Name of the draggable background object

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

//--- Create control buttons
   CreateButton("DrawBtn",     "Draw",      10, 20, 100, 30, clrGreen, false);
   CreateButton("SynchBtn",    "Synch",     10, 60, 100, 30, clrGray,  false);
   CreateButton("ClearAllBtn", "Clear All", 10,100, 100, 30, clrGray,  false);

   ObjectSetInteger(0, PREFIX+"SynchBtn",    OBJPROP_STATE, false);
   ObjectSetInteger(0, PREFIX+"SynchBtn",    OBJPROP_BGCOLOR, clrGray);
   ObjectSetInteger(0, PREFIX+"ClearAllBtn", OBJPROP_STATE, false);
   ObjectSetInteger(0, PREFIX+"ClearAllBtn", OBJPROP_BGCOLOR, clrGray);

//--- Initialise panel position
   g_panelX = PanelX;
   g_panelY = PanelY;

   ChartRedraw();
   UpdatePanel();                // create panel (empty initially)
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, PREFIX+"DrawBtn");
   ObjectDelete(0, PREFIX+"SynchBtn");
   ObjectDelete(0, PREFIX+"ClearAllBtn");
   DeletePanelObjects();          // clean up panel
  }

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//--- Button clicks ------------------------------------------------
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      //--- Draw button
      if(sparam==PREFIX+"DrawBtn")
        {
         if(g_mode==MODE_IDLE)
           {
            g_mode=MODE_DRAWING;
            ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_STATE,true);
            ObjectSetString(0,PREFIX+"DrawBtn",OBJPROP_TEXT,"Draw (Active)");
            ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_STATE,false);
            ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGray);
            ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Synch");
           }
         else
            if(g_mode==MODE_DRAWING)
              {
               g_mode=MODE_IDLE;
               ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_STATE,false);
               ObjectSetString(0,PREFIX+"DrawBtn",OBJPROP_TEXT,"Draw");
              }
         ChartRedraw();
        }
      //--- Synch button
      else
         if(sparam==PREFIX+"SynchBtn")
           {
            if(g_mode==MODE_SYNC_READY && g_pendingLine!="")
              {
               //--- Add line to monitored list
               AddMonitoredLine(g_pendingLine);

               //--- Extend line to the right, change colour and make it bold
               ObjectSetInteger(0,g_pendingLine,OBJPROP_RAY_RIGHT,true);
               ObjectSetInteger(0,g_pendingLine,OBJPROP_COLOR,MonitorColor);
               ObjectSetInteger(0,g_pendingLine,OBJPROP_WIDTH,LineWidth);

               //--- Reset state
               g_mode=MODE_IDLE;
               g_pendingLine="";

               //--- Update buttons
               ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_STATE,false);
               ObjectSetString(0,PREFIX+"DrawBtn",OBJPROP_TEXT,"Draw");
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_STATE,false);
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGray);
               ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Synch");
               ChartRedraw();

               UpdateClearAllButtonState();
               UpdatePanel();
              }
           }
         //--- Clear All button
         else
            if(sparam==PREFIX+"ClearAllBtn")
              {
               ClearAllMonitoredLines();
              }
     }

//--- New object created -------------------------------------------
   else
      if(id==CHARTEVENT_OBJECT_CREATE)
        {
         if(g_mode==MODE_DRAWING)
           {
            if(ObjectGetInteger(0,sparam,OBJPROP_TYPE)==OBJ_TREND)
              {
               g_pendingLine=sparam;
               g_mode=MODE_SYNC_READY;
               ObjectSetInteger(0,sparam,OBJPROP_COLOR,PendingColor);
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_STATE,false);
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGreen);
               ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Synch Ready");
               ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_STATE,false);
               ObjectSetString(0,PREFIX+"DrawBtn",OBJPROP_TEXT,"Draw");
               ChartRedraw();
              }
           }
        }

      //--- Object deleted ------------------------------------------------
      else
         if(id==CHARTEVENT_OBJECT_DELETE)
           {
            string objName=sparam;
            //--- Remove from monitored list if present
            for(int i=0; i<ArraySize(g_monitored); i++)
              {
               if(g_monitored[i].name==objName)
                 {
                  //--- Shift remaining elements
                  for(int j=i; j<ArraySize(g_monitored)-1; j++)
                     g_monitored[j]=g_monitored[j+1];
                  ArrayResize(g_monitored,ArraySize(g_monitored)-1);
                  Print("Removed deleted line: ",objName);
                  UpdateClearAllButtonState();
                  UpdatePanel();
                  break;
                 }
              }
            //--- If it was the pending line, clear it
            if(g_pendingLine==objName)
              {
               g_pendingLine="";
               g_mode=MODE_IDLE;
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_STATE,false);
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGray);
               ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Synch");
               ChartRedraw();
              }
           }

         //--- Drag event for panel ------------------------------------------
         else
            if(id==CHARTEVENT_OBJECT_DRAG)
              {
               if(sparam==g_panelBGName)
                 {
                  //--- Get new position of the background rectangle
                  long newX=ObjectGetInteger(0,g_panelBGName,OBJPROP_XDISTANCE);
                  long newY=ObjectGetInteger(0,g_panelBGName,OBJPROP_YDISTANCE);
                  int deltaX=(int)newX-g_panelX;
                  int deltaY=(int)newY-g_panelY;
                  if(deltaX!=0 || deltaY!=0)
                    {
                     //--- Move all panel objects by the same delta
                     for(int i=ObjectsTotal(0)-1; i>=0; i--)
                       {
                        string objName=ObjectName(0,i);
                        if(StringFind(objName,PANEL_PREFIX)==0)
                          {
                           long objX=ObjectGetInteger(0,objName,OBJPROP_XDISTANCE);
                           long objY=ObjectGetInteger(0,objName,OBJPROP_YDISTANCE);
                           ObjectSetInteger(0,objName,OBJPROP_XDISTANCE,objX+deltaX);
                           ObjectSetInteger(0,objName,OBJPROP_YDISTANCE,objY+deltaY);
                          }
                       }
                     g_panelX=(int)newX;
                     g_panelY=(int)newY;
                     ChartRedraw();
                    }
                 }
              }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckPriceInteractions();
  }

//+------------------------------------------------------------------+
//| Main function: detect approaching, touch, breakout, reversal    |
//+------------------------------------------------------------------+
void CheckPriceInteractions()
  {
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double touchTol=TouchTolerancePips*10*point;
   double approachTol=ApproachZonePips*10*point;

   for(int i=0; i<ArraySize(g_monitored); i++)
     {
      string name=g_monitored[i].name;
      if(ObjectFind(0,name)<0)
         continue;              // line was deleted externally

      datetime currTime=TimeCurrent();
      double linePrice=ObjectGetValueByTime(0,name,currTime);
      if(linePrice==0)
         continue;

      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double p1=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
      double p2=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
      bool isAscending=(p2>p1);

      //--- Determine current side (normal = 1, breakout = -1)
      int currentSide=0;
      if(isAscending)
        {
         if(bid>linePrice)
            currentSide=1;            // above support (normal)
         else
            if(bid<linePrice)
               currentSide=-1;       // below support (breakout)
        }
      else
        {
         if(bid<linePrice)
            currentSide=1;            // below resistance (normal)
         else
            if(bid>linePrice)
               currentSide=-1;       // above resistance (breakout)
        }

      double distance=MathAbs(bid-linePrice);
      EAlertState oldState=g_monitored[i].alertState;

      //--- 1. Approach detection
      if(distance<=approachTol && g_monitored[i].alertState<ALERT_APPROACH_SENT)
        {
         SendNotification("Approaching "+name,linePrice);
         g_monitored[i].alertState=ALERT_APPROACH_SENT;
        }

      //--- 2. Touch detection (new bar)
      datetime currBarTime=iTime(NULL,0,0);
      if(g_monitored[i].lastTouchBarTime<currBarTime)
        {
         double barHigh=iHigh(NULL,0,0);
         double barLow=iLow(NULL,0,0);
         //--- Check if linePrice is within bar range (with tolerance)
         if(linePrice>=barLow-touchTol && linePrice<=barHigh+touchTol)
           {
            //--- This is a touch on the new bar
            if(g_monitored[i].alertState<ALERT_TOUCH_SENT)
              {
               SendNotification("Touch on "+name,linePrice);
               g_monitored[i].alertState=ALERT_TOUCH_SENT;
              }
           }
         g_monitored[i].lastTouchBarTime=currBarTime;
        }

      //--- 3. Breakout detection
      int lastSide=g_monitored[i].lastSide;
      if(lastSide!=0 && currentSide!=0 && currentSide!=lastSide)
        {
         //--- Price crossed the line
         if(!g_monitored[i].alertedBreak)
           {
            SendNotification("Breakout on "+name,linePrice);
            g_monitored[i].alertedBreak=true;
            g_monitored[i].alertState=ALERT_BREAKOUT_SENT;
           }
        }

      //--- 4. Reversal detection
      //--- Reversal = after a touch, price moves back to normal side (1) without having crossed to breakout?
      //--- Simplified: if we were in breakout side (-1) and now back to normal (1) without a new breakout alert,
      //--- and we had previously sent a touch alert, consider it a reversal.
      if(g_monitored[i].alertState==ALERT_TOUCH_SENT && lastSide==-1 && currentSide==1)
        {
         SendNotification("Reversal on "+name,linePrice);
         g_monitored[i].alertState=ALERT_REVERSAL_SENT;
        }

      //--- Reset alertState when price moves away from line (outside approach zone) and we are not in a touch state
      if(distance>approachTol && g_monitored[i].alertState!=ALERT_TOUCH_SENT && g_monitored[i].alertState!=ALERT_NONE)
        {
         g_monitored[i].alertState=ALERT_NONE;
        }

      //--- Store last side for next tick
      g_monitored[i].lastSide=currentSide;

      //--- If alert state changed, update panel
      if(oldState!=g_monitored[i].alertState)
         UpdatePanel();
     }
  }

//+------------------------------------------------------------------+
//| Helper to send popup + sound notifications                      |
//+------------------------------------------------------------------+
void SendNotification(string msg,double price)
  {
   string fullMsg=StringFormat("%s at %G",msg,price);
   if(AlertPopup)
      Alert(fullMsg);
   if(AlertSound)
      PlaySound(SoundFile);
   Print(fullMsg);
  }

//+------------------------------------------------------------------+
//| Add line to monitored list                                      |
//+------------------------------------------------------------------+
void AddMonitoredLine(string lineName)
  {
   int sz=ArraySize(g_monitored);
   ArrayResize(g_monitored,sz+1);
   g_monitored[sz].name            =lineName;
   g_monitored[sz].lastSide        =0;
   g_monitored[sz].alertedBreak    =false;
   g_monitored[sz].lastTouchBarTime =0;
   g_monitored[sz].alertState      =ALERT_NONE;
   Print("Now monitoring: ",lineName);
  }

//+------------------------------------------------------------------+
//| Clear all monitored lines (revert properties and remove from list)|
//+------------------------------------------------------------------+
void ClearAllMonitoredLines()
  {
   for(int i=ArraySize(g_monitored)-1; i>=0; i--)
     {
      string name=g_monitored[i].name;
      if(ObjectFind(0,name)>=0)
        {
         //--- Revert line properties to pending state
         ObjectSetInteger(0,name,OBJPROP_COLOR,PendingColor);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,1);          // default width
         ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
        }
     }
   ArrayResize(g_monitored,0);
   UpdateClearAllButtonState();
   UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Enable/disable Clear All button based on monitored list size    |
//+------------------------------------------------------------------+
void UpdateClearAllButtonState()
  {
   bool hasLines=(ArraySize(g_monitored)>0);
   color bgColor=hasLines ? clrOrange : clrGray;
   ObjectSetInteger(0,PREFIX+"ClearAllBtn",OBJPROP_BGCOLOR,bgColor);
  }

//+------------------------------------------------------------------+
//| Delete all panel objects                                         |
//+------------------------------------------------------------------+
void DeletePanelObjects()
  {
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
     {
      string objName=ObjectName(0,i);
      if(StringFind(objName,PANEL_PREFIX)==0)
         ObjectDelete(0,objName);
     }
   g_panelBGName="";
  }

//+------------------------------------------------------------------+
//| Convert alert state to readable string                          |
//+------------------------------------------------------------------+
string AlertStateToString(EAlertState state)
  {
   switch(state)
     {
      case ALERT_NONE:
         return("None");
      case ALERT_APPROACH_SENT:
         return("Approach");
      case ALERT_TOUCH_SENT:
         return("Touch");
      case ALERT_BREAKOUT_SENT:
         return("Breakout");
      case ALERT_REVERSAL_SENT:
         return("Reversal");
      default:
         return("Unknown");
     }
  }

//+------------------------------------------------------------------+
//| Measure the pixel width of a text string for the given font size|
//+------------------------------------------------------------------+
int MeasureTextWidth(string text,int fontSize,string fontName="Arial")
  {
   uint w=0,h=0;
//--- Set the font and size for text measurement
   if(!TextSetFont(fontName,-fontSize,0,0))
     {
      //--- Fallback: approximate width by character count * font size * 0.6
      return(StringLen(text)*fontSize*3/5);
     }
   if(!TextGetSize(text,w,h))
     {
      return(StringLen(text)*fontSize*3/5);
     }
   return((int)w);
  }

//+------------------------------------------------------------------+
//| Update the status panel – text flush left, width fits content   |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   DeletePanelObjects();

   int total=ArraySize(g_monitored);
   int x=g_panelX;
   int y=g_panelY;
   int lineHeight=18;
   int fontSize=10;
   string fontName="Arial";

//--- Compute maximum text width among all lines + header
   int maxWidth=0;
//--- Header text
   int headerWidth=MeasureTextWidth("Monitored Lines",fontSize,fontName);
   if(headerWidth>maxWidth)
      maxWidth=headerWidth;

//--- Each line: "LineName: State"
   for(int i=0; i<total; i++)
     {
      string text=StringFormat("%s: %s",g_monitored[i].name,AlertStateToString(g_monitored[i].alertState));
      int w=MeasureTextWidth(text,fontSize,fontName);
      if(w>maxWidth)
         maxWidth=w;
     }

//--- Panel width = text width + right padding only (left side flush)
   int panelWidth=maxWidth+PanelPadding;

//--- Total height = header + lines + a little padding
   int totalHeight=HEADER_HEIGHT+lineHeight*total+4;

//--- 1. Background rectangle (draggable)
   string bgName=PANEL_PREFIX+"BG";
   ObjectCreate(0,bgName,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bgName,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,bgName,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,bgName,OBJPROP_XSIZE,panelWidth);
   ObjectSetInteger(0,bgName,OBJPROP_YSIZE,totalHeight);
   ObjectSetInteger(0,bgName,OBJPROP_BGCOLOR,PanelBgColor);
   ObjectSetInteger(0,bgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bgName,OBJPROP_BACK,true);
   ObjectSetInteger(0,bgName,OBJPROP_SELECTABLE,true);   // make it draggable
   ObjectSetInteger(0,bgName,OBJPROP_HIDDEN,false);
   g_panelBGName=bgName;

//--- 2. Header background (optional, for visual separation)
   string headerBgName=PANEL_PREFIX+"Header";
   ObjectCreate(0,headerBgName,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,headerBgName,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,headerBgName,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,headerBgName,OBJPROP_XSIZE,panelWidth);
   ObjectSetInteger(0,headerBgName,OBJPROP_YSIZE,HEADER_HEIGHT);
   ObjectSetInteger(0,headerBgName,OBJPROP_BGCOLOR,PanelHeaderColor);
   ObjectSetInteger(0,headerBgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,headerBgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,headerBgName,OBJPROP_BACK,true);
   ObjectSetInteger(0,headerBgName,OBJPROP_SELECTABLE,false); // not draggable
   ObjectSetInteger(0,headerBgName,OBJPROP_HIDDEN,false);

//--- 3. Header text (flush left)
   string headerTextName=PANEL_PREFIX+"HeaderText";
   ObjectCreate(0,headerTextName,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,headerTextName,OBJPROP_XDISTANCE,x);          // left edge
   ObjectSetInteger(0,headerTextName,OBJPROP_YDISTANCE,y+2);
   ObjectSetString(0,headerTextName,OBJPROP_TEXT,"Monitored Lines");
   ObjectSetInteger(0,headerTextName,OBJPROP_COLOR,PanelTextColor);
   ObjectSetInteger(0,headerTextName,OBJPROP_FONTSIZE,fontSize);
   ObjectSetString(0,headerTextName,OBJPROP_FONT,fontName);
   ObjectSetInteger(0,headerTextName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,headerTextName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,headerTextName,OBJPROP_HIDDEN,false);

//--- 4. Line labels (all flush left)
   for(int i=0; i<total; i++)
     {
      string lineName=g_monitored[i].name;
      string stateStr=AlertStateToString(g_monitored[i].alertState);
      string text=StringFormat("%s: %s",lineName,stateStr);
      string objTextName=PANEL_PREFIX+"Line_"+IntegerToString(i);

      ObjectCreate(0,objTextName,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,objTextName,OBJPROP_XDISTANCE,x);          // left edge
      ObjectSetInteger(0,objTextName,OBJPROP_YDISTANCE,y+HEADER_HEIGHT+2+i*lineHeight);
      ObjectSetString(0,objTextName,OBJPROP_TEXT,text);
      ObjectSetInteger(0,objTextName,OBJPROP_COLOR,PanelTextColor);
      ObjectSetInteger(0,objTextName,OBJPROP_FONTSIZE,fontSize);
      ObjectSetString(0,objTextName,OBJPROP_FONT,fontName);
      ObjectSetInteger(0,objTextName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,objTextName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,objTextName,OBJPROP_HIDDEN,false);
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Create a labelled button                                         |
//+------------------------------------------------------------------+
void CreateButton(string btnName,string text,int x,int y,int w,int h,color bgColor,bool state)
  {
   string objName=PREFIX+btnName;
   ObjectCreate(0,objName,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,objName,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,objName,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,objName,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,objName,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,objName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,objName,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,objName,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,objName,OBJPROP_BGCOLOR,bgColor);
   ObjectSetInteger(0,objName,OBJPROP_BORDER_COLOR,clrBlack);
   ObjectSetInteger(0,objName,OBJPROP_STATE,state);
   ObjectSetString(0,objName,OBJPROP_TEXT,text);
   ObjectSetInteger(0,objName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,objName,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,objName,OBJPROP_ZORDER,0);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
