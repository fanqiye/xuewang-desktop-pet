Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $root '雪王现代桌宠.ps1'
$vbsPath = Join-Path $root '启动动态雪王.vbs'
$manifestPath = Join-Path $root 'assets-hq\manifest.json'
$sourceDir = Join-Path $root 'assets-source'
$tokenPath = Join-Path $root 'design-tokens.json'
$errors = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $scriptPath)) { $errors.Add('缺少现代桌宠主脚本') }
if (-not (Test-Path -LiteralPath $vbsPath)) { $errors.Add('缺少隐藏启动器') }
if (-not (Test-Path -LiteralPath $manifestPath)) { $errors.Add('缺少高清 PNG 帧清单') }
if (-not (Test-Path -LiteralPath $tokenPath)) { $errors.Add('缺少现代设计令牌') }
if (-not (Test-Path -LiteralPath $sourceDir)) { $errors.Add('缺少透明主姿态素材') }

$vbsText = Get-Content -Raw -LiteralPath $vbsPath
if ($vbsText -notmatch [regex]::Escape('雪王现代桌宠.ps1')) { $errors.Add('隐藏启动器没有指向现代桌宠') }
$vbsBytes = [IO.File]::ReadAllBytes($vbsPath)
if ($vbsBytes.Length -lt 2 -or $vbsBytes[0] -ne 0xFF -or $vbsBytes[1] -ne 0xFE) { $errors.Add('隐藏启动器不是 WSH 兼容的 UTF-16LE 编码') }

if (Test-Path -LiteralPath $manifestPath) {
    Add-Type -AssemblyName System.Drawing
    $manifest = Get-Content -Raw -LiteralPath $manifestPath -Encoding UTF8 | ConvertFrom-Json
    $states = @($manifest.PSObject.Properties)
    if ($states.Count -ne 52) { $errors.Add("高清动画状态数量错误：$($states.Count)") }
    $requiredStates = @(
        'hungry','bullied','angry','smug','stuffed','shy','dizzy','pout','crown-tap','cheek-poke','ear-touch','belly-poke','wand-touch','cape-pull','foot-tickle','wake-startle',
        'doro-crawl','food-sneak','guard-pounce','cape-burrito','nightmare-hide','sulk-cocoon','pancake-fall','foot-slip','belly-flop','ice-spell','queen-decree','wand-backfire',
        'snack-struggle','snack-cry','bag-bite','crown-drop','crown-chase','snowball-play','snowball-slide','cheek-squish','cheek-boing','feast-guard','midnight-feast','last-bite'
    )
    foreach ($requiredState in $requiredStates) {
        if ($states.Name -notcontains $requiredState) { $errors.Add("缺少动作或表情状态：$requiredState") }
    }
    $frameCount = 0
    foreach ($state in $states) {
        $frames = @($state.Value.frames)
        $frameCount += $frames.Count
        if ($frames.Count -lt 2) { $errors.Add("高清动画帧数不足：$($state.Name)") }
        foreach ($relative in $frames) {
            $framePath = Join-Path (Join-Path $root 'assets-hq') $relative
            if (-not (Test-Path -LiteralPath $framePath)) {
                $errors.Add("缺少高清帧：$relative")
                continue
            }
            $bitmap = [Drawing.Bitmap]::new($framePath)
            try {
                if ($bitmap.Width -ne 192 -or $bitmap.Height -ne 208) { $errors.Add("高清帧尺寸错误：$relative") }
                if ($bitmap.PixelFormat -ne [Drawing.Imaging.PixelFormat]::Format32bppArgb) { $errors.Add("高清帧不是 32 位透明格式：$relative") }
                if ($bitmap.GetPixel(0,0).A -gt 8) { $errors.Add("高清帧背景不透明：$relative") }
            } finally { $bitmap.Dispose() }
        }
    }
    if ($frameCount -lt 270) { $errors.Add("高清 PNG 帧总数不足：$frameCount") }
}

if (Test-Path -LiteralPath $sourceDir) {
    Add-Type -AssemblyName System.Drawing
    $masterFiles = @(Get-ChildItem -LiteralPath $sourceDir -Filter '*.png')
    if ($masterFiles.Count -ne 21) { $errors.Add("透明主姿态数量错误：$($masterFiles.Count)") }
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir 'xuewang-cheek-squish-fixed.png'))) { $errors.Add('缺少已修正双手挤脸主姿态') }
    foreach($masterFile in $masterFiles) {
        $bitmap = [Drawing.Bitmap]::new($masterFile.FullName)
        try {
            if ($bitmap.PixelFormat -ne [Drawing.Imaging.PixelFormat]::Format32bppArgb) { $errors.Add("主姿态不是 32 位透明格式：$($masterFile.Name)") }
            $cornerAlpha = @($bitmap.GetPixel(0,0).A,$bitmap.GetPixel($bitmap.Width-1,0).A,$bitmap.GetPixel(0,$bitmap.Height-1).A,$bitmap.GetPixel($bitmap.Width-1,$bitmap.Height-1).A)
            if (($cornerAlpha | Measure-Object -Maximum).Maximum -gt 8) { $errors.Add("主姿态背景不透明：$($masterFile.Name)") }
        } finally { $bitmap.Dispose() }
    }
}

