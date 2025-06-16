
#Get-ExecutionPolicy -list
#---------------------------------------------------------------------------------------------------------------------------*
#  Purpose        : Script to install pre-requisites for Microsoft DMS and perform SQL Assessment for a given input list
#  Schedule       : Ad-Hoc / On-Demand
#  Date           : 23-July-2024
#  Author         : Rackimuthu Kandaswamy, Lekshmy Mk, Arun Kumar
#  Version        : 1.2
#   
#  INPUT          : SQL Input Folder, Server List in Excel file
#  VARIABLE       : NONE
#  PARENT         : NONE
#  CHILD          : NONE
#---------------------------------------------------------------------------------------------------------------------------*
#---------------------------------------------------------------------------------------------------------------------------*
#
#  IMPORTANT NOTE : The script has to be run on Non-Mission-Critical systems ONLY and not on any production server...
#
#---------------------------------------------------------------------------------------------------------------------------*
#---------------------------------------------------------------------------------------------------------------------------*
# Usage:
# Powershell.exe -File .\CMF_DMSSQLandSKUAssessmentsCombo_v1.2.ps1
#
<#
    Change Log
    ----------
#>
Set-ExecutionPolicy -ExecutionPolicy  bypass -scope currentuser

#----Libraries-----
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing


#----FUNCTIONS-----
function exitCode{
    Stop-Transcript
    Write-Host "-Ending Execution"
    exit
}

function launchADS 
{
    if(Test-Path "C:\Program Files\dotnet\shared\Microsoft.NETCore.App")
    {
        Write-Host "-C:\Program Files\dotnet Folder Exists... checking .net Core version installed"
        $dotnetcoreVersion = (dir (Get-Command dotnet).Path.Replace('dotnet.exe', 'shared\Microsoft.NETCore.App')) | Sort-Object -Property Name -Descending |select Name -First 1
        $nodotnetcore = 0
        [int]$dotnetcoreVersion_root=$dotnetcoreVersion.Name.Split(".")[0]

        if(-not $dotnetcoreVersion_root -ge 6)
        {
            $nodotnetcore = 1
        }
    }
    else
    {
        $nodotnetcore = 1
    }

    if($nodotnetcore -eq 1)
    {
        Write-Host "-.Net Core is not available to perform SQL Assessment..."
        $response = Read-Host "===> Enter 'Y' or 'N' to continue: "
        if($response.ToUpper() -eq "Y")
        {
            Write-Host '-Downloading...'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                
            #Adding exception block for invoke web request
            try {
                $response =Invoke-WebRequest -Uri "https://download.visualstudio.microsoft.com/download/pr/31949bf4-c9ef-4e57-9da2-d798ab8b8bbf/fb7a481d9381bb740223629422a006e0/dotnet-runtime-6.0.21-win-x64.exe" -OutFile "$folder\Downloads\DotNetCoreInstaller.exe"
            } 
            catch {
                Write-Host "======================================================================================="  
                Write-Host "Error while downloading .Net core package  "  -ForegroundColor Red  
                Write-Host "======================================================================================="  
                Write-Host "Please see the error below & execution has been stopped          " 
                throw  $_.Exception.Response.StatusCode.Value__
            }

            Write-Host '-Installing .Net Core ...'
            & $folder'\Downloads\DotNetCoreInstaller.exe' /install /passive /norestart /log $folder"\Logs\DotNETCore-Install.log" | Out-Null
            Write-Host "=======================================================================================" 
            Write-Host ".Net core installation complete. " -ForegroundColor Green
            Write-host "Server reboot is mandatory post .Net Core installation. Kindly re-run the script post reboot"  -ForegroundColor Green
            Write-Host "======================================================================================="
            write-host "-Fetching .Net FrameWork Version installed..."
            $dotnet=Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}'} | Select PSChildName, version

            $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Version).Version


            if($dotnet -match "4.8")
            {
                Write-Host "-.Net 4.8 available"
            }
            else
            {
                Write-Host "=======================================================================================" 
                Write-Host ".Net 4.8 not available" -ForegroundColor Red
                Write-Host "=======================================================================================" 
                $response = read-host "Enter 'Y' to continue to download and install or press any other key to abort"

                if($response.ToUpper() -eq "Y")
                {
                    Write-Host '-Downloading...'
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                            
                    #Adding exception block for invoke web request
                        try { 
                            $response =Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2088631" -OutFile "$folder\Downloads\DotNetInstaller.exe"
                        } 
                        catch {

                            Write-Host "======================================================================================="  
                            Write-Host "Error while downloading .Net package , Please make sure computer is connected to internet  "  -ForegroundColor Red  
                            Write-Host "======================================================================================="  
                            Write-Host "Please see the error below & execution has been stopped          " 
                            throw  $_.Exception.Response.StatusCode.Value__
                        }

        
                    Write-Host '-Installing .Net 4.8 ...Please wait!' -ForegroundColor Green
                    & $folder'\Downloads\DotNetInstaller.exe' /install /passive /showfinalerror /showrmui /promptrestart /log $folder"\Logs\DotNET48-Install.log" | Out-Null

                    Write-Host "=======================================================================================" 
                    Write-Host ".Net 4.8 installation complete. Please restart this machine and rerun the script. Thank you!" -ForegroundColor Green
                    Write-Host "======================================================================================="
        
                    timeout /t -1

                    exitCode
                }
                elseif ($response.ToUpper() -eq "N")
                {
                    Write-Host "Consent not provided for framework installation. Aborting the execution."  -BackgroundColor Red
                    $status="FAILED"
                    $comments=".Net framework is mandatory for execution. Kindly install manually/re-execute and provide consent for .Net framework installation."
                    exitcode
                }
                else
                {
                    Write-Host "Invalid response. Exiting.."  -BackgroundColor Red
                    $status="FAILED"
                    $comments=".Net Framework is mandatory for execution. Kindly install manually/re-execute and provide consent for .Net framework installation."
                    exitcode
                }
     
            }
        exitcode
        }
        elseif ($response.ToUpper() -eq "N")
        {
            Write-Host "Consent not provided for .Net Core installation. Aborting the execution."  -BackgroundColor Red
            $status="FAILED"
            $comments=".Net Core is mandatory for execution. Kindly install manually/re-execute and provide consent for .Net Core installation."
            exitcode
        }
        else
        {
            Write-Host "Invalid response. Exiting.."  -BackgroundColor Red
            $status="FAILED"
            $comments=".Net Core is mandatory for execution. Kindly install manually/re-execute and provide consent for .Net Core installation."
            exitcode
        }
    }
    else
    {
        Write-Host "-Fetching .Net FrameWork Version installed..."
        $dotnet=Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}'} | Select PSChildName, version

        $(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Version).Version


        if($dotnet -match "4.8")
        {
            Write-Host "-.Net 4.8 available"
        }
        else
        {
            Write-Host "=======================================================================================" 
            Write-Host ".Net 4.8 not available" -ForegroundColor Red
            Write-Host "=======================================================================================" 
            $response = read-host "Enter 'Y' to continue to download and install or press any other key to abort"

            if($response.ToUpper() -eq "Y")
            {
                Write-Host '-Downloading...'
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                #Adding exception block for invoke web request
                try { 
                    $response =Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2088631" -OutFile "$folder\Downloads\DotNetInstaller.exe"
                } 
                catch {
                    Write-Host "======================================================================================="  
                    Write-Host "Error while downloading .Net package , Please make sure computer is connected to internet  "  -ForegroundColor Red  
                    Write-Host "======================================================================================="  
                    Write-Host "Please see the error below & execution has been stopped          " 
                    throw  $_.Exception.Response.StatusCode.Value__
                }

                Write-Host '-Installing .Net 4.8 ...Please wait!' -ForegroundColor Green
                & $folder'\Downloads\DotNetInstaller.exe' /install /passive /showfinalerror /showrmui /promptrestart /log $folder"\Logs\DotNET48-Install.log" | Out-Null

                Write-Host "=======================================================================================" 
                Write-Host ".Net 4.8 installation complete. Please restart this machine and rerun the script. Thank you!" -ForegroundColor Green
                Write-Host "======================================================================================="
        
                timeout /t -1

                exitCode
            }
            elseif ($response.ToUpper() -eq "N")
            {
                Write-Host "Consent not provided for framework installation. Aborting the execution."  -BackgroundColor Red
                $status="FAILED"
                $comments=".Net framework is mandatory for execution. Kindly install manually/re-execute and provide consent for .Net framework installation."
                exitcode
            }
            else
            {
                Write-Host "Invalid response. Exiting.."  -BackgroundColor Red
                $status="FAILED"
                $comments=".Net Framework is mandatory for execution. Kindly install manually/re-execute and provide consent for .Net framework installation."
                exitcode
            }
        }
    }
}

