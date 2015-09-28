Param($spotId)

Begin {
  Set-DefaultAWSRegion $env:AWSRegion
  if($spotId)
  {
  $spot = Get-EC2SpotInstanceRequest -SpotInstanceRequestId $spotId
  }
  else
  {
   Write-Error "The spot id should not be null or empty"
  }
}

Process {
  New-EC2Tag -Resource $spot.InstanceId -Tag @{ Key=$_.Key; Value=$_.Value }
}

End {
  # Executes once after last pipeline object is processed
}
