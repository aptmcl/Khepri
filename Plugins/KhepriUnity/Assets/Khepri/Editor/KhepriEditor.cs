using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityMeshSimplifier;

// Persistent polling — runs regardless of inspector visibility
[InitializeOnLoad]
public static class KhepriEditorPoller {
    private static Khepri cachedKhepri;

    static KhepriEditorPoller() {
        EditorApplication.update += Poll;
    }

    static void Poll() {
        // Drive the serve loop continuously (MonoBehaviour.Update only fires on events in edit mode)
        if (cachedKhepri == null)
            cachedKhepri = UnityEngine.Object.FindAnyObjectByType<Khepri>();
        cachedKhepri?.sceneLoad?.Update();

        if (KhepriUnity.Primitives.Instance == null) return;
        if (KhepriUnity.Primitives.requestEnterPlayMode) {
            KhepriUnity.Primitives.requestEnterPlayMode = false;
            EditorApplication.EnterPlaymode();
        }
        if (KhepriUnity.Primitives.requestExitPlayMode) {
            KhepriUnity.Primitives.requestExitPlayMode = false;
            EditorApplication.ExitPlaymode();
        }
    }
}

// TODO tooltips in GUIContent
[CustomEditor(typeof(Khepri))]
public class KhepriEditor : Editor {
    private static Khepri khepri; // Serializable container for data

    #region GUI Styles
    private GUIStyle greenBoldFont;
    private GUIStyle redBoldFont;
    private GUIStyle foldoutStyle;
    private GUIStyle foldoutStyle2;
    private GUIStyle buttonStyle;
    private GUIStyle buttonStyle2;
    private GUIStyle buttonStyle3;
    #endregion
    
    #region GUI Labels
    // TODO TOOLTIPS
    // Header
    private GUIContent khepriText = new GUIContent("Khepri", 
        "Hello curious fellow!");
    private GUIContent focusModeText = new GUIContent("Focus Mode",
        "If enabled, allows for this inspector to always stay on focus, but you won't be able to select other GameObjects in the Hierarchy View.");
    // Start / Stop Khepri Buttons
    private GUIContent startKhepriButtonText = new GUIContent("Start Khepri", 
        "Start up Khepri Unity connection with navigation.");
    private GUIContent stopKhepriButtonText = new GUIContent("Stop Khepri");
    private string startStopKhepriTooltip = "Start/stop Khepri with navigation.";
    private string startStopKhepriNoNavigationTooltip =
        "Start/stop Khepri without navigation for optimizations and scene management in editor. Useful at the last stages of the architectural design process.";
    private string startNavigationTooltip = "Start only navigation.";
    private string pauseResumeSocketTooltip = "Pause / Resume socket for slightly better performance without stopping Khepri. While socket is paused Unity cannot receive any Khepri commands until the socket resumes.";
    private GUIContent startKhepriEditorButtonText = new GUIContent("Start Khepri w/o Navigation",
        "Start Khepri without navigation for optimizations and scene management in editor.");
    private GUIContent pauseSocketButtonText = new GUIContent("Pause Socket",
        "Pause Khepri socket for better performance but cannot receive any commands from Khepri until resume.");
    private GUIContent resumeSocketButtonText = new GUIContent("Resume Socket", "Resumes socket. May reduce performance.");
    // Start / Stop Navigation Buttons
    private GUIContent startNavigation1ButtonText = new GUIContent("Start Navigation", 
        "This cannot be done while Khepri is running.");
    private GUIContent startNavigation2ButtonText = new GUIContent("Stop Khepri to enable Navigation", 
        "This cannot be done while Khepri is running.");
    private GUIContent stopNavigationButtonText = new GUIContent("Stop Navigation");
    // Scene Manager
    private GUIContent sceneManagerText = new GUIContent("Scene Manager");
    private GUIContent saveNewSceneButtonText = new GUIContent("Save in a New Scene");
    private GUIContent resetSceneButtonText = new GUIContent("Reset Scene");
    private GUIContent saveCurrentSceneButtonText = new GUIContent("Save Current Scene");
    private GUIContent openSceneButtonText = new GUIContent("Open Scene");
    // Optimization Settings
    private GUIContent optimizationSettingsText = new GUIContent("Optimization Settings",
        "Optimizes scene for navigation but might take a while to process.");
    private GUIContent combineButtonText = new GUIContent("Combine Meshes",
        "Combines all meshes in the Main Object into a single mesh for a better performance. WARNING: Not recommended with scenes with a lot of pointlights as it may degrade performance instead.");
    private GUIContent optimizeButtonText = new GUIContent("Optimize");
    // Toogles
    private GUIContent togglesText = new GUIContent("Toggles", 
        "Enable or disable settings.");
    // Materials
    private GUIContent enableMaterialsText = new GUIContent("Enable Materials");
    private GUIContent materialSettingsText = new GUIContent("Material Settings", 
        "Advanced settings.");
    private string[] optionsTextureQuality = {"Full Res", "Half Res", "Quarter Res", "Eighth Res"};
    private GUIContent textureQualityText = new GUIContent("Texture Quality");
    private string[] optionsAnisotropicFiltering = {"Disabled", "Per Texture", "Forced On"};
    private GUIContent anisotropicText = new GUIContent("Anisotropic Textures");
    private GUIContent textureStreamingText = new GUIContent("Texture Streaming");
    private GUIContent defaultMaterialButtonText = new GUIContent("Default Material Settings",
        "Return all settings to default settings.");
    // LOD
    private GUIContent enableLODText = new GUIContent("Enable Level of Detail", 
        "Enabling LOD may increase performance, specially on designs with complex meshes, but at the cost of slightly increasing generation time.");
    private GUIContent LODSettingsText = new GUIContent("LOD Settings");
    private GUIContent simplificationSettingsText = new GUIContent("Simplification Settings");
    private GUIContent preserveBorderEdgeText = new GUIContent("Preserve Border Edges");
    private GUIContent preserveSeamEdgeText = new GUIContent("Preserve UV Seam Edges");
    private GUIContent preserveUVFoldoverEdgeText = new GUIContent("Preserve UV Foldover Edges");
    private GUIContent agressivenessText = new GUIContent("Agressiveness",
        "The agressiveness of the mesh simplification. Higher number equals higher quality, but more expensive to run.");
    private GUIContent deleteLevelText = new GUIContent("X", "Deletes this LOD level.");
    private GUIContent screenRelativeHeightText = new GUIContent("Screen Relative Height",
        "The screen relative height to use for the transition.");
    private GUIContent LODQualityText = new GUIContent("Quality", 
        "The desired quality for this level.");
    private GUIContent LODCombineMeshesText = new GUIContent("Combine Meshes",
        "If all renderers and meshes under this level should be combined into one.");
    private GUIContent LODCastShadowText = new GUIContent("Casts Shadows");
    private GUIContent LODReceiveShadowText = new GUIContent("Receives Shadows");
    private GUIContent LODAddLevelText = new GUIContent("Add Level");
    private GUIContent defaultLODButtonText = new GUIContent("Default LOD Settings", 
            "Return all settings to default settings.");
    // Colliders
    private GUIContent enableCollidersText = new GUIContent("Enable Colliders");
    // Illumination Settings
    private GUIContent illuminationSettingsText = new GUIContent("Illumination Settings");
    // Day & Night
    private GUIContent dayNightSettingsText = new GUIContent("Day & Night Settings",
        "Sun position control.");
    private GUIContent realtimeDirectionalLightText = new GUIContent("Realtime Directional Light");
    private GUIContent advancedSunSettingsText = new GUIContent("Advanced Sun Settings",
        "If enabled, the sun position can be set based on give xyz rotation.");
    private GUIContent defaultSunButtonText = new GUIContent("Default Time", "Return time to default time.");
    // Scene Illumination
    private GUIContent sceneIlluminationSettingsText = new GUIContent("Scene Illumination Settings");
    private GUIContent enablePointlightText = new GUIContent("Enable Pointlights");
    private GUIContent enablePointlightShadowText = new GUIContent("Enable Pointlights Shadow");
    private GUIContent defaultIlluminationButtonText = new GUIContent("Default Illumination Settings");
    // Player Settings
    private GUIContent playerSettingsText = new GUIContent("Player");
    private GUIContent playerSettings2Text = new GUIContent("Player Settings");
    private GUIContent playerRadiusText = new GUIContent("Player Radius");
    private GUIContent playerWalkSpeedText = new GUIContent("Walk Speed");
    private GUIContent playerFlySpeedText = new GUIContent("Fly Speed");
    private GUIContent playerJumpHeightText = new GUIContent("Jump Height");
    private GUIContent playerCameraSensitivityText = new GUIContent("Camera Rotation Sensitivity");
    private GUIContent playerGravityMultiplierText = new GUIContent("Gravity Multiplier");
    private GUIContent playerMaxFallSpeedText = new GUIContent("Max Fall Speed");
    private GUIContent defaultPlayerButtonText = new GUIContent("Default Player Settings");
    // Selection Settings
    private GUIContent selectionSettingsText = new GUIContent("Selection Settings");
    private GUIContent highlightColorText = new GUIContent("Highlight Color");
    private GUIContent defaultSelectionText = new GUIContent("Default Selection Settings");
    // Navigation
    private GUIContent navigationSettingsText = new GUIContent("Navigation", "Navigation controls.");
    private GUIContent controlsText = new GUIContent("Controls");