Write-Host "-Launching SQL Assessment..."


#-------------GET FOLDER LOCATION-------------------
function getFolderLocation 
{
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Data Entry Form'
    $form.Size = New-Object System.Drawing.Size(300,200)
    $form.StartPosition = 'CenterScreen'

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,120)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150,120)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.Text = 'Enter Working Folder Path below:'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(260,20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true

    $form.Add_Shown({$textBox.Select()})
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $x = $textBox.Text
        $folder = $x
    }
    else
    {
        write-host "-Error In Input...Using default path..."
        $folder = "C:\DMSAssessment"
    }

    if(Test-Path $folder)
    {
        Write-Host "-Folder Exist"
    }
    else
    {
        New-Item $folder -ItemType Directory
        Write-Host "-$folder folder created..."
    }


    Write-Output $folder

}
function selectFolder
{
    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    Write-Host "Input Section "   -ForegroundColor Green
    Write-Host "======================================================================================="
    Write-Host "Select the Working folder in the Popup window" -ForegroundColor Green
    $foldername.Description = "Select a working Folder for DMS..."
    $foldername.rootfolder = "MyComputer"

    Start-Sleep -Seconds 5

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder = $foldername.SelectedPath
    }
    else
    {
        exitCode
    }
    return $folder
}
#----------ENDS GET FOLDER LOCATION----------#

#----------STARTS CREATE FOLDER ----------#
function createFolder([string]$newFolder) {
    if(Test-Path $newFolder)
    {
        Write-Host "-Folder'$newFolder' Exist..."
    }
    else
    {
        New-Item $newFolder -ItemType Directory
        Write-Host "-$newFolder folder created..."
    }
}
#----------ENDS CREATE FOLDER ----------#

