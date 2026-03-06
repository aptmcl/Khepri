using System.Collections.Generic;
using UnityEngine;

namespace KhepriUnity {
    public class AgentPool : MonoBehaviour {
        [Header("Pool Settings")]
        [SerializeField] private GameObject agentPrefab;
        [SerializeField] private int initialPoolSize = 100;
        [SerializeField] private int maxPoolSize = 1000;
        
        private Queue<GameObject> inactiveAgents = new Queue<GameObject>();
        private List<GameObject> activeAgents = new List<GameObject>();
        
        private void Awake() {
            PrewarmPool();
        }
        
        private void PrewarmPool() {
            for (int i = 0; i < initialPoolSize; i++) {
                CreateNewAgent();
            }
        }
        
        private void CreateNewAgent() {
            GameObject agent = Instantiate(agentPrefab, Vector3.zero, Quaternion.identity);
            agent.SetActive(false);
            inactiveAgents.Enqueue(agent);
        }
        
        public GameObject GetAgent(Vector3 position, Quaternion rotation) {
            GameObject agent;
            
            if (inactiveAgents.Count > 0) {
                agent = inactiveAgents.Dequeue();
            } else if (activeAgents.Count < maxPoolSize) {
                CreateNewAgent();
                agent = inactiveAgents.Dequeue();
            } else {
                Debug.LogWarning("Agent pool is full. Consider increasing maxPoolSize.");
                return null;
            }
            
            agent.transform.position = position;
            agent.transform.rotation = rotation;
            agent.SetActive(true);
            activeAgents.Add(agent);
            
            return agent;
        }
        
        public void ReturnAgent(GameObject agent) {
            if (agent == null) return;
            
            // Reset agent state
            Agent_ agentComponent = agent.GetComponent<Agent_>();
            if (agentComponent != null) {
                // AML agentComponent.ResetAgent();
            }
            
            agent.SetActive(false);
            activeAgents.Remove(agent);
            inactiveAgents.Enqueue(agent);
        }
        
        public void ReturnAllAgents() {
            for (int i = activeAgents.Count - 1; i >= 0; i--) {
                if (activeAgents[i] != null) {
                    ReturnAgent(activeAgents[i]);
                }
            }
        }
        
        public int GetActiveAgentCount() => activeAgents.Count;
        public int GetInactiveAgentCount() => inactiveAgents.Count;
    }
}
