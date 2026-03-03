using UnityEngine;

public interface Movement
{
    void UpdateMovementSettings(float flySpeed, float walkSpeed, float lookSpeed, float gravityMultiplier,
        float maxFallSpeed, float playerRadius);
    
    bool GetCursorMode();

    void UpdateLaserSettings(float width, Color color);
}
