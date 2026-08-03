// Auto-run support for Khepri Unity stress tests.
//
// Usage from CI:
//   Unity.exe -projectPath <path> -executeMethod KhepriAutoRunner.AutoStartListener
//
// This script:
//   1. Locates (or creates) the Khepri GameObject in the open scene.
//   2. Marks the Khepri instance to start the configured connection mode on
//      the next play-mode tick (`startKhepriOnLoad = true`).
//   3. Enters Play mode programmatically — the existing
//      `KhepriEditor.HandleStartStopKhepri` then calls `StartKhepri()` and the
//      default client mode connects to the Khepri socket server on port 12345.
//
// The script intentionally does NOT exit Play mode or quit Unity — the Julia
// harness drives those side effects (it sends a Disconnect/quit command after
// the test suite finishes, then `taskkill /IM Unity.exe`).

using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class KhepriAutoRunner {
    // Entry point for `-executeMethod KhepriAutoRunner.AutoStartListener`.
    // Returns immediately — the connection starts inside the next editor frame
    // when the play-mode transition completes.
    public static void AutoStartListener() {
        Debug.Log("[KhepriAutoRunner] Initiating listener startup...");

        // Make sure a scene with a Khepri object is loaded. If the project
        // is opened with no scene, we open the bundled BlankScene which
        // already has the Khepri GameObject + script wired.
        Khepri khepri = Object.FindAnyObjectByType<Khepri>();
        if (khepri == null) {
            string defaultScene = "Assets/Khepri/DefaultScene/BlankScene.unity";
            if (File.Exists(defaultScene)) {
                Debug.Log($"[KhepriAutoRunner] Opening default scene {defaultScene}");
                EditorSceneManager.OpenScene(defaultScene, OpenSceneMode.Single);
                khepri = Object.FindAnyObjectByType<Khepri>();
            }
        }
        if (khepri == null) {
            Debug.LogError("[KhepriAutoRunner] No Khepri GameObject found in scene and BlankScene missing.");
            EditorApplication.Exit(1);
            return;
        }

        // Hand over to the existing edit->play->start flow. `startKhepriOnLoad`
        // is checked by KhepriEditor.HandleStartStopKhepri once Play mode
        // actually engages, which calls SceneLoad.StartKhepri().
        khepri.startKhepriOnLoad = true;
        EditorApplication.EnterPlaymode();
        Debug.Log("[KhepriAutoRunner] EnterPlaymode requested; Khepri connection will start once Khepri.Start() runs.");
    }

    // Convenience menu item so the same code path is available interactively.
    [MenuItem("Khepri/Auto-Start Listener (CI)")]
    public static void AutoStartListenerMenu() => AutoStartListener();
}