if (Test-Path -LiteralPath $scriptPath) {
    $scriptText = Get-Content -Raw -LiteralPath $scriptPath
    foreach ($feature in 'state.json','LocalApplicationData','preferences','welcomeSeen','NotifyIcon','getCursorWorkAreaDip','petting','feeding','sleeping','feedbackCard','nextNudgeAt','ignoredNudges','petCooldownUntil','lastBondDecay','affectionCanDecrease','BitmapScalingMode','assets-hq','ambientRoutineNames','ambientTimer','activityPhase','cursor-curious','dream-twitch','wake-stretch','holdState','health','stamina','petStatus','departureReason','controlWindow','showControlPanel','toggleControlPanel','followMode','stopFollowing','returnHomeMode','craving','grievance','invokeRegionInteraction','resolveHitRegion','regionTapCounts','longPressCount','comboReactionCount','reactionSteps','recentEvents','interactionRegionGrid','quickCareGrid','panelPortrait','panelConclusion','panelFeedbackHost','archivePage','interactionPage','artifactPage','artifactSlots','artifactItems','artifactSets','artifactSlotGrid','artifactChoiceGrid','artifactEquipped','artifactEffects','雪王陪伴屋','国民常青','摇摇雪顶','极夜甜品宫','doro-crawl','pancake-fall','crown-chase','snack-struggle','cape-burrito','休息片刻') {
        if ($scriptText -notmatch [regex]::Escape($feature)) { $errors.Add("缺少成熟互动机制：$feature") }
    }

    foreach ($forbiddenFeature in 'FromFollowDwell','followDwellSince','panelPresenceTimer','$overPet') {
        if ($scriptText -match [regex]::Escape($forbiddenFeature)) { $errors.Add("仍包含会自动弹出档案仪的旧路径：$forbiddenFeature") }
    }
    foreach ($externalChatPattern in 'OpenAI\.[Cc]odex','open[Cc]odex','suppressNextClick','打开\s+[Cc]odex') {
        if ($scriptText -match $externalChatPattern) { $errors.Add("仍包含外部聊天应用入口：$externalChatPattern") }
    }

    $mouseEnterStart = $scriptText.IndexOf('$petImage.Add_MouseEnter')
    $mouseLeaveStart = if ($mouseEnterStart -ge 0) { $scriptText.IndexOf('$petImage.Add_MouseLeave', $mouseEnterStart) } else { -1 }
    if ($mouseEnterStart -lt 0 -or $mouseLeaveStart -le $mouseEnterStart) {
        $errors.Add('缺少雪王悬停视觉处理')
    } else {
        $mouseEnterBlock = $scriptText.Substring($mouseEnterStart, $mouseLeaveStart - $mouseEnterStart)
        if ($mouseEnterBlock -match 'showControlPanel|toggleControlPanel') { $errors.Add('悬停仍会打开或切换档案仪') }
    }

    $rightClickStart = $scriptText.IndexOf('$petImage.Add_MouseRightButtonUp')
    $leftClickStart = if ($rightClickStart -ge 0) { $scriptText.IndexOf('$petImage.Add_MouseLeftButtonDown', $rightClickStart) } else { -1 }
    if ($rightClickStart -lt 0 -or $leftClickStart -le $rightClickStart) {
        $errors.Add('缺少右键档案仪开关处理')
    } else {
        $rightClickBlock = $scriptText.Substring($rightClickStart, $leftClickStart - $rightClickStart)
        if ($rightClickBlock -notmatch [regex]::Escape('toggleControlPanel')) { $errors.Add('右键没有切换档案仪') }
        if ($rightClickBlock -match [regex]::Escape('-LongPress')) { $errors.Add('右键仍被身体长按反应占用') }
    }
}