function Perform-Checks () 
{
    #Check for ImportExcel module
    Write-Host "======================================================================================="
    Write-Host "`nChecking for ImportExcel Module"
    
    if((Get-Module -ListAvailable).Name -notcontains "ImportExcel")
    {
        Write-Host "Excel PS module not found.."  -BackgroundColor Red
        Write-Host "=======================================================================================" 
        $response = read-host "Do you want to continue download and install Excel PS Module? 'Y' or 'N' : "
    
        if($response.ToUpper() -eq "Y")
        {
            Write-Host "Downloading ImportExcel PS Module..."
            try 
            { 
                Install-Module -Name ImportExcel
            } 
            catch 
            {
                Write-Host "======================================================================================="  
                Write-Host "Error while downloading Importexcel package , Please make sure computer is connected to internet "  -ForegroundColor Red  
                Write-Host "Or "  -ForegroundColor Red 
                Write-Host "Please install it manually "  -ForegroundColor Red   
                Write-Host "======================================================================================="  
                Write-Host "Please see the error below & execution has been stopped          " 
                throw  $_.Exception.Response.StatusCode.Value__
            }
            Write-Host "Downloaded."
        }
        else
        {
            Write-Host "Excel PS module is required for the execution. Exiting..."
            exitCode
        }
    }
    
    #Check for Az.DataMigration module
    Write-Host "======================================================================================="
    Write-Host "`nChecking for Az.DataMigration Module"
    
    if((Get-Module -ListAvailable).Name -notcontains "Az.DataMigration")
    {
        Write-Host "Az.DataMigration module not found.."  -BackgroundColor Red
        Write-Host "=======================================================================================" 
        $response = read-host "Do you want to continue download and install Az.DataMigration Module? 'Y' or 'N' : "
    
        if($response.ToUpper() -eq "Y")
        {
            Write-Host "Downloading Az.DataMigration PS Module..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
            try { 
                Install-Module -Name Az.DataMigration -Force
            } 
            catch {
    
                Write-Host "======================================================================================="  
                Write-Host "Error while downloading Az.DataMigration package , Please make sure computer is connected to internet "  -ForegroundColor Red  
                Write-Host "Or "  -ForegroundColor Red 
                Write-Host "Please install it manually "  -ForegroundColor Red   
                Write-Host "======================================================================================="  
                Write-Host "Please see the error below. Execution has been stopped...          " 
                throw  $_.Exception.Response.StatusCode.Value__
            }
        
            Write-Host "Downloaded."
        }
        else
        {
            Write-Host "Az.DataMigration module is required for the execution. Exiting..."
            exitCode
        }
    }
    else
    {
        Write-Host "Az.DataMigration Module already available" -ForegroundColor green
    }
}

#----variables
$exit = 0
$nodotnetcore = 0

#----ENDS variables

$ErrorActionPreference = "Stop"

#---------------------------------------------------------PROGRAM BEGINS HERE----------------------------------------------------------
CLS

write-host "                                                                            " -BackgroundColor DarkMagenta
Write-Host "                  Welcome to CMF - DMS 1.2 SQL Assessment                   " -ForegroundColor white -BackgroundColor DarkMagenta
write-host "                     (CSU Migration factory)                                " -BackgroundColor DarkMagenta
write-host "                              V1.0                                          " -BackgroundColor DarkMagenta
Write-Host " "

Write-Host "Please select the assessment operation to perform" -ForegroundColor Green
Write-Host "===================================================================="
Write-Host "1. Perform both SQL Assessment and Performance data gathering"
Write-Host "2. Perform SQL assessment only"
Write-Host "3. Perform Performance data gathering only"
Write-Host "4. Exit"

$validInputs = "1", "2", "3", "4"
do 
{
    $response = Read-Host -Prompt "Enter value"
    if(-not $validInputs.Contains($response))
    {
        Write-Host "Please select the choice between 1 - 4"
    }
} until ($validInputs.Contains($response))

$taskToPerform = $response

$ADSNeeded = "4"
if($ADSNeeded.Contains($taskToPerform))
{
    exitcode
}


Write-Host "======================================================================================="
Write-Host "Reviewing Installed Softwares on this machine..."

$softwares=Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* 
if($softwares.DisplayName -like "*SQL Server*Engine*")
{
    Write-Host "======================================================================================="  
    Write-Host "SQL Server product installed/detected on this server...  "  -ForegroundColor Red  -BackgroundColor yellow
    foreach ($name in $Softwares) 
    {
        if($name.DisplayName -ilike "*SQL Server*Engine*") 
        {
            $name.DisplayName
        }
    }
    Write-host "It is recommended to use a separate non-critical server to perform assessment."
    Write-Host "Input Section "   -ForegroundColor Green
    Write-Host "======================================================================================="
    $response = Read-Host "Enter 'Y' to continue or any other key to abort"
    if($response -ne "Y")
    {
        exitCode
    }
}

$folder = $PSScriptRoot
$Validation=@()

$Validation+=& "$folder/Validation_Scripts/Check_PowerShell_Version.ps1"

If($Validation.Status.Contains("FAILED"))
{
    Write-host "Powershell version is below 5.1 . Kindly upgrade the version and re-execute the program . Terminating the execution ." -ForegroundColor Red
    exitcode
}

cd $folder

Write-host "Copying old files to Archive..."

If(!(test-path -PathType container $folder\Archive))
{
      createFolder $folder\Archive
}

if((Test-Path -Path $folder\output) -or 
  (Test-Path -Path $folder\Compressed) -or
  (Test-Path -Path $folder\Downloads) -or
  (Test-Path -Path $folder\Logs) -or
  (Test-Path -Path $folder\Config) )
  {
     $FolderTimestamp=Get-Date -Format "MM_dd_yyyy_HH_mm"
     $Archive_Folder="DMS_Logs_"+$FolderTimestamp
     createFolder $folder\Archive\$Archive_Folder

     
     try {Move-Item -Path $folder\output -Destination $folder\Archive\$Archive_Folder}catch {}
     try {Move-Item -Path $folder\Compressed -Destination $folder\Archive\$Archive_Folder}catch {}
     try {Move-Item -Path $folder\Downloads -Destination $folder\Archive\$Archive_Folder}catch {}
     try {Move-Item -Path $folder\Logs -Destination $folder\Archive\$Archive_Folder}catch {}
     try {Move-Item -Path $folder\Config -Destination $folder\Archive\$Archive_Folder}catch {}
     
     try {Get-ChildItem -Path $folder\output -Recurse | Move-Item -Destination $folder\Archive\$Archive_Folder\output}catch {}
  } 


#createFolder $folder
createFolder $folder\output\
createFolder $folder\output\Compressed\
createFolder $folder\Downloads\
createFolder $folder\Logs\
createFolder $folder\Config\

