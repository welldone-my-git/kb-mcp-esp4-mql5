//+------------------------------------------------------------------+
//|                                                          RQA.mqh |
//|                          RQA Library for MQL5                    |
//|                                                                  |
//|  FULL LIBRARY — Main include file                                |
//|                                                                  |
//|  Usage:                                                          |
//|    #include <RQA\RQA.mqh>                                        |
//|                                                                  |
//|  Classes exported:                                               |
//|    CRQAMatrix   — builds the NxN recurrence matrix               |
//|    CRQAMetrics  — computes all RQA measures                      |
//|    CRQAEpsilon  — automatic epsilon selection                    |
//|    CRQAWindow   — rolling/windowed RQA analysis                  |
//|    CRQA          — high-level all-in-one facade                  |
//|                                                                  |
//|  Structs:                                                        |
//|    SRQAResult        — holds all metric values                   |
//|    SRQAWindowResult  — per-window metric values                  |
//|                                                                  |
//|  Enums:                                                          |
//|    ENUM_RQA_NORM     — distance norm choice                      |
//|    ENUM_EPSILON_METHOD — epsilon auto-selection                  |
//+------------------------------------------------------------------+
#ifndef RQA_MQH
#define RQA_MQH

#include "RQAMatrix.mqh"
#include "RQAMetrics.mqh"
#include "RQAEpsilon.mqh"
#include "RQAWindow.mqh"

//+------------------------------------------------------------------+
//| CRQA — high-level facade (one-stop shop)                         |
//+------------------------------------------------------------------+
class CRQA
  {
private:
   CRQAMatrix        m_matrix;
   CRQAMetrics       m_metrics;
   SRQAResult        m_result;
   bool              m_computed;

   double            m_epsilon;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;
   ENUM_EPSILON_METHOD m_epsilonMethod;
   double            m_epsilonParam;

public:
                     CRQA();

   //--- Configuration setters
   void              SetEpsilon(double eps)
     { m_epsilon = eps; m_epsilonMethod = EPSILON_FIXED; }

   void              SetEpsilonAuto(ENUM_EPSILON_METHOD method, double param = 0.05)
     { m_epsilonMethod = method; m_epsilonParam = param; }

   void              SetEmbedding(int dim, int delay)
     { m_embDim = dim; m_delay = delay; }

   void              SetNorm(ENUM_RQA_NORM norm)
     { m_norm = norm; }

   void              SetMinDiagLine(int v) { m_metrics.SetMinDiagLine(v); }
   void              SetMinVertLine(int v) { m_metrics.SetMinVertLine(v); }

   //--- Main compute — pass price/indicator array
   bool              Compute(const double &series[], int N);

   //--- Results access (after Compute)
   void              GetResult(SRQAResult &out) const { out = m_result; }

   double            RR()          const { return m_result.RR; }
   double            DET()         const { return m_result.DET; }
   double            LAM()         const { return m_result.LAM; }
   double            TT()          const { return m_result.TT; }
   double            L()           const { return m_result.L; }
   double            Lmax()        const { return m_result.Lmax; }
   double            Vmax()        const { return m_result.Vmax; }
   double            ENTR()        const { return m_result.ENTR; }
   double            DIV()         const { return m_result.DIV; }
   double            RATIO()       const { return m_result.RATIO; }
   double            TREND()       const { return m_result.TREND; }
   double            COMPLEXITY()  const { return m_result.COMPLEXITY; }

   //--- Print summary to log
   void              PrintSummary() const;

   //--- Access underlying objects for advanced use
   int               MatrixSize() const { return m_matrix.Size(); }
   double            Epsilon()  const { return m_epsilon; }
  };

//+------------------------------------------------------------------+
//| Constructor — initialise defaults                                |
//+------------------------------------------------------------------+
CRQA::CRQA()
   : m_computed(false),
     m_epsilon(0.1),
     m_embDim(1),
     m_delay(1),
     m_norm(RQA_NORM_EUCLIDEAN),
     m_epsilonMethod(EPSILON_FIXED),
     m_epsilonParam(0.05)
  {
  }

//+------------------------------------------------------------------+
//| Compute — run full RQA on the supplied series                    |
//+------------------------------------------------------------------+
bool CRQA::Compute(const double &series[], int N)
  {
   m_computed = false;
   m_result.Reset();

   if(N < 4)
     {
      Print("CRQA::Compute — series too short (min 4 bars)");
      return false;
     }

   // Auto-select epsilon if needed
   double eps = m_epsilon;
   if(m_epsilonMethod != EPSILON_FIXED)
      eps = CRQAEpsilon::Select(series, N, m_epsilonMethod, m_epsilonParam);

   m_epsilon = eps;

   // Build recurrence matrix
   if(!m_matrix.Build(series, N, eps, m_embDim, m_delay, m_norm))
      return false;

   // Compute metrics
   if(!m_metrics.Compute(m_matrix, m_result))
      return false;

   m_computed = true;
   return true;
  }

//+------------------------------------------------------------------+
//| PrintSummary — dump all metrics to the Experts log               |
//+------------------------------------------------------------------+
void CRQA::PrintSummary() const
  {
   if(!m_computed)
     {
      Print("CRQA: Not computed yet — call Compute() first");
      return;
     }
   PrintFormat("===== RQA Summary =====");
   PrintFormat("Epsilon     : %.6f  (embDim=%d, delay=%d)",
               m_epsilon, m_embDim, m_delay);
   PrintFormat("RR          : %.4f  (%.2f%%)", m_result.RR, m_result.RR * 100.0);
   PrintFormat("DET         : %.4f", m_result.DET);
   PrintFormat("LAM         : %.4f", m_result.LAM);
   PrintFormat("TT          : %.4f", m_result.TT);
   PrintFormat("L (avg diag): %.4f", m_result.L);
   PrintFormat("Lmax        : %.0f", m_result.Lmax);
   PrintFormat("Vmax        : %.0f", m_result.Vmax);
   PrintFormat("ENTR        : %.4f", m_result.ENTR);
   PrintFormat("DIV         : %.4f", m_result.DIV);
   PrintFormat("RATIO       : %.4f", m_result.RATIO);
   PrintFormat("TREND       : %.6f", m_result.TREND);
   PrintFormat("COMPLEXITY  : %.6f", m_result.COMPLEXITY);
   PrintFormat("=======================");
  }

#endif // RQA_MQH