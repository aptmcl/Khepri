using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace KhepriUnity {

    public class NoMovement : IMovement {
        public Vector3 Move(float deltaTime, float impacience) {
            return Vector3.zero;
        }

        public void SetAgent(Agent_ agent) {
        }
    }
}