    #endregion

    private static bool _callbacksRegistered = false;

    public void OnEnable() {
        khepri = (Khepri) target;
        if (!khepri.hasStarted)
            khepri.Start();

        if (!_callbacksRegistered) {
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
            _callbacksRegistered = true;
        }
    }

    public void OnDisable() {
        if (_callbacksRegistered) {
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
            _callbacksRegistered = false;
        }
    }

    private static void OnPlayModeStateChanged(PlayModeStateChange change) {
        if (khepri == null) return;

        switch (change) {
            case PlayModeStateChange.ExitingEditMode:
                EditorUtility.SetDirty(khepri);
                khepri.wasRunningBeforePlayMode = khepri.isKhepriRunning;
                StopKhepri();
                khepri.khepriWithNavigation = false;
                khepri.khepriWithoutNavigation = false;
                break;
            case PlayModeStateChange.EnteredEditMode:
                khepri.startKhepriOnLoad = false;
                khepri.startKhepriinPlaymode = false;
                if (khepri.wasRunningBeforePlayMode) {
                    khepri.wasRunningBeforePlayMode = false;
                    StartKhepri();
                }
                break;
            case PlayModeStateChange.ExitingPlayMode:
                khepri.wasRunningBeforePlayMode = khepri.isKhepriRunning;
                StopKhepri();
                khepri.khepriWithNavigation = false;
                khepri.khepriWithoutNavigation = false;
                break;
            case PlayModeStateChange.EnteredPlayMode:
                UpdateSettings();
                if (khepri.wasRunningBeforePlayMode) {
                    khepri.wasRunningBeforePlayMode = false;
                    StartKhepri();
                }
                break;
        }
    }

    // Draws UI
    public override void OnInspectorGUI() {
        //base.OnInspectorGUI();
        //EditorUtility.SetDirty(khepri);
        GenerateUIStyles();
        
        // Header
        GenerateHeaderUI();

        // Buttons
        //GenerateStartStopKhepriUI();
        //GenerateNavigateUI();
        GenerateKhepriButtonsUI();

        GenerateOptimizeUI();
        GenerateSaveResetSceneUI();

        // Toggles
        GUILayout.Space(10);
        GUILayout.Label(togglesText, EditorStyles.boldLabel);
        GenerateEnableMaterialsUI();
        GenerateEnableLODUI();
        GenerateEnableCollidersUI();

        // Illumination
        GUILayout.Space(10);
        GUILayout.Label(illuminationSettingsText, EditorStyles.boldLabel);
        GenerateDayNightUI();
        GenerateIlluminationUI();

        // Player Settings
        GUILayout.Space(10);
        GUILayout.Label(playerSettingsText, EditorStyles.boldLabel);
        GeneratePlayerUI();
        GenerateSelectionUI();

        GUILayout.Space(10);
        GUILayout.Label(navigationSettingsText, EditorStyles.boldLabel);
        GenerateNavigationUI();
    }
    
