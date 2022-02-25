# brshAD - A module to group AD scripts and functions

Let's face it, AD is useful. It's also a bit cumbersome.

This module is intended to group together misc. scripts
and functions that I use to do various things in and
around AD.

## Function List

| Command                    | Description                                                                 |
| -------------------------- | --------------------------------------------------------------------------- |
| Disable-adLinuxUser        | Disables the Linux login for a user (or removes the attribs completely)     |
| Find-adGPOSetting          | Search all GPOs for specific text                                           |
| Get-adDomainControllers    | List domain controllers                                                     |
| Get-adDomainReplicationAge | Gets the value of the msDS-LogonTimeSyncInterval for the domain             |
| Get-adFSMORoleOwner        | FSMO role owners 				                                           |
| Get-adFunctionalLevels     | Forest and domain functional levels                                         |
| Get-adHelp                 | List commands available in the brshAD Module                                |
| Get-adLDAPsBindInfo        | Parses the Security EventLog for WinFilter events to find LDAPS connections |
| Get-adLinuxGroup           | Gets groups and their *nix GID                                              |
| Get-adLinuxUser            | Gets users and their *nix UID                                               |
| Get-adLiveComputer         | Mixes get-adcomputer with ping to pull a list of "online" computers         |
| Get-adQuickPing            | A simple CIM ping wrapper                                                   |
| Get-adSiteInformation      | Pulls Site Information like name, IPs...                                    |
| Get-adSiteLinkInformation  | Pulls Site Link info incl. Schedule                                         |
| Get-adSubnetsWithoutSite   | Parse the Netlogon log for IPs not assigned to a site                       |
| Get-adSyncStatus           | Itemizes AD Repliction Status                                               |
| Get-adTimePeers            | Just a wrapper for w32tm /query /peers                                      |
| Get-adTimeSource           | Just a wrapper for w32tm /query /source                                     |
| Get-adTimeStatus           | Just a wrapper for w32tm /query /status                                     |
| Get-adUnsignedLDAPBind     | Parses the DirectoryServices EventLog for IPs using unsigned LDAP binds     |
| Get-adUsersGroups          | Gets the groups a user is a member of                                       |
| Invoke-adDCDiag            | Colorizes the output of DCDiag                                              |
| Start-adADUC               | Start ADUC for non-trusted domains                                          |
| Sync-adTime                | Wrapper for the w32tm.exe /resync                                           |
| Test-adTimeMonitor         | Wrapper for w32tm /monitor                                                  |
| Test-adTimeServer          | Wrapper for W32tm's TimeServer Test                                         |

## Domain Name Autocomplete

Some of the functions can use tab autocomplete to "fill-in" multiple domain options. You just need to
pre-populate the domains in the /config/ADDomains.txt file. Just fully qualify the domain name and tabs
will help you out.

Those same functions will default to the first item in the list.

Otherwise, those functions will default to the current domain.