Write-Host "-Sub-directories created..."
#
#
#
#---------------------------------------- ASSESSMENT STARTS -----------------------------
#
#
#
#Check for .net core and framework
launchADS
Perform-Checks

$outputfolder = $null
$inputfile = $null
$inputfile = $PSScriptRoot+"\DMS-INPUT-FILE.xlsx"

Write-Host "Input Section "   -ForegroundColor Green
Write-Host "===================================================================="
Write-Host "Please find the Input file name with Full Path: $inputfile " -ForegroundColor Green
Write-Host "===================================================================="  

if ([string]::IsNullOrWhitespace($inputfile))
{
    $inputfile="C:\DMS\DMS-INPUT-FILE.xlsx"
}

$inputfilecheck=-1;

if (-not(Test-Path -Path $inputfile -PathType Leaf)) 
{
     try 
     {    
         Write-Host "======================================================================================="  
         Write-Host "Unable to read the input file [$inputfile]. Check file & its permission...  "  -ForegroundColor Red  
         Write-Host "======================================================================================="  
         Write-Host "Please see the error below & SQL assessment has been stopped          "  
         throw $_.Exception.Message                      
     }
     catch { throw $_.Exception.Message }
}
else
{
     try 
     {
         $sqllist = Import-Excel -Path $inputfile #-WorksheetName input-to-DMS-for-assessment
         $Rowcount=0

         foreach($row in $sqllist)
         {
              $Hostname = $row.'Computer Name'
              $Rowcount=$Rowcount+1
         }
     }
     catch 
     {
         Write-Host "=================================================================================="  
         Write-Host "The file [$inputfile] does not have the worksheet named input-to-DMS-for-assessment  "  -ForegroundColor Red  
         Write-Host "=================================================================================="  
         Write-Host "Please see the error below & SQL Assessment has been stopped          "  
         throw $_.Exception.Message
     }

    # Check if Column "Computer Name"  and Value exist 
    try 
    {
        $namelist = $sqllist."Computer Name"
        IF ([string]::IsNullOrWhitespace($namelist)){throw "'Computer Name' is not valid in the input-to-DMS-for-assessment worksheet" }
    }
    catch 
    {
        Write-Host "======================================================================================="  
        Write-Host "Error while reading 'Computer Name' from the worksheet named input-to-DMS-for-assessment  "  -ForegroundColor Red  
        Write-Host "======================================================================================="  
        Write-Host "Please see the error below & SQL Assessment has been stopped          " 
        throw $_.Exception.Message
    }
    
    # Check if Column "SQL Server Instance Name"  and Value exist 
    try 
    {
        $instancelist = $sqllist."SQL Server Instance Name"
        IF ([string]::IsNullOrWhitespace($instancelist)){throw "'SQL Server Instance Name' is not valid in the input-to-DMS-for-assessment worksheet" }
    }
    catch 
    {
        Write-Host "=================================================================================================="  
        Write-Host "Error while reading 'SQL Server Instance Name' from the worksheet named input-to-DMS-for-assessment  "  -ForegroundColor Red  
        Write-Host "=================================================================================================="  
        Write-Host "Please see the error below & SQL Assessment has been stopped          "  
        throw $_.Exception.Message
    }

     
    # Check if Column "Authentication type"  and Value exist 
    try 
    {
        $authlist = $sqllist."Authentication type"
        IF ([string]::IsNullOrWhitespace($authlist)){throw "'Authentication type' is not valid in the input-to-DMS-for-assessment worksheet" }
    }
    catch 
    {
        Write-Host "=============================================================================================="  
        Write-Host "Error while reading 'Authentication type' from the worksheet named input-to-DMS-for-assessment "  -ForegroundColor Red  
        Write-Host "=============================================================================================="   
        Write-Host "Please see the error below & SQL Assessment has been stopped          "  
        throw $_.Exception.Message
    }

  
    # Check if Column "DBUserName"  and Value exist 
    try 
    {
        $userlist = $sqllist."DBUserName"
    }
    catch 
    {
        Write-Host "===================================================================================="  
        Write-Host "Error while reading 'DBUserName' from the worksheet named input-to-DMS-for-assessment "  -ForegroundColor Red  
        Write-Host "===================================================================================="   
        Write-Host "Please see the error below & SQL Assessment has been stopped          "  
        throw $_.Exception.Message
    }


    # Check if Column "DBPassword"  and Value exist 
    try 
    {
        $pwdlist = $sqllist."DBPassword"
    }
    catch 
    {
        Write-Host "===================================================================================="  
        Write-Host "Error while reading 'DBPassword' from the worksheet named input-to-DMS-for-assessment "  -ForegroundColor Red  
        Write-Host "===================================================================================="   
        Write-Host "Please see the error below & SQL Assessment has been stopped          " 
        throw $_.Exception.Message
    }

    # Check if Column "DBPort"  and Value exist  
    try 
    {
        $portlist = $sqllist."DBPort"
    }
    catch 
    {
        Write-Host "================================================================================"  
        Write-Host "Error while reading 'DBPort' from the worksheet named input-to-DMS-for-assessment "  -ForegroundColor Red  
        Write-Host "================================================================================"  
        Write-Host "Please see the error below & SQL Assessment has been stopped          " -ForegroundColor white
        throw $_.Exception.Message
    }
       
    # Check if Column "SQL Server Product Name"  and Value exist  
      try 
      {
          $kvnamelist = $sqllist."KeyVaultName"
           IF (-not([string]::IsNullOrWhitespace($kvnamelist))) 
           { 
                #Check for Az.KeyVault module
                
                Write-Host "`nChecking for Az.KeyVault Module"
                if((Get-Module -ListAvailable).Name -notcontains "Az.KeyVault")
                {
                    Write-Host "Az.KeyVault module not found.."  -BackgroundColor Red
                    Write-Host "=======================================================================================" 
                    $response = read-host "Do you want to continue download and install Az.KeyVault Module? 'Y' or 'N' : "
    
                    if($response.ToUpper() -eq "Y")
                    {
                        Write-Host "Downloading Az.KeyVault PS Module..."
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
                        try 
                        { 
                            Install-Module -Name Az.KeyVault -Force
                        } 
                        catch 
                        {
                            Write-Host "======================================================================================="  
                            Write-Host "Error while downloading Az.KeyVault package , Please make sure computer is connected to internet "  -ForegroundColor Red  
                            Write-Host "Or "  -ForegroundColor Red 
                            Write-Host "Please install it manually "  -ForegroundColor Red   
                            Write-Host "======================================================================================="  
                            Write-Host "Please see the error below. Execution has been stopped...          " 
                            throw  $_.Exception.Response.StatusCode.Value__
                        }
                        Write-Host "Downloaded."
                    }
                    else
                    {
                        Write-Host "Az.KeyVault module is required for the execution. Exiting..."
                        exitCode
                    }
                }
                else
                {
                    Write-Host "Az.KeyVault Module already available" -ForegroundColor green
                }
           }
      }
      catch 
      {
        throw $_.Exception.Message
      }


 $inputfilecheck=0;
} # Input file else