    #region UI Generations and Handler Methods
    void GenerateUIStyles() {
        greenBoldFont = new GUIStyle(GUI.skin.button);
        greenBoldFont.normal.textColor = new Color(0.01f,0.49f,0.31f);
        greenBoldFont.fontStyle = FontStyle.Bold;
        greenBoldFont.hover.textColor = new Color(0.01f,0.39f,0.25f);

        redBoldFont = new GUIStyle(GUI.skin.button);
        redBoldFont.normal.textColor = new Color(0.59f,0.09f,0.01f);
        redBoldFont.fontStyle = FontStyle.Bold;
        redBoldFont.hover.textColor = new Color(0.39f,0.06f,0.01f);
        
        foldoutStyle = new GUIStyle(EditorStyles.foldout);
        foldoutStyle.fontStyle = FontStyle.Bold;
        foldoutStyle.margin.left = 10;
        
        foldoutStyle2 = new GUIStyle(EditorStyles.foldout);
        foldoutStyle2.margin.left = 10;
        
        buttonStyle = new GUIStyle(GUI.skin.button);
        buttonStyle.fixedHeight = 30;
        buttonStyle.fixedWidth = 45;
        buttonStyle.alignment = TextAnchor.MiddleCenter;
        buttonStyle.margin = new RectOffset(5,0,5,5);
        buttonStyle.imagePosition = ImagePosition.ImageOnly;

        buttonStyle2 = new GUIStyle(buttonStyle);
        buttonStyle2.margin = new RectOffset(0,0,5,5);

        buttonStyle3 = new GUIStyle(buttonStyle);
        buttonStyle3.margin = new RectOffset(0,5,5,5);
    }
    void GenerateHeaderUI() {
        GUIStyle titleStyle = new GUIStyle();
        titleStyle.fontSize = 20;
        titleStyle.fontStyle = FontStyle.Bold;
        titleStyle.alignment = TextAnchor.UpperLeft;
        GUILayout.BeginHorizontal();
        var textDimensions = GUI.skin.label.CalcSize(focusModeText);
        EditorGUILayout.LabelField(khepriText, titleStyle, GUILayout.Width(EditorGUIUtility.currentViewWidth - (textDimensions.x + 60)));
        EditorGUILayout.LabelField(focusModeText, GUILayout.Width(textDimensions.x));
        khepri.enableFocus = EditorGUILayout.Toggle(khepri.enableFocus);

        GUILayout.EndHorizontal();
        GUILayout.Space(75);
        GUI.DrawTexture(new Rect(new Vector2((EditorGUIUtility.currentViewWidth - 100) / 2f, 0), new Vector2(100, 100)), khepri.khepriLogo, ScaleMode.ScaleAndCrop, true, 1.3f);
    }
    void GenerateStartStopKhepriUI() {
        GUILayout.BeginHorizontal();
        GUILayout.Space(((EditorGUIUtility.currentViewWidth - 240) / 2f));
        
        if (!khepri.isKhepriRunning) {
            if (GUILayout.Button(startKhepriButtonText, greenBoldFont, GUILayout.Height(60), GUILayout.Width(200))) {
                if (EditorApplication.isPlaying) {
                    khepri.startKhepriinPlaymode = true;
                    StartKhepri();
                }
                else {
                    khepri.startKhepriOnLoad = true;
                    EditorApplication.EnterPlaymode();
                }
            }
        }
        else {
            GUIStyle redFont = new GUIStyle(GUI.skin.button);
            redFont.normal.textColor = new Color(0.01f,0.49f,0.31f);
            redFont.fontStyle = FontStyle.Bold;
            redFont.hover.textColor = new Color(0.01f,0.39f,0.25f);
            
            if (GUILayout.Button(stopKhepriButtonText, redBoldFont, GUILayout.Height(60), GUILayout.Width(200))) {
                StopKhepri();
                if (EditorApplication.isPlaying && !khepri.startKhepriinPlaymode)
                    EditorApplication.ExitPlaymode();
            }
        }
        GUILayout.EndHorizontal();
        
        GUILayout.BeginHorizontal();
        GUILayout.Space(((EditorGUIUtility.currentViewWidth - 240) / 2f));
        if (!khepri.isKhepriRunning && !EditorApplication.isPlaying) {
            if (GUILayout.Button(startKhepriEditorButtonText, greenBoldFont, GUILayout.Height(20), GUILayout.Width(200))) {
                StartKhepri();
            }
        }
        GUILayout.EndHorizontal();

        GUILayout.BeginHorizontal();
        GUILayout.Space(((EditorGUIUtility.currentViewWidth - 240) / 2f));
        if (khepri.isKhepriRunning) {
            if (!SceneLoad.visualizing) {
                if (GUILayout.Button(pauseSocketButtonText, GUILayout.Height(20), GUILayout.Width(200))) {
                    SceneLoad.visualizing = true;
                    //khepri.sceneLoad.primitives.OptimizeParent();
                }
            }
            else {
                if (GUILayout.Button(resumeSocketButtonText, GUILayout.Height(20), GUILayout.Width(200))) {
                    SceneLoad.visualizing = false;
                }
            }
        }
        GUILayout.EndHorizontal();

        HandleStartStopKhepri();
    }
    void HandleStartStopKhepri() {
        if (khepri.startKhepriOnLoad) {
            if (EditorApplication.isPlaying) {
                khepri.startKhepriOnLoad = false;
                // This sets up Primitives with the correct settings
                // in case the socket is already with messages (which means when the connection is successful, the
                // primitive commands will be executed with the correct settings from the inspector)
                UpdateSettings();
                if (StartKhepri())
                    khepri.khepriWithNavigation = true;
            }
        }
    }
    void GenerateNavigateUI() {
        EditorGUI.BeginDisabledGroup(khepri.isKhepriRunning);
        GUILayout.BeginHorizontal();
        GUILayout.Space(((EditorGUIUtility.currentViewWidth - 240) / 2f));
        if (!EditorApplication.isPlaying) {
            GUIContent text = khepri.isKhepriRunning ? startNavigation2ButtonText : startNavigation1ButtonText;
            if (GUILayout.Button(text, GUILayout.Height(20), GUILayout.Width(200))) {
                EditorApplication.EnterPlaymode();
            }
        }
        else {
            if (GUILayout.Button(stopNavigationButtonText, GUILayout.Height(20), GUILayout.Width(200))) {
                EditorApplication.ExitPlaymode();
            }
        }
        GUILayout.EndHorizontal();
        EditorGUI.EndDisabledGroup();
    }
    static bool StartKhepri()
    {
        SceneLoad.visualizing = false;
        bool? success = khepri.sceneLoad?.StartKhepri();
        if (success != true) // this can either be false (if starting the server failed) or null (if sceneload wasn't initialized properly)
            return false;

        khepri.isKhepriRunning = true;
        EditorApplication.update += khepri.sceneLoad.Update;
        return true;
    }
    static void StopKhepri()
    {
        if (khepri.isKhepriRunning) {
            khepri.sceneLoad?.StopKhepri();
            khepri.isKhepriRunning = false;
            EditorApplication.update -= khepri.sceneLoad.Update;
        }
    }
    
