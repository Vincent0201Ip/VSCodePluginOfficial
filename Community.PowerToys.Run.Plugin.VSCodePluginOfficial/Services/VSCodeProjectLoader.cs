using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Models;

namespace Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Services
{
    /// <summary>
    /// Service for loading VS Code project information from workspace storage.
    /// Supports both local and remote (SSH) projects with caching for improved performance.
    /// </summary>
    public class VSCodeProjectLoader
    {
        private readonly string _appDataPath;
        private readonly List<VSCodeProject> _cachedProjects = new();
        private DateTime _lastCacheUpdate = DateTime.MinValue;
        private const int CacheValidityMinutes = 5;

        public VSCodeProjectLoader()
        {
            _appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        }

        /// <summary>
        /// Loads all VS Code projects from workspace storage.
        /// Results are cached for 5 minutes to improve performance.
        /// </summary>
        /// <returns>A list of VS Code projects, sorted by last opened date (most recent first).</returns>
        public List<VSCodeProject> LoadProjects()
        {
            if (DateTime.Now.Subtract(_lastCacheUpdate).TotalMinutes < CacheValidityMinutes)
            {
                return _cachedProjects;
            }

            var projects = new List<VSCodeProject>();

            // Load from workspace storage (works reliably)
            try
            {
                projects.AddRange(LoadFromWorkspaceStorage());
            }
            catch (Exception)
            {
                // Ignore and continue
            }

            // Remove duplicates based on path (case-insensitive)
            var uniqueProjects = projects
                .GroupBy(p => p.Path.ToLowerInvariant())
                .Select(g => g.OrderByDescending(p => p.LastOpened).First())
                .OrderByDescending(p => p.LastOpened)
                .ToList();

            _cachedProjects.Clear();
            _cachedProjects.AddRange(uniqueProjects);
            _lastCacheUpdate = DateTime.Now;

            return _cachedProjects;
        }

        private List<VSCodeProject> LoadFromWorkspaceStorage()
        {
            var projects = new List<VSCodeProject>();
            var workspacePath = Path.Combine(_appDataPath, "Code", "User", "workspaceStorage");

            if (!Directory.Exists(workspacePath))
            {
                return projects;
            }

            try
            {
                var workspaceFolders = Directory.GetDirectories(workspacePath);
                
                foreach (var folder in workspaceFolders)
                {
                    var workspaceJsonPath = Path.Combine(folder, "workspace.json");
                    
                    if (File.Exists(workspaceJsonPath))
                    {
                        try
                        {
                            var json = File.ReadAllText(workspaceJsonPath);
                            dynamic workspaceData = JsonConvert.DeserializeObject(json);
                            
                            string folderUri = workspaceData?.folder;
                            if (string.IsNullOrEmpty(folderUri))
                                continue;
                            
                            // Parse the folder URI
                            string folderPath;
                            string projectType;
                            
                            if (folderUri.StartsWith("file://", StringComparison.OrdinalIgnoreCase))
                            {
                                // Local file URI: file:///c%3A/Users/Username/Projects/MyProject
                                folderPath = Uri.UnescapeDataString(folderUri.Substring(8)); // Remove "file:///"
                                folderPath = folderPath.Replace('/', '\\');
                                projectType = "local";
                                
                                // Verify local path exists
                                if (!Directory.Exists(folderPath))
                                    continue;
                            }
                            else if (folderUri.StartsWith("vscode-remote://", StringComparison.OrdinalIgnoreCase))
                            {
                                // Remote SSH URI: vscode-remote://ssh-remote%2Bhostname/path/to/project
                                folderPath = Uri.UnescapeDataString(folderUri);
                                projectType = "remote";
                            }
                            else
                            {
                                // Unknown format, skip
                                continue;
                            }
                            
                            // Extract project name
                            string name = workspaceData?.name;
                            if (string.IsNullOrEmpty(name))
                            {
                                // Get name from path
                                if (projectType == "local")
                                {
                                    name = new DirectoryInfo(folderPath).Name;
                                }
                                else
                                {
                                    // For remote, extract last part of path
                                    var pathParts = folderPath.Split('/');
                                    name = pathParts[pathParts.Length - 1];
                                }
                            }
                            
                            // Get last opened time
                            DateTime lastOpened;
                            if (projectType == "local" && Directory.Exists(folderPath))
                            {
                                lastOpened = Directory.GetLastWriteTime(folderPath);
                            }
                            else
                            {
                                // For remote, use workspace folder modification time
                                lastOpened = Directory.GetLastWriteTime(folder);
                            }
                            
                            projects.Add(new VSCodeProject
                            {
                                Name = projectType == "remote" ? $"{name} (Remote)" : name,
                                Path = folderPath,
                                LastOpened = lastOpened
                            });
                        }
                        catch (Exception)
                        {
                            continue;
                        }
                    }
                }
            }
            catch (Exception)
            {
                return new List<VSCodeProject>();
            }

            return projects;
        }

