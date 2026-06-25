//+------------------------------------------------------------------+
//|                                          TDA_Demo.mq5            |
//|                                  TDA Library for MQL5            |
//|   TDA_demo: Takens embedding + pairwise distance matrix          |
//+------------------------------------------------------------------+
#property copyright "Hammad Dilber"
#property version   "1.00"
#property script_show_inputs

#include <TDA\TDAPointCloud.mqh>
#include <TDA\TDADistance.mqh>

//--- inputs
input int InpWindow = 80;   // bars of close history to embed
input int InpEmbDim = 3;    // embedding dimension d
input int InpDelay  = 1;    // time delay tau

//+------------------------------------------------------------------+
//| Script entry point                                               |
//+------------------------------------------------------------------+
void OnStart()
  {
   double closes[];
   int copied = CopyClose(_Symbol, _Period, 0, InpWindow, closes);
   if(copied != InpWindow)
     {
      PrintFormat("TDA_Demo: needed %d closes, got %d - aborting", InpWindow, copied);
      return;
     }

   //--- Takens embedding
   CTDAPointCloud cloud;
   if(!cloud.Build(closes, InpWindow, InpEmbDim, InpDelay))
      return;

   //--- pairwise distance matrix
   CTDADistance dist;
   if(!dist.Build(cloud, TDA_NORM_EUCLIDEAN))
      return;

   PrintFormat("Cloud size %d, dim %d, max distance %.6f",
               cloud.Size(), cloud.Dim(), dist.MaxDistance());

   //--- show the first few embedded points
   int show = (cloud.Size() < 4 ? cloud.Size() : 4);
   for(int i = 0; i < show; i++)
     {
      double coords[];
      cloud.Get(i, coords);
      string s = "";
      for(int d = 0; d < cloud.Dim(); d++)
         s += StringFormat("%s%.5f", (d == 0 ? "" : ", "), coords[d]);
      PrintFormat("  v[%d] = ( %s )", i, s);
     }

   //--- sample distances from the matrix
   if(cloud.Size() >= 3)
      PrintFormat("  d(0,1) = %.6f   d(0,2) = %.6f   d(1,2) = %.6f",
                  dist.Get(0, 1), dist.Get(0, 2), dist.Get(1, 2));
  }
//+------------------------------------------------------------------+