    void GenerateKhepriButtonsUI() {
        GUILayout.BeginHorizontal();
        GUILayout.FlexibleSpace();

        // Start Khepri with navigation
        EditorGUI.BeginDisabledGroup(khepri.khepriWithoutNavigation);
        khepri.startKhepriToggle = GUILayout.Toggle(khepri.isKhepriRunning, new GUIContent(khepri.startKhepriLogo, startStopKhepriTooltip), buttonStyle);
        if (khepri.startKhepriToggle != khepri.isKhepriRunning) {
            if (khepri.isKhepriRunning) { // Stop Khepri
                StopKhepri();
                khepri.khepriWithNavigation = false;
                if (EditorApplication.isPlaying && !khepri.startKhepriinPlaymode) // if we start khepri with navigation, with should stop both aswell
                    EditorApplication.ExitPlaymode();
            }
            else { // Start Khepri
                if (EditorApplication.isPlaying) { // If navigation was already on while starting khepri
                    khepri.startKhepriinPlaymode = true;
                    if (StartKhepri())
                        khepri.khepriWithNavigation = true;
                }
                else { // If navigation is off, we should start navigation before starting khepri on this mode
                    khepri.startKhepriOnLoad = true;
                    EditorApplication.EnterPlaymode();
                }
            }
        }
        EditorGUI.EndDisabledGroup();
        
        // Pause socket (actually, this doesn't do much and I really wanna remove it...)
        EditorGUI.BeginDisabledGroup(!khepri.isKhepriRunning);
        khepri.pauseSocketToggle = GUILayout.Toggle(khepri.pauseSocketLastToggle, new GUIContent(khepri.pauseSocketLogo, pauseResumeSocketTooltip), buttonStyle2);

        if (khepri.pauseSocketToggle != khepri.pauseSocketLastToggle) {
            SceneLoad.visualizing = khepri.pauseSocketToggle;
            khepri.pauseSocketLastToggle = khepri.pauseSocketToggle;
        }
        EditorGUI.EndDisabledGroup();

        // Start Khepri without navigation
        EditorGUI.BeginDisabledGroup(khepri.khepriWithNavigation);
        khepri.startKhepriNoNavigationToggle = GUILayout.Toggle(khepri.isKhepriRunning, new GUIContent(khepri.startKhepriNoNavigationLogo, startStopKhepriNoNavigationTooltip), buttonStyle2);
        if (khepri.startKhepriNoNavigationToggle != khepri.isKhepriRunning) {
            if (khepri.isKhepriRunning) {
                StopKhepri();
                khepri.khepriWithoutNavigation = false;
            }
            else {
                if (StartKhepri())
                    khepri.khepriWithoutNavigation = true;
            }
        }
        EditorGUI.EndDisabledGroup();

        // Start navigation
        khepri.startNavigationToogle = GUILayout.Toggle(EditorApplication.isPlaying,
            new GUIContent(khepri.startNavigationLogo, startNavigationTooltip), buttonStyle3);
        if (khepri.startNavigationToogle != EditorApplication.isPlaying) {
            if (!EditorApplication.isPlaying)
                EditorApplication.EnterPlaymode();
            else
                EditorApplication.ExitPlaymode();
        }

        GUILayout.FlexibleSpace();
        GUILayout.EndHorizontal();
        
        HandleStartStopKhepri();
    }
    void GenerateSaveResetSceneUI() {
        GUILayout.Space(10);
        EditorGUI.BeginDisabledGroup(khepri.isKhepriRunning);
        EditorGUI.BeginDisabledGroup(EditorApplication.isPlaying);
        GUILayout.Label(sceneManagerText, EditorStyles.boldLabel);
        
        GUILayout.BeginHorizontal();
        khepri.sceneName = GUILayout.TextField(khepri.sceneName, GUILayout.MinWidth(200));
        if (GUILayout.Button(saveNewSceneButtonText)) {
            EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene(), "Assets/Scenes/" + khepri.sceneName + ".unity", true);
            EditorSceneManager.OpenScene("Assets/Scenes/" + khepri.sceneName + ".unity", OpenSceneMode.Single);
        }
        GUILayout.EndHorizontal();
        