        private List<VSCodeProject> LoadFromRecentFiles()
        {
            var projects = new List<VSCodeProject>();
            var statePath = Path.Combine(_appDataPath, "Code", "User", "globalStorage", "state.vscdb");

            if (!File.Exists(statePath))
            {
                return projects;
            }

            try
            {
                // Read the SQLite database as binary and convert to string
                var content = File.ReadAllText(statePath, System.Text.Encoding.UTF8);
                
                if (string.IsNullOrEmpty(content))
                {
                    return projects;
                }
                
                // Try to find recently opened entries in the database
                // The database stores JSON data, look for patterns like:
                // - "history.recentlyOpenedPathsList"
                // - "openedPathsList" 
                // - "entries" with "folderUri" or "workspace"
                
                var patterns = new[] 
                { 
                    "history.recentlyOpenedPathsList",
                    "openedPathsList",
                    "recently.opened"
                };

                foreach (var pattern in patterns)
                {
                    var index = content.IndexOf(pattern, StringComparison.OrdinalIgnoreCase);
                    if (index == -1) continue;

                    // Extract JSON after the pattern (SQLite stores key-value pairs)
                    // Look for the JSON value that follows
                    var startIndex = content.IndexOf('{', index);
                    if (startIndex == -1) continue;

                    // Find the matching closing brace
                    var jsonContent = ExtractJsonObject(content, startIndex);
                    if (string.IsNullOrEmpty(jsonContent)) continue;

                    try
                    {
                        dynamic data = JsonConvert.DeserializeObject(jsonContent);
                        
                        if (data == null) continue;
                        
                        // Try different JSON structures
                        var entries = data?.entries ?? data?.workspaces;
                        
                        if (entries != null)
                        {
                            // Check if entries is enumerable
                            try
                            {
                                foreach (var entry in entries)
                                {
                                    try
                                    {
                                        if (entry == null) continue;
                                        
                                        var project = ParseProjectEntry(entry);
                                        if (project != null)
                                        {
                                            projects.Add(project);
                                        }
                                    }
                                    catch (Exception)
                                    {
                                        continue;
                                    }
                                }
                            }
                            catch (Exception)
                            {
                                // entries is not enumerable, skip
                                continue;
                            }
                        }
                        
                        // If we found projects, no need to check other patterns
                        if (projects.Count > 0)
                            break;
                    }
                    catch (Exception)
                    {
                        continue;
                    }
                }
            }
            catch (Exception)
            {
                return new List<VSCodeProject>();
            }

            return projects;
        }

        private string ExtractJsonObject(string content, int startIndex)
        {
            try
            {
                var braceCount = 0;
                var inString = false;
                var escapeNext = false;

                for (int i = startIndex; i < content.Length; i++)
                {
                    var c = content[i];

                    if (escapeNext)
                    {
                        escapeNext = false;
                        continue;
                    }

                    if (c == '\\')
                    {
                        escapeNext = true;
                        continue;
                    }

                    if (c == '"' && !escapeNext)
                    {
                        inString = !inString;
                        continue;
                    }

                    if (!inString)
                    {
                        if (c == '{')
                        {
                            braceCount++;
                        }
                        else if (c == '}')
                        {
                            braceCount--;
                            if (braceCount == 0)
                            {
                                return content.Substring(startIndex, i - startIndex + 1);
                            }
                        }
                    }
                }
            }
            catch (Exception)
            {
                return null;
            }

            return null;
        }

