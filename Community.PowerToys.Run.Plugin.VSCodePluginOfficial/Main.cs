using ManagedCommon;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows;
using System.Windows.Input;
using Wox.Plugin;
using Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Models;
using Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Services;

namespace Community.PowerToys.Run.Plugin.VSCodePluginOfficial;

/// <summary>
/// Main class of this plugin that implement all used interfaces.
/// </summary>
public class Main : IPlugin, IContextMenu, IDisposable
{
    /// <summary>
    /// ID of plugin.
    /// </summary>
    public static string PluginID => "F70451FFFA5F4F2686B8AB6888E1440B";

    /// <summary>
    /// Name of plugin.
    /// </summary>
    public string Name => "VSCode";

    /// <summary>
    /// Description of plugin.
    /// </summary>
    public string Description => "Manage VS Code projects and SSH connections";

    private PluginInitContext Context { get; set; }

    private string IconPath { get; set; }

    private bool Disposed { get; set; }

    private const string VSCodeKeyword = "vscode";
    private const string SSHKeyword = "ssh";
    private const string OpenKeyword = "open";
    private readonly VSCodeProjectLoader _projectLoader;
    private readonly SSHConfigParser _sshParser;

    static Main()
    {
        // Add assembly resolver to load Newtonsoft.Json from plugin directory
        AppDomain.CurrentDomain.AssemblyResolve += OnAssemblyResolve;
    }

    private static Assembly OnAssemblyResolve(object sender, ResolveEventArgs args)
    {
        try
        {
            var assemblyName = new AssemblyName(args.Name);
            
            // Handle Newtonsoft.Json with any version
            if (assemblyName.Name == "Newtonsoft.Json")
            {
                var pluginDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                var assemblyPath = Path.Combine(pluginDirectory, "Newtonsoft.Json.dll");
                
                if (File.Exists(assemblyPath))
                {
                    // Load the assembly without version check
                    return Assembly.LoadFrom(assemblyPath);
                }
                
                // Try to find in base directory as fallback
                var baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
                var basePath = Path.Combine(baseDirectory, "Newtonsoft.Json.dll");
                
                if (File.Exists(basePath))
                {
                    return Assembly.LoadFrom(basePath);
                }
            }
        }
        catch (Exception ex)
        {
            // Log error for debugging (will appear in PowerToys logs)
            System.Diagnostics.Debug.WriteLine($"Assembly resolve error: {ex.Message}");
        }
        
        return null;
    }

    public Main()
    {
        _projectLoader = new VSCodeProjectLoader();
        _sshParser = new SSHConfigParser();
    }

