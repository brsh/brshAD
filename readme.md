# brshAD - A module to group AD scripts and functions

Let's face it, AD is useful. It's also a bit cumbersome.

This module is intended to group together misc. scripts
and functions that I use to do various things in and
around AD.

As of the creation of this readme, the following functions
exist:

| Command                  | Description                                                             |
| ------------------------ | ----------------------------------------------------------------------- |
| Get-adDomainControllers  | List domain controllers                                                 |
| Get-adFSMORoleOwner      | FSMO role owners                                                        |
| Get-adFunctionalLevels   | Forest and domain functional levels                                     |
| Get-adSubnetsWithoutSite | Parse the Netlogon log for IPs not assigned to a site                   |
| Get-adSyncStatus         | Itemizes AD Repliction Status                                           |
| Get-adUnsignedLDAPBind   | Parses the DirectoryServices EventLog for IPs using unsigned LDAP binds |
| Invoke-adDCDiag          | Colorizes the output of DCDiag                                          |

