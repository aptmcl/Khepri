using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FreeFlyCamera : MonoBehaviour {

	public float FlySpeed = 0.2f;
	public float LookSpeed = 10f;

	void Start() {
		Cursor.visible = false;
	}
 
	void Update () {
		transform.position += (transform.right * Input.GetAxis("Horizontal") + transform.forward * Input.GetAxis("Vertical")) * FlySpeed;
		transform.eulerAngles += new Vector3(-Input.GetAxis("Mouse Y"), Input.GetAxis("Mouse X"), 0) * LookSpeed;
	}
}
