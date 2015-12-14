param($tc_user,$tc_psw,$smtpServer,$smtpPort,$username,$password,$from,$receivers,$serverAddress,$labManager,$acceptanceTests,$buildType)

function Execute-HTTPPostCommand() {
    param(
        [string] $target = $null
    )

    $request = [System.Net.WebRequest]::Create($target)
    Write-Host $request.RequestUri
    $request.PreAuthenticate = $true
    $request.Method = "GET"
    $request.Credentials = new-object system.net.networkcredential($tc_user, $tc_psw)
    $response = $request.GetResponse()
    $sr = [Io.StreamReader]($response.GetResponseStream())
    $xmlout = $sr.ReadToEnd()
    return $xmlout;
}

function sendEmail($subject, $content)
{
    $smtp = new-object Net.Mail.SmtpClient($smtpServer, $smtpPort)
    $smtp.EnableSsl = $true 

    $smtp.Credentials = new-object Net.NetworkCredential($username, $password)
    $msg = new-object Net.Mail.MailMessage
    $msg.From = $from
    $receivers | % {$msg.To.add($_)}
    $msg.Subject = $subject
    $msg.IsBodyHTML = $true
    $msg.Body = $content
    $smtp.Send($msg)
}


$result = $false
$buildList = $labManager + $acceptanceTests
foreach ($build in $buildList)
{
    if($build -eq $buildType) {continue;}

    $command = $($serverAddress + "/httpAuth/app/rest/buildTypes/id:$build/builds/running:true/")
    $xml = [xml]$(Execute-HTTPPostCommand $command)
    if($xml -ne $null)
    {
        $result = $true
        break;
    }      
}

function get_result($xml,$v)
{
if($xml -ne $null)
    {
    if($v -eq $version)
        {
        $command = $serverAddress + $xml.build.statistics.href
        $statisticsXml = [xml]$(Execute-HTTPPostCommand $command)
        $buildDuration = (($statisticsXml.properties.property | ?{"BuildDuration" -eq $_.name}).value.Substring(0,4)/60).ToString("f1")
        $startDate = $xml.build.startDate.Substring(0,13)
        $startDate = $startDate.Substring(0,4) + "/" + $startDate.Substring(4,2)+ "/" + $startDate.Substring(6,2) + " " + $startDate.Substring(9,2) + ":" + $startDate.Substring(11,2)
        $formattedStartDate =  (Get-Date $startDate).ToUniversalTime().AddHours(8).ToString('yyyy/MM/dd HH:mm')
        $totalTestCount = $xml.build.testOccurrences.count
        $passedTestCount = $xml.build.testOccurrences.passed
        $failedTestCount = $xml.build.testOccurrences.failed
        $newFailedTestCount = $xml.build.testOccurrences.newFailed
        if($newFailedTestCount -ne $null){$failedTestCount +="($newFailedTestCount new)"}
        if($xml.build.status -eq "FAILURE" -and $failedTestCount -eq $null) {$failedTestCount = $xml.build.statusText}
        $urls = $xml.build.webUrl.Split('/')
        $logUrl = $($serverAddress + "/" + $urls[$urls.length-1])
        if($xml.build.status -eq "FAILURE"){$tdstyle="tg-mzz2"} else {$tdstyle="tg-uhi5"}

        return "<tr><td class=""tg-xdyu"">$($xml.build.buildType.name)</td><td class=""$tdstyle"">$($xml.build.status)</td><td class=""tg-031e""><a href=""$logUrl"">$($xml.build.number)</a></td><td class=""tg-031e"">$formattedStartDate</td><td class=""tg-031e"">$buildDuration</td><td class=""tg-031e"">$totalTestCount</td><td class=""tg-031e"">$passedTestCount</td><td class=""tg-mzz2"">$failedTestCount</td></tr>"
        }
    else
        {
        return "<tr><td class=""tg-xdyu"">$($xml.build.buildType.name)</td><td class=""$tdstyle"">-</td><td class=""tg-031e"">-</td><td class=""tg-031e"">-</td><td class=""tg-031e"">-</td><td class=""tg-031e"">-</td><td class=""tg-031e"">-</td><td class=""tg-mzz2"">-</td></tr>"
        }
    }
}

echo "Check current build whether is last build"
if($result -eq $false)
{
$result = @"
<head>
<style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{font-family:Arial, sans-serif;font-size:14px;padding:10px 5px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;}
.tg th{font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 5px;border-style:solid;border-width:1px;overflow:hidden;word-break:normal;}
.tg .tg-wv6k{font-weight:bold;background-color:#329a9d;text-align:center}
.tg .tg-xdyu{font-weight:bold;font-style:italic}
.tg .tg-mzz2{font-weight:bold;color:#fe0000}
.tg .tg-uhi5{font-weight:bold;color:#32cb00}
</style>
</head><body>
<table class="tg"><tr><th class="tg-wv6k">Acceptance Tests</th><th class="tg-wv6k">Status</th><th class="tg-wv6k">Build</th><th class="tg-wv6k">Start Date</th><th class="tg-wv6k">Build Duration(m)</th><th class="tg-wv6k">Total Tests</th><th class="tg-wv6k">Tests Passed</th><th class="tg-wv6k">Tests Failed</th></tr>
"@
Sleep 10
$command = $($serverAddress + "/httpAuth/app/rest/buildTypes/id:$buildType/builds/running:true/")
$xml = [xml]$(Execute-HTTPPostCommand $command)
$version = $xml.build.number
$result += get_result $xml $xml.build.number

echo "Get all the test result"
foreach ($build in $acceptanceTests)
{
    $command = $($serverAddress + "/httpAuth/app/rest/buildTypes/id:$build/builds/running:false/")
    $xml = [xml]$(Execute-HTTPPostCommand $command)
    $result += get_result $xml $xml.build.number
}
$result += "</table></body></html>"

echo "Send emails"
sendEmail "MNSP Test Result($version)" $result
}