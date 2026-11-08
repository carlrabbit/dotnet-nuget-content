param(
    [Parameter(Mandatory = $true)][string] $CandidateDirectory,
    [int] $TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$packageVersion = '2.0.0'
$candidateRoot = (Resolve-Path -LiteralPath $CandidateDirectory).Path
$ridPackage = Join-Path $candidateRoot "dotnet-nuget-content.win-x64.$packageVersion.nupkg"
$runId = [guid]::NewGuid().ToString('N')
$work = Join-Path ([System.IO.Path]::GetTempPath()) "dotnet-nuget-content M0008 scale $runId"
$root = Join-Path $work 'fixture-root'
$exe = Join-Path $work 'dotnet-nuget-content.exe'
$seed = 'm8-scale-v1'
$script:sampleReports = [System.Collections.Generic.List[object]]::new()
$wholeRunWatch = [System.Diagnostics.Stopwatch]::StartNew()

function Invoke-MeasuredNative([string[]] $Arguments, [string] $Name) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $exe
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    [long]$peakWorkingSet = 0
    while (-not $process.HasExited) {
        $process.Refresh()
        if ($process.PeakWorkingSet64 -gt $peakWorkingSet) { $peakWorkingSet = $process.PeakWorkingSet64 }
        if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "$Name exceeded the $TimeoutSeconds-second operational watchdog; this is a hang guard, not a performance SLA."
        }
        Start-Sleep -Milliseconds 50
    }
    $process.Refresh()
    if ($process.PeakWorkingSet64 -gt $peakWorkingSet) { $peakWorkingSet = $process.PeakWorkingSet64 }
    $watch.Stop()
    $result = [pscustomobject]@{
        Name = $Name; Arguments = $Arguments; ExitCode = $process.ExitCode
        Stdout = $stdoutTask.GetAwaiter().GetResult(); Stderr = $stderrTask.GetAwaiter().GetResult()
        ElapsedMilliseconds = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
        PeakWorkingSetBytes = $peakWorkingSet
    }
    $script:sampleReports.Add([ordered]@{
        name = $Name; arguments = $Arguments; elapsedMilliseconds = $result.ElapsedMilliseconds
        peakWorkingSetBytes = $peakWorkingSet; exitCode = $result.ExitCode; stdoutBytes = [Text.Encoding]::UTF8.GetByteCount($result.Stdout)
    })
    return $result
}

function Invoke-Workspace([string[]] $Arguments, [string] $Name) {
    $result = Invoke-MeasuredNative ($Arguments + @('--workspace', $root)) $Name
    if ($result.ExitCode -ne 0) { throw "$Name failed with exit $($result.ExitCode): $($result.Stderr)" }
    if ($result.Stderr) { throw "$Name unexpectedly wrote diagnostics: $($result.Stderr)" }
    return $result
}

