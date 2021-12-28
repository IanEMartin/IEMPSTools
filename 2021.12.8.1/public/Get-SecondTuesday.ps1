# Returns a date object of the second tuesday of the month for given moth and year
function Get-SecondTuesday {
  [CmdletBinding()]
  param
  (
    [int]
    $Month,

    [int]
    $Year
  )

  [int]$Day = 1
  while ((Get-Date -Year $Year -Month $Month -Day $Day -Hour 0 -Minute 0 -Second 0).DayOfWeek -ne 'Tuesday') {
    $day++
  }
  $day += 7
  return (Get-Date -Year $Year -Month $Month -Day $Day -Hour 0 -Minute 0 -Second 0)
}
