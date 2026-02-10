using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Models;

namespace Community.PowerToys.Run.Plugin.VSCodePluginOfficial.Services
{
    /// <summary>
    /// Parser for SSH configuration files (~/.ssh/config).
    /// Supports standard SSH config keywords: Host, HostName, User, Port, IdentityFile.
    /// Results are cached for 5 minutes to improve performance.
    /// </summary>
    public class SSHConfigParser
    {
        private readonly string _sshConfigPath;
        private readonly List<SSHConfigEntry> _cachedEntries = new();
        private DateTime _lastCacheUpdate = DateTime.MinValue;
        private const int CacheValidityMinutes = 5;

        public SSHConfigParser()
        {
            var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            _sshConfigPath = Path.Combine(userProfile, ".ssh", "config");
        }

        /// <summary>
        /// Parses the SSH config file and returns all configured SSH hosts.
        /// Results are cached for 5 minutes to improve performance.
        /// </summary>
        /// <returns>A list of SSH configuration entries from ~/.ssh/config.</returns>
        public List<SSHConfigEntry> ParseConfig()
        {
            if (DateTime.Now.Subtract(_lastCacheUpdate).TotalMinutes < CacheValidityMinutes)
            {
                return _cachedEntries;
            }

            var entries = new List<SSHConfigEntry>();

            if (!File.Exists(_sshConfigPath))
            {
                return entries;
            }

            try
            {
                SSHConfigEntry currentEntry = null;
                var lines = File.ReadAllLines(_sshConfigPath);

                foreach (var line in lines)
                {
                    var trimmedLine = line.Trim();

                    if (string.IsNullOrWhiteSpace(trimmedLine) || trimmedLine.StartsWith("#"))
                    {
                        continue;
                    }

                    var parts = trimmedLine.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);

                    if (parts.Length >= 2)
                    {
                        var keyword = parts[0].ToLowerInvariant();
                        var value = string.Join(" ", parts.Skip(1)).Trim();

                        switch (keyword)
                        {
                            case "host":
                                if (currentEntry != null)
                                {
                                    entries.Add(currentEntry);
                                }
                                currentEntry = new SSHConfigEntry { Host = value };
                                break;
                            
                            case "hostname":
                                if (currentEntry != null)
                                {
                                    currentEntry.HostName = value;
                                }
                                break;
                            
                            case "user":
                                if (currentEntry != null)
                                {
                                    currentEntry.User = value;
                                }
                                break;
                            
                            case "port":
                                if (currentEntry != null && int.TryParse(value, out int port))
                                {
                                    currentEntry.Port = port;
                                }
                                break;
                            
                            case "identityfile":
                                if (currentEntry != null)
                                {
                                    currentEntry.IdentityFile = value;
                                }
                                break;
                        }
                    }
                }

                if (currentEntry != null)
                {
                    entries.Add(currentEntry);
                }
            }
            catch (Exception)
            {
                return new List<SSHConfigEntry>();
            }

            _cachedEntries.Clear();
            _cachedEntries.AddRange(entries);
            _lastCacheUpdate = DateTime.Now;

            return _cachedEntries;
        }

        /// <summary>
        /// Clears the cached SSH configuration entries, forcing a reload on the next call to ParseConfig.
        /// </summary>
        public void InvalidateCache()
        {
            _cachedEntries.Clear();
            _lastCacheUpdate = DateTime.MinValue;
        }
    }
}
