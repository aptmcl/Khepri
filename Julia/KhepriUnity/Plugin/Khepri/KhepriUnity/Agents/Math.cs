using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace KhepriUnity {

    public interface IDistribution {
        float Sample();
    }

    public class Gaussian : IDistribution {
        private float mean;
        private float stddev;
        private float min;
        private float max;

        public Gaussian(float mean, float stddev, float min, float max) {
            this.mean = mean;
            this.stddev = stddev;
            this.min = min;
            this.max = max;
        }

        public float Sample() {
            // The method requires sampling from a uniform random of (0,1]
            float x1 = Random.Range(float.Epsilon, 1f);
            float x2 = Random.Range(float.Epsilon, 1f);

            float y1 = Mathf.Sqrt(-2.0f * Mathf.Log(x1)) * Mathf.Cos(2.0f * Mathf.PI * x2);
            y1 = y1 * stddev + mean;
            return Mathf.Min(max, Mathf.Max(min, y1));
        }
    }

    public class Uniform : IDistribution {
        private float min;
        private float max;

        public Uniform(float min, float max) {
            this.min = min;
            this.max = max;
        }

        public float Sample() {
            return Random.Range(min, max);
        }
    }

    public class Single : IDistribution {
        private float value;

        public Single(float value) {
            this.value = value;
        }

        public float Sample() {
            return value;
        }
    }
}