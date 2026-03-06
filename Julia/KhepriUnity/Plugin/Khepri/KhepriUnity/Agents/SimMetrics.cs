using System;
using System.IO;

public static class SimMetrics
{
    private static float duration = 0f;

    public static void UpdateMetric(float deltaTime)
    {
        duration += deltaTime;
    }

    public static float GetEvacuationTime()
    {
        return duration;
    }

    public static void WriteMetrics(string directoryPath)
    {
        //string directoryPath = @"C:\ExternalFolder"; // Specify your external folder path
        string filePath = Path.Combine(directoryPath, "results.txt");

        // Ensure the directory exists
        Directory.CreateDirectory(directoryPath);

        // Write to the file
        string metric = $"{duration}";
        File.WriteAllText(filePath, metric);
    }

    public static void ResetMetrics()
    {
        duration = 0f;
    }
}
