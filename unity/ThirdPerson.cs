using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ThirdPerson : MonoBehaviour
{
	public Transform playerCamera;
	public Animator a1;
	public float rotationSpeed = 3.0f;
	
	[Header("Movement")]
    public float moveSpeed = 5f;
    public float gravity = -12f;
    public float jumpHeight = 1.5f;
	public Transform characterMesh;
	
	private Quaternion x_rotation;
	private float rotation_input;
	private float frame_time = 0.0f;
	private Vector3 CamPosition;
	private float look_input;
	private float look_y = 0.0f;
	private CharacterController controller;
	private float verticalVelocity;
	private float cam_dist = 1.5f;
	private Vector3 move_vector;
	private bool sprint = false;
	
	
    // Start is called before the first frame update
    void Start()
    {
        x_rotation = transform.rotation;
		controller = GetComponent<CharacterController>();
    }

    // Update is called once per frame
    void Update()
    {
        frame_time = Time.deltaTime;
		
		float h = Input.GetAxisRaw("Horizontal");
        float v = Input.GetAxisRaw("Vertical");

        Vector3 input = new Vector3(h, 0f, v).normalized;

        // move relative to camera direction
        Vector3 camForward = playerCamera.forward;
        camForward.y = 0f;
        camForward.Normalize();

        Vector3 camRight = playerCamera.right;
        camRight.y = 0f;
        camRight.Normalize();
		

        Vector3 moveDir = camForward * input.z + camRight * input.x;

        if (controller.isGrounded)
        {
            verticalVelocity = -1f;
            if (Input.GetButtonDown("Jump"))
            {
                verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);
				a1.SetTrigger("Jump");
            }
			sprint = Input.GetButton("Sprint");
			
        }
        else
        {
            verticalVelocity += gravity * Time.deltaTime;
        }

        Vector3 velocity = moveDir * moveSpeed + Vector3.up * verticalVelocity;
        controller.Move(velocity * Time.deltaTime);

        // rotate character toward movement
        if (moveDir.sqrMagnitude > 0.01f && characterMesh)
        {
            Quaternion rot = Quaternion.LookRotation(moveDir, Vector3.up);
            characterMesh.rotation = Quaternion.Slerp(characterMesh.rotation, rot, 15.0f * Time.deltaTime);
        }
		
		
		
		rotation_input = Input.GetAxis("Mouse X") * rotationSpeed;
		look_input = Input.GetAxis("Mouse Y") * rotationSpeed * 0.9f; // Make vertical mouse look less sensitive.
		look_y -= look_input;
		look_y = Mathf.Clamp(look_y, -90.0f, 90.0f);
		x_rotation *= Quaternion.Euler(0, rotation_input, 0);
		Quaternion x2 = x_rotation * Quaternion.Euler(look_y, 0, 0);
		CamPosition = x2 * (-Vector3.forward + new Vector3(0.25f, 0, 0)) * cam_dist;
		playerCamera.position = transform.position + CamPosition + new Vector3(0, 0.5f, 0);
		playerCamera.rotation = x2;
		
		
		
		if (Physics.SphereCast(transform.position + new Vector3(0, 0.5f, 0), 0.2f, (playerCamera.position - (transform.position + new Vector3(0, 0.5f, 0))).normalized, out RaycastHit hit, 5.0f))
        {
            cam_dist = Mathf.Min(hit.distance - 0.02f, 1.5f);
        }
		
		//EngineTools.DebugDisplay.value1 = input.ToString();
		a1.SetFloat("Speed", input.magnitude);
		a1.SetBool("Sprint", sprint);
		
    }
	
	Vector3 ProjectOnPlane (Vector3 vector, Vector3 normal)
	{
		return vector - normal * (vector.x * normal.x + vector.y * normal.y + vector.z * normal.z);
	}
}
