param(
  [Parameter(Mandatory=$True,Position=1)]
  [string]$iotHubName,
  [Parameter(Mandatory=$True,Position=2)]
  [string]$deviceId,
  [Parameter(Mandatory=$True,Position=3)]
  [string]$moduleId,
  [Parameter(Mandatory=$True,Position=4)]
  [string]$methodName,
  [Parameter(Mandatory=$True,Position=5)]
  [string]$iotHubCS,
  [Parameter(Mandatory=$true,Position=6)]
  [int]$maxTestWaitTimeInSeconds
)

$installed_apps = Get-CimInstance win32_product | Select-Object Name
$az_installed = $false

For ($i=0; $i -lt $installed_apps.Length; $i++) {
$app = [string]$installed_apps[$i]
     if ($app.contains("Microsoft") -and $app.Contains("Azure") -and $app.Contains("CLI")){    
    $az_installed = $true
    break}
     }

if ($az_installed -eq $false)
{
write-host "Azure CLI is not installed - script can not be executed"
Exit 
}

write-host "Check if iot-extension for AZ CLI installed"
$az_iot_ext_install_status=$(az extension show --name azure-cli-iot-ext)
if ($az_iot_ext_install_status.Length -eq 0)
    {
        write-host "Add iot-extension for AZ CLI"
        az extension add --name azure-cli-iot-ext
    }


# Listener wait duration
$listenerWaitValue = 2000


#Setup the listener process info
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = "cmd.exe"

#get approximate invocation time
$epochseconds = Get-Date (Get-Date).ToUniversalTime() -UFormat %s
$invokeTimeInEpochMilliSeconds= [double][math]::Round([double]$epochseconds*1000)

$startInfo.Arguments = "/c az iot hub monitor-events --props app -y -n "+$iotHubName+" -d "+ $deviceId+" -l "+$iotHubCS + " -e "+$invokeTimeInEpochMilliSeconds+" -t "+$maxTestWaitTimeInSeconds
$startInfo.RedirectStandardOutput = $true

$startInfo.RedirectStandardError = $true
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true


#Start the listener process
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
$process.Start() | Out-Null

#Setup the sender process info
$senderStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$senderStartInfo.FileName = "cmd.exe"

#create a correlation ID for the sender
$random = get-random -inputobject (1..40000) 
$correlationid = "CId"+[string]$random

$methodpayload = "{\" +"`"correlationId\`":\`""+$correlationid+"\`"}"
$senderStartInfo.Arguments = "/c az iot hub invoke-module-method  -n "+$iotHubName+" -d "+$deviceId+" -m "+$moduleId+" --mn "+$methodName+" -l "+$iotHubCS +" --mp "+ $methodpayload

$senderStartInfo.RedirectStandardOutput = $true
$senderStartInfo.RedirectStandardError = $true

$senderStartInfo.UseShellExecute = $false
$senderStartInfo.CreateNoWindow = $true

#Start the sender process
$senderProcess = New-Object System.Diagnostics.Process
$senderProcess.StartInfo = $senderStartInfo

Write-Host "Test commnunication from IOT Hub:$iotHubName to module: $moduleId on device:$deviceId by invoke module direct method:$methodName ..."
$senderProcess.Start() | Out-Null

$senderProcess.WaitForExit()
$senderOutput = $senderProcess.StandardOutput.ReadToEnd()
 if($senderOutput.Contains("200") -and $senderOutput.Contains($correlationid)) 
 {
    Write-Host "Module direct Method Invoked - Hub to Device connection validated" -ForegroundColor Green
    write-host $senderOutput
 }
 else
 {
    $sendererror= $senderProcess.StandardError.ReadToEnd()
    Write-Host "Module direct Method Invoked - Hub to Device connection validation failed:"$sendererror -ForegroundColor Red
    exit 1

 }

$senderProcess.close()
$senderProcess.Dispose()

$process.WaitForExit($listenerWaitValue) 
$listenerOutput = $process.StandardOutput.ReadToEnd()


Write-Host ("Test commnunication from module:$moduleId running on device:$deviceId to IOT Hub:$iotHubName by checking recieved iothub messages ...")

if($listenerOutput.Contains($deviceId) -and $listenerOutput.Contains($moduleId) -and $listenerOutput.Contains($correlationid))
 {
    Write-Host "Device to Hub connection validatied" -ForegroundColor Green
    write-host $listenerOutput
 }
 else
 {
   $listenererror= $process.StandardError.ReadToEnd()
    Write-Host "Device to Hub connection validationon failed:"$listenerOutput -ForegroundColor Red
    Write-Host $listenererror -ForegroundColor Red
    exit 1

 }


$process.Close();
$process.Dispose();