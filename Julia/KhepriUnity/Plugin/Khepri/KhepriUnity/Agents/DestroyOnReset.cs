using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace KhepriUnity {

    public class DestroyOnReset : MonoBehaviour {
        void Awake() {
            SystemManager.instance.OnSimulationReset.AddListener(DestroyGameObject);
        }

        public void DestroyGameObject() {
            SystemManager.instance.OnSimulationReset.RemoveListener(DestroyGameObject);
            Destroy(gameObject);
        }
    }
}