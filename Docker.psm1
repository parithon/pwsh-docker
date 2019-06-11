Function Get-DockerImages {
  param(
    [switch]$a
  )
  
  $params = @()
  $params += "image","ls"
  if ($a) {
    $params += "-a"
  }

  $images = docker @params

  $titles = [regex]::Split($images[0], "\s{2,}") | ForEach-Object { return (Get-Culture).TextInfo.ToTitleCase($_.ToLower()).Replace(" ", "") }

  $infos = @()
  $images | Select-Object -Skip 1 | ForEach-Object {
    $columns = [regex]::Split($_, "\s{2,}") | Where-Object { -not [string]::IsNullOrEmpty($_) }
    $info = New-Object PSCustomObject
    for ($i = 0; $i -lt $titles.Count; $i++) {
      $info | Add-Member -MemberType NoteProperty -Name $titles[$i] -Value $columns[$i]
    }
    $infos += $info
  }

  return $infos
}

Function Get-DockerCommands {
  param(
    [string]$Command
  )
  $help = $(if ($Command) { docker $Command --help } else { docker --help }) | Select-String -Pattern "^\s{2}\w+"
  $cmds = @()
  for ($i = 0; $i -lt $help.Count; $i++) {
    $cmdline = $help[$i].Line.Trim()
    $cmds += $cmdline.Substring(0, $cmdline.IndexOf(" "))
  }
  return $cmds
}

Function Invoke-Docker {
  [Alias("d")]
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      $cmds = Get-DockerCommands
      return $(if ($wordToComplete) { $cmds | Where-Object { $_ -like "$wordToComplete*" } } else { $cmds })
    })]
    [string]$Command,
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      $cmd = $fakeBoundParameters["Command"]
      $ast = $commandAst.CommandElements | Where-Object Value -EQ $cmd
      $subcmdidx = $commandAst.CommandElements.IndexOf($ast)
      $subcmd = $commandAst.CommandElements[$subcmdidx + 1].Value

      if ((-not $subcmd -or $subcmd -eq $wordToComplete) -and (Get-DockerCommands) -contains $cmd) {
        $cmds = Get-DockerCommands $cmd
        $results = $(if ($wordToComplete) { $cmds | Where-Object { $_ -like "$wordToComplete*" } } else { $cmds })
        if ($results) { return $results }
      }

      if ($subcmd -ne "ls" -or $subcmd -ne "build" -or $subcmd -ne "import") {
        $images = Get-DockerImages | Select-Object @{Name="RepoTag";Expression={$_.Repository+":"+$_.Tag}}
        $options = @()
        $options += $images | Select-Object -ExpandProperty RepoTag
        return $options
      }
    })]
    [string[]]$Arguments
  )

  $params = @()
  $params += $Arguments

  switch ($Command) {
    "b" { docker build @params }
    "c" { docker container @params }
    "cs" { docker container start @params }
    "cx" { docker container stop @params }
    "i" { docker images @params }
    "t" { docker tag @params }
    "k" { docker kill @params }
    "l" { docker logs @params }
    "li" { docker login @params }
    "lo" { docker logout @params }
    "r" { docker run @params  }
    "rmc" { docker container rm @params }
    "p" { docker push @params }
    default { docker $Command @params }
  }
}

Export-ModuleMember -Function "Invoke-Docker","Get-DockerImages","Get-DockerCommands" -Alias "d"