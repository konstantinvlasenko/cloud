Param($spotId)

Begin {
  Set-DefaultAWSRegion $env:AWSRegion
  $spot = Get-EC2SpotInstanceRequest $spotId
}

Process {
  $instanceId | out-default
  New-EC2Tag -Resource $spot.InstanceId -Tag @{ Key=$_.Key; Value=$_.Value }
}

End {
  # Executes once after last pipeline object is processed
}