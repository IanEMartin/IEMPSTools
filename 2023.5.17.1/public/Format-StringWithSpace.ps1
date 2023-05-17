Filter Format-StringWithSpace {
  if ($_ -match ' ') {
    "'$_'"
  } else {
    $_
  }
}
