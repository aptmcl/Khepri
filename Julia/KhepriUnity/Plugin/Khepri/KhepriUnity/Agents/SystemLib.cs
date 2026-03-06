using System.Collections;
using System.Collections.Generic;
using System.Linq;

//using UnityEditor.PackageManager;
//using UnityEditor.PackageManager.Requests;
using UnityEngine;

namespace KhepriUnity {

    public static class SystemLib {
        private enum SimType 
        {
            HSF,
            none
        }

        private static SimType _simType = SimType.none;
        private static List<float> parameters = new List<float>();
        private static IDistribution velDist;
        private static float agentRadius = 1.2f; // Minimum distance between agents when spawning

        public static void SetAgentSpawnRadius(float radius) {
            agentRadius = radius;
        }

        // Simulation Functions ------------------------------------------------------------------------------------------------------------
        public static void CreateAgent(float posx, float posy, float posz, float rot, int rgb, List<Goal_> goals) {
            IMovement movement = null;
            switch (_simType) {
                case SimType.HSF:
                    movement = new HelbingSF(
                        parameters[0], parameters[1],
                        parameters[2], parameters[3],
                        parameters[4], parameters[5],
                        parameters[6], parameters[7],
                        velDist.Sample());
                    break;
                default:
                    movement = new NoMovement();
                    break;
            }
            SystemManager.instance.InstantiateAgent(new Vector3(posx, posy+1, posz), rot, IntToColor(rgb), movement, goals);
        }

        public static void StartUnitySimulation(float maxSimTime = 1000f) {
            SystemManager.instance.StartSimulation(maxSimTime);
        }

        public static void SetSimulationSpeed(float simSpeed) {
            SystemManager.instance.simulationSpeed = simSpeed;
        }

        public static void CloseSimulator() {
            Application.Quit();
        }

        public static void ResetScene() {
            SystemManager.instance.ResetScene();
        }

        public static int IsSimulationFinished() {
            return SystemManager.isFinished ? 1 : 0;
        }

        public static int WasSimulationSuccessful() {
            return SystemManager.timeOut ? 0 : 1;
        }

        public static float GetEvacuationTime() {
            return SimMetrics.GetEvacuationTime();
        }

        // Initial Distribution of Velocity Functions --------------------------------------------------------------------------------------
        public static void SetVelGaussHSF(float mean, float stdDev, float min = 0.5f, float max = Mathf.Infinity) {
            velDist = new Gaussian(mean, stdDev, min, max);
        }

        public static void SetVelUniformHSF(float min, float max) {
            velDist = new Uniform(min, max);
        }

        public static void SetVelHSF(float vel) {
            velDist = new Single(vel);
        }

        // Movement Functions --------------------------------------------------------------------------------------------------------------
        public static void SetSimHSF(
            float relaxationTime = 0.5f, float maximumSpeedCoef = 1.3f,
            float V = 2.1f, float sigma = 0.3f,
            float U = 10.0f, float R = 0.2f,
            float c = 0.5f, float phi = 100.0f) {
            _simType = SimType.HSF;
            parameters = new List<float> { relaxationTime, maximumSpeedCoef, V, sigma, U, R, c, phi };
            velDist = new Gaussian(1.34f, 0.26f, 0.5f, Mathf.Infinity);
        }

        public static void SetSimNone() {
            _simType = SimType.none;
        }

        // Agent Spawning Functions --------------------------------------------------------------------------------------------------------
        public static void SpawnAgentsRect(
            int numAgents,
            float cx, float cy, float cz, // center coordinates
            float dx, float dz, // width and length
            float rot, // in degrees TODO: overload with radians
            int rgb,
            int[] goalsIDs)
        {
            List<Goal_> goals = goalsIDs.Select(id => SystemManager.goalsList[id]).ToList();
            Matrix4x4 m = Matrix4x4.identity;
            m.SetTRS(new Vector3(cx, cy, cz), Quaternion.Euler(0, rot, 0), new Vector3(dx, 0, dz)); // The matrix that performs the transformation, rotation and scaling of the points

            int agentsCount = 0;
            while (agentsCount < numAgents)
            {
                float x = UnityEngine.Random.Range(-0.5f, 0.5f);
                float z = UnityEngine.Random.Range(-0.5f, 0.5f);
                
                Vector3 pos = m.MultiplyPoint3x4(new Vector3(x, 0, z)); // Position in the real world
                
                if (SystemManager.instance.IsPosAvailable(pos, agentRadius))
                {
                    CreateAgent(pos.x, pos.y, pos.z, UnityEngine.Random.Range(0, 360.0f), rgb, goals);
                    ++agentsCount;
                }
            }
        }

