using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Architecture : MonoBehaviour
{
    public static Architecture instance = null;

    public GameObject wall;
    public GameObject floor;
    public GameObject cylColumn;
    public GameObject doorFrame;
    public GameObject floorPoints;

    private void Awake()
    {
        if (instance == null)
            instance = this;
        else if (instance != this)
            Destroy(gameObject);
    }

    public void CreateWall(Vector3 center, float rot, Vector3 scale)
    {
        GameObject wallInstance = Instantiate(wall, center, Quaternion.Euler(0, rot, 0));
        wallInstance.transform.localScale = scale;
    }

    public void CreateFloor(Vector3 center, float rot, Vector3 scale)
    {
        GameObject floorInstance = Instantiate(floor, center, Quaternion.Euler(0, rot, 0));
        floorInstance.transform.localScale = scale;
    }

    public void CreateFloorPoints(Vector2[] points, float heigth)
    {
        GameObject floorInstance = Instantiate(floorPoints);
        floorInstance.GetComponent<GenerateFloor>().Setup(points, heigth);
    }

    public void CreateCylColumn(Vector3 center, float rot, Vector3 scale)
    {
        GameObject CCInstance = Instantiate(cylColumn, center, Quaternion.Euler(0, rot, 0));
        CCInstance.transform.localScale = scale;
    }

    public void CreateDoorFrame(Vector3 center, float rot, Vector3 scale)
    {
        GameObject doorFrameInstance = Instantiate(doorFrame, center, Quaternion.Euler(0, rot, 0));
        doorFrameInstance.transform.localScale = scale;
    }
}