$outputflodercheck=-1;
if ($inputfilecheck -eq 0)
{
    IF ([string]::IsNullOrWhitespace($outputfolder)){$outputfolder="$folder\output\"}

    if (-not(Test-Path -Path $outputfolder)) 
    {
        try 
        {    
            Write-Host "======================================================================================="  
            Write-Host "Unable to locate the output folder [$outputfolder]. Check folder & its permission...  "  -ForegroundColor Red  
            Write-Host "======================================================================================="  
            Write-Host "Please see the error below & SQL Assessment has been stopped          "  
            throw $_.Exception.Message                      
        }
        catch 
        {
            throw $_.Exception.Message
        }
    }
    else
    { 
        $outputflodercheck=0;
    }
}


#check input and output files then proceed <-- Main Loop
if ({($outputflodercheck -eq 0) -and ($inputfilecheck -eq 0)})
{

        Start-Transcript -path  $folder\Logs\DMS_Assessment_Transcript.txt -Append
        $Report_start_time=Get-Date -Format "dddd MM/dd/yyyy HH:mm:ss K"

        [int]$input_count = $namelist.Count

        if($input_count -gt 10) 
        {
            [int]$no_of_servers = Read-Host "Enter the number of Servers to execute per batch, based on the system performance:"
        }
        else 
        {
            $no_of_servers = $input_count
        }

        [int]$Counter = $no_of_servers

        [int]$j = 0
        [int]$loop=1
        $output_data = @()

        while($j -lt $input_count)
        {

            # - For SKU

            "{" | Out-File $folder\Config\SKUConfig$loop.json

            ' "action": "PerfDataCollection",' | Out-File -Append $folder\Config\SKUConfig$loop.json

            ' "sqlConnectionStrings": [' | Out-File -Append $folder\Config\SKUConfig$loop.json

            # - For Assessment

            "{" | Out-File $folder\Config\AssessmentConfig$loop.json

            ' "action": "Assess",' | Out-File -Append $folder\Config\AssessmentConfig$loop.json
            """outputFolder"": ""$($folder -replace '[\\/]','\\')\\output\\""," | Out-file -Append $folder\Config\AssessmentConfig$loop.json
            ' "overwrite": "True",' | Out-File -Append $folder\Config\AssessmentConfig$loop.json
            '  "collectAdHocQuery": "false",' | Out-File -Append $folder\Config\AssessmentConfig$loop.json
            ' "sqlConnectionStrings": [' | Out-File -Append $folder\Config\AssessmentConfig$loop.json

            try 
            {
                #function graphicalbar() 
                #{
                    #-------- GRAPHICAL PROGRESS BAR INIT
                    #title for the winform
                    $Title = "SQL Assessment"
                    #winform dimensions
                    $height=100
                    $width=400
                    #winform background color
                    $color = "White"


                    #create the form
                    $pbform1 = New-Object System.Windows.Forms.Form
                    $pbform1.Text = $title
                    $pbform1.Height = $height
                    $pbform1.Width = $width
                    $pbform1.BackColor = $color

                    $pbform1.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
                    #display center screen
                    $pbform1.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

                    # create label
                    $label1 = New-Object system.Windows.Forms.Label
                    $label1.Text = "not started"
                    $label1.Left=5
                    $label1.Top= 10
                    $label1.Width= $width - 20
                    #adjusted height to accommodate progress bar
                    $label1.Height=15
                    $label1.Font= "Verdana"
                    #optional to show border
                    #$label1.BorderStyle=1

                    #add the label to the form
                    $pbform1.controls.add($label1)

                    $progressBar1 = New-Object System.Windows.Forms.ProgressBar
                    $progressBar1.Name = 'progressBar1'
                    $progressBar1.Value = 0
                    $progressBar1.Style="Continuous"

                    $System_Drawing_Size = New-Object System.Drawing.Size
                    $System_Drawing_Size.Width = $width - 40
                    $System_Drawing_Size.Height = 20
                    $progressBar1.Size = $System_Drawing_Size

                    $progressBar1.Left = 5
                    $progressBar1.Top = 40
            
                    $pbform1.Controls.Add($progressBar1)
            
                    $pbform1.Show()| out-null

                    #give the form focus
                    $pbform1.Focus() | out-null

                    #update the form
                    $label1.text="Preparing..."
                    $pbform1.Refresh()
                    $pbform1.Close() 
                    #----------GRAPHICS PROGRESS BAR INIT ---ENDS
                #}
                #graphicalbar

                #----- CHECK DBA RUN STATUS ADSRunsStatus.csv
                    if(-not((Test-Path -Path $folder\Logs\DMSRunStatus.csv)))
                    {
                        Write-Host "Creating DMSRunStatus Log..."
                        $newcsv = {} | Select "ServerName","InstanceName","Status" | Export-Csv "$folder\Logs\DMSRunStatus.csv" -NoTypeInformation
                        Write-Host "DMSRunStatus Log file creation done" -ForegroundColor Green
                    }
                    else
                    {
                        Write-Host "DMSRunStatus.csv exist. Retrying only failed instances..."
                    }
            
                    $ADSRunStatus = Import-Csv "$folder\Logs\DMSRunStatus.csv"
                #----- DMSRunStatus.csv ends

      
                $i = 0
                 
                if($Counter -eq 1) 
                {
                    $num = $sqllist[$j]
                }
                else 
                {
                    $num = $sqllist[$j..($Counter-1)]
                }
        
                foreach ($row_Content in $num) 
                {
                    $namelist = $row_Content."Computer Name"
                    $instancelist = $row_Content."SQL Server Instance Name"
                    $authlist = $row_Content."Authentication type"
                    $userlist = $row_Content."DBUserName"
                    $pwdlist = $row_Content."DBPassword"
                    $portlist = $row_Content."DBPort"
                    $cnnStringSetings = $row_Content."ConnectionStringSettings"
                    #$productlist = $row_Content."Target SQL Server Version"
                    $kvSubscription = $row_Content."KeyVaultSubscriptionId"	
                    $kvName = $row_Content."KeyVaultName"	
                    $kvSecret = $row_Content."KeyVaultSecretName"

                    IF ([string]::IsNullOrWhitespace($namelist)){continue;}

                    #---UPDATE PROGRESS--------------==================----------------
            
                        Write-Progress -Activity "DMS SQL Assessment/Performance Collection..." -PercentComplete $((($i+$j+1)/$Rowcount)*100) -CurrentOperation "$($i+$j+1). $($namelist)\$($instancelist) ($($i+$j+1) out of $($Rowcount))"

                        #graphical progress bar
                        [int]$pct = $((($i+$j+1)/$Rowcount)*100)

                        #update the progress bar
                        $progressbar1.Value = $pct

                        $label1.text="$($i+$j+1). $($namelist)\$($instancelist) ($($i+$j+1) out of $($Rowcount))"
                        $pbform1.Refresh()
                
                    #---PROGRESS BAR ENDS------------==================-----------------

                    Write-Host "DMS 2.0 SQL Assessment/Performance Collection: " $Report_start_time  -ForegroundColor Green
                
                    # Main Running: DMS (Compatibility) assessment starts from here...
                    Write-host "Running: DMS SQL (Compatibility) assessment/Performance Collection for :$($namelist)\$($instancelist)" -ForegroundColor green

                    $authcheck=-1; # 1 is for Windows and 2 is for SQL Server Authentication
                    
                    if ( $authlist.ToUpper() -notin ("WINDOWS AUTHENTICATION", "SQL SERVER AUTHENTICATION") )
                    {
                        try 
                        {    
                            Write-Host "======================================================================================================="  
                            Write-Host "Currently Supported 'Authentication types' are 'WINDOWS AUTHENTICATION' or 'SQL SERVER AUTHENTICATION' "  -ForegroundColor Red  
                            Write-Host "======================================================================================================="  
                            Write-Host "Please see the error below & DMS SQL Assessment has been stopped          "  
                            throw $_.Exception.Message                      
                        }
                        catch 
                        { 
                            throw $_.Exception.Message            
                        }
                    }
                    else
                    {
                        if ( $authlist.ToUpper() -eq "WINDOWS AUTHENTICATION") 
                        { 
                            $authcheck=1
                        } 
                        else 
                        { 
                            $authcheck=2
                        } 
                    }

                    if ($authcheck -eq 2)
                    {
                         if (  
                            ( $null -ne $namelist     -and $namelist     -ne ''  ) -and
                            ( $null -ne $instancelist -and $instancelist -ne ''  ) -and
                            ( $null -ne $kvName       -and $kvName     -ne ''  ) -and
                            ( $null -ne $kvSecret     -and $kvSecret    -ne ''  ))
                            {
                 
                                try  
                                {     #SQL Server Auth validation passed

                                    #check KV Config
                                    try
                                    {
                                        $azctx = Get-AzContext
                                    }
                                    catch
                                    {
                                        $_.Exception.Message
                                    }

                                    if(-not $azctx) # if context not exists try to get one
                                    {
                                        $azctx =  Connect-AzAccount -UseDeviceAuthentication 
                                        $azctx = Get-AzContext
                                    }
                        
                                    # recheck the context
                                    if($azctx) # context exists
                                    {
                                        #set context to desired subscription
                                        if ($kvSubscription -ne $azctx.Subscription.Id)
                                        {
                                            Set-AzContext -Subscription $kvSubscription
                                        }
                                        $pwdlist = Get-AzKeyVaultSecret -VaultName $kvName -Name $kvSecret -AsPlainText
                                    }
                                    else 
                                    {
                                        Write-Host "No Azure context found, execute Connect-AzAccount to continue"
                                    }


                                }
                                catch 
                                { 
                                    throw $_.Exception.Message
                                }
                            }
                            elseif (
                                ( $null -ne $namelist     -and $namelist     -ne ''  ) -and
                                ( $null -ne $instancelist -and $instancelist -ne ''  ) -and
                                ( $null -ne $pwdlist      -and $pwdlist      -ne ''  ) -and
                                ( $null -ne $userlist     -and $userlist     -ne ''  ))
                                {
                                    Write-Host "SQL SERVER AUTHENTICATION without Keyvault" -ForegroundColor Green
                                }
                            else
                            {
                                throw "'Computer Name', 'SQL Server Instance Name', 'DBUserName' ,'DBPassword, 'DBPort' or 'SQL Server Product Name' is not available." 
                            }
                    }
                    else
                    {
                        if (  
                            ( $null -ne $namelist     -and $namelist     -ne ''  ) -and
                            ( $null -ne $instancelist -and $instancelist -ne ''  ))
                            {
                                <#try  {    #Write-Host "Windows Authentication" #Windows Auth , no userid and password check 
                       
                                }
                                catch { throw $_.Exception.Message            }#>
                            }
                            else
                            {
                                throw "'Computer Name', 'SQL Server Instance Name', 'DBPort' or 'SQL Server Product Name' is not available." 
                            }
                    }
         
                    $defualtinstancecheck=-1;
                    $db_connection_string="";

                    if ( $instancelist.ToUpper() -eq "MSSQLSERVER") 
                    { 
                        $defualtinstancecheck=1
                    } 
                    else 
                    { 
                        $defualtinstancecheck=2
                    }

                    if ( $defualtinstancecheck -eq 1) 
                    { 
                        $db_connection_string = -join("Data Source=",$namelist) 
                    } 
                    else 
                    { 
                        $db_connection_string = -join("Data Source=",$namelist,"\",$instancelist) 
                    } 

                    if (($portlist -ne 1433) -And (-not [string]::IsNullOrWhitespace($portlist)))
                    {
                        $db_connection_string = -join($db_connection_string,",",$portlist)
                    }


                    if (($authcheck -eq 2) -and ($kvName -eq $null))  #SQL SERVER Authentication without KV
                    { 
                        $db_connection_string = -join($db_connection_string,";User ID=",$userlist,";Password=",$pwdlist,";Integrated Security=false") 
                    } 
                    elseif (($authcheck -eq 2) -and ($kvName -ne $null))  #SQL SERVER Authentication with KV
                    { 
                        $db_connection_string = -join($db_connection_string,";User ID=",$kvSecret,";Password=",$pwdlist,";Integrated Security=false") 
                    }
                    else 
                    { 
                        $db_connection_string = -join($db_connection_string,";Initial Catalog=master;Integrated Security=true") 
                    } 

                    if(-not ([string]::IsNullOrWhitespace($cnnStringSetings)))
                    {
                        $db_connection_string = -join($db_connection_string,";$cnnStringSetings") 

                    }

                    #---------- For SKU---------
                    if($i -eq 0)
                    {
                        """$($($db_connection_string -replace '[\\/]','\\') -replace "Server=","Data Source=")""" | Out-File -Append $folder\Config\SKUConfig$loop.json
                        """$($($db_connection_string -replace '[\\/]','\\') -replace "Server=","Data Source=")""" | Out-File -Append $folder\Config\AssessmentConfig$loop.json
                    }
                    else
                    {
                        ",""$($($db_connection_string -replace '[\\/]','\\') -replace "Server=","Data Source=")""" | Out-File -Append $folder\Config\SKUConfig$loop.json 
                        ",""$($($db_connection_string -replace '[\\/]','\\') -replace "Server=","Data Source=")""" | Out-File -Append $folder\Config\AssessmentConfig$loop.json
                    }

                    if ($outputfolder.Substring($outputfolder.Length - 1) -ne "\")
                    {
                        $file_name = -join( $outputfolder.Replace('\', '\\'), "`\`\" ,  $namelist , "_" , $instancelist ) 
                    }
                    else
                    { 
                        $file_name = -join( $outputfolder.Replace('\', '\\'),  $namelist , "_" , $instancelist ) 
                    }
                    $target="";
                    $ADScommand="";
                    $i++
                }

                "]" | Out-file -Append $folder\Config\AssessmentConfig$loop.json
        
                "}" | Out-File -Append $folder\Config\AssessmentConfig$loop.json
        
                "]," | Out-file -Append $folder\Config\SKUConfig$loop.json
                """outputFolder"": ""$($folder -replace '[\\/]','\\')\\output\\PerfData""" | Out-file -Append $folder\Config\SKUConfig$loop.json
                "}" | Out-File -Append $folder\Config\SKUConfig$loop.json


                $ADSNeeded = "1","2"
                if($ADSNeeded.Contains($taskToPerform)) 
                {
                        try
                        {
	                        $file_name="$folder\output"

	                        $Assessment_output=Get-AzDataMigrationAssessment -ConfigFilePath $folder\Config\AssessmentConfig$loop.json
 
                            $file_timestamp=(Get-Date).ToString("yyyy-MM-dd-HHmmss") +".json"    
                            if ($Assessment_output -ne $null)
                            {
                                $filename=Get-ChildItem -Path $file_name -Include SqlAssessmentReport*.json -File -Recurse -ErrorAction SilentlyContinue
                                if ($filename.Name -ne "")
                                {
                                    $ServerData= Get-Content "$file_name\SqlAssessmentReport*.json" | ConvertFrom-Json
                                    $sdtest = $ServerData.Servers

                                    foreach($SD in $sdtest)
                                    {
                                        $serverfilename=$SD.Properties.ServerName
                                        $ServerIP=$SD.Properties.FQDN
                                        $outfilename="$file_name"+"\"+"$serverfilename"+"_"+"$file_timestamp"

                                        $folderToTest = Split-Path $outfilename
                                        if(-not $(Test-Path $folderToTest))
                                        {
                                            New-Item -ItemType Directory -Force -Path $folderToTest | Out-Null
                                        }
                                        $SD | ConvertTo-Json | Out-File -FilePath $outfilename -Force
                      
                                        
                                        $ADS_Content= Get-Content -Path $outfilename -Raw | ConvertFrom-Json
                                        if ($ADS_Content.Status -eq "Error") 
                                        {
                                            Write-Host "DMS Assessment Failed " -ForegroundColor Red 
                                            $ADSStatus = "F"
                                            $temp_output = New-Object PSObject -Property @{ Host_Name=$ServerIP;Status="FAILED"; }
                                        }
                                        elseif ($ADS_Content.Status -eq "Completed") 
                                        {
                                            Write-Host "DMS Assessment Successful " -ForegroundColor Green 
                                            $ADSStatus = "S"
                                            $temp_output = New-Object PSObject -Property @{ Host_Name=$ServerIP;Status="SUCCESS"; }
                                        }
                                        $output_data += $temp_output
                                    }
                                }
                                $Report_start_time=Get-Date -Format "dddd MM/dd/yyyy HH:mm:ss K"
                                $strdate = Get-Date -Format "MMddyyyy_HHmm"
                                Compress-Archive -Path "$folder\output\*.*" -DestinationPath "$folder\output\Compressed\CMF-DMS_SQLAssessment_$strdate.zip"
                                Write-Host "SQL Assessment Completed.....: " $Report_start_time  -ForegroundColor Green

                                Write-Host "============================================================================================================"  
                                Write-Host "Assessment data stored compressed at $folder\output\Compressed" -ForegroundColor Green -BackgroundColor Black
                                Write-Host "============================================================================================================" 
                                Invoke-Item "$folder\output\Compressed"

                                Write-Host "" 
                                Write-Host "======================================================================================="  
                                Write-Host "Below is The final status of Assessment Execution "  -ForegroundColor Green  
                                Write-Host "======================================================================================="

                                Write-Host ($Output_data | Select-Object Host_Name,Status,Error_Msg| Format-Table -AutoSize -wrap| Out-String)  
                            }
                            else
                            {
                                Write-Host "SQL Assessment Skipped.....: " $Report_start_time  -ForegroundColor Green
                            }
                        }
                        catch
                        {
                            throw $_.Exception.Message 
                        }
                }
            }
            catch 
            {
                Write-Host "================================================================================"  
                Write-Host "Error while running the assessment for $($namelist) "  -ForegroundColor Red  
                Write-Host "================================================================================"  
                Write-Host "Please see the error below & SQL Assessment has been stopped          " -ForegroundColor white
                throw $_.Exception.Message
            }
  
            $j = $j + $no_of_servers
            $Counter = $Counter+$no_of_servers
            $loop++
        } #WHILE END

}  # if input and output 
else
{    
    Write-Host "============================================================================================================"  
    Write-Host "Unable to locate the output folder [$outputfolder] or Inputfile [$inputfile] , Check folder & its permission...  "  -ForegroundColor Red  
    Write-Host "============================================================================================================"  
}

$SKUNeeded = "1", "3"

if($SKUNeeded.Contains($taskToPerform))
{
    Write-Host "======================================================================================="  
    Write-Host "Continue Performance Data Collection ?  "  -ForegroundColor Green
    Write-Host "======================================================================================="
    $response = read-host "Enter 'Y' to continue or any other key to abort"
    
    if($response -eq "Y")
    {
        Write-Host "Please Provide the Data Collection duration in Day/s " -ForegroundColor Green
        Write-Host "===================================================================="
        Write-Host "Valid Inputs for Date Range is 0 to 15" 
        Write-Host "If you want to run the data collections below one day please enter 0 "

        #$validInputs_Days = "0", "1", "2", "3", "4" ,"5", "6", "7", "8" , "9", "10", "11", "12" , "13", "14", "15"
        $validInputs_Days = 0..15
        do 
        {
            [int]$Day_response = Read-Host -Prompt "Enter Day value"
            if(-not $validInputs_Days.Contains($Day_response))
            {
                Write-Host "Please select the choice between 0 - 15"
            }
        } until ($validInputs_Days.Contains($Day_response))

        Write-Host "Please Provide the Data Collection duration Hours " -ForegroundColor Green
        Write-Host "===================================================================="
        Write-Host "Valid Inputs for Hour Range is 1 to 23" 
        Write-Host "If you do not want to add Hours please enter 0 "

        $validInputs_Hours = 0..23
        do 
        {
            [int]$Hour_response = Read-Host -Prompt "Enter  Hour value"
            if(-not $validInputs_Hours.Contains($Hour_response))
            {
                Write-Host "Please select the choice between 0 - 23"
            }
        } until ($validInputs_Hours.Contains($Hour_response))

       [int]$Delay_Time = (($Day_response*24*60*60)+($Hour_response*60*60))

       write-host $Delay_Time -ForegroundColor Green
       Write-Host "Config file ready..."
       Write-Host "Triggering Performance data collection"
       createFolder $folder\output\PerfData

       Start-Job -FilePath $PSScriptRoot\Terminate.ps1 -ArgumentList $Delay_Time

        if($input_count%$no_of_servers -eq 0)
        {
            [int]$k=$input_count/$no_of_servers
        }
        else 
        {
            [int]$k=$input_count/$no_of_servers+1
        }
        
        [int]$p=1

        while($p -le $k)
        {
            Get-AzDataMigrationPerformanceDataCollection -ConfigFilePath  $folder\Config\SKUConfig$p.json
            $strdate = Get-Date -Format "MMddyyyy_HHmm"
            Compress-Archive -Path "$folder\output\PerfData\*.*" -DestinationPath "$folder\output\Compressed\CMF_SKUAssessment_$strdate.zip"
            Write-Host "=============================================================================================================="  
            Write-Host "Performance data stored compressed at $folder\output\Compressed" -ForegroundColor Green -BackgroundColor Black
            Write-Host "==============================================================================================================" 
            Invoke-Item "$folder\output\Compressed"
            $p++
        }
    }

    $ADSNeeded = "4"
    if($ADSNeeded.Contains($taskToPerform))
    {
        exitcode
    }
    else
    {
        exitCode
    }
}
exitcode
#timeout /t -1