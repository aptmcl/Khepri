using System.Threading;
using KhepriUnity;
using UnityEngine;

public class SceneLoadScript
{
	[RuntimeInitializeOnLoadMethod]
	static void OnRuntimeMethodLoad()
	{
		new Thread(() => {
			while (true) {
				Thread.Sleep(2000);
				Debug.Log("Meow");
				//UnityMainThreadDispatcher.Instance().Enqueue(new Action(test)); 
				UnityMainThreadDispatcher.Instance().Enqueue(test); 
				Thread.Sleep(2000);
				UnityMainThreadDispatcher.Instance().Enqueue(delegate { Primitives.DeleteAll(); }); 
				
			}
		}).Start();
	}
	
	private static void test() {
		//Primitives.MakeCube(new Vector3(0, 0, 0), 1);
		Primitives.MakeCylinder(new Vector3(0, 0, 0), 1, new Vector3(2, 2, 2));
		Primitives.MakeCube(new Vector3(2, 2, 2), 1);
	}
}
