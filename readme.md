# brshAD - A module to group AD scripts and functions

Let's face it, AD is useful. It's also a bit cumbersome.

This module is intended to group together misc. scripts
and functions that I use to do various things in and
around AD.

As of the creation of this readme, the following functions
exist:

| Command                   | Description                                                                 |
| ------------------------- | --------------------------------------------------------------------------- |
| Disable-adLinuxUser       | Disables the Linux login for a user (or removes the attribs completely)     |
| Get-adDomainControllers   | List domain controllers                                                     |
| Get-adFSMORoleOwner       | FSMO role owners                                                            |
| Get-adFunctionalLevels    | Forest and domain functional levels                                         |
| Get-adHelp                | List commands available in the brshAD Module                                |
| Get-adLDAPsBindInfo       | Parses the Security EventLog for WinFilter events to find LDAPS connections |
| Get-adLinuxGroup          | Gets groups and their *nix GID                                              |
| Get-adLinuxUser           | Gets users and their *nix UID                                               |
| Get-adSiteInformation     | Pulls Site Information like name, IPs...                                    |
| Get-adSiteLinkInformation | Pulls Site Link info incl. Schedule                                         |
| Get-adSubnetsWithoutSite  | Parse the Netlogon log for IPs not assigned to a site                       |
| Get-adSyncStatus          | Itemizes AD Repliction Status                                               |
| Get-adTimePeers           | Just a wrapper for w32tm /query /peers                                      |
| Get-adTimeSource          | Just a wrapper for w32tm /query /source                                     |
| Get-adTimeStatus          | Just a wrapper for w32tm /query /status                                     |
| Get-adUnsignedLDAPBind    | Parses the DirectoryServices EventLog for IPs using unsigned LDAP binds     |
| Get-adUsersGroups         | Gets the groups a user is a member of                                       |
| Invoke-adDCDiag           | Colorizes the output of DCDiag                                              |
| Sync-adTime               | Wrapper for the w32tm.exe /resync                                           |
| Test-adTimeMonitor        | Wrapper for w32tm /monitor                                                  |
| Test-adTimeServer         | Wrapper for W32tm's TimeServer Test                                         |
