using System;
using System.IO;
using Newtonsoft.Json;

var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
var workspacePath = Path.Combine(appDataPath, "Code", "User", "workspaceStorage");

Console.WriteLine($"AppData: {appDataPath}");
Console.WriteLine($"Workspace path: {workspacePath}");
Console.WriteLine($"Exists: {Directory.Exists(workspacePath)}");

if (!Directory.Exists(workspacePath))
{
    Console.WriteLine("Workspace path does not exist!");
    return;
}

var folders = Directory.GetDirectories(workspacePath);
Console.WriteLine($"\nFound {folders.Length} workspace folders");

int processed = 0;
int success = 0;
int failed = 0;

foreach (var folder in folders.Take(5)) // Test first 5
{
    processed++;
    var workspaceJsonPath = Path.Combine(folder, "workspace.json");
    Console.WriteLine($"\n--- Folder {processed} ---");
    Console.WriteLine($"Path: {folder}");
    
    if (!File.Exists(workspaceJsonPath))
    {
        Console.WriteLine("No workspace.json");
        failed++;
        continue;
    }
    
    try
    {
        var json = File.ReadAllText(workspaceJsonPath);
        Console.WriteLine($"JSON: {json}");
        
        dynamic workspaceData = JsonConvert.DeserializeObject(json);
        string folderUri = workspaceData?.folder;
        
        Console.WriteLine($"Folder URI: {folderUri}");
        
        if (string.IsNullOrEmpty(folderUri))
        {
            Console.WriteLine("Empty folder URI");
            failed++;
            continue;
        }
        
        string folderPath;
        string projectType;
        
        if (folderUri.StartsWith("file://", StringComparison.OrdinalIgnoreCase))
        {
            folderPath = Uri.UnescapeDataString(folderUri.Substring(8));
            folderPath = folderPath.Replace('/', '\\');
            projectType = "local";
            
            Console.WriteLine($"Parsed as LOCAL: {folderPath}");
            Console.WriteLine($"Exists: {Directory.Exists(folderPath)}");
            
            if (!Directory.Exists(folderPath))
            {
                failed++;
                continue;
            }
        }
        else if (folderUri.StartsWith("vscode-remote://", StringComparison.OrdinalIgnoreCase))
        {
            folderPath = Uri.UnescapeDataString(folderUri);
            projectType = "remote";
            Console.WriteLine($"Parsed as REMOTE: {folderPath}");
        }
        else
        {
            Console.WriteLine("Unknown URI format");
            failed++;
            continue;
        }
        
        success++;
        Console.WriteLine($"✓ SUCCESS - Type: {projectType}");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"✗ ERROR: {ex.Message}");
        failed++;
    }
}

Console.WriteLine($"\n=== Summary ===");
Console.WriteLine($"Processed: {processed}");
Console.WriteLine($"Success: {success}");
Console.WriteLine($"Failed: {failed}");
