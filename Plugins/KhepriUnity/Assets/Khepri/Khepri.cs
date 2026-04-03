using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

[ExecuteInEditMode, Serializable]
public class Khepri : MonoBehaviour {
    public SceneLoad sceneLoad;
    public bool isKhepriRunning = false;
    [SerializeField]
    public bool wasRunningBeforePlayMode = false;
    public Transform directionalLightTransform;
    public Light directionalLight;
    public bool hasStarted = false;

    // Header Logo
    public string khepriLogoFilename = "khepri_logo.png";
    public Texture2D khepriLogo;
    
    // Buttons Logo
    public string startKhepriLogoFilename = "khepri_start.png";
    public Texture2D startKhepriLogo;
    public string startKhepriNoNavigationLogoFilename = "khepri_start_no_navi.png";
    public Texture2D startKhepriNoNavigationLogo;
    public string startNavigationLogoFilename = "navi.png";
    public Texture2D startNavigationLogo;
    public string pauseSocketLogoFilename = "pause.png";
    public Texture2D pauseSocketLogo;
    
    [SerializeField]
    public bool startKhepriToggle = false;
    [SerializeField]
    public bool startKhepriNoNavigationToggle = false;
    [SerializeField]
    public bool pauseSocketToggle = false;
    public bool pauseSocketLastToggle = false;
    [SerializeField]
    public bool startNavigationToogle = false;

    [SerializeField] 
    public bool enableFocus = true;

    // Khepri Start
    [SerializeField]
    public bool startKhepriOnLoad = false;
    [SerializeField]
    public bool startKhepriinPlaymode = false;
    [SerializeField]
    public bool khepriWithNavigation = false;
    [SerializeField]
    public bool khepriWithoutNavigation = false;
    
    // Optimize
    [SerializeField] 
    public bool enableMeshCombine = false;
    public bool defaultEnableMeshCombine = false;
    [SerializeField] 
    public bool optimized = false;
    
    // Scene Manager
    [SerializeField]
    public string sceneName = "NewScene";

    // Materials
    [SerializeField] 
    public bool enableMaterials = true;
    [SerializeField] 
    public bool materialSettingsFoldout = false;
    [SerializeField]
    public int textureQualitySelected = 0;
    public int defaultTextureQualitySelected = 0;
    [SerializeField] 
    public int anisotropicFilteringSelected = 2;
    public int defaultAnisotropicFilteringSelected = 2;
    [SerializeField]
    public bool enableTextureStreaming = true;
    public bool defaultEnableTextureStreaming = true;
    
    // Colliders
    [SerializeField]
    public bool enableColliders = true;

    // LOD
    [SerializeField]
    public bool enableLOD = false;
    [SerializeField] 
    public bool lodSettingsFoldout = false;
    [SerializeField] 
    public int fadeModeSelected = 0;
    public int defaultFadeModeSelected = 0;
    [SerializeField] 
    public bool enableAnimateCrossfade = false;
    public bool defaultEnableAnimateCrossfade = false;
    [SerializeField] 
    public bool simplificationFoldout = false;
    [SerializeField] 
    public bool preserveBorderEdge = false;
    public bool defaultPreserveBorderEdge = false;
    [SerializeField] 
    public bool preserveUVSeamEdge = false;
    public bool defaultPreserveUVSeamEdge = false;
    [SerializeField] 
    public bool preserveUVFoldoverEdge = false;
    public bool defaultPreserveUVFoldoverEdge = false;
    [SerializeField] 
    public int simplificationAgressiveness = 7;
    public int defaultSimplicationAgressiveness = 7;
    [SerializeField] 
    public int numLevels = 3;
    public int defaultNumLevels = 3;
    [SerializeField]
    public List<float> screenRelativeHeightList = new List<float>() {0.6f, 0.15f, 0.02f};
    public List<float> defaultScreenRelativeHeightList = new List<float>() {0.6f, 0.15f, 0.02f};
    [SerializeField]
    public List<float> qualityList = new List<float>() {1f, 0.5f, 0.25f};
    public List<float> defaultQualityList = new List<float>() {1f, 0.5f, 0.25f};
    [SerializeField]
    public List<bool> combineMeshesList = new List<bool>() {true, true, true};
    public List<bool> defaultCombineMeshesList = new List<bool>() {true, true, true};
    [SerializeField]
    public List<bool> castShadowList = new List<bool>() {true, true, true};
    public List<bool> defaultCastShadowList = new List<bool>() {true, true, true};
    [SerializeField]
    public List<bool> receiveShadowList = new List<bool>() {true, true, false};
    public List<bool> defaultReceiveShadowList = new List<bool>() {true, true, false};
    
