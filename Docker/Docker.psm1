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

  $titles = [regex]::Split($images[0], "\s{2,}") | ForEach-Object { return (Get-Culture).TextInfo.ToTitleCase($_.ToLower()) }

  $infos = @()
  $images | Select-Object -Skip 1 | ForEach-Object {
    $columns = [regex]::Split($_, "\s{2,}") | Where-Object { -not [string]::IsNullOrEmpty($_) }
    $info = New-Object PSCustomObject
    for ($i = 0; $i -lt $titles.Count; $i++) {
      
      $info | Add-Member -MemberType NoteProperty -Name $titles[$i].Replace(" ", "") -Value $columns[$i]
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

Function Get-DockerContainers {
  param([switch]$a)
  $params = @()
  $params += "container","ls"
  if ($a) { $params += "-a" }

  $containers = docker @params

  $titles = [regex]::Split($containers[0], "\s{2,}") | ForEach-Object { return (Get-Culture).TextInfo.ToTitleCase($_.ToLower()) }

  $infos = @()
  $containers | Select-Object -Skip 1 | ForEach-Object {
    $info = New-Object PSCustomObject
    for ($i = 0; $i -lt $titles.Count; $i++) {
      $r = $_
      $columnStartIndex = ($containers | Select-String -Pattern "$($titles[$i])").Matches.Index
      $columnEndIndex = $(if (($i+1) -lt $titles.Count) { ($containers | Select-String -Pattern "$($titles[$i+1])").Matches.Index } else { $r.Length })
      $column = $r.Substring($columnStartIndex, $columnEndIndex - $columnStartIndex).Trim()
      $info | Add-Member -MemberType NoteProperty -Name $titles[$i].Replace(" ", "") -Value $column
    }
    $infos += $info
  }

  return $infos
}

Function Get-DockerComposeCommands {
  param(
    [string]$Command
  )
  $help = $(if ($Command) { docker-compose $Command --help } else { docker-compose --help }) | Select-String -Pattern "^\s{2}\w+" | Where-Object { $_ -notlike "*docker-compose*" }
  $cmds = @()
  for ($i = 0; $i -lt $help.Count; $i++) {
    $cmdline = $help[$i].Line.Trim()
    $cmds += $cmdline.Substring(0, $cmdline.IndexOf(" "))
  }
  return $cmds
}

Function Get-DockerComposeServices {
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  if (-not (Test-Path $Path)) {
    throw
  }
  $file = Get-Content (Convert-Path $Path)
  $categories = $file | Select-String -Pattern "^\w+:"
  $service = $categories | Where-Object {$_.Line -like "services:*"}
  $serviceIdx = $categories.IndexOf($service)
  $startLine = ($categories[$serviceIdx] | Select-Object -ExpandProperty LineNumber)
  $endLine = $(if ($serviceIdx -lt $categories.Length - 1) {$categories[$serviceIdx+1] | Select-Object -ExpandProperty LineNumber} else {$file.Count})
  return $file | Select-Object -Skip $startLine -First ($endLine - $startLine) | Select-String -Pattern "^\s{2}\w+:" | Select-Object @{Name="Service";Expression={$_.Line.Trim().Replace(":","")}} | Sort-Object -Property Service
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

      if ($cmd -eq "container" -or $cmd -eq "rmc") {
        $containers = Get-DockerContainers -a | Select-Object -ExpandProperty Names
        return $containers
      }

      if ($subcmd -ne "ls" -or $subcmd -ne "build" -or $subcmd -ne "import") {
        $images = Get-DockerImages -a | Select-Object @{Name="RepoTag";Expression={$_.Repository+":"+$_.Tag}}
        $options = @()
        $options += $images | Select-Object -ExpandProperty RepoTag
        return $options
      }
    })]
    [string[]]$Parameters
  )

  $params = @()
  $params += $Parameters

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
    "v" { docker volume @params }
    default { docker $Command @params }
  }
}

Function Invoke-DockerCompose {
  [Alias("dc")]
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      $cmds = Get-DockerComposeCommands
      return $(if ($wordToComplete) { $cmds | Where-Object { $_ -like "$wordToComplete*" } } else { $cmds })
    })]
    [string]$Command,
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      $fIdx = $commandAst.CommandElements | Where-Object {$_.Value -eq "-f" -or $_.Value -eq "--file"}
      $file = $commandAst[$fIdx+1].Value
      $services = Get-DockerComposeServices -Path $(if ($file) { $file } else { 'docker-compose.yml' }) | Select-Object -ExpandProperty Service
      return $(if ($wordToComplete) { $services | Where-Object { $_ -like "$wordToComplete*" } } else { $services })
    })]
    [string[]]$Parameters
  )

  $params = @()
  $params += $Parameters
  
  switch ($Command) {
    "b" { docker-compose build @params }
    "c" { docker-compose create @params }
    "d" { docker-compose down @params }
    "l" { docker-compose logs @params }
    "s" { docker-compose start @params }
    "u" { docker-compose up @params }
    "ud" { docker-compose up --detach @params }
    "x" { docker-compose stop @params }
    default { docker-compose $Command @params }
  }
}

Export-ModuleMember -Function "Invoke-Docker" -Alias "d"
Export-ModuleMember -Function "Invoke-DockerCompose" -Alias "dc"
Export-ModuleMember -Function "Get-DockerImages","Get-DockerCommands","Get-DockerContainers","Get-DockerComposeCommands","Get-DockerComposeServices"