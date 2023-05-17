function Edit-Notes {
  [CmdletBinding()]
  Param(
    [string]$Notes,
    [string]$Change,
    [string]$Label = 'Changes:',
    [int]$Length = 0,
    [switch]$Add,
    [switch]$LogEntry
  )

  Begin {
  }

  Process {
    $noteTime = Get-Date -Format 'yyyy-MMM-dd HHmm'
    if ($Label -eq 'Changes:' -or $LogEntry) {
      if ($Notes -match $Label) {
        $StaticNotes = $Notes.Substring(0, $Notes.IndexOf($Label) + $Label.Length)
        $ChangesNotes = $Notes.Substring($Notes.IndexOf($Label) + $Label.Length)
        if ($Length -gt 0) {
          $NewChangeNotes = $null
          $ChangeNotesLines = ($ChangesNotes.Trim()).Split("`n")
          $linecount = 1
          foreach ($line in $ChangeNotesLines) {
            $linecount++
            if ($linecount -gt $Length) {
              break
            }
            $NewChangeNotes += '{0}{1}' -f "`n", $line
          }
          $ChangesNotes = $NewChangeNotes
        }
        $NewChange = '{0}{1}  {2}' -f "`n", $noteTime, $Change
        $NewNotes = '{0}{1}{2}' -f $StaticNotes, $NewChange, $ChangesNotes
      } else {
        $StaticNotes = $Notes
        $AddChangesDelimiter = "`n$Label"
        $NewChange = '{0}{1}  {2}' -f "`n", $noteTime, $Change
        $NewNotes = '{0}{1}{2}' -f $StaticNotes, $AddChangesDelimiter, $NewChange
      }
      $NewNotes
    } else {
      $SearchLabel = ('{0}:' -f $Label)
      if ($Notes -match $SearchLabel) {
        $StaticNotes = $Notes.Substring(0, $Notes.IndexOf($SearchLabel) + $SearchLabel.Length)
        $NotesAfterLabel = $Notes.Substring($Notes.IndexOf($SearchLabel) + $SearchLabel.Length)
        $LabelNotes = $NotesAfterLabel.Substring(0, $NotesAfterLabel.IndexOf("`n"))
        $NotesAfterLabel = $NotesAfterLabel -replace $LabelNotes
        if ($Add) {
          $LabelNotes = '{0}, {1} ' -f $LabelNotes.Trim(), $Change
        } else {
          $LabelNotes = $Change
        }
        $NewLabelNotes = '{0} {1}{2}' -f $StaticNotes, $LabelNotes, $NotesAfterLabel
        $NewLabelNotes
      } else {
        Throw 'Unable to find label provided.'
      }
    }
  }

  End {}
}
