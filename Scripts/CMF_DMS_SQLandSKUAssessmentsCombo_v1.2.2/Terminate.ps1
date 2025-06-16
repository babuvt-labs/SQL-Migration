#Set-ExecutionPolicy -ExecutionPolicy  unrestricted 
$wshell = New-Object -ComObject wscript.shell;

[int]$Delay=$args[0]
Start-Sleep -Seconds $Delay

$wshell.AppActivate('Administrator: Command Prompt')
#$wshell.AppActivate('C:\Windows\System32\cmd.exe')
#Start-Sleep -Seconds 5
$wshell.SendKeys('{ENTER}')
Start-Sleep -Seconds 5
$wshell.AppActivate('Administrator: Command Prompt')
#$wshell.AppActivate('C:\Windows\System32\cmd.exe')
$wshell.SendKeys('~')
#>