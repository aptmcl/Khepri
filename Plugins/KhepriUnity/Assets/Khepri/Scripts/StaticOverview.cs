using System.Collections.Generic;
using UnityEngine;

public class StaticOverview : MonoBehaviour {

    private class Trans {
        public Vector3 position = Vector3.zero;
        public Quaternion rotation = Quaternion.identity;
    }

    private static readonly Dictionary<KeyCode, int> PositionBindings = new Dictionary<KeyCode, int> {
        { KeyCode.Alpha0, 0 },
        { KeyCode.Alpha1, 1 },
        { KeyCode.Alpha2, 2 },
        { KeyCode.Alpha3, 3 },
        { KeyCode.Alpha4, 4 },
        { KeyCode.Alpha5, 5 },
        { KeyCode.Alpha6, 6 },
        { KeyCode.Alpha7, 7 },
        { KeyCode.Alpha8, 8 },
        { KeyCode.Alpha9, 9 }
    };

    private List<Trans> overviewsList = new List<Trans>();
    private Transform thisTransform;
    private Transform cameraTransform;
    private Movement movementScript;

    void Start() {
        thisTransform = transform;
        cameraTransform = Camera.main.transform;
        var player = GameObject.FindWithTag("Player");
        if (player != null) {
            movementScript = player.GetComponent<Movement>();
        } else {
            Debug.LogWarning("StaticOverview: Player not found. Overview functionality will be limited.");
        }

        for (int i = 0; i < 10; i++)
            overviewsList.Add(new Trans());

        // Default positions
        overviewsList[0] = new Trans() {
            position = new Vector3(-91, 126, 79),
            rotation = Quaternion.Euler(39f, 135f, 0f)
        };
        overviewsList[9] = new Trans() {
            position = new Vector3(-56, 19.5f, 15.7f),
            rotation = Quaternion.Euler(9, 122, 0f)
        };
    }

    void Update() {
        if (movementScript == null || movementScript.GetCursorMode())
            return;

        foreach (var binding in PositionBindings) {
            if (Input.GetKey(KeyCode.LeftShift)) {
                if (Input.GetKeyDown(binding.Key)) {
                    SavePosition(binding.Value);
                    break;
                }
            } else {
                if (Input.GetKeyUp(binding.Key)) {
                    LoadPosition(binding.Value);
                    break;
                }
            }
        }
    }

    private void SavePosition(int index) {
        Debug.Log($"Overview position bound to {index}.");
        overviewsList[index].position = thisTransform.position;
        overviewsList[index].rotation = cameraTransform.rotation;
    }

    private void LoadPosition(int index) {
        thisTransform.position = overviewsList[index].position;
        cameraTransform.rotation = overviewsList[index].rotation;
    }
}
