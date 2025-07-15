using System;
using System.Collections.Generic;
using System.Collections;
using System.Reflection;
using System.Linq;
using UnityEngine;
using UnityEditor;

public class GenVsSolution
{
	[MenuItem("Assets/GenVsSolution", false, 10)]
	static public void SyncVSSolution()
     {
         string syncClass = "SyncVS";
 
         Debug.Log("Syncing VS Solution:");
 
         IEnumerable<Type> syncVS = from ass in AppDomain.CurrentDomain.GetAssemblies()
                                    from t in ass.GetTypes()
                                    where t.Name.Equals(syncClass)
                                    select t;
         if (syncVS.Count() != 1)
             Debug.Log("ERROR: Not single unique class of type: " + syncClass);
         else
         {
             Type sync = syncVS.First();
             MethodInfo method = sync.GetMethod("SyncSolution");
             if (method == null)
                 Debug.Log("ERROR: Unable to find SyncSolution method");
             else
                 method.Invoke(null, null);
         }
     }

}	