        public static void SpawnAgentsEllipse(
            int numAgents,
            float cx, float cy, float cz, // center coordinates
            float dx, float dz, // major and minor radius
            float rot, // in degrees TODO: overload with radians
            int rgb,
            int[] goalsIDs)
        {
            List<Goal_> goals = goalsIDs.Select(id => SystemManager.goalsList[id]).ToList();
            Matrix4x4 m = Matrix4x4.identity;
            m.SetTRS(new Vector3(cx, cy, cz), Quaternion.Euler(0, rot, 0), new Vector3(dx, 0, dz)); // The matrix that performs the transformation, rotation and scaling of the points
            
            int agentsCount = 0;
            while (agentsCount < numAgents)
            {
                float x = UnityEngine.Random.Range(-0.5f, 0.5f);
                float z = UnityEngine.Random.Range(-0.5f, 0.5f);
                
                Vector3 pos = m.MultiplyPoint3x4(new Vector3(x, 0, z)); // Position in the real world
                
                if ((x * x + z * z <= 0.25f) && SystemManager.instance.IsPosAvailable(pos, agentRadius))
                {
                    CreateAgent(pos.x, pos.y, pos.z, UnityEngine.Random.Range(0, 360.0f), rgb, goals);
                    ++agentsCount;
                }
            }
        }

        public static void SpawnAgentsPolygon(
            int numAgents,
            float cy,
            int rgb,
            int[] goalsIDs,
            Vector2[] polygonVertices)
        {
            List<Goal_> goals = goalsIDs.Select(id => SystemManager.goalsList[id]).ToList();
            var (p, width, height) = Intersections.BoundingBox(polygonVertices);
            
            int agentsCount = 0;
            while (agentsCount < numAgents)
            {
                Vector3 pos = new Vector3(p.x + UnityEngine.Random.Range(0f, 1f) * width, cy,
                                          p.y + UnityEngine.Random.Range(0f, 1f) * height);
                
                if (Intersections.PointOnPolygon(new Vector2(pos.x, pos.z), polygonVertices) &&
                    SystemManager.instance.IsPointOnNavMesh(pos) &&
                    SystemManager.instance.IsPosAvailable(pos, agentRadius))
                {
                    CreateAgent(pos.x, pos.y, pos.z, UnityEngine.Random.Range(0, 360.0f), rgb, goals);
                    ++agentsCount;
                }
            }
        }

        // Architecture Functions ----------------------------------------------------------------------------------------------------------
        public static int CreateGoal(
            float posx, float posy, float posz,// center coordinates
            float dx, float dz, // width and length
            float rot) // rotation in degrees TODO: overload with radians
        {
            return SystemManager.instance.AddGoal(new Vector3(posx, posy, posz), new Vector3(dx, 0.5f, dz), rot);
        }
        /*
        public static void CreateWall(
            float posx, float posz, // center coordinates
            float dx, float dz, // width and length/thickness
            float rot) // rotation in degrees TODO: overload with radians
        {
            Architecture.instance.CreateWall(new Vector3(posx, 1.75f, posz), rot, new Vector3(dx, 3.0f, dz));
        }

        public static void CreateFloor(
            float posx, float posz, // center coordinates
            float dx, float dz, // width and length
            float rot) // rotation in degrees TODO: overload with radians
        {
            Architecture.instance.CreateFloor(new Vector3(posx, 0.0f, posz), rot, new Vector3(dx, 0.5f, dz));
        }
        public static void CreateFloorPoints(Vector2[] pos) {
            Architecture.instance.CreateFloorPoints(pos, 0.5f);
        }

        public static void CreateCylColumn(
            float posx, float posz, // center coordinates
            float dx, float dz, // width and length
            float rot) // rotation in degrees TODO: overload with radians
        {
            Architecture.instance.CreateCylColumn(new Vector3(posx, 1.75f, posz), rot, new Vector3(dx, 1.5f, dz));
        }

        public static void CreateDoorFrame(
            float posx, float posz, // center coordinates
            float dx, float dz, // width and length
            float rot) // rotation in degrees TODO: overload with radianas
        {
            Architecture.instance.CreateDoorFrame(new Vector3(posx, 1.75f, posz), rot, new Vector3(dx, 3.0f, dz));
        }
        */
        // NavMesh Functions ---------------------------------------------------------------------------------------------------------------
        public static void UpdateNavMesh() {
            SystemManager.instance.UpdateNavMesh();
        }

        // Utility Functions ---------------------------------------------------------------------------------------------------------------
        private static Color IntToColor(int rgba) {
            // Extract the color components using bitwise operations
            float r = ((rgba >> 16) & 0xFF) / 255f; // Red
            float g = ((rgba >> 8) & 0xFF) / 255f; // Green
            float b = (rgba & 0xFF) / 255f;  // Blue

            // Create and return a new Color object
            return new Color(r, g, b, 1);
        }
    }
}
