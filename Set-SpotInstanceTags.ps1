Param($spotId)

Begin {
  Set-DefaultAWSRegion $env:AWSRegion
  $spot = Get-EC2SpotInstanceRequest -SpotInstanceRequestId $spotId
}

Process {
  New-EC2Tag -Resource $spot.InstanceId -Tag @{ Key=$_.Key; Value=$_.Value }
}

End {
  # Executes once after last pipeline object is processed
}
