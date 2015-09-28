Param($spotId)

Set-DefaultAWSRegion $env:AWSRegion
if($spotId)
{
  $spot = Get-EC2SpotInstanceRequest -SpotInstanceRequestId $spotId
}
else
{
   Write-Error "The spot id should not be null or empty"
}
(Get-EC2Instance $spot.InstanceId).RunningInstance