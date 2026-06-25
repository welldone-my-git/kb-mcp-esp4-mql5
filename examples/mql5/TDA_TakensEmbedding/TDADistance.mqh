//+------------------------------------------------------------------+
//|                                                TDADistance.mqh   |
//|                                           TDA Library for MQL5   |
//|           Full pairwise distance matrix over a TDA point cloud   |
//+------------------------------------------------------------------+
#ifndef TDADISTANCE_MQH
#define TDADISTANCE_MQH

#include "TDAPointCloud.mqh"

//+------------------------------------------------------------------+
//| Distance norms: Chebyshev, Euclidean, Manhattan                  |
//+------------------------------------------------------------------+
enum ENUM_TDA_NORM
  {
   TDA_NORM_MAX       = 0,   // Maximum norm (Chebyshev)
   TDA_NORM_EUCLIDEAN = 1,   // Euclidean norm
   TDA_NORM_MANHATTAN = 2    // Manhattan (L1) norm
  };

//+------------------------------------------------------------------+
//| CTDADistance - full NxN pairwise distance matrix of a cloud      |
//|                                                                  |
//|  The full matrix lets the Vietoris-Rips filtration grow          |
//|  epsilon continuously and record every birth/death event.        |
//|  Symmetric, zero diagonal, stored as a flattened NxN array.      |
//+------------------------------------------------------------------+
class CTDADistance
  {
private:
   double            m_D[];        // flattened NxN distance matrix
   int               m_N;          // number of points
   ENUM_TDA_NORM     m_norm;       // distance norm
   double            m_maxDist;    // max pairwise distance

   double            ComputePairDistance(const CTDAPointCloud &cloud,
                                         int i, int j) const;

public:
                     CTDADistance();
                    ~CTDADistance() {}

   //--- build from a point cloud
   bool              Build(const CTDAPointCloud &cloud,
                           ENUM_TDA_NORM norm = TDA_NORM_EUCLIDEAN);

   //--- accessors
   double            Get(int i, int j) const;
   int               Size()         const { return m_N; }
   ENUM_TDA_NORM     Norm()         const { return m_norm; }
   double            MaxDistance()  const { return m_maxDist; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CTDADistance::CTDADistance()
   : m_N(0), m_norm(TDA_NORM_EUCLIDEAN), m_maxDist(0.0)
  {
  }

//+------------------------------------------------------------------+
//| Distance between point i and point j under the selected norm     |
//+------------------------------------------------------------------+
double CTDADistance::ComputePairDistance(const CTDAPointCloud &cloud,
                                          int i, int j) const
  {
   int dim = cloud.Dim();
   double dist = 0.0;
   for(int d = 0; d < dim; d++)
     {
      double diff = cloud.GetCoord(i, d) - cloud.GetCoord(j, d);
      switch(m_norm)
        {
         case TDA_NORM_MAX:
            dist = MathMax(dist, MathAbs(diff));
            break;
         case TDA_NORM_MANHATTAN:
            dist += MathAbs(diff);
            break;
         case TDA_NORM_EUCLIDEAN:
         default:
            dist += diff * diff;
            break;
        }
     }
   if(m_norm == TDA_NORM_EUCLIDEAN)
      dist = MathSqrt(dist);
   return dist;
  }

//+------------------------------------------------------------------+
//| Build the full pairwise distance matrix                          |
//+------------------------------------------------------------------+
bool CTDADistance::Build(const CTDAPointCloud &cloud, ENUM_TDA_NORM norm)
  {
   m_N    = cloud.Size();
   m_norm = norm;
   if(m_N < 2)
     {
      Print("TDADistance::Build - need at least 2 points");
      return false;
     }

   ArrayResize(m_D, m_N * m_N);
   m_maxDist = 0.0;

   for(int i = 0; i < m_N; i++)
     {
      m_D[i * m_N + i] = 0.0;
      for(int j = i + 1; j < m_N; j++)
        {
         double d = ComputePairDistance(cloud, i, j);
         m_D[i * m_N + j] = d;
         m_D[j * m_N + i] = d;          // symmetric
         if(d > m_maxDist) m_maxDist = d;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Bounds-checked distance access                                   |
//+------------------------------------------------------------------+
double CTDADistance::Get(int i, int j) const
  {
   if(i < 0 || i >= m_N || j < 0 || j >= m_N)
      return 0.0;
   return m_D[i * m_N + j];
  }

#endif // TDADISTANCE_MQH