        private VSCodeProject ParseProjectEntry(dynamic entry)
        {
            if (entry == null)
                return null;
                
            try
            {
                // Try to extract folder path from various possible fields
                string folderUri = null;
                
                try
                {
                    folderUri = entry?.folderUri?.ToString() 
                        ?? entry?.workspace?.configPath?.ToString()
                        ?? entry?.configPath?.ToString()
                        ?? entry?.fsPath?.ToString();
                }
                catch (Exception)
                {
                    return null;
                }

                if (string.IsNullOrEmpty(folderUri))
                    return null;

                string folderPath;
                string projectType;
                string name = null;

                // Handle different URI formats
                if (folderUri.StartsWith("file:///", StringComparison.OrdinalIgnoreCase))
                {
                    // Local file URI: file:///c%3A/Users/Username/Projects/MyProject
                    folderPath = Uri.UnescapeDataString(folderUri.Substring(8));
                    folderPath = folderPath.Replace('/', '\\');
                    
                    // Handle Windows drive letters (c: -> C:\)
                    if (folderPath.Length >= 2 && folderPath[1] == ':')
                    {
                        folderPath = char.ToUpper(folderPath[0]) + folderPath.Substring(1);
                    }
                    
                    projectType = "local";
                    
                    // Verify local path exists
                    if (!Directory.Exists(folderPath))
                        return null;
                        
                    name = new DirectoryInfo(folderPath).Name;
                }
                else if (folderUri.StartsWith("vscode-remote://", StringComparison.OrdinalIgnoreCase))
                {
                    // Remote SSH URI: vscode-remote://ssh-remote+host/path/to/project
                    folderPath = Uri.UnescapeDataString(folderUri);
                    projectType = "remote";
                    
                    // Extract project name from remote path
                    var parts = folderPath.Split('/');
                    name = parts.Length > 0 ? parts[parts.Length - 1] : "Remote Project";
                }
                else
                {
                    // Try as direct path
                    folderPath = folderUri;
                    projectType = "local";
                    
                    if (Directory.Exists(folderPath))
                    {
                        name = new DirectoryInfo(folderPath).Name;
                    }
                    else
                    {
                        return null;
                    }
                }

                // Get label if provided
                try
                {
                    string label = entry?.label?.ToString();
                    if (!string.IsNullOrEmpty(label))
                    {
                        name = label;
                    }
                }
                catch (Exception)
                {
                    // Ignore label errors
                }

                // Get last opened time
                DateTime lastOpened = DateTime.Now;
                
                if (projectType == "local" && Directory.Exists(folderPath))
                {
                    lastOpened = Directory.GetLastWriteTime(folderPath);
                }
                
                // Check if entry has a timestamp
                try
                {
                    long? timestamp = entry?.timestamp;
                    if (timestamp.HasValue && timestamp.Value > 0)
                    {
                        // Convert JavaScript timestamp (milliseconds) to DateTime
                        lastOpened = DateTimeOffset.FromUnixTimeMilliseconds(timestamp.Value).LocalDateTime;
                    }
                }
                catch (Exception)
                {
                    // Use directory timestamp as fallback
                }

                return new VSCodeProject
                {
                    Name = projectType == "remote" ? $"{name} (Remote)" : name,
                    Path = folderPath,
                    LastOpened = lastOpened
                };
            }
            catch (Exception)
            {
                return null;
            }
        }

        /// <summary>
        /// Clears the cached project list, forcing a reload on the next call to LoadProjects.
        /// </summary>
        public void InvalidateCache()
        {
            _cachedProjects.Clear();
            _lastCacheUpdate = DateTime.MinValue;
        }
    }
}
