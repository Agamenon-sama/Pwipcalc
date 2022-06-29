# Pwipcalc

A script to calculate few informations about a subnet from the ip address and subnet mask

This was a simple homework but I'm just putting it here for anyone interested

## Description

This script  takes as input an ipv4 address in dotted decimal notation (ddn)
and the subnet mask in CIDR notation but without the "/" (for example "24").

The informations returned are the following:

- The ip address in ddn and binary notation
- The subnet mask in ddn, binary and CIDR notation
- The wildcard mask in ddn (for ACLs...)
- Network address in ddn
- Broadcast address in ddn
- Smallest usable address in ddn
- Biggest usable address in ddn

## Usage

```
ipcalc.ps1 -ipAddr 184.59.120.153 -subnetMask 17
```

## Note

This program was written and tested with powershell for Linux. It was also
mildly tested on windows so it should work well.

## License

Public Domain