    /// <summary>
    /// Returns a filtered list of results based on the given query.
    /// Supports searching for VS Code projects and SSH connections.
    /// </summary>
    /// <param name="query">The query to filter results. Use 'ssh' prefix for SSH connections.</param>
    /// <returns>A filtered list of results matching the query.</returns>
    public List<Result> Query(Query query)
    {
        try
        {
            // query.Search contains the text AFTER the action keyword
            // For example: "vsc projects" -> query.Search = "projects"
            var search = query.Search.ToLowerInvariant().Trim();

            // DEBUG: Log what we're searching for
            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Query.Search = '{query.Search}', search = '{search}'");
            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] OpenKeyword = '{OpenKeyword}', SSHKeyword = '{SSHKeyword}', VSCodeKeyword = '{VSCodeKeyword}'");

            // Check if user specified a sub-command
            // Use exact match or "keyword " (with space) to avoid matching project names
            if (search == SSHKeyword || search.StartsWith(SSHKeyword + " "))
            {
                // User typed: vsc ssh <search>
                System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Matched SSH keyword");
                return SearchSSHConnections(search.Substring(SSHKeyword.Length).Trim());
            }
            else if (search == OpenKeyword || search.StartsWith(OpenKeyword + " "))
            {
                // User typed: vsc open <anything>
                // Show all recent projects and open selected one in PowerShell with opencode
                System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Matched OPEN keyword - calling GetOpenInPowerShellResults()");
                return GetOpenInPowerShellResults();
            }
            else if (search == VSCodeKeyword || search.StartsWith(VSCodeKeyword + " "))
            {
                // User typed: vsc vscode <search>
                System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Matched VSCODE keyword");
                return SearchVSCodeProjects(search.Substring(VSCodeKeyword.Length).Trim());
            }
            else
            {
                // User typed just: vsc <search>
                // Default to searching VS Code projects
                System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] No keyword match - searching projects with term '{search}'");
                return SearchVSCodeProjects(search);
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] ERROR in Query: {ex.Message}\n{ex.StackTrace}");
            return new List<Result>
            {
                new Result
                {
                    Title = "Plugin Error",
                    SubTitle = $"Error in Query: {ex.Message}",
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ => false
                }
            };
        }
    }

    /// <summary>
    /// Searches for VS Code projects matching the search term.
    /// </summary>
    /// <param name="search">The search term to filter projects.</param>
    /// <returns>A list of matching VS Code project results.</returns>
    private List<Result> SearchVSCodeProjects(string search)
    {
        try
        {
            var projects = _projectLoader.LoadProjects();
            
            if (projects == null)
            {
                projects = new List<VSCodeProject>();
            }
            
            var results = new List<Result>();

            foreach (var project in projects.Where(p => 
                p != null &&
                (string.IsNullOrEmpty(search) ||
                p.Name.Contains(search, StringComparison.OrdinalIgnoreCase) || 
                p.Path.Contains(search, StringComparison.OrdinalIgnoreCase))))
            {
                results.Add(new Result
                {
                    Title = project.Name,
                    SubTitle = project.Path,
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ =>
                    {
                        OpenVSCode(project.Path);
                        return true;
                    },
                    ContextData = project
                });
            }

            // If no results and no search term, show a message
            if (results.Count == 0 && string.IsNullOrEmpty(search))
            {
                results.Add(new Result
                {
                    Title = "No VS Code projects found",
                    SubTitle = "Open a folder in VS Code to see it here",
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ => false
                });
            }

            return results;
        }
        catch (Exception ex)
        {
            return new List<Result>
            {
                new Result
                {
                    Title = "Error loading VS Code projects",
                    SubTitle = $"{ex.GetType().Name}: {ex.Message}",
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ => false
                }
            };
        }
    }

    /// <summary>
    /// Searches for SSH connections matching the search term.
    /// </summary>
    /// <param name="search">The search term to filter SSH connections.</param>
    /// <returns>A list of matching SSH connection results.</returns>
    private List<Result> SearchSSHConnections(string search)
    {
        var connections = _sshParser.ParseConfig();
        var results = new List<Result>();

        foreach (var connection in connections.Where(c => 
            string.IsNullOrEmpty(search) ||
            c.Host.Contains(search, StringComparison.OrdinalIgnoreCase) || 
            (c.HostName != null && c.HostName.Contains(search, StringComparison.OrdinalIgnoreCase))))
        {
            results.Add(new Result
            {
                Title = connection.Host,
                SubTitle = connection.HostName ?? connection.Host,
                IcoPath = IconPath,
                Action = _ =>
                {
                    OpenSSHConnection(connection);
                    return true;
                },
                ContextData = connection
            });
        }

        return results;
    }

    /// <summary>
    /// Returns all recent projects for opening in PowerShell with opencode.
    /// </summary>
    /// <returns>A list of all recent VS Code projects.</returns>
    private List<Result> GetOpenInPowerShellResults()
    {
        try
        {
            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] GetOpenInPowerShellResults() called");

            var results = new List<Result>();

            // Add a header result to confirm this feature is working
            results.Add(new Result
            {
                Title = "🚀 Open in PowerShell Mode",
                SubTitle = "Select a project below to open it in PowerShell with 'opencode' command",
                IcoPath = IconPath ?? "Images/vscode.dark.png",
                Score = 1000, // High score to appear at top
                Action = _ => false
            });

            var projects = _projectLoader.LoadProjects();
            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Loaded {projects?.Count ?? 0} projects");

            if (projects == null)
            {
                projects = new List<VSCodeProject>();
            }

            foreach (var project in projects.Where(p => p != null))
            {
                System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Adding project: {project.Name} - {project.Path}");
                results.Add(new Result
                {
                    Title = project.Name,
                    SubTitle = $"📂 Open in PowerShell: {project.Path}",
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ =>
                    {
                        return OpenInPowerShell(project);
                    },
                    ContextData = project
                });
            }

            // If no projects found, show a message
            if (results.Count == 1) // Only the header result
            {
                System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] No projects found, showing message");
                results.Add(new Result
                {
                    Title = "No VS Code projects found",
                    SubTitle = "Open a folder in VS Code to see it here",
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ => false
                });
            }

            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] Returning {results.Count} results");
            return results;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[VSCode Plugin] ERROR in GetOpenInPowerShellResults: {ex.Message}\n{ex.StackTrace}");
            return new List<Result>
            {
                new Result
                {
                    Title = "Error loading VS Code projects",
                    SubTitle = $"{ex.GetType().Name}: {ex.Message}",
                    IcoPath = IconPath ?? "Images/vscode.dark.png",
                    Action = _ => false
                }
            };
        }
    }

    /// <summary>
    /// Opens a VS Code project by launching VS Code with the specified path or URI.
    /// </summary>
    /// <param name="projectPath">The local path or remote URI of the project to open.</param>
    private void OpenVSCode(string projectPath)
    {
        var vscodePath = GetVSCodePath();
        
        if (vscodePath == null)
        {
            MessageBox.Show(
                "VS Code could not be found on your system.\n\n" +
                "Please install VS Code from https://code.visualstudio.com/\n" +
                "or ensure it's added to your system PATH.",
                "VS Code Not Found",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return;
        }
        
        try
        {
            // VS Code can handle both local paths and remote URIs
            // For remote: vscode-remote://ssh-remote+hostname/path/to/project
            // For local: C:\Users\Username\Projects\MyProject
            var startInfo = new ProcessStartInfo
            {
                FileName = vscodePath,
                Arguments = projectPath.StartsWith("vscode-remote://", StringComparison.OrdinalIgnoreCase) 
                    ? $"--folder-uri \"{projectPath}\""  // Remote URI
                    : $"\"{projectPath}\"",               // Local path
                UseShellExecute = true
            };
            Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to open VS Code.\n\n" +
                $"Error: {ex.Message}\n\n" +
                $"VS Code Path: {vscodePath}\n" +
                $"Project: {projectPath}\n\n" +
                $"Try running the debug script: debug-vscode-path.ps1",
                "Error Opening VS Code",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }

    /// <summary>
    /// Opens an SSH connection in a new terminal window.
    /// </summary>
    /// <param name="connection">The SSH configuration entry to connect to.</param>
    private void OpenSSHConnection(SSHConfigEntry connection)
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c start ssh {connection.Host}",
                UseShellExecute = true
            };
            Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to open SSH connection: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    /// <summary>
    /// Opens a PowerShell window at the project directory and runs opencode.
    /// </summary>
    /// <param name="project">The VS Code project to open.</param>
    /// <returns>True if successful, false otherwise.</returns>
    private bool OpenInPowerShell(VSCodeProject project)
    {
        // Check if it's a remote project
        if (project.Path.StartsWith("vscode-remote://", StringComparison.OrdinalIgnoreCase))
        {
            MessageBox.Show(
                $"Remote projects are not supported for PowerShell opening.\n\n" +
                $"Project: {project.Name}\n" +
                $"Remote URI: {project.Path}\n\n" +
                $"Please use the regular 'vsc' command to open remote projects in VS Code.",
                "Remote Project Not Supported",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            return false;
        }

        // Check if directory exists
        if (!Directory.Exists(project.Path))
        {
            MessageBox.Show(
                $"The project directory no longer exists.\n\n" +
                $"Project: {project.Name}\n" +
                $"Path: {project.Path}\n\n" +
                $"The project may have been moved or deleted.",
                "Directory Not Found",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return false;
        }

        try
        {
            // Escape single quotes in the path for PowerShell (replace ' with '')
            var escapedPath = project.Path.Replace("'", "''");

            // Build PowerShell command: cd to directory, then run opencode
            // -NoExit keeps the window open after running commands
            var command = $"cd '{escapedPath}'; opencode";
            
            var startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-NoExit -Command \"{command}\"",
                UseShellExecute = true
            };
            
            Process.Start(startInfo);
            return true;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to open PowerShell.\n\n" +
                $"Error: {ex.Message}\n\n" +
                $"Project: {project.Name}\n" +
                $"Path: {project.Path}",
                "Error Opening PowerShell",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            return false;
        }
    }

    /// <summary>
    /// Attempts to find the VS Code executable path by checking common installation locations.
    /// </summary>
    /// <returns>The path to VS Code executable, or null if not found.</returns>
    private string GetVSCodePath()
    {
        var possiblePaths = new[]
        {
            Environment.ExpandEnvironmentVariables(@"%ProgramFiles%\Microsoft VS Code\Code.exe"),
            Environment.ExpandEnvironmentVariables(@"%ProgramFiles(x86)%\Microsoft VS Code\Code.exe"),
            Environment.ExpandEnvironmentVariables(@"%LocalAppData%\Programs\Microsoft VS Code\Code.exe"),
            Environment.ExpandEnvironmentVariables(@"%UserProfile%\.vscode\bin\code.cmd")
        };

        // First check known installation paths
        var foundPath = possiblePaths.FirstOrDefault(File.Exists);
        if (foundPath != null)
        {
            return foundPath;
        }

        // Try to find 'code' command in PATH
        var pathDirs = Environment.GetEnvironmentVariable("PATH")?.Split(';') ?? Array.Empty<string>();
        foreach (var dir in pathDirs)
        {
            try
            {
                var codePath = Path.Combine(dir.Trim(), "code.exe");
                if (File.Exists(codePath))
                {
                    return codePath;
                }
                
                var codeCmdPath = Path.Combine(dir.Trim(), "code.cmd");
                if (File.Exists(codeCmdPath))
                {
                    return codeCmdPath;
                }
            }
            catch
            {
                // Invalid path in PATH variable, skip
                continue;
            }
        }

        // VS Code not found
        return null;
    }

    /// <summary>
    /// Initialize plugin with given <see cref="PluginInitContext"/>.
    /// </summary>
    /// <param name="context">The <see cref="PluginInitContext"/> for this plugin.</param>
    public void Init(PluginInitContext context)
    {
        Context = context ?? throw new ArgumentNullException(nameof(context));
        
        if (Context.API != null)
        {
            Context.API.ThemeChanged += OnThemeChanged;
            UpdateIconPath(Context.API.GetCurrentTheme());
        }
        else
        {
            IconPath = "Images/vscode.dark.png";
        }
    }

    /// <summary>
    /// Return a list context menu entries for a given <see cref="Result"/> (shown at the right side of result).
    /// </summary>
    /// <param name="selectedResult">The <see cref="Result"/> for list with context menu entries.</param>
    /// <returns>A list context menu entries.</returns>
    public List<ContextMenuResult> LoadContextMenus(Result selectedResult)
    {
        if (selectedResult.ContextData is VSCodeProject project)
        {
            return
            [
                new ContextMenuResult
                {
                    PluginName = Name,
                    Title = "Copy Path",
                    Glyph = "\xE8C8", // Copy
                    FontFamily = "Segoe Fluent Icons,Segoe MDL2 Assets",
                    AcceleratorKey = Key.C,
                    AcceleratorModifiers = ModifierKeys.Control,
                    Action = _ =>
                    {
                        Clipboard.SetDataObject(project.Path);
                        return true;
                    },
                },
                new ContextMenuResult
                {
                    PluginName = Name,
                    Title = "Open in File Explorer",
                    Glyph = "\xE8B7", // Folder
                    FontFamily = "Segoe Fluent Icons,Segoe MDL2 Assets",
                    Action = _ =>
                    {
                        Process.Start("explorer.exe", project.Path);
                        return true;
                    },
                }
            ];
        }
        else if (selectedResult.ContextData is SSHConfigEntry ssh)
        {
            return
            [
                new ContextMenuResult
                {
                    PluginName = Name,
                    Title = "Copy Command",
                    Glyph = "\xE8C8", // Copy
                    FontFamily = "Segoe Fluent Icons,Segoe MDL2 Assets",
                    AcceleratorKey = Key.C,
                    AcceleratorModifiers = ModifierKeys.Control,
                    Action = _ =>
                    {
                        Clipboard.SetDataObject($"ssh {ssh.Host}");
                        return true;
                    },
                }
            ];
        }

        return [];
    }

    /// <inheritdoc/>
    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    /// <summary>
    /// Wrapper method for <see cref="Dispose()"/> that dispose additional objects and events form the plugin itself.
    /// </summary>
    /// <param name="disposing">Indicate that plugin is disposed.</param>
    protected virtual void Dispose(bool disposing)
    {
        if (Disposed || !disposing)
        {
            return;
        }

        if (Context?.API != null)
        {
            Context.API.ThemeChanged -= OnThemeChanged;
        }

        Disposed = true;
    }

    private void UpdateIconPath(Theme theme) => IconPath = theme == Theme.Light || theme == Theme.HighContrastWhite ? "Images/vscode.light.png" : "Images/vscode.dark.png";

    private void OnThemeChanged(Theme currentTheme, Theme newTheme) => UpdateIconPath(newTheme);
}
