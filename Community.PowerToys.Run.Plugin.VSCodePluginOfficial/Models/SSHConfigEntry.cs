namespace Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Models
{
    /// <summary>
    /// Represents an SSH configuration entry from ~/.ssh/config file.
    /// </summary>
    public class SSHConfigEntry
    {
        /// <summary>
        /// Gets or sets the Host alias from the SSH config.
        /// This is the name used to connect: ssh [Host]
        /// </summary>
        public string Host { get; set; }
        
        /// <summary>
        /// Gets or sets the actual hostname or IP address of the SSH server.
        /// </summary>
        public string HostName { get; set; }
        
        /// <summary>
        /// Gets or sets the SSH username.
        /// </summary>
        public string User { get; set; }
        
        /// <summary>
        /// Gets or sets the SSH port number (default is 22 if not specified).
        /// </summary>
        public int? Port { get; set; }
        
        /// <summary>
        /// Gets or sets the path to the SSH identity file (private key).
        /// </summary>
        public string IdentityFile { get; set; }
        
        /// <summary>
        /// Gets a description in the format: user@hostname or just hostname.
        /// </summary>
        public string Description => string.IsNullOrEmpty(User) 
            ? HostName ?? Host 
            : $"{User}@{HostName ?? Host}";
        
        /// <summary>
        /// Gets the Host alias as the title.
        /// </summary>
        public string Title => Host;
    }
}