if (Test-Path -LiteralPath $tokenPath) {
    $tokenData = Get-Content -Raw -LiteralPath $tokenPath -Encoding UTF8 | ConvertFrom-Json
    foreach($tokenName in 'polar-950','glass-shell','frost-400','royal-500','archive-gold','dessert-amber','grievance-violet') {
        if ($tokenData.primitive.PSObject.Properties.Name -notcontains $tokenName) { $errors.Add("缺少至冬设计令牌：$tokenName") }
    }
    foreach($tokenName in 'surface-hover','surface-pressed','primary','focus-ring','border-default','panel-feedback-surface','artifact-evergreen','artifact-shake','artifact-polar-night','artifact-equipped','artifact-option-surface','artifact-option-hover','artifact-official','artifact-original') {
        if ($tokenData.semantic.PSObject.Properties.Name -notcontains $tokenName) {
            $errors.Add("缺少圣遗物语义令牌：$tokenName")
            continue
        }
        $primitiveReference = [string]$tokenData.semantic.$tokenName
        if ($tokenData.primitive.PSObject.Properties.Name -notcontains $primitiveReference) { $errors.Add("圣遗物语义令牌没有引用 primitive：$tokenName") }
    }
    foreach($tokenName in 'panel-tab-height','panel-page-gap','panel-feedback-radius','panel-feedback-padding','artifact-slot-height','artifact-choice-height','artifact-card-radius','artifact-badge-radius','artifact-grid-gap') {
        if ($tokenData.component.PSObject.Properties.Name -notcontains $tokenName) { $errors.Add("缺少圣遗物组件令牌：$tokenName") }
    }
    if ([int]$tokenData.component.'control-width' -lt 420) { $errors.Add('陪伴屋宽度不足') }
    if ([int]$tokenData.component.'control-radius' -lt 24) { $errors.Add('陪伴屋圆角层级不足') }
    if ([int]$tokenData.component.'artifact-slot-height' -lt 52) { $errors.Add('圣遗物槽位卡高度不足') }
    if ([int]$tokenData.component.'artifact-choice-height' -lt 64) { $errors.Add('圣遗物候选卡高度不足') }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

$output = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File $scriptPath -SelfTest 2>&1 | Out-String
$requiredMarkers = @(
    'SELF_TEST_OK','soundSystem=True','traySound=True','trayExit=True','renderer=WPF','hqFrames=True','expressionStates=52','expressionLogic=True','hitRegions=9','regionSpecific=True','gentleTouch=True','sleepRegions=True','longPress=True','comboSystem=True','greedSystem=True','bullySystem=True','modernFeedback=True','modernPanel=True','manualPanel=True','panelFeedback=True',
    'cleanHoverHint=True','artifactSlots=5','artifactItems=15','artifactSets=3','artifactSystem=True','artifactUi=True','artifactPersistence=True','artifactDiskLoad=True','stateBackupRecovery=True','stateTransactionalLoad=True','sweetCareZero=True','shakeDismantle=True','staminaRecovery=True',
    'ambientRoutines=53','ambientVariety=True','naturalSchedule=True','naturalStart=True',
    'staticRest=True','interactions=3','interactionLogic=True','affectionCanDecrease=True',
        'lifeSystem=True','departureReachable=True','followMode=True','nudgeWindow=True','persistence=True'
)
foreach ($marker in $requiredMarkers) {
    if ($output -notmatch [regex]::Escape($marker)) { $errors.Add("自检缺少标记：$marker") }
}
if ($LASTEXITCODE -ne 0 -or $errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    Write-Error "动态桌宠自检失败：$output"
    exit 1
}

$probeRoot = Join-Path ([IO.Path]::GetTempPath()) ("xuewang-persistence-" + [Guid]::NewGuid().ToString('N'))
$probeStatePath = Join-Path $probeRoot 'state.json'
try {
    New-Item -ItemType Directory -Path $probeRoot | Out-Null
    $nowIso = (Get-Date).ToString('o')
    $minimumIso = [datetime]::MinValue.ToString('o')
    $seedState = [ordered]@{
        affection=52; fullness=72; stamina=78; energy=78; health=100; craving=68; grievance=0
        petStatus='home'; departureReason=''; departedAt=$null
        lowHungerTicks=0; starvationTicks=0; recoveryTicks=0; interactions=0; ignoredNudges=0; feedRefusals=0
        lastInteraction=$nowIso; lastBondDecay=$nowIso; lastBondEvent='持久化测试'; recentEvents=@('持久化测试')
        artifacts=[ordered]@{
            version=1
            equipped=[ordered]@{flower='evergreen-flower';plume='evergreen-plume';sands='evergreen-sands';goblet='evergreen-goblet';circlet='evergreen-circlet'}
            cooldowns=[ordered]@{sweetCare=$minimumIso;shakeBuff=$minimumIso;longPressAffinity=$minimumIso;midnightFeast=$minimumIso}
            shakeBuffUntil=$minimumIso
        }
        lastUpdated=$nowIso
    } | ConvertTo-Json -Depth 7
    [IO.File]::WriteAllText($probeStatePath, $seedState, [Text.UTF8Encoding]::new($false))

    $probeOutput = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File $scriptPath -PersistenceProbe -StatePathOverride $probeStatePath 2>&1 | Out-String
    $probeExit = $LASTEXITCODE
    if ($probeExit -ne 0 -or $probeOutput -notmatch 'PERSISTENCE_PROBE_OK write=True emptySlot=True atomic=True') {
        $errors.Add("真实写盘探针失败：$probeOutput")
    } else {
        $writtenState = Get-Content -Raw -LiteralPath $probeStatePath -Encoding UTF8 | ConvertFrom-Json
        $savedPreferenceNames = @($writtenState.preferences.PSObject.Properties.Name)
        if ([string]$writtenState.artifacts.equipped.plume -ne '' -or [int]$writtenState.affection -ne 61 -or
            $savedPreferenceNames -notcontains 'petWidth' -or $savedPreferenceNames -notcontains 'autoMood' -or $savedPreferenceNames -notcontains 'welcomeSeen' -or
            [double]$writtenState.preferences.petWidth -ne [double]$tokenData.component.'pet-width' -or -not [bool]$writtenState.preferences.autoMood -or
            (Test-Path -LiteralPath "$probeStatePath.tmp")) {
            $errors.Add('真实写盘探针没有保存空槽与界面偏好，或遗留临时文件')
        }
    }

    Copy-Item -LiteralPath $probeStatePath -Destination "$probeStatePath.bak" -Force
    $semanticallyBadState = $seedState | ConvertFrom-Json
    $semanticallyBadState.affection = 1
    $semanticallyBadState.fullness = 2
    $semanticallyBadState.stamina = 3
    $semanticallyBadState.health = 'not-an-integer'
    $semanticallyBadState.lastInteraction = 'not-a-date'
    [IO.File]::WriteAllText($probeStatePath, ($semanticallyBadState | ConvertTo-Json -Depth 7), [Text.UTF8Encoding]::new($false))
    $recoveryOutput = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File $scriptPath -SelfTest -StatePathOverride $probeStatePath 2>&1 | Out-String
    $recoveryExit = $LASTEXITCODE
    if ($recoveryExit -ne 0 -or $recoveryOutput -notmatch 'artifactDiskLoad=True' -or $recoveryOutput -notmatch 'stateBackupRecovery=True' -or $recoveryOutput -notmatch 'stateTransactionalLoad=True' -or $recoveryOutput -notmatch 'artifactPersistence=True') {
        $errors.Add("事务式备份恢复或空槽重载探针失败：$recoveryOutput")
    }

    $recoveryWriteOutput = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File $scriptPath -PersistenceProbe -StatePathOverride $probeStatePath 2>&1 | Out-String
    $recoveryWriteExit = $LASTEXITCODE
    if ($recoveryWriteExit -ne 0 -or $recoveryWriteOutput -notmatch 'PERSISTENCE_PROBE_OK write=True emptySlot=True atomic=True recovered=True backupValid=True') {
        $errors.Add("恢复后的安全写回探针失败：$recoveryWriteOutput")
    } else {
        try {
            $recoveredMain = Get-Content -Raw -LiteralPath $probeStatePath -Encoding UTF8 | ConvertFrom-Json
            $recoveredBackup = Get-Content -Raw -LiteralPath "$probeStatePath.bak" -Encoding UTF8 | ConvertFrom-Json
            if ([int]$recoveredMain.affection -ne 61 -or [int]$recoveredBackup.affection -ne 61 -or (Test-Path -LiteralPath "$probeStatePath.tmp")) {
                $errors.Add('恢复写回后主档或备份不是完整有效副本')
            }
        } catch {
            $errors.Add("恢复写回后主档或备份无法解析：$($_.Exception.Message)")
        }
    }
} finally {
    $resolvedProbeRoot = [IO.Path]::GetFullPath($probeRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedProbeRoot.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        foreach ($probeFile in @($probeStatePath, "$probeStatePath.bak", "$probeStatePath.tmp")) {
            if (Test-Path -LiteralPath $probeFile) { Remove-Item -LiteralPath $probeFile -Force }
        }
        if (Test-Path -LiteralPath $resolvedProbeRoot) { Remove-Item -LiteralPath $resolvedProbeRoot -Force }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'XUEWANG_DYNAMIC_TEST_OK'