function Get-Sha256([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

try {
    if (-not (Test-Path -LiteralPath $ridPackage -PathType Leaf)) { throw "Candidate RID package is missing: $ridPackage" }
    New-Item -ItemType Directory -Path $work, $root | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ridPackage)
    try {
        $nativeEntry = $archive.GetEntry('tools/any/win-x64/dotnet-nuget-content.exe')
        if (-not $nativeEntry) { throw 'Candidate RID package is missing its win-x64 executable.' }
        $input = $nativeEntry.Open(); $output = [System.IO.File]::Open($exe, [System.IO.FileMode]::CreateNew)
        try { $input.CopyTo($output) } finally { $output.Dispose(); $input.Dispose() }
    } finally { $archive.Dispose() }

    [System.IO.File]::WriteAllText((Join-Path $work 'outside-sentinel.txt'), 'must remain outside scan scope')
    $init = Invoke-MeasuredNative @('workspace', 'init', '--workspace', $root) 'fixture initialization'
    if ($init.ExitCode -ne 0) { throw "Fixture workspace initialization failed: $($init.Stderr)" }
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'content') | Out-Null
    $packageIds = @((0..9) | ForEach-Object { 'sample.scale.pkg{0:d2}' -f $_ })
    foreach ($i in 0..9) {
        $id = $packageIds[$i]
        $alias = 'pkg{0:d2}' -f $i
        $source = Join-Path $work "source-$alias"
        New-Item -ItemType Directory -Path $source | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $source 'fixture.txt'), "$seed $alias`n")
        $package = Join-Path $root "content/$id.1.0.0.nupkg"
        $pack = Invoke-MeasuredNative @('pack', '--id', $id, '--version', '1.0.0', '--source', $source, '--output', $package) "create $alias package"
        if ($pack.ExitCode -ne 0) { throw "Could not create $alias package: $($pack.Stderr)" }
        $add = Invoke-MeasuredNative @('workspace', 'add', '--alias', $alias, '--package', "content/$id.1.0.0.nupkg", '--directory', "content/$alias", '--workspace', $root) "register $alias"
        if ($add.ExitCode -ne 0) { throw "Could not register ${alias}: $($add.Stderr)" }
    }
    $unpack = Invoke-Workspace @('workspace', 'unpack', '--all') 'unpack all package members'
    foreach ($i in 0..9) { if (-not (Test-Path -LiteralPath (Join-Path $root ('content/pkg{0:d2}/.nuget-content/manifest.json' -f $i)) -PathType Leaf)) { throw "Fixture member pkg$i was not unpacked." } }

    $props = [System.Text.StringBuilder]::new()
    [void]$props.AppendLine('<Project><PropertyGroup><ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally></PropertyGroup><ItemGroup>')
    foreach ($id in $packageIds) { [void]$props.AppendLine("<PackageVersion Include=`"$id`" Version=`"1.0.0`" />") }
    [void]$props.AppendLine('</ItemGroup></Project>')
    [System.IO.File]::WriteAllText((Join-Path $root 'Directory.Packages.props'), $props.ToString(), [System.Text.UTF8Encoding]::new($false))

    foreach ($projectNo in 0..99) {
        $projectName = 'Project{0:d3}' -f $projectNo
        $projectDirectory = Join-Path $root "projects/$projectName"
        New-Item -ItemType Directory -Path $projectDirectory | Out-Null
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net11.0</TargetFramework></PropertyGroup><ItemGroup>')
        if (($projectNo % 2) -eq 0) { $lines.Add('<PackageReference Include="' + $packageIds[0] + '" Version="1.0.0" />') }
        else { $lines.Add('<PackageReference Include="' + $packageIds[0] + '" />') }
        $other = 1 + ($projectNo % 9)
        if (($projectNo % 2) -eq 0) { $lines.Add('<PackageReference Include="' + $packageIds[$other] + '" />') }
        else { $lines.Add('<PackageReference Include="' + $packageIds[$other] + '" Version="1.0.0" />') }
        if ($projectNo -eq 0) {
            $lines.Add('<PackageReference Include="' + $packageIds[9] + '" Version="$(UnresolvedPackageVersion)" />')
            $lines.Add('<PackageReference Include="' + $packageIds[8] + '" Version="1.0.0" Condition="''$(UseOptionalPackage)'' == ''true''" />')
        }
        $lines.Add('</ItemGroup></Project>')
        [System.IO.File]::WriteAllText((Join-Path $projectDirectory "$projectName.csproj"), ($lines -join "`n"), [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $projectDirectory 'unrelated.txt'), "$seed $projectNo`n", [System.Text.UTF8Encoding]::new($false))
        New-Item -ItemType Directory -Path (Join-Path $projectDirectory 'obj'), (Join-Path $projectDirectory 'bin') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $projectDirectory 'obj/Generated.csproj'), ('<Project><ItemGroup><PackageReference Include="' + $packageIds[0] + '" Version="1.0.0" /></ItemGroup></Project>'))
        [System.IO.File]::WriteAllText((Join-Path $projectDirectory 'bin/Generated.csproj'), ('<Project><ItemGroup><PackageReference Include="' + $packageIds[0] + '" Version="1.0.0" /></ItemGroup></Project>'))
    }
    $realProjects = @(Get-ChildItem -LiteralPath (Join-Path $root 'projects') -Filter '*.csproj' -File -Recurse | Where-Object { $_.FullName -match '\\Project\d{3}\\Project\d{3}\.csproj$' })
    if ($realProjects.Count -ne 100) { throw "Fixture must contain exactly 100 source SDK-style projects, found $($realProjects.Count)." }

    $selectedWorkspace = Join-Path $root 'content/pkg00/fixture.txt'
    [System.IO.File]::AppendAllText($selectedWorkspace, 'selected advancement`n')
    $advance = Invoke-Workspace @('workspace', 'advance', '--alias', 'pkg00', '--patch') 'advance selected package'
    if ($advance.Stdout -notmatch '1\.0\.1') { throw 'Selected package did not advance to version 1.0.1.' }

    $usageArgs = @('workspace', 'usage', '--all', '--json')
    $usageOne = Invoke-Workspace $usageArgs 'usage scan sample 1'
    $usageTwo = Invoke-Workspace $usageArgs 'usage scan sample 2'
    $usageJson = $usageTwo.Stdout | ConvertFrom-Json
    if (@($usageJson.members).Count -ne 10) { throw 'Usage scan did not return all 10 registered package records.' }
    $usageIds = @($usageJson.members | ForEach-Object packageId | Sort-Object -Unique)
    if ($usageIds.Count -ne 10 -or @($usageJson.members.useSites | Where-Object { $_.path -match 'outside-sentinel|\.\.\\' }).Count -gt 0) { throw 'Usage scan package coverage or path scope is incorrect.' }
    $observedProjectPaths = @($usageJson.members.useSites | ForEach-Object path | Sort-Object -Unique)
    if ($observedProjectPaths.Count -ne 100 -or @($observedProjectPaths | Where-Object { $_ -match '(^|/)(obj|bin)/|Generated\.csproj' }).Count -gt 0) { throw "Usage scan included generated projects or missed source projects: observed $($observedProjectPaths.Count) project paths." }
    foreach ($path in $observedProjectPaths) {
        $full = [System.IO.Path]::GetFullPath((Join-Path $root $path))
        if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Usage result escaped the project root: $path" }
    }

    $inspectArgs = @('workspace', 'inspect', '--all', '--json')
    $inspectOne = Invoke-MeasuredNative ($inspectArgs + @('--workspace', $root)) 'workspace inspection sample 1'
    $inspectTwo = Invoke-MeasuredNative ($inspectArgs + @('--workspace', $root)) 'workspace inspection sample 2'
    if ($inspectOne.ExitCode -ne 1 -or $inspectTwo.ExitCode -ne 1 -or $inspectOne.Stderr -notmatch 'Conditional package reference' -or $inspectTwo.Stderr -notmatch 'Conditional package reference') { throw 'Inspect did not consistently report the expected conditional declaration diagnostic.' }
    $inspectJson = $inspectTwo.Stdout | ConvertFrom-Json
    if (@($inspectJson.members).Count -ne 10 -or @($inspectJson.members | Where-Object { $_.state -eq 'corrupt' -or $_.state -eq 'mismatched' }).Count -gt 0 -or @($inspectJson.diagnostics | Where-Object { $_ -match 'Conditional package reference' }).Count -eq 0) { throw 'Workspace inspect returned an incomplete or invalid member state/diagnostic.' }

    $previewArgs = @('workspace', 'references', 'update', '--alias', 'pkg00', '--json')
    $preview1 = Invoke-Workspace $previewArgs 'selected reference preview sample 1'
    $preview2 = Invoke-Workspace $previewArgs 'selected reference preview sample 2'
    $plan = $preview2.Stdout | ConvertFrom-Json
    if ($plan.targetVersion -ne '1.0.1' -or $plan.applied -or -not $plan.canApply -or @($plan.changes).Count -lt 2) { throw 'Selected reference preview did not provide a valid read-only update plan.' }
    $projectFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'projects') -Filter '*.csproj' -File -Recurse)
    $preApply = @{}
    foreach ($file in $projectFiles) { $preApply[$file.FullName] = Get-Sha256 $file.FullName }
    $propsPath = Join-Path $root 'Directory.Packages.props'
    $propsBefore = Get-Sha256 $propsPath
    $unrelatedPath = Join-Path $root 'projects/Project000/unrelated.txt'
    $unrelatedBefore = Get-Sha256 $unrelatedPath
    $apply = Invoke-Workspace @('workspace', 'references', 'update', '--alias', 'pkg00', '--apply', '--json') 'selected reference apply'
    $applyJson = $apply.Stdout | ConvertFrom-Json
    if (-not $applyJson.applied -or $applyJson.targetVersion -ne '1.0.1') { throw 'Selected reference apply did not report the 1.0.1 update.' }
    foreach ($file in $projectFiles) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $sourceProject = [regex]::Match($file.FullName, '\\Project(?<n>\d{3})\\Project\k<n>\.csproj$')
        $shouldChange = $sourceProject.Success -and ([int]$sourceProject.Groups['n'].Value % 2 -eq 0)
        if ($shouldChange -and $content -match 'sample\.scale\.pkg00" Version="1\.0\.0"') { throw "Selected direct reference was not updated: $($file.FullName)" }
        if ($shouldChange -and $content -notmatch 'sample\.scale\.pkg00" Version="1\.0\.1"') { throw "Selected direct reference was not set to 1.0.1: $($file.FullName)" }
        if (-not $shouldChange) {
            if ((Get-Sha256 $file.FullName) -cne $preApply[$file.FullName]) { throw "Apply changed an unrelated project file: $($file.FullName)" }
        }
    }
    $propsAfter = [System.IO.File]::ReadAllText($propsPath)
    if ((Get-Sha256 $propsPath) -eq $propsBefore -or $propsAfter -notmatch 'sample\.scale\.pkg00" Version="1\.0\.1"' -or [regex]::Matches($propsAfter, '<PackageVersion Include="sample\.scale\.pkg00"').Count -ne 1) { throw 'The selected central package version was not changed exactly once.' }
    if ((Get-Sha256 $unrelatedPath) -cne $unrelatedBefore) { throw 'Reference apply changed an unrelated project file.' }

    $dynamicPreview = Invoke-MeasuredNative @('workspace', 'references', 'update', '--alias', 'pkg09', '--json', '--workspace', $root) 'dynamic reference negative preview'
    if ($dynamicPreview.ExitCode -ne 1 -or $dynamicPreview.Stderr) { throw "Dynamic reference preview did not return the documented blocked-plan operation code: $($dynamicPreview.Stderr)" }
    $dynamicPlan = $dynamicPreview.Stdout | ConvertFrom-Json
    if ($dynamicPlan.canApply -or $dynamicPlan.applied -or @($dynamicPlan.blockers).Count -eq 0) { throw 'Dynamic/conditional declaration did not block a reference update plan.' }
    $dynamicFile = Join-Path $root 'projects/Project000/Project000.csproj'
    $dynamicBefore = Get-Sha256 $dynamicFile
    $dynamicApply = Invoke-MeasuredNative (@('workspace', 'references', 'update', '--alias', 'pkg09', '--apply', '--json', '--workspace', $root)) 'dynamic reference negative apply'
    if ($dynamicApply.ExitCode -ne 1 -or $dynamicApply.Stderr) { throw "Blocked dynamic reference apply did not fail with the documented operation code: $($dynamicApply.Stderr)" }
    $blockedPlan = $dynamicApply.Stdout | ConvertFrom-Json
    if ($blockedPlan.applied -or $blockedPlan.canApply -or (Get-Sha256 $dynamicFile) -cne $dynamicBefore) { throw 'Blocked dynamic/conditional reference apply wrote project files.' }
    $conditionalPreview = Invoke-MeasuredNative @('workspace', 'references', 'update', '--alias', 'pkg08', '--json', '--workspace', $root) 'conditional reference negative preview'
    if ($conditionalPreview.ExitCode -ne 1 -or $conditionalPreview.Stderr) { throw "Conditional reference preview did not return the documented blocked-plan operation code: $($conditionalPreview.Stderr)" }
    $conditionalPlan = $conditionalPreview.Stdout | ConvertFrom-Json
    if ($conditionalPlan.canApply -or $conditionalPlan.applied -or @($conditionalPlan.blockers).Count -eq 0) { throw 'Conditional declaration did not block a reference update plan.' }
    $conditionalBefore = Get-Sha256 $dynamicFile
    $conditionalApply = Invoke-MeasuredNative (@('workspace', 'references', 'update', '--alias', 'pkg08', '--apply', '--json', '--workspace', $root)) 'conditional reference negative apply'
    if ($conditionalApply.ExitCode -ne 1 -or $conditionalApply.Stderr) { throw "Blocked conditional reference apply did not fail with the documented operation code: $($conditionalApply.Stderr)" }
    $conditionalBlockedPlan = $conditionalApply.Stdout | ConvertFrom-Json
    if ($conditionalBlockedPlan.applied -or $conditionalBlockedPlan.canApply -or (Get-Sha256 $dynamicFile) -cne $conditionalBefore) { throw 'Blocked conditional reference apply wrote project files.' }
    $outsideSentinel = Join-Path $work 'outside-sentinel.txt'
    if ([System.IO.File]::ReadAllText($outsideSentinel) -cne 'must remain outside scan scope') { throw 'Scale operations changed a file outside the project root.' }

    [double]$elapsedTotal = 0
    [double]$qualificationElapsedTotal = 0
    foreach ($sample in $script:sampleReports) {
        $elapsedTotal += [double]$sample['elapsedMilliseconds']
        if ([string]$sample['name'] -match 'usage scan|workspace inspection|reference preview|reference apply|reference negative') { $qualificationElapsedTotal += [double]$sample['elapsedMilliseconds'] }
    }
    $elapsed = [math]::Round($elapsedTotal, 1)
    $qualificationElapsed = [math]::Round($qualificationElapsedTotal, 1)
    $wholeRunWatch.Stop()
    $usageSiteCount = @($usageJson.members | ForEach-Object useSites | ForEach-Object { $_ }).Count
    $usageClassifications = @($usageJson.members | ForEach-Object useSites | ForEach-Object { $_.classification } | Sort-Object -Unique)
    $inspectStates = @($inspectJson.members | Group-Object state | Sort-Object Name | ForEach-Object { [ordered]@{ state = $_.Name; count = $_.Count } })
    $referenceSourceKinds = @($plan.changes | Group-Object sourceKind | Sort-Object Name | ForEach-Object { [ordered]@{ sourceKind = $_.Name; count = $_.Count } })
    $result = [ordered]@{
        schemaVersion = 1; fixtureSeed = $seed; projectCount = 100; registeredPackageCount = 10
        referenceMix = 'literal direct, literal central, dynamic version, conditional declaration; one selected package update'
        environment = [ordered]@{ os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription; architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(); sdk = (& dotnet --version).Trim() }
        candidateRidPackage = [System.IO.Path]::GetFileName($ridPackage); candidateRidPackageSha256 = Get-Sha256 $ridPackage
        watchdogSecondsPerOperation = $TimeoutSeconds; watchdogIsPerformanceSla = $false
        operations = @($script:sampleReports); totalOperationElapsedMilliseconds = $elapsed; measuredUsageInspectionReferenceElapsedMilliseconds = $qualificationElapsed
        totalWallClockElapsedMilliseconds = [math]::Round($wholeRunWatch.Elapsed.TotalMilliseconds, 1)
        outputs = [ordered]@{
            usage = [ordered]@{ packageIds = $usageIds; observedProjectPaths = $observedProjectPaths.Count; useSiteCount = $usageSiteCount; classifications = $usageClassifications }
            inspect = [ordered]@{ memberStates = $inspectStates; diagnostics = @($inspectJson.diagnostics) }
            selectedReferencePreview = [ordered]@{ targetVersion = $plan.targetVersion; canApply = $plan.canApply; changes = @($plan.changes); sourceKinds = $referenceSourceKinds }
            selectedReferenceApply = [ordered]@{ targetVersion = $applyJson.targetVersion; applied = $applyJson.applied }
            dynamicReferenceBlockers = @($blockedPlan.blockers)
            conditionalReferenceBlockers = @($conditionalBlockedPlan.blockers)
        }
        assertions = [ordered]@{ projectCount = 100; packageCount = 10; usageProjectPathsObserved = $observedProjectPaths.Count; generatedProjectExclusions = $true; inspectMembers = @($inspectJson.members).Count; referenceChanges = @($plan.changes).Count; selectedApply = $applyJson.applied; dynamicApplyBlocked = -not $blockedPlan.applied; conditionalApplyBlocked = -not $conditionalBlockedPlan.applied; unrelatedProjectPreserved = $true; outsideRootSentinelPreserved = $true }
    }
    $json = $result | ConvertTo-Json -Depth 10
    if ($CandidateDirectory) {
        $reportPath = Join-Path $candidateRoot 'repository-scale-report.json'
        [System.IO.File]::WriteAllText($reportPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
    }
    Write-Output $json
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
