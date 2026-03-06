using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace KhepriUnity {

    // All models should implement these methods
    public interface IMovement {
        public Vector3 Move(float deltaTime, float impacience);

        public void SetAgent(Agent_ agent);
    }
}