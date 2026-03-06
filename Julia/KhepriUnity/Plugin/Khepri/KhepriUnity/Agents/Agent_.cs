using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.AI;

namespace KhepriUnity {

    public class Agent_ : MonoBehaviour {
        public CharacterController characterController;

        public ConcurrentDictionary<Collider, Agent_> _nearbyAgents = new ConcurrentDictionary<Collider, Agent_>();
        public Vector3 velocityPrev = Vector3.zero;
        public IMovement baseMovement;
        public Color color;
        public float reductionFactor = 0.7f; // reduce the person diamenter. used to solve congestion and pass through small doors

        [HideInInspector] public List<Vector3> closestPTSObstacles = new List<Vector3>(); // List with the closest points of the obstacles
        [HideInInspector] public Goal_ goal;
        [HideInInspector] public List<Goal_> allGoals = new List<Goal_>();
        [HideInInspector] public float k = 1f; // used in the low pass filter

        private MeshRenderer _cachedMeshRenderer; // Cached for SetColor optimization
        //private int _updateCounter = 0;
        //private const int CLOSEST_POINT_UPDATE_INTERVAL = 2; // Update every N frames when nearly stopped

        private List<Collider> _obstacles = new List<Collider>(); // List with the closest walls
        public float baseRadius = 0.2279f;
        public float colliderRadius = 2f;
        public GameObject capsule;
        private float stopped = 0f;
        private Vector3 prevPosition;

        public int agentID;

        public void GenerateID()
        {
            agentID = SystemManager.uniqueID.GetUniqueID();
        }

        private void OnTriggerEnter(Collider other) {
            if (other.transform.IsChildOf(transform))
                return;

            // When in proximity to an obstacle, add it to a list
            if (other.gameObject.tag == SystemManager.obstacleTag) {
                if (!_obstacles.Contains(other))
                {
                    _obstacles.Add(other);
                }
            }

            // Add nearby agents to list
            if (other.gameObject.tag == SystemManager.agentTag) {
                _nearbyAgents.TryAdd(other, other.gameObject.GetComponentInParent<Agent_>());
            }
        }

        private void OnTriggerExit(Collider other) {
            if (other.transform.IsChildOf(transform))
                return;

            // When far away of an obstacle, remove it from the list
            if (other.gameObject.tag == SystemManager.obstacleTag)
            {
                _obstacles.Remove(other);
            }

            // Remove agent from list when far away
            if (other.gameObject.tag == SystemManager.agentTag)
            {
                _nearbyAgents.TryRemove(other, out _);
            }
        }

        /*private void OnTriggerStay(Collider other) {
            // Update closest point for obstacle while in trigger range
            // This is called by physics at FixedUpdate rate
            if (other.gameObject.CompareTag(SystemManager.obstacleTag)) {
                int index = _obstacles.IndexOf(other);
                if (index >= 0) {
                    closestPTSObstacles[index] = other.ClosestPoint(transform.position);
                }
            }
        }*/

        private void GetClosestPoint() {
            // Fallback method - now primarily handled by OnTriggerStay
            /*int counter = 0;
            foreach (Collider collider in _obstacles) {
                if (collider != null) {
                    closestPTSObstacles[counter] = collider.ClosestPoint(transform.position);
                }
                counter++;
            }*/
            closestPTSObstacles = _obstacles.Select(collider => collider.ClosestPoint(transform.position)).ToList();
        }

        private void OnEnable() {
            SystemManager.instance.AddAgent(this);
            prevPosition = transform.position;
        }

        /*private void OnDisable() {
            SystemManager.instance.RemoveAgent(this);
        }*/

        private float LowPassFilter(float x, float y, float deltaTime) {
            float alpha = 1 - Mathf.Exp(-deltaTime / k);
            return alpha * x + (1 - alpha) * y;
        }

