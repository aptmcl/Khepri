namespace KhepriUnity {
    public static class KhepriConstants {
        // Network configuration
        public const int DEFAULT_SERVER_PORT = 11002;
        public const int DEFAULT_CLIENT_PORT = 12345;
        public const string DEFAULT_SERVER_ADDRESS = "127.0.0.1";

        // Agent system
        public const float AGENT_DEACTIVATION_HEIGHT = 200f;
        public const float AGENT_STOPPED_VELOCITY_THRESHOLD = 0.25f;

        // LOD system
        public const int MIN_MESH_VERTICES_FOR_LOD = 30;

        // Highlight/Selection defaults
        public const float DEFAULT_HIGHLIGHT_WIDTH = 4f;

        // NavMesh caching
        public const float NAVMESH_CACHE_VALIDITY_SECONDS = 0.5f;
        public const float NAVMESH_POSITION_TOLERANCE = 0.5f;
    }
}