        GUILayout.BeginHorizontal();
        if (GUILayout.Button(resetSceneButtonText)) {
            string name = EditorSceneManager.GetActiveScene().name;
            EditorSceneManager.OpenScene("Assets/Khepri/DefaultScene/BlankScene.unity", OpenSceneMode.Single);
            EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene(), "Assets/Scenes/" + name  + ".unity", true);
            EditorSceneManager.OpenScene("Assets/Scenes/" + name + ".unity", OpenSceneMode.Single);
        }

        if (GUILayout.Button(saveCurrentSceneButtonText)) {
            EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        }
        GUILayout.EndHorizontal();

        if (GUILayout.Button(openSceneButtonText)) {
            string path = EditorUtility.OpenFilePanel("Open Scene", "Assets/Scenes", "unity");
            if (path.Length != 0) {
                EditorSceneManager.OpenScene(path, OpenSceneMode.Single);
            }
        }
        EditorGUI.EndDisabledGroup();
        EditorGUI.EndDisabledGroup();
    }
    void GenerateOptimizeUI() {
        GUILayout.Space(10);
        GUILayout.Label(optimizationSettingsText, EditorStyles.boldLabel);
        EditorGUI.BeginChangeCheck();
        if (!khepri.optimized)
            khepri.enableMeshCombine = GUILayout.Toggle(khepri.enableMeshCombine, combineButtonText);
        if (GUILayout.Button(optimizeButtonText)) {
            khepri.sceneLoad?.primitives.OptimizeParent();
            khepri.optimized = true;
        }
        if (EditorGUI.EndChangeCheck())
            HandleOptimize();
    }
    static void HandleOptimize() {
        khepri.sceneLoad?.primitives.SetEnableMergeParent(khepri.enableMeshCombine);
    }
    void GenerateEnableMaterialsUI() {
        EditorGUI.BeginChangeCheck();
        khepri.enableMaterials = EditorGUILayout.Toggle(enableMaterialsText, khepri.enableMaterials);
        EditorGUI.BeginDisabledGroup(!khepri.enableMaterials);
        GUILayout.BeginVertical("HelpBox");
        khepri.materialSettingsFoldout = EditorGUILayout.Foldout(khepri.materialSettingsFoldout, materialSettingsText, foldoutStyle);
        if (khepri.materialSettingsFoldout && khepri.enableMaterials) {
            // Texture Quality
            khepri.textureQualitySelected = EditorGUILayout.Popup(textureQualityText, khepri.textureQualitySelected,
                optionsTextureQuality);
            // Anisotropic Filtering
            khepri.anisotropicFilteringSelected = EditorGUILayout.Popup(anisotropicText,
                khepri.anisotropicFilteringSelected, optionsAnisotropicFiltering);
            // Texture Streaming
            khepri.enableTextureStreaming =
                EditorGUILayout.Toggle(textureStreamingText, khepri.enableTextureStreaming);

            if (GUILayout.Button(defaultMaterialButtonText)) {
                ResetEnableMaterials();
            }
        }

        EditorGUI.EndDisabledGroup();
        GUILayout.EndVertical();

        if (EditorGUI.EndChangeCheck())
            HandleEnableMaterials();
    }
    static void HandleEnableMaterials() {
        khepri.sceneLoad?.primitives.SetApplyMaterials(khepri.enableMaterials);
        if (khepri.enableMaterials) {
            QualitySettings.globalTextureMipmapLimit = khepri.textureQualitySelected;

            AnisotropicFiltering filtering;
            if (khepri.anisotropicFilteringSelected == 0)
                filtering = AnisotropicFiltering.Disable;
            else if (khepri.anisotropicFilteringSelected == 1)
                filtering = AnisotropicFiltering.Enable;
            else
                filtering = AnisotropicFiltering.ForceEnable;
            QualitySettings.anisotropicFiltering = filtering;

            QualitySettings.streamingMipmapsActive = khepri.enableTextureStreaming;
        }
        else {
            QualitySettings.globalTextureMipmapLimit = 3;
            QualitySettings.anisotropicFiltering = AnisotropicFiltering.Disable;
        }
    }
    void ResetEnableMaterials() {
        khepri.textureQualitySelected = khepri.defaultTextureQualitySelected;
        khepri.anisotropicFilteringSelected = khepri.defaultAnisotropicFilteringSelected;
        khepri.enableTextureStreaming = khepri.defaultEnableTextureStreaming;
    }
    void GenerateEnableLODUI() {
        EditorGUI.BeginChangeCheck();
        khepri.enableLOD = EditorGUILayout.Toggle(enableLODText, khepri.enableLOD);

        EditorGUI.BeginDisabledGroup(!khepri.enableLOD);
        GUILayout.BeginVertical("HelpBox");
        khepri.lodSettingsFoldout = EditorGUILayout.Foldout(khepri.lodSettingsFoldout, LODSettingsText, foldoutStyle);
        if (khepri.lodSettingsFoldout && khepri.enableLOD) {
            /*string[] optionsFadeMode =
                {"None", "Cross Fade", "Speed Tree"};
            khepri.fadeModeSelected = EditorGUILayout.Popup(new GUIContent("Fade Mode"),
                khepri.fadeModeSelected, optionsFadeMode);

            bool hasCrossFade = (khepri.fadeModeSelected == 1 || khepri.fadeModeSelected == 2);
            if (hasCrossFade) {
                khepri.enableAnimateCrossfade = GUILayout.Toggle(khepri.enableAnimateCrossfade,
                    new GUIContent("Animate Crossfading"));
            }*/

            khepri.simplificationFoldout = EditorGUILayout.Foldout(khepri.simplificationFoldout,
                simplificationSettingsText, foldoutStyle2);
            if (khepri.simplificationFoldout) {
                ++EditorGUI.indentLevel;

                khepri.preserveBorderEdge = EditorGUILayout.Toggle(preserveBorderEdgeText,
                    khepri.preserveBorderEdge);
                khepri.preserveUVSeamEdge = EditorGUILayout.Toggle(preserveSeamEdgeText,
                    khepri.preserveUVSeamEdge);
                khepri.preserveUVFoldoverEdge = EditorGUILayout.Toggle(preserveUVFoldoverEdgeText,
                    khepri.preserveUVFoldoverEdge);
                khepri.simplificationAgressiveness = EditorGUILayout.IntField(agressivenessText,
                    khepri.simplificationAgressiveness);

                --EditorGUI.indentLevel;
            }
            
            for (int i = 0; i < khepri.numLevels; i++) {
               GenerateLevelUI(i);
            }
            
            if (GUILayout.Button(LODAddLevelText)) {
                float lastLevelScreenHeight;
                float lastQuality;
                if (khepri.numLevels != 0) {
                    lastLevelScreenHeight =
                        khepri.screenRelativeHeightList[khepri.screenRelativeHeightList.Count - 1];
                    lastQuality = khepri.qualityList[khepri.screenRelativeHeightList.Count - 1];
                }
                else {
                    lastLevelScreenHeight = 1f;
                    lastQuality = 2f;
                }

                khepri.numLevels++;
                khepri.screenRelativeHeightList.Add(lastLevelScreenHeight * 0.5f);
                khepri.qualityList.Add(lastQuality * 0.5f);
                khepri.combineMeshesList.Add(true);
                khepri.castShadowList.Add(true);
                khepri.receiveShadowList.Add(true);
            }

            if (GUILayout.Button(defaultLODButtonText)) {
                ResetEnableLOD();
            }
        }

        GUILayout.EndVertical();
        EditorGUI.EndDisabledGroup();

        if (EditorGUI.EndChangeCheck())
            HandleEnableLOD();
    }
    void GenerateLevelUI(int index) {
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        
        EditorGUILayout.BeginHorizontal(EditorStyles.helpBox);
        GUILayout.Label(string.Format("Level {0}", index + 1), EditorStyles.boldLabel);
        //var previousBackgroundColor = GUI.backgroundColor;
        //GUI.backgroundColor = new Color(1f, 0.6f, 0.6f, 1f);
        if (GUILayout.Button(deleteLevelText, GUILayout.Width(20f))) {
            khepri.numLevels--;
            khepri.screenRelativeHeightList.RemoveAt(index);
            khepri.qualityList.RemoveAt(index);
            khepri.combineMeshesList.RemoveAt(index);
            khepri.castShadowList.RemoveAt(index);
            khepri.receiveShadowList.RemoveAt(index);
            GUIUtility.ExitGUI();
        }
        //GUI.backgroundColor = previousBackgroundColor;
        EditorGUILayout.EndHorizontal();
        
        ++EditorGUI.indentLevel;
        khepri.screenRelativeHeightList[index] = EditorGUILayout.Slider(screenRelativeHeightText, khepri.screenRelativeHeightList[index], 0f, 1f);
        khepri.qualityList[index] = EditorGUILayout.Slider(LODQualityText, khepri.qualityList[index], 0f, 1f);
        khepri.combineMeshesList[index] = EditorGUILayout.Toggle(LODCombineMeshesText, 
            khepri.combineMeshesList[index]);
        khepri.castShadowList[index] = EditorGUILayout.Toggle(LODCastShadowText, khepri.castShadowList[index]);
        khepri.receiveShadowList[index] = EditorGUILayout.Toggle(LODReceiveShadowText, khepri.receiveShadowList[index]);
        --EditorGUI.indentLevel;
        EditorGUILayout.EndVertical();
    }
    static void HandleEnableLOD() {
        khepri.sceneLoad?.primitives.SetApplyLOD(khepri.enableLOD);
        List<LODLevel> lodLevels = new List<LODLevel>();
        for (int i = 0; i < khepri.numLevels; i++) {
            lodLevels.Add(new LODLevel(khepri.screenRelativeHeightList[i], khepri.qualityList[i]) {
                CombineMeshes = khepri.combineMeshesList[i], CombineSubMeshes = khepri.combineMeshesList[i],
                ShadowCastingMode = khepri.castShadowList[i]? ShadowCastingMode.On : ShadowCastingMode.Off, 
                ReceiveShadows = khepri.receiveShadowList[i],
                SkinQuality = SkinQuality.Auto,
                SkinnedMotionVectors = true,
                LightProbeUsage = LightProbeUsage.BlendProbes,
                ReflectionProbeUsage = ReflectionProbeUsage.BlendProbes
            });
        }
        khepri.sceneLoad?.primitives.SetLODLevels(lodLevels.ToArray());

        SimplificationOptions simplificationOptions = new SimplificationOptions() {
            Agressiveness = khepri.simplificationAgressiveness,
            EnableSmartLink = true,
            MaxIterationCount = 100,
            PreserveBorderEdges = khepri.preserveBorderEdge,
            PreserveUVFoldoverEdges = khepri.preserveUVFoldoverEdge,
            PreserveUVSeamEdges = khepri.preserveUVSeamEdge,
            VertexLinkDistance = Double.Epsilon
        };
        khepri.sceneLoad?.primitives.SetLODSimplificationOptions(simplificationOptions);

    }
    void ResetEnableLOD() {
        khepri.fadeModeSelected = khepri.defaultFadeModeSelected;
        khepri.enableAnimateCrossfade = khepri.defaultEnableAnimateCrossfade;
        khepri.preserveBorderEdge = khepri.defaultPreserveBorderEdge;
        khepri.preserveUVSeamEdge = khepri.defaultPreserveUVSeamEdge;
        khepri.preserveUVFoldoverEdge = khepri.defaultPreserveUVFoldoverEdge;
        khepri.simplificationAgressiveness = khepri.defaultSimplicationAgressiveness;
        khepri.numLevels = khepri.defaultNumLevels;
        khepri.screenRelativeHeightList = new List<float>(khepri.defaultScreenRelativeHeightList);
        khepri.qualityList = new List<float>(khepri.defaultQualityList);
        khepri.combineMeshesList = new List<bool>(khepri.defaultCombineMeshesList);
        khepri.castShadowList = new List<bool>(khepri.defaultCastShadowList);
        khepri.receiveShadowList = new List<bool>(khepri.defaultReceiveShadowList);
    }
    void GenerateEnableCollidersUI() {
        khepri.enableColliders = EditorGUILayout.Toggle(enableCollidersText, khepri.enableColliders);
    }
    static void HandleEnableCollider() {
        khepri.sceneLoad?.primitives.SetApplyColliders(khepri.enableColliders);
    }
    void GenerateDayNightUI() {
        EditorGUI.BeginChangeCheck();
        GUILayout.BeginVertical("HelpBox");
        khepri.dayNightSettingsFoldout = EditorGUILayout.Foldout(khepri.dayNightSettingsFoldout,
            dayNightSettingsText, foldoutStyle);
        if (khepri.dayNightSettingsFoldout) {
            EditorGUI.BeginDisabledGroup(EditorApplication.isPlaying);
            khepri.realTimeDirectionalLight =
                EditorGUILayout.Toggle(realtimeDirectionalLightText, khepri.realTimeDirectionalLight);
            EditorGUI.EndDisabledGroup();

            EditorGUI.BeginDisabledGroup(!khepri.realTimeDirectionalLight);
            khepri.enableAdvancedSunSettings = 
                EditorGUILayout.Toggle(advancedSunSettingsText, khepri.enableAdvancedSunSettings);
            if (!khepri.enableAdvancedSunSettings) {
                GUILayout.BeginHorizontal();
                int hour = (int) khepri.dayTime / 60;
                int minutes = (int) (((khepri.dayTime / 60) - hour) * 60);
                GUILayout.Label(hour.ToString("00") + ":" + minutes.ToString("00"), GUILayout.MaxWidth(50));

                // Slider works on multiple of 5 except 23:59h
                khepri.dayTime = Math.Min(Mathf.Round(GUILayout.HorizontalSlider(khepri.dayTime, 0, 1439) / 5f) * 5,
                    1439);
                GUILayout.EndHorizontal();  
            }
            else {
                khepri.sunX = EditorGUILayout.Slider(new GUIContent("X"), khepri.sunX, 0f, 359);
                khepri.sunY = EditorGUILayout.Slider(new GUIContent("Y"), khepri.sunY, 0f, 359);
                //khepri.sunZ = EditorGUILayout.Slider(new GUIContent("Z"), khepri.sunZ, 0f, 359);
            }

            if (GUILayout.Button(defaultSunButtonText)) {
                ResetDayNight();
            }

            EditorGUI.EndDisabledGroup();
        }
        GUILayout.EndVertical();
        if (EditorGUI.EndChangeCheck())
            HandleDayNight();
    }
    static void HandleDayNight() {
        if (khepri.directionalLight != null)
                khepri.directionalLight.lightmapBakeType = khepri.realTimeDirectionalLight
                    ? LightmapBakeType.Realtime
                    : LightmapBakeType.Baked;

        if (khepri.realTimeDirectionalLight) {
            if (!khepri.enableAdvancedSunSettings)
                //khepri.directionalLightTransform.rotation = Quaternion.Euler((270 + khepri.dayTime / 4) % 360,
                //    khepri.directionalLightTransform.rotation.y, khepri.directionalLightTransform.rotation.z);
                khepri.sceneLoad?.primitives.SetSun((270 + khepri.dayTime / 4) % 360, 0); // Uni dimensional sun path
            else 
                khepri.sceneLoad?.primitives.SetSun(khepri.sunX, khepri.sunY);
        }
            
    }
    void ResetDayNight() {
        khepri.realTimeDirectionalLight = khepri.defaultRealTimeDirectionalLight;
        khepri.dayTime = khepri.defaultDayTime;
        khepri.enableAdvancedSunSettings = khepri.defaultEnableAdvancedSunSettings;
        khepri.sunX = khepri.defaultSunX;
        khepri.sunY = khepri.defaultSunY;
    }
    void GenerateIlluminationUI() {
        EditorGUI.BeginChangeCheck();
        GUILayout.BeginVertical("HelpBox");
        khepri.sceneIlluminationSettingsFoldout = EditorGUILayout.Foldout(khepri.sceneIlluminationSettingsFoldout,
            sceneIlluminationSettingsText, foldoutStyle);
        if (khepri.sceneIlluminationSettingsFoldout) {
            // Pointlights
            khepri.enablePointlights = EditorGUILayout.Toggle(enablePointlightText, khepri.enablePointlights);
            // Pointlights Shadow
            khepri.enablePointlightsShadows = EditorGUILayout.Toggle(enablePointlightShadowText, khepri.enablePointlightsShadows);

            if (GUILayout.Button(defaultIlluminationButtonText)) {
                ResetIllumination();
            }
        }
        GUILayout.EndVertical();
        if (EditorGUI.EndChangeCheck())
            HandleIllumination();
    }
    static void HandleIllumination() {
        khepri.sceneLoad?.primitives.SetEnableLights(khepri.enablePointlights);
        khepri.sceneLoad?.primitives.SetEnablePointLightsShadow(khepri.enablePointlightsShadows);
        // RenderSettings.ambient*/reflection* APIs are non-functional under HDRP.
        // Ambient and reflection settings are managed through HDRP Volume profiles.
    }
    void ResetIllumination() {
        khepri.enablePointlights = khepri.defaultEnablePointlights;
        khepri.enablePointlightsShadows = khepri.defaultEnablePointlightsShadows;
    }
    void GeneratePlayerUI() {
        EditorGUI.BeginChangeCheck();
        GUILayout.BeginVertical("HelpBox");
        khepri.playerSettingsFoldout = EditorGUILayout.Foldout(khepri.playerSettingsFoldout, playerSettings2Text, foldoutStyle);
        if (khepri.playerSettingsFoldout) {
            khepri.playerRadius = EditorGUILayout.FloatField(playerRadiusText, khepri.playerRadius);
            khepri.playerWalkSpeed = EditorGUILayout.FloatField(playerWalkSpeedText, khepri.playerWalkSpeed);
            khepri.playerFlySpeed = EditorGUILayout.FloatField(playerFlySpeedText, khepri.playerFlySpeed);
            khepri.playerJumpHeight = EditorGUILayout.FloatField(playerJumpHeightText, khepri.playerJumpHeight);
            khepri.playerLookSpeed = EditorGUILayout.FloatField(playerCameraSensitivityText, khepri.playerLookSpeed);
            khepri.playerGravityMultiplier = EditorGUILayout.FloatField(playerGravityMultiplierText, khepri.playerGravityMultiplier);
            khepri.playerMaxFallSpeed = EditorGUILayout.FloatField(playerMaxFallSpeedText, khepri.playerMaxFallSpeed);
            
            if (GUILayout.Button(defaultPlayerButtonText)) {
                ResetPlayer();
            }
        }
        GUILayout.EndVertical();

        if (EditorGUI.EndChangeCheck())
            HandlePlayer();
    }
    static void HandlePlayer() {
        var player = GameObject.FindWithTag("Player");
        if (player != null) {
            var movement = player.GetComponent<Movement>();
            if (movement != null) {
                movement.UpdateMovementSettings(khepri.playerFlySpeed,
                    khepri.playerWalkSpeed, khepri.playerLookSpeed, khepri.playerGravityMultiplier,
                    khepri.playerMaxFallSpeed, khepri.playerRadius);
            }
        }
    }
    void ResetPlayer() {
        khepri.playerRadius = khepri.defaultPlayerRadius;
        khepri.playerWalkSpeed = khepri.defaultPlayerWalkSpeed;
        khepri.playerFlySpeed = khepri.defaultPlayerFlySpeed;
        khepri.playerJumpHeight = khepri.defaultPlayerJumpHeight;
        khepri.playerLookSpeed = khepri.defaultPlayerLookSpeed;
        khepri.playerGravityMultiplier = khepri.defaultPlayerGravityMultiplier;
        khepri.playerMaxFallSpeed = khepri.defaultPlayerMaxFallSpeed;
    }
    void GenerateSelectionUI() {
        EditorGUI.BeginChangeCheck();
        GUILayout.BeginVertical("HelpBox");
        khepri.selectionSettingsFoldout = EditorGUILayout.Foldout(khepri.selectionSettingsFoldout, selectionSettingsText, foldoutStyle);
        if (khepri.selectionSettingsFoldout) {
            khepri.highlightColor = EditorGUILayout.ColorField(highlightColorText, khepri.highlightColor);

            if (GUILayout.Button(defaultSelectionText)) {
                ResetSelection();
            }
        }

        GUILayout.EndVertical();
        if (EditorGUI.EndChangeCheck())
            HandleSelection();
    }
    static void HandleSelection() {
        khepri.sceneLoad?.primitives.SetHighlightColor(khepri.highlightColor);
    }
    void ResetSelection() {
        khepri.highlightColor = khepri.defaultHighlightColor;
    }
    void GenerateNavigationUI() {
        GUILayout.BeginVertical("HelpBox");
        khepri.navigationControlsFoldout = EditorGUILayout.Foldout(khepri.navigationControlsFoldout, controlsText, foldoutStyle);
        if (khepri.navigationControlsFoldout) {
            GUILayout.Label("Keyboard", EditorStyles.boldLabel);
            GUILayout.Label("Movement: A W S D");
            GUILayout.Label("Camera: MOUSE");
            GUILayout.Label("Turbo: SHIFT");
            GUILayout.Label("Move Upwards: SPACE");
            GUILayout.Label("Move Downwards: ALT");
            GUILayout.Label("Change Navigation Mode: M");
            GUILayout.Label("Change Cursor Mode: RMB / CTRL");
            GUILayout.Label("Static Overview Save Position: SHIFT + [0-9]");
            GUILayout.Label("Static Overview View Position: [0-9]");
            GUILayout.Label("Select Object: LMB");
            
            GUILayout.Space(10);
            GUILayout.Label("VR - Oculus Touch", EditorStyles.boldLabel);
            GUILayout.Label("Movement: RIGHT JOYSTICK");
            GUILayout.Label("Camera: LEFT JOYSTICK");
            GUILayout.Label("Turbo: RIGHT TRIGGER");
            GUILayout.Label("Move Upwards: RIGHT JOYSTICK PRESS");
            GUILayout.Label("Move Downwards: LEFT JOYSTICK PRESS");
            GUILayout.Label("Change Navigation Mode: A");
            GUILayout.Label("Toogle Selection Laser: LEFT GRIP / RIGHT GRIP");
            GUILayout.Label("Select Object: LEFT TRIGGER / RIGHT TRIGGER (while holding LEFT GRIP / RIGHT GRIP)");
        }
        GUILayout.EndVertical();
    }
    static void UpdateSettings() {
        HandleEnableLOD();
        HandleEnableCollider();
        HandleEnableMaterials();
        HandleIllumination();
        HandleOptimize();
        HandlePlayer();
        HandleSelection();
        HandleDayNight();
    }
    void ResetSettings() {
        khepri.materialSettingsFoldout = false;
        khepri.dayNightSettingsFoldout = false;
        khepri.sceneIlluminationSettingsFoldout = false;
        khepri.lodSettingsFoldout = false;
        khepri.simplificationFoldout = false;
        khepri.playerSettingsFoldout = false;
        khepri.navigationControlsFoldout = false;
        khepri.selectionSettingsFoldout = false;

        khepri.enableMeshCombine = khepri.defaultEnableMeshCombine;

        khepri.enableMaterials = true;
        ResetEnableMaterials();
        khepri.enableLOD = false;
        ResetEnableLOD();
        khepri.enableColliders = true;
        ResetDayNight();
        ResetIllumination();
        ResetPlayer();
        ResetSelection();
    }
    #endregion
}