        public void RemoveNearbyAgent(Agent_ agent_) {
            // Direct removal by collider key - thread-safe
            var collider = agent_.GetComponent<Collider>();
            if (collider != null) {
                _nearbyAgents.TryRemove(collider, out _);
            }
        }

        public void UpdateAgent(float deltaTime) {
            // Optimize: skip closest point calculation when agent is nearly stopped
            /*_updateCounter++;
            bool shouldUpdateClosestPoints = stopped < 0.5f || (_updateCounter % CLOSEST_POINT_UPDATE_INTERVAL == 0);
            if (shouldUpdateClosestPoints) {
                GetClosestPoint();
            }*/

            GetClosestPoint();

            Vector3 movement = baseMovement.Move(deltaTime, stopped);

            //velocityPrev = movement / deltaTime;
            //characterController.Move(movement);
            velocityPrev = (transform.position - prevPosition) / deltaTime; ;
            prevPosition = transform.position;

            // Reduce agent radius to allow more fluid movement in congested areas
            SphereCollider sphereColl = characterController.GetComponent<SphereCollider>();
            sphereColl.radius = Mathf.Lerp(colliderRadius, colliderRadius * reductionFactor, stopped);
            characterController.radius = Mathf.Lerp(baseRadius, baseRadius * reductionFactor, stopped);
            capsule.transform.localScale = new Vector3(characterController.radius * 2, capsule.transform.localScale.y, characterController.radius * 2);

            float minMagnitude = 0.005f;
            movement *= movement.magnitude > minMagnitude ? 1.0f : minMagnitude / movement.magnitude;
            movement += new Vector3(0, -9.81f * deltaTime, 0);
            characterController.Move(movement);

            float x = (velocityPrev.sqrMagnitude <= KhepriConstants.AGENT_STOPPED_VELOCITY_THRESHOLD) ? 1.0f : 0.0f;
            stopped = LowPassFilter(x, stopped, deltaTime);
            SetColor(color * (1 - stopped));
        }

        public void SetColor(Color newColor) {
            if (_cachedMeshRenderer == null) {
                _cachedMeshRenderer = GetComponentInChildren<MeshRenderer>();
            }
            if (_cachedMeshRenderer != null) {
                _cachedMeshRenderer.material.color = newColor;
            }
        }

        public void AssignGoal()
        {
            this.goal = ClosestGoal(this.transform.position, allGoals);
        }

        public float MinPathDistance(Vector3 start, Vector3 end)
        {
            NavMeshPath path = new NavMeshPath();

            if (NavMesh.CalculatePath(start, end, NavMesh.AllAreas, path))
            {
                float totalDistance = 0.0f;

                for (int i = 1; i < path.corners.Length; i++)
                {
                    totalDistance += Vector3.Distance(path.corners[i - 1], path.corners[i]);
                }
                return totalDistance;
            }
            else
            {
                return float.MaxValue;
            }
        }

        public Goal_ ClosestGoal(Vector3 position, IEnumerable<Goal_> goals)
        {
            Goal_ minGoal = goals.First();
            float minDist = MinPathDistance(position, minGoal.transform.position);
            foreach (var goal in goals)
            {
                float dist = MinPathDistance(position, goal.transform.position);
                if (dist < minDist)
                {
                    minDist = dist;
                    minGoal = goal;
                }
            }
            return minGoal;
        }

        public void GoalReached(Goal_ goal) {
            if (this.goal == goal) {
                Cleanup();
                transform.position = new Vector3(0, KhepriConstants.AGENT_DEACTIVATION_HEIGHT, 0);
                SystemManager.instance.ScheduleForDestruction(this);
            }
        }

        public void Cleanup()
        {
            foreach (var pair in _nearbyAgents)
            {
                Agent_ other = pair.Value;
                if (other != null)
                {
                    other.RemoveNearbyAgent(this);
            }
        }
            _nearbyAgents.Clear();
            _nearbyAgents = new ConcurrentDictionary<Collider, Agent_>();

            SystemManager.instance.RemoveAgent(this);
        }

    }
}
