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
  [string]$iotHubCS
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

# Sender wait duration
$senderWaitValue = 2000

# Listener wait duration
$listenerWaitValue = 2000


#Setup the listener process info
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = "cmd.exe"

#get approximate invocation time
$epochseconds = Get-Date (Get-Date).ToUniversalTime() -UFormat %s
$invokeTimeInEpochMilliSeconds= [double][math]::Round([double]$epochseconds*1000)

$startInfo.Arguments = "/c az iot hub monitor-events --props app -y -n "+$iotHubName+" -d "+ $deviceId+" -l "+$iotHubCS + " -e "+$invokeTimeInEpochMilliSeconds
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
$senderStartInfo.UseShellExecute = $false
$senderStartInfo.CreateNoWindow = $true

#Start the sender process
$senderProcess = New-Object System.Diagnostics.Process
$senderProcess.StartInfo = $senderStartInfo

Write-Host "Test commnunication from IOT Hub:$iotHubName to module: $moduleId on device:$deviceId by invoke module direct method:$methodName ..."

$senderProcess.Start() | Out-Null
$senderOutput = $senderProcess.StandardOutput.ReadToEnd()
$senderProcess.WaitForExit($senderWaitValue)


 if($senderOutput.Contains("200") -and $senderOutput.Contains($correlationid)) 
 {
    Write-Host "Module direct Method Invoked - Hub to Device connection validated" -ForegroundColor Green
    write-host $senderOutput
 }
 else
 {
    Write-Host "Module direct Method Invoked - Hub to Device connection validation failed:"+$senderOutput -ForegroundColor Red
    exit 1

 }

$senderProcess.close()
$senderProcess.Dispose()

$listenerOutput = $process.StandardOutput.ReadToEnd()

$process.WaitForExit($listenerWaitValue)

Write-Host ("Test commnunication from module:$moduleId running on device:$deviceId to IOT Hub:$iotHubName by checking recieved iothub messages ...")

if($listenerOutput.Contains($deviceId) -and $listenerOutput.Contains($moduleId) -and $listenerOutput.Contains($correlationid))
 {
    Write-Host "Device to Hub connection validatied" -ForegroundColor Green
    write-host $listenerOutput
 }
 else
 {
    Write-Host "Device to Hub connection validationon failed:"+$listenerOutput -ForegroundColor Red
    exit 1

 }


$process.Close();
$process.Dispose();