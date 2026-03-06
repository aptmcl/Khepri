using UnityEngine;

public enum Mode { FreeFly, Walk }

public class PlayerMovement : MonoBehaviour, Movement {
	private float flySpeed = 2f;
	private float walkSpeed = 1f;
	private float lookSpeed = 10f;
	private float gravityMultiplier = -1.05f;
	private float maxFallSpeed = -6f;
	private float jumpHeight = 2f;
	private float playerHeight = 2f;
	private float slopeLimit = 45f;
	private float stepOffset = 0.3f;
	private float playerRadius = 0.5f;
	
	private bool cursorMode = true;
	private Mode playerMode;
	private float verticalSpeed = 1;
	private CharacterController characterController;
	private Transform cameraTransform;

	private void Awake() {
		characterController = GetComponent<CharacterController>();
		cameraTransform = Camera.main.transform;
		characterController.height = playerHeight;
		characterController.slopeLimit = slopeLimit;
		characterController.stepOffset = stepOffset;
		characterController.radius = playerRadius;
	}

	void Start() {
		//ToggleCursorMode();
		playerMode = Mode.FreeFly;
	}
 
	void Update () {
        float delta = Time.deltaTime * 10;
		float speedMul = Input.GetKey(KeyCode.LeftShift) ? 4 : 1;
		
		float rotationX = ((cameraTransform.rotation.eulerAngles.x + 90) % 360) - 90;
		float rotationY = ((cameraTransform.rotation.eulerAngles.y + 90) % 360) - 90;
		rotationX += -Input.GetAxis("Mouse Y") * lookSpeed * delta;
		rotationX = Mathf.Clamp(rotationX, -90, 90);
		rotationY += Input.GetAxis("Mouse X") * lookSpeed * delta;

        switch (playerMode) {
            case Mode.FreeFly:
                if (!cursorMode) {
                    transform.position += flySpeed * speedMul * delta * (cameraTransform.right * Input.GetAxis("Horizontal") + cameraTransform.forward * Input.GetAxis("Vertical"));

                    if (Input.GetKey(KeyCode.Space))
                        transform.position += flySpeed * speedMul * delta * Vector3.up;

                    if (Input.GetKey(KeyCode.LeftAlt))
                        transform.position -= flySpeed * speedMul * delta * Vector3.up;

                    cameraTransform.rotation = Quaternion.Euler(rotationX, rotationY, 0);
                }
                break;
            case Mode.Walk:
                if (!cursorMode) {
                    Vector3 forward = cameraTransform.forward;
                    forward.y = 0;
                    forward.Normalize();
                    Vector3 right = cameraTransform.right;
                    right.y = 0;
                    right.Normalize();
                    if (characterController.isGrounded && Input.GetKey(KeyCode.Space))
                        verticalSpeed = jumpHeight;
                    else if (characterController.isGrounded)
                        verticalSpeed = 0;
                    else {
                        verticalSpeed += gravityMultiplier * delta;
                        verticalSpeed = Mathf.Clamp(verticalSpeed, maxFallSpeed, jumpHeight * 2);
                    }
                    Vector3 gravityVector = new Vector3(0, verticalSpeed, 0);

                    Vector3 movement = walkSpeed * speedMul * delta * (right * Input.GetAxis("Horizontal") + forward * Input.GetAxis("Vertical")) + gravityVector * delta;
                    characterController.Move(movement);

                    cameraTransform.rotation = Quaternion.Euler(rotationX, rotationY, 0);
                }
                break;
        }
        KhepriUnity.Primitives khepri = KhepriUnity.Primitives.Instance;
        if (khepri != null && khepri.InSelectionProcess) {
			if (Input.GetMouseButtonDown(0)) {
                //Identify
                ToggleSelectedObject(khepri, Camera.main.ScreenPointToRay(Input.mousePosition));
			} else if (Input.GetKeyUp(KeyCode.Escape)) {
                //Force selection end
                khepri.InSelectionProcess = false;
            }
		}
        if (Input.GetKeyUp(KeyCode.LeftControl) || Input.GetKeyUp(KeyCode.Mouse1)) {
            ToggleCursorMode();
        } else if (Input.GetKeyUp(KeyCode.M)) {
            SwitchPlayerMode();
        } else if (Input.GetKeyUp(KeyCode.K)) {
            ToggleKhepri();
        } else if (Input.GetKeyUp(KeyCode.Q)) {
            Application.Quit();
        }
	}

    void ToggleSelectedObject(KhepriUnity.Primitives khepri, Ray ray) {
        RaycastHit hit;
        if (Physics.Raycast(ray, out hit)) {
            khepri.ToggleSelectedGameObject(hit.collider.gameObject);
            if (!khepri.SelectingManyGameObjects) {
                khepri.InSelectionProcess = false;
            }
        }
    }

    void ToggleKhepri() {
        SceneLoad.visualizing = ! SceneLoad.visualizing;
    }

	void ToggleCursorMode() {
		if (Cursor.lockState == CursorLockMode.Locked) {
            Cursor.lockState = CursorLockMode.None;
            cursorMode = true;
            Cursor.visible = true;
        } else {
            Cursor.lockState = CursorLockMode.Locked;
            cursorMode = false;
            Cursor.visible = false;
        }
	}

	void SwitchPlayerMode() {
		switch (playerMode) {
			case Mode.FreeFly:
				playerMode = Mode.Walk;
				break;
			case Mode.Walk:
				playerMode = Mode.FreeFly;
				break;
		}
	}

	public void UpdateMovementSettings(float flySpeed, float walkSpeed, float lookSpeed, float gravityMultiplier,
		float maxFallSpeed, float playerRadius) {
		this.flySpeed = flySpeed;
		this.walkSpeed = walkSpeed;
		this.lookSpeed = lookSpeed;
		this.gravityMultiplier = gravityMultiplier;
		this.maxFallSpeed = maxFallSpeed;
		this.playerRadius = playerRadius;

		if (characterController != null)
			characterController.radius = playerRadius;
	}

	public bool GetCursorMode() {
		return cursorMode;
	}
}
