#! /usr/bin/pwsh

<#
    .SYNOPSIS
    Calculates some information regarding ipv4 subnets

    .DESCRIPTION
    Given an ipv4 address and a subnet mask, ipcalc returns informations
    including:
     - The ip address in dotted decimal notation (ddn) and binary notation
     - The subnet mask in ddn, binary and CIDR notation
     - The wildcard mask in ddn (for ACLs...)
     - Network address in ddn
     - Broadcast address in ddn
     - Smallest usable address in ddn
     - Biggest usable address in ddn
    
    .PARAMETER
    -ipAddr ipv4 address in ddn
    -subnetMask number of bits set to 1 starting from the left

    .EXAMPLE
    ipcalc.ps1 -ipAddr 184.59.120.153 -subnetMask 17
#>

# Setting program parameters
param (
    [parameter(mandatory)]$ipAddr,
    [parameter(mandatory)][int]$subnetMask
)

function convert-snmToBin($snetm) {
    $binMask = "" # contains value to return
    $numOfZeros = 32 - $snetm # number of zeros to add after the 1s for the hosts
    $octetCounter = 0 # counter used to determine the when to put the dot "."

    # put 1 and decrement subnet mask until it reaches 0
    while ($snetm -ne 0) {
        $binMask += "1"
        $snetm = $snetm - 1
        $octetCounter = $octetCounter + 1
        if ($octetCounter -eq 8) { # put "." after each 8 bits
            $binMask += "."
            $octetCounter = 0
        }
    }

    # put 1 and decrement subnet mask until it reaches 0
    while ($numOfZeros -ne 0) {
        $binMask += "0"
        $numOfZeros = $numOfZeros - 1
        $octetCounter = $octetCounter + 1
        if ($octetCounter -eq 8) { # put "." after each 8 bits
            $binMask += "."
            $octetCounter = 0
        }
    }

    $binMask = $binMask.substring(0, $binMask.length - 1) # remove trailing dot

    return $binMask
}

function convert-snmBinToArray($snm) {
    # get the values separated by ".", convert them
    # to int from binary strings and return them as an array
    $snmArray = @()
    $snm.split('.') | foreach {$snmArray += [convert]::toint32($_, 2)}
    return $snmArray
}

function convert-ipArrayToDDN($ip) {
    # takes ip address as an array and return it as a string in ddn
    $ipDDN = ""
    foreach ($elem in $ip) {
        $ipDDN += "$elem."
    }
    $ipDDN = $ipDDN.substring(0, $ipDDN.length - 1) # remove trailing dot
    return $ipDDN
}

function convert-snmArrayToWildcard($snmArray) {
    # transform subnet mask to wildcard mask which is basically
    # the same but the bits are flipped. It's used for example in ACLs in routers
    $wild = @()
    foreach ($elem in $snmArray) {
        if ($elem -eq 0) {
            # if octet is 0, set it directly to 255
            # because scanning 0 with this algorithm will give wrong results
            $wild += 255
            continue
        }
        $elemStr = [convert]::toString($elem, 2)
        $elemStr = $elemStr.replace("1", "t") # flips 1 bits to a temporary bit
        $elemStr = $elemStr.replace("0", "1") # flips 0 to 1
        $elemStr = $elemStr.replace("t", "0") # flips temporary bits to 0
        $wild += [convert]::toint32($elemStr, 2)
    }
    return $wild
}

function get-networkAddr($ip, $snmArray) {
    $netAddr = @()
    for (($i = 0); $i -lt 4; $i++) {
        $netAddr += $ipAddr[$i] -band $snmArray[$i]
    }
    return $netAddr
}

function get-broadcastAddr($ip, $wildArray) {
    $netAddr = @()
    for (($i = 0); $i -lt 4; $i++) {
        # adding the octet in the network address with that of the wildcard
        # should give us the broadcast
        # 158.048.102.000 = network
        # 000.000.000.255 = wildcard = /24 subnet
        # 158.048.102.255 = broadcast
        $netAddr += $ip[$i] + $wildArray[$i]
    }
    return $netAddr
}

function get-hostMin($network) {
    # create local copy of the address to preserve the original from change
    $temp = $network.PsObject.copy()
    # increment smallest octet
    $temp[3]++
    # return in ddn
    return convert-ipArrayToDDN($temp)
}

function get-hostMax($broadcast) {
    # create local copy of the address to preserve the original from change
    $temp = $broadcast.PsObject.copy()
    # decrement smallest octet
    $temp[3]--
    # return in ddn
    return convert-ipArrayToDDN($temp)
}


# Check if the ip address is valid
if ($ipAddr.split('.').length -ne 4) {
    write-error "The ip address is invalid"
    exit 1
}
$ipAddr.split('.') | foreach {
    # testing if each octet is in the correct range and type
    if ( -not ($_ -match '^[0-9]+$') ) {
        write-error "The ip address is invalid"
        write-error "$_ contains non numbers"
        exit 4
    }
    if ([int]$_ -gt 255 -or [int]$_ -lt 0) {
        write-error "The ip address is invalid"
        write-error "$_ is not in the correct range"
        exit 2
    }
}

#######################
### EXECUTION START ###
#######################

# Creating an array from the string ip
$ipAddr = @(
    [int]($ipAddr.split('.'))[0],
    [int]($ipAddr.split('.'))[1],
    [int]($ipAddr.split('.'))[2],
    [int]($ipAddr.split('.'))[3]
)

# Check if subnet mask is valid
if ([int]$subnetMask -gt 31 -or [int]$subnetMask -lt 0) {
    write-error "The subnet mask is invalid"
    exit 3
}

# Making ip address in dotted decimal notation
$ipStr = ""
foreach ($elem in $ipAddr) {$ipStr += [string]$elem + "."}
$ipStr = $ipStr.substring(0, $ipStr.length - 1) # remove trailing dot

# Making ip address in dotted binary notation
$ipBinStr = ""
foreach ($elem in $ipAddr) {$ipBinStr += [convert]::tostring([string]$elem, 2) + "."}
$ipBinStr = $ipBinStr.substring(0, $ipBinStr.length - 1) # remove trailing dot

# Some convertions for the output
$snmBin = convert-snmToBin($subnetMask)
$snmArray = convert-snmBinToArray($snmBin)
$wildcard = convert-snmArrayToWildcard($snmArray)
$networkAddr = get-networkAddr -ip $ipAddr -snmArray $snmArray
$broadcastAddr = get-broadcastAddr -ip $networkAddr -wildArray $wildcard
$hostMin = get-hostMin($networkAddr)
$hostMax = get-hostMax($broadcastAddr)
$snmDDN = convert-ipArrayToDDN($snmArray)
$wildcard = convert-ipArrayToDDN($wildcard)
$networkAddr = convert-ipArrayToDDN($networkAddr)
$broadcastAddr = convert-ipArrayToDDN($broadcastAddr)

write-host "IP address:       ", $ipStr, $ipBinStr
write-host "Subnet mask:      ", $snmDDN, $snmBin
write-host "CIDR notation:    ", "/$subnetMask"
write-host "Wildcard mask:    ", $wildcard
write-host "Network address:  ", $networkAddr
write-host "HostMin address:  ", $hostMin
write-host "HostMax address:  ", $hostMax
write-host "Broadcast address:", $broadcastAddr

