using System;

namespace Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Models
{
    /// <summary>
    /// Represents a VS Code project (workspace) entry.
    /// Can be either a local project or a remote SSH project.
    /// </summary>
    public class VSCodeProject
    {
        /// <summary>
        /// Gets or sets the display name of the project.
        /// </summary>
        public string Name { get; set; }
        
        /// <summary>
        /// Gets or sets the full path or remote URI of the project.
        /// For local: C:\Users\Username\Projects\MyProject
        /// For remote: vscode-remote://ssh-remote+hostname/path/to/project
        /// </summary>
        public string Path { get; set; }
        
        /// <summary>
        /// Gets or sets the date and time when the project was last opened.
        /// </summary>
        public DateTime LastOpened { get; set; }
        
        /// <summary>
        /// Gets the project path as a description.
        /// </summary>
        public string Description => Path;
        
        /// <summary>
        /// Gets the project name as a title.
        /// </summary>
        public string Title => Name;
    }
}
