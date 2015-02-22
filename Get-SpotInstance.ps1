Param($spotId)

Set-DefaultAWSRegion $env:AWSRegion
$spot = Get-EC2SpotInstanceRequest $spotId
(Get-EC2Instance $spot.InstanceId).RunningInstance