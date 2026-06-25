//+------------------------------------------------------------------+
//|                                                   RQAWindow.mqh  |
//|                          RQA Library for MQL5                    |
//|          Windowed (rolling) RQA for time-varying analysis        |
//+------------------------------------------------------------------+
#ifndef RQAWINDOW_MQH
#define RQAWINDOW_MQH

#include "RQAMatrix.mqh"
#include "RQAMetrics.mqh"

//+------------------------------------------------------------------+
//| Rolling window result — one entry per window step                |
//+------------------------------------------------------------------+
struct SRQAWindowResult
  {
   int         barIndex;    // starting bar of this window
   SRQAResult  metrics;     // all RQA metrics for this window
  };

//+------------------------------------------------------------------+
//| CRQAWindow — applies RQA over a rolling window                   |
//+------------------------------------------------------------------+
class CRQAWindow
  {
private:
   int               m_windowSize;   // bars per window
   int               m_step;         // step between windows
   double            m_epsilon;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;
   int               m_minDiagLine;
   int               m_minVertLine;

public:
                     CRQAWindow();

   //--- Config
   void              SetWindow(int windowSize, int step = 1) { m_windowSize = windowSize; m_step = step; }
   void              SetEpsilon(double eps)  { m_epsilon = eps; }
   void              SetEmbedding(int dim, int delay) { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm) { m_norm = norm; }
   void              SetMinLines(int diagMin, int vertMin) { m_minDiagLine = diagMin; m_minVertLine = vertMin; }

   //--- Run rolling analysis — fills results[]
   bool              Run(const double &series[], int seriesLen,
                         SRQAWindowResult &results[]);

   //--- Extract single metric time-series from results
   static void       ExtractRR   (const SRQAWindowResult &r[], double &out[]);
   static void       ExtractDET  (const SRQAWindowResult &r[], double &out[]);
   static void       ExtractLAM  (const SRQAWindowResult &r[], double &out[]);
   static void       ExtractTT   (const SRQAWindowResult &r[], double &out[]);
   static void       ExtractENTR (const SRQAWindowResult &r[], double &out[]);
   static void       ExtractLmax (const SRQAWindowResult &r[], double &out[]);
   static void       ExtractTREND(const SRQAWindowResult &r[], double &out[]);
  };

//+------------------------------------------------------------------+
//| Constructor — set default window/embedding parameters            |
//+------------------------------------------------------------------+
CRQAWindow::CRQAWindow()
   : m_windowSize(50), m_step(1), m_epsilon(0.0), m_embDim(1),
     m_delay(1), m_norm(RQA_NORM_EUCLIDEAN),
     m_minDiagLine(2), m_minVertLine(2)
  {
  }

//+------------------------------------------------------------------+
//| Run — execute rolling RQA and populate results array             |
//+------------------------------------------------------------------+
bool CRQAWindow::Run(const double &series[], int seriesLen,
                      SRQAWindowResult &results[])
  {
   if(seriesLen < m_windowSize)
     {
      Print("RQAWindow::Run — series shorter than window");
      return false;
     }

   CRQAMatrix  mat;
   CRQAMetrics mtr(m_minDiagLine, m_minVertLine);

   int numWindows = (seriesLen - m_windowSize) / m_step + 1;
   ArrayResize(results, numWindows);

   double slice[];
   ArrayResize(slice, m_windowSize);

   int idx = 0;
   for(int start = 0; start + m_windowSize <= seriesLen; start += m_step)
     {
      // Copy window slice
      for(int k = 0; k < m_windowSize; k++)
         slice[k] = series[start + k];

      // Build matrix
      double eps = (m_epsilon > 0.0) ? m_epsilon : 0.1;
      if(!mat.Build(slice, m_windowSize, eps, m_embDim, m_delay, m_norm))
        {
         results[idx].barIndex = start;
         results[idx].metrics.Reset();
         idx++;
         continue;
        }

      // Compute metrics
      results[idx].barIndex = start;
      mtr.Compute(mat, results[idx].metrics);
      idx++;
     }

   ArrayResize(results, idx);
   return true;
  }

//+------------------------------------------------------------------+
//| ExtractRR — pull Recurrence Rate series from window results      |
//+------------------------------------------------------------------+
void CRQAWindow::ExtractRR(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.RR;
  }

//+------------------------------------------------------------------+
//| ExtractDET — pull Determinism series from window results         |
//+------------------------------------------------------------------+
void CRQAWindow::ExtractDET(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.DET;
  }

//+------------------------------------------------------------------+
//| ExtractLAM — pull Laminarity series from window results          |
//+------------------------------------------------------------------+
void CRQAWindow::ExtractLAM(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.LAM;
  }

//+------------------------------------------------------------------+
//| ExtractTT — pull Trapping Time series from window results        |
//+------------------------------------------------------------------+
void CRQAWindow::ExtractTT(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.TT;
  }

//+------------------------------------------------------------------+
//| ExtractENTR — pull Shannon Entropy series from window results    |
//+------------------------------------------------------------------+
void CRQAWindow::ExtractENTR(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.ENTR;
  }

//+------------------------------------------------------------------+
//| ExtractLmax — pull max diagonal length series from window results|
//+------------------------------------------------------------------+
void CRQAWindow::ExtractLmax(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.Lmax;
  }

//+------------------------------------------------------------------+
//| ExtractTREND — pull Trend series from window results             |
//+------------------------------------------------------------------+
void CRQAWindow::ExtractTREND(const SRQAWindowResult &r[], double &out[])
  {
   int n = ArraySize(r);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = r[i].metrics.TREND;
  }

#endif // RQAWINDOW_MQH
