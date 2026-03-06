using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UniqueID
{
    private int _uniqueID = 0;

    public int GetUniqueID()
    {
        return _uniqueID++;
    }

    public void ResetID()
    {
        _uniqueID = 0;
    }
}
