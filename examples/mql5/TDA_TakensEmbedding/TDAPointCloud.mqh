//+------------------------------------------------------------------+
//|                                               TDAPointCloud.mqh  |
//|                                            TDA Library for MQL5  |
//|        Phase-space embedding: 1D series to N points in R^embDim  |
//+------------------------------------------------------------------+
#ifndef TDAPOINTCLOUD_MQH
#define TDAPOINTCLOUD_MQH

//+------------------------------------------------------------------+
//| CTDAPointCloud - Takens time-delay embedding of a series         |
//|                                                                  |
//|  Given a series x[0..L-1], dimension d and delay tau, it         |
//|  produces N = L - (d-1)*tau vectors:                             |
//|     v_i = ( x[i], x[i+tau], ..., x[i+(d-1)*tau] )                |
//+------------------------------------------------------------------+
class CTDAPointCloud
  {
private:
   double            m_points[];   // flattened [N x embDim]
   int               m_N;          // number of embedded points
   int               m_embDim;     // embedding dimension
   int               m_delay;      // time delay tau

public:
                     CTDAPointCloud();
                    ~CTDAPointCloud() {}

   //--- build the point cloud from a 1D series
   bool              Build(const double &series[], int seriesLen,
                           int embDim = 3, int delay = 1);

   //--- accessors
   int               Size()   const { return m_N; }
   int               Dim()    const { return m_embDim; }
   int               Delay()  const { return m_delay; }

   //--- read a full point (copy into coords[])
   bool              Get(int idx, double &coords[]) const;

   //--- single-coordinate access (no array alloc)
   double            GetCoord(int idx, int d) const;

   //--- raw access for compute-intensive downstream consumers
   void              GetRaw(double &out[]) const { ArrayCopy(out, m_points); }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CTDAPointCloud::CTDAPointCloud()
   : m_N(0), m_embDim(1), m_delay(1)
  {
  }

//+------------------------------------------------------------------+
//| Build N = seriesLen - (embDim-1)*delay embedded vectors          |
//+------------------------------------------------------------------+
bool CTDAPointCloud::Build(const double &series[], int seriesLen,
                            int embDim, int delay)
  {
   if(seriesLen < 2 || embDim < 1 || delay < 1)
     {
      Print("TDAPointCloud::Build - invalid parameters");
      return false;
     }

   m_embDim = embDim;
   m_delay  = delay;
   m_N      = seriesLen - (embDim - 1) * delay;
   if(m_N <= 0)
     {
      Print("TDAPointCloud::Build - series too short for given embedding");
      m_N = 0;
      return false;
     }

   ArrayResize(m_points, m_N * m_embDim);
   for(int i = 0; i < m_N; i++)
      for(int d = 0; d < m_embDim; d++)
         m_points[i * m_embDim + d] = series[i + d * m_delay];

   return true;
  }

//+------------------------------------------------------------------+
//| Copy point idx into coords[]                                     |
//+------------------------------------------------------------------+
bool CTDAPointCloud::Get(int idx, double &coords[]) const
  {
   if(idx < 0 || idx >= m_N)
     {
      ArrayResize(coords, 0);
      return false;
     }
   ArrayResize(coords, m_embDim);
   for(int d = 0; d < m_embDim; d++)
      coords[d] = m_points[idx * m_embDim + d];
   return true;
  }

//+------------------------------------------------------------------+
//| Direct single-coordinate read (bounds-checked)                   |
//+------------------------------------------------------------------+
double CTDAPointCloud::GetCoord(int idx, int d) const
  {
   if(idx < 0 || idx >= m_N || d < 0 || d >= m_embDim)
      return 0.0;
   return m_points[idx * m_embDim + d];
  }

#endif // TDAPOINTCLOUD_MQH
