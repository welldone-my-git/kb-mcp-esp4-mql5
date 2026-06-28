//+------------------------------------------------------------------+
//|                                            EquityCurvePanel.mqh  |
//| CEquityCurvePanel: renders a cumulative equity curve from        |
//| ITradeRepository data using CCanvas. Operates independently      |
//| of terminal history; works with live or mock repositories.       |
//+------------------------------------------------------------------+
#ifndef EQUITYCURVEPANEL_MQH
#define EQUITYCURVEPANEL_MQH

#include "ITradeRepository.mqh"
#include <Canvas\Canvas.mqh>

//+-------------------------------------------------------------------+
//| CEquityCurvePanel                                                 |
//| Purpose: Handles canvas-drawn dashboard elements to present a     |
//|          continuous visual representation of quantitative metrics |
//+-------------------------------------------------------------------+
class CEquityCurvePanel
  {
private:
   CCanvas           m_canvas;         // Dynamic object canvas resource instance
   string            m_obj_name;       // Graphical object terminal mapping key string
   int               m_chart_id;       // Target working chart ID identification number
   int               m_x;              // Panel window horizontal anchor coordinate location
   int               m_y;              // Panel window vertical anchor coordinate location
   int               m_width;          // Total panel bounding frame width size in pixels
   int               m_height;         // Total panel bounding frame height size in pixels
   bool              m_initialized;    // Visual container operational lifecyle state flag

   color             m_bg_color;       // Custom panel background interface fill color
   color             m_curve_color;    // Custom vector array line connection color
   color             m_grid_color;     // Custom chart boundary division coordinate color
   color             m_text_color;     // Custom metadata labels terminal color string
   color             m_zero_color;     // Custom baseline breakdown zero matrix line color

   //--- DrawGrid draws background, title bar band, grid lines, and
   //--- zero line. It does NOT write the title text because repo is
   //--- not in scope here. Title text is written in Render() after
   //--- DrawCurve() returns, where repo is a named parameter.
   void              DrawGrid(double min_val, double max_val);
   void              DrawCurve(double &equity[], int count);
   void              DrawLabels(ITradeRepository *repo);

public:
   //--- Lifecycle Management
                     CEquityCurvePanel(int chart_id, int x, int y, int width, int height);
                    ~CEquityCurvePanel(void);

   //--- State Configurations
   bool              Create(void);
   void              Render(ITradeRepository *repo);
   void              Remove(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Injects anchoring constraints and sets thematic colors  |
//+------------------------------------------------------------------+
CEquityCurvePanel::CEquityCurvePanel(int chart_id, int x, int y, int width, int height)
   : m_chart_id(chart_id),
     m_x(x),
     m_y(y),
     m_width(width),
     m_height(height),
     m_initialized(false),
     m_obj_name("REPO_EQUITY_CANVAS"),
     m_bg_color(C'245,247,250'),    // soft off-white, matches MT5 chart background
     m_curve_color(C'30,100,200'),  // clean blue, readable on light background
     m_grid_color(C'210,215,220'),  // light grey grid lines
     m_text_color(C'40,44,52'),     // dark charcoal text
     m_zero_color(C'150,155,165')   // muted mid-grey for zero line
  {
  }

//+-------------------------------------------------------------------+
//| Destructor                                                        |
//| Purpose: Cleans graphical container references on context release |
//+-------------------------------------------------------------------+
CEquityCurvePanel::~CEquityCurvePanel(void)
  {
   Remove();
  }

//+------------------------------------------------------------------+
//| Create                                                           |
//| Purpose: Allocates and formats background memory bitmap surfaces |
//+------------------------------------------------------------------+
bool CEquityCurvePanel::Create(void)
  {
   if(!m_canvas.CreateBitmapLabel(m_chart_id, 0, m_obj_name,
                                  m_x, m_y, m_width, m_height,
                                  COLOR_FORMAT_ARGB_NORMALIZE))
     {
      Print("[CEquityCurvePanel] Failed to create canvas bitmap label.");
      return(false);
     }

   m_initialized = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| DrawGrid                                                         |
//| Purpose: Draws background fill, title bar band, grid lines, and  |
//|          zero line. Title text is NOT written here because repo  |
//|          is not in scope. Render() writes the title after        |
//|          DrawCurve() returns, where repo is a named parameter.   |
//+------------------------------------------------------------------+
void CEquityCurvePanel::DrawGrid(double min_val, double max_val)
  {
//--- Full canvas background fill
   m_canvas.Erase(ColorToARGB(m_bg_color, 255));

//--- Title bar background band only; title text written in Render()
   m_canvas.FillRectangle(0, 0, m_width, 22, ColorToARGB(C'220,225,232', 255));

//--- Map horizontal reference dividers sequentially (4 regions)
   for(int i = 1; i <= 4; i++)
     {
      int y_pos = 22 + (int)((m_height - 44) * i / 4.0);
      m_canvas.Line(40, y_pos, m_width - 8, y_pos,
                    ColorToARGB(m_grid_color, 255));

      //--- Skip the label on the lowest grid line to prevent collision
      //    with the stat label row drawn by DrawLabels()
      if(i < 4)
        {
         double grid_val = max_val - (max_val - min_val) * i / 4.0;
         m_canvas.TextOut(2, y_pos - 8, DoubleToString(grid_val, 0),
                          ColorToARGB(m_text_color, 200));
        }
     }

//--- Evaluate and overlay safe structural zero baseline break axes
   if(min_val < 0.0 && max_val > 0.0)
     {
      double range  = max_val - min_val;
      int    y_zero = 22 + (int)((m_height - 44) * (max_val / range));
      m_canvas.Line(40, y_zero, m_width - 8, y_zero,
                    ColorToARGB(m_zero_color, 255));
     }
  }

//+-----------------------------------------------------------------------+
//| DrawCurve                                                             |
//| Purpose: Parses raw data points and projects spatial graph line paths |
//+-----------------------------------------------------------------------+
void CEquityCurvePanel::DrawCurve(double &equity[], int count)
  {
   if(count < 2)
     {
      return;
     }

   double min_val = equity[0];
   double max_val = equity[0];

//--- Extract high and low scaling targets to prevent clipping
   for(int i = 1; i < count; i++)
     {
      if(equity[i] < min_val)
        {
         min_val = equity[i];
        }
      if(equity[i] > max_val)
        {
         max_val = equity[i];
        }
     }

   double range = max_val - min_val;
   if(range == 0.0)
     {
      range = 1.0;
     }

//--- Define strict coordinate margins inside canvas layouts.
//--- plot_y1 uses m_height - 36 (increased from -22) to give
//--- the bottom label row 36 pixels and prevent it overlapping
//--- the curve line.
   int plot_x0 = 40;
   int plot_x1 = m_width - 8;
   int plot_y0 = 22;
   int plot_y1 = m_height - 46;
   int plot_w  = plot_x1 - plot_x0;
   int plot_h  = plot_y1 - plot_y0;

   DrawGrid(min_val, max_val);

   int prev_px = plot_x0;
   int prev_py = plot_y1 - (int)((equity[0] - min_val) / range * plot_h);

//--- Draw the calculated vector coordinate arrays step-by-step
   for(int i = 1; i < count; i++)
     {
      int px = plot_x0 + (int)((double)i / (count - 1) * plot_w);
      int py = plot_y1 - (int)((equity[i] - min_val) / range * plot_h);

      m_canvas.Line(prev_px, prev_py, px, py, ColorToARGB(m_curve_color, 255));
      prev_px = px;
      prev_py = py;
     }
  }

//+----------------------------------------------------------------------+
//| DrawLabels                                                           |
//| Purpose: Prints core summary matrix indicators inside bottom margins |
//+----------------------------------------------------------------------+
void CEquityCurvePanel::DrawLabels(ITradeRepository *repo)
  {
   string label = "Win Rate: " + DoubleToString(repo.GetWinRate(), 2) + "%" +
                  "  |  Avg Trade: " + DoubleToString(repo.GetAverageTrade(), 2) +
                  "  |  Max DD: -" + DoubleToString(repo.GetMaxDrawdown(), 2);

   m_canvas.TextOut(8, m_height - 22, label, ColorToARGB(m_text_color, 200));
  }

//+------------------------------------------------------------------------+
//| Render                                                                 |
//| Purpose: Updates internal buffers and prompts real-time redraw updates |
//+------------------------------------------------------------------------+
void CEquityCurvePanel::Render(ITradeRepository *repo)
  {
   if(!m_initialized || repo == NULL)
     {
      return;
     }

   int count = repo.GetTradeCount();
   if(count == 0)
     {
      return;
     }

   double equity[];
   ArrayResize(equity, count);

//--- Parse total net returns over individual asset classes
   double running = 0.0;
   for(int i = 0; i < count; i++)
     {
      STradeRecord rec = repo.GetClosedTrade(i);
      running      += rec.profit + rec.commission + rec.swap;
      equity[i]     = running;
     }

//--- DrawCurve calls DrawGrid internally which draws the title bar
//--- background band. After DrawCurve returns, repo is in scope so
//    the title text can be written on top of the band correctly.
   DrawCurve(equity, count);

//--- Write title text after DrawCurve so repo pointer is available.
//--- GetRepositoryType() returns "LIVE" or "MOCK" depending on which
//--- concrete implementation was injected at construction time.
   string title = "Equity Curve — " + repo.GetRepositoryType();
   m_canvas.TextOut(8, 4, title, ColorToARGB(m_text_color, 255));

   DrawLabels(repo);

   m_canvas.Update();
  }

//+------------------------------------------------------------------+
//| Remove                                                           |
//| Purpose: Deletes visual elements and releases active handles     |
//+------------------------------------------------------------------+
void CEquityCurvePanel::Remove(void)
  {
   if(m_initialized)
     {
      m_canvas.Destroy();
      ObjectDelete(m_chart_id, m_obj_name);
      m_initialized = false;
     }
  }

#endif // EQUITYCURVEPANEL_MQH
//+------------------------------------------------------------------+
