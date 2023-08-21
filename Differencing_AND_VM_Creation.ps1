

function CheckParentLocation
{
    if(!(test-path C:\temp\Parent.txt))
    {
        Read-Host "Please enter the parent VHD location" | out-file C:\temp\Parent.txt

    }

}

function CheckChildLocation
{
    if(!(test-path C:\temp\child.txt))
    {
        Read-Host "Please enter the child VHD location" | out-file C:\temp\child.txt

    }
}

function CheckVMConfigLocation
{
    if(!(test-path C:\temp\VMConfig.txt))
    {
        $ConfigFilePath = Read-Host "Where would you like to store your VM Config files?" | out-file C:\temp\VMConfig.txt

    }
}

function TPMEnablement($VmName, $owner)
{
    $owner = Get-HgsGuardian -Name $owner

    Write-Host "Enabling TPM..."
    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
    Set-VMKeyProtector -VMName $VmName -KeyProtector $kp.RawData
    Enable-VMTPM -VMName $VmName
    Write-Host "TPM Enabled."

}

function GuardianCheck($VmName)
{
    $TestTPMGuardianPath = Test-Path c:\temp\GuardianName.txt -ErrorAction SilentlyContinue
    if($TestTPMGuardianPath)
    {
        continue
    }
    else
    {
        #Continue to next if block.
    }
    
    
    $owner = Get-HgsGuardian UntrustedGuardian -ErrorAction SilentlyContinue
    if(!($owner))
    {
        Write-Host "There are currently no guardians available to enable TPM. You can select enter Y to create a guardian or N to manually enable the TPM."
        $TPMGuardian = Read-Host "Would you like to create a guardian?"

        if($TPMGuardian -eq 'Y')
        {
            $TPMGuardianName = Read-Host "What would you like to name the guardian?"

            $TPMGuardianStorage = Read-Host "Would you like to use this guardian in future builds? (y/n)"

            Write-Host "Creating Guardian..."
            New-HgsGuardian -Name $TPMGuardianName -GenerateCertificates | out-null
            Write-Host "Guardian Created..."

            if($TPMGuardianStorage -eq 'y')
            {
                $TPMGuardianName | out-File C:\temp\GuardianName.txt
                 TPMEnablement $vmname $TPMGuardianName
            }
            else
            {
                TPMEnablement $vmname $TPMGuardianName
                
            }
        }


    }
    else
    {
        TPMEnablement $vmname $owner
    }
}


CheckParentLocation
CheckChildLocation
CheckVMConfigLocation


$ParentLocation = Get-content C:\temp\Parent.txt
$ChildLocation = Get-Content C:\temp\Child.txt
$VMConfigLocation = Get-content C:\temp\VMConfig.txt

Write-Host "Parent VHDX List"
Write-Host "==============================================================="
(get-childitem -path $ParentLocation).Name.replace(".vhdx","")
Write-Host "==============================================================="

$Parent = Read-Host -Prompt "Which parent vhd would you like to use?"

$Child = Read-Host -Prompt "What would you like to name your child VHD?"

New-VHD -ParentPath "$($ParentLocation)\$($Parent).vhdx" -path "$($ChildLocation)\$($Child).vhdx"


Write-Host "Creating Virtual Machine..."
$VmName = Read-Host -Prompt "What would you like to name the virtual machine?"


$memory = Read-Host -prompt "Memory to use (GB)"
$memory = [uint64]($memory -replace '\D') * 1GB


$cpu = Read-Host -prompt "How many CPU Cores to use"
$cpu = [int64]($cpu)


$Network = Read-Host -prompt "Would you like to add a Network Adapter? Y/N"
if ($Network -eq 'Y')
{
    $SwitchList = Get-VMSwitch | Select-Object Name,SwitchType 
    Write-Host "HyperV Switch List"
    Write-Host "==============================================================="
    Write-output $SwitchList |Format-table
    Write-Host "==============================================================="
    $SwitchName = Read-Host -prompt "What is the 'name' of the switch you would like to use"
   
}
else
{
    $SwitchName = 0

}



new-VM $VMName -MemoryStartupBytes $memory -Generation 2 -VHDPath "$($ChildLocation)\$($Child).vhdx" -Path "$VMConfigLocation"
Set-VM -VMName "$VMName" -AutomaticCheckpointsEnabled $False -ProcessorCount $cpu 

If ($SwitchName)
{
    Connect-VMNetworkAdapter -VMName $VmName -SwitchName $SwitchName
}

$TPM = Read-Host -prompt "Would you like to enable TPM? Y/N"


If ($TPM -eq 'Y')
{
    GuardianCheck $VmName
}