    // Illumination
    // Day and night
    [SerializeField] 
    public bool dayNightSettingsFoldout = false;
    [SerializeField] 
    public bool realTimeDirectionalLight = true;
    public bool defaultRealTimeDirectionalLight = true;
    [SerializeField] 
    public float dayTime = 840;
    public float defaultDayTime = 840;
    [SerializeField] 
    public bool enableAdvancedSunSettings = false;
    public bool defaultEnableAdvancedSunSettings = false;
    [SerializeField] 
    public float sunX = 120;
    public float defaultSunX = 120;
    [SerializeField] 
    public float sunY = 0;
    public float defaultSunY = 0;
    [SerializeField] 
    public float sunZ = 0;
    public float defaultSunZ = 0;
    
    // Scene Illumination
    [SerializeField] 
    public bool sceneIlluminationSettingsFoldout = false;
    [SerializeField]
    public bool enablePointlights = true;
    public bool defaultEnablePointlights = true;
    [SerializeField]
    public bool enablePointlightsShadows = true;
    public bool defaultEnablePointlightsShadows = true;
    // Player
    [SerializeField] 
    public bool playerSettingsFoldout = false;
    [SerializeField] 
    public float playerRadius = 0.2f;
    public float defaultPlayerRadius = 0.2f;
    [SerializeField] 
    public float playerWalkSpeed = 1f;
    public float defaultPlayerWalkSpeed = 1f;
    [SerializeField] 
    public float playerFlySpeed = 2f;
    public float defaultPlayerFlySpeed = 2f;
    [SerializeField] 
    public float playerJumpHeight = 2f;
    public float defaultPlayerJumpHeight = 2f;
    [SerializeField] 
    public float playerLookSpeed = 10f;
    public float defaultPlayerLookSpeed = 10f;
    [SerializeField] 
    public float playerGravityMultiplier = -1.05f;
    public float defaultPlayerGravityMultiplier = -1.05f;
    [SerializeField] 
    public float playerMaxFallSpeed = -6f;
    public float defaultPlayerMaxFallSpeed = -6f;
    
    // Selection
    [SerializeField]
    public bool selectionSettingsFoldout = false;
    [SerializeField]
    public Color highlightColor = new Color(1,0.45f,0);
    public Color defaultHighlightColor = new Color(1,0.45f,0);

    // Navigation Controls
    [SerializeField] 
    public bool navigationControlsFoldout = false;

    // Does nothing. Only here to hold the custom Inspector and it's (serializable) data
    // Forces focus on this object when a scene loads
    public void Start() {
        transform.hideFlags = HideFlags.HideInInspector;
        //AML Selection.activeGameObject = this.gameObject;
        //Selection.selectionChanged += Focus;
        //AML EditorApplication.update += Focus;
        sceneLoad = new SceneLoad();

        khepriLogo = new Texture2D(1300,1000);
        khepriLogo.LoadImage( File.ReadAllBytes(Directory.GetCurrentDirectory() + "/Assets/Khepri/Editor/" + khepriLogoFilename));
        khepriLogo.Apply();
        
        startKhepriLogo = new Texture2D(350,350);
        startKhepriLogo.LoadImage( File.ReadAllBytes(Directory.GetCurrentDirectory() + "/Assets/Khepri/Editor/" + startKhepriLogoFilename));
        startKhepriLogo.Apply();
            
        startKhepriNoNavigationLogo = new Texture2D(350,350);
        startKhepriNoNavigationLogo.LoadImage( File.ReadAllBytes(Directory.GetCurrentDirectory() + "/Assets/Khepri/Editor/" + startKhepriNoNavigationLogoFilename));
        startKhepriNoNavigationLogo.Apply();
        
        startNavigationLogo = new Texture2D(350,350);
        startNavigationLogo.LoadImage( File.ReadAllBytes(Directory.GetCurrentDirectory() + "/Assets/Khepri/Editor/" + startNavigationLogoFilename));
        startNavigationLogo.Apply();
        
        pauseSocketLogo = new Texture2D(350, 350);
        pauseSocketLogo.LoadImage( File.ReadAllBytes(Directory.GetCurrentDirectory() + "/Assets/Khepri/Editor/" + pauseSocketLogoFilename));
        pauseSocketLogo.Apply();

        var sun = GameObject.FindWithTag("Sun");
        if (sun != null) {
            directionalLightTransform = sun.transform;
            directionalLight = sun.GetComponent<Light>();
        } else {
            Debug.LogWarning("Khepri: Sun object not found. Directional light features will be unavailable.");
        }
        hasStarted = true;
    }
    /*AML
    public void Focus() {
        if (enableFocus && Selection.activeGameObject != gameObject) 
            Selection.activeGameObject = this.gameObject;
    }
    */
    private void Update() {
        sceneLoad?.Update();
    }
    /*AML
    private void OnDestroy() {
        EditorApplication.update -= Focus;
    }
    */
}
