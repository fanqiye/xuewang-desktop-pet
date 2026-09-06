param(
    [switch]$SelfTest,
    [switch]$OpenPanel,
    [switch]$OpenInteraction,
    [switch]$OpenArtifacts,
    [switch]$PersistenceProbe,
    [string]$StatePathOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:createdNew = $false
$mutexName = if ($SelfTest) { 'Local\XueWangModernPet_20260817_SelfTest' } elseif ($PersistenceProbe) { 'Local\XueWangModernPet_20260817_PersistenceProbe' } else { 'Local\XueWangModernPet_20260817' }
$script:mutex = [Threading.Mutex]::new($true, $mutexName, [ref]$script:createdNew)
if (-not $script:createdNew) { exit 0 }

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace XueWangDesktopPet {
    public static class NativeIcon {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyIcon(IntPtr handle);
    }
}
'@

    $app = [Windows.Application]::new()
    $app.ShutdownMode = [Windows.ShutdownMode]::OnMainWindowClose

    $assetDir = Join-Path $PSScriptRoot 'assets-hq'
    $manifestPath = Join-Path $assetDir 'manifest.json'
    $tokenPath = Join-Path $PSScriptRoot 'design-tokens.json'
    $legacyStatePath = Join-Path $PSScriptRoot 'state.json'
    $localDataRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $appDataDir = if ([string]::IsNullOrWhiteSpace($localDataRoot)) { $PSScriptRoot } else { Join-Path $localDataRoot 'SnowCourt\XueWangPet' }
    if ($PersistenceProbe -and [string]::IsNullOrWhiteSpace($StatePathOverride)) { throw 'PersistenceProbe 必须使用独立的 StatePathOverride，禁止改写正式存档。' }
    $statePath = if ([string]::IsNullOrWhiteSpace($StatePathOverride)) { Join-Path $appDataDir 'state.json' } else { [IO.Path]::GetFullPath($StatePathOverride) }
    if ($PersistenceProbe) {
        $probeTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $statePath.StartsWith($probeTempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'PersistenceProbe 只允许写入系统临时目录。' }
    }
    if (-not $SelfTest -and [string]::IsNullOrWhiteSpace($StatePathOverride)) {
        [IO.Directory]::CreateDirectory($appDataDir) | Out-Null
        if (-not (Test-Path -LiteralPath $statePath) -and (Test-Path -LiteralPath $legacyStatePath)) {
            Copy-Item -LiteralPath $legacyStatePath -Destination $statePath
            if (Test-Path -LiteralPath "$legacyStatePath.bak") { Copy-Item -LiteralPath "$legacyStatePath.bak" -Destination "$statePath.bak" }
        }
    }
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "缺少高清动画清单：$manifestPath" }
    if (-not (Test-Path -LiteralPath $tokenPath)) { throw "缺少设计令牌：$tokenPath" }

    $manifest = Get-Content -Raw -LiteralPath $manifestPath -Encoding UTF8 | ConvertFrom-Json
    $tokens = Get-Content -Raw -LiteralPath $tokenPath -Encoding UTF8 | ConvertFrom-Json
    $primitive = $tokens.primitive
    $semantic = $tokens.semantic
    $semanticColor = {
        param([string]$Name)
        $reference = [string]$semantic.PSObject.Properties[$Name].Value
        if ([string]::IsNullOrWhiteSpace($reference)) { throw "缺少语义设计令牌：$Name" }
        return [string]$primitive.PSObject.Properties[$reference].Value
    }
    $color = @{
        Surface = & $semanticColor 'surface-card'
        SurfaceBorder = & $semanticColor 'border-default'
        Ink = & $semanticColor 'text-primary'
        Muted = & $semanticColor 'text-secondary'
        Accent = & $semanticColor 'accent'
        Positive = [string]$primitive.'aurora-400'
        PositiveSoft = [string]$primitive.'polar-800'
        Need = [string]$primitive.'dessert-amber'
        NeedSoft = [string]$primitive.'polar-800'
        Energy = [string]$primitive.'royal-300'
        EnergySoft = [string]$primitive.'polar-800'
        Health = [string]$primitive.'imperial-red'
        HealthDark = [string]$primitive.'imperial-red'
        HealthSoft = [string]$primitive.'polar-800'
        Boundary = [string]$primitive.'grievance-violet'
        BoundarySoft = [string]$primitive.'polar-800'
        Identity = [string]$primitive.'archive-gold'
        Trust = [string]$primitive.'trust-rose'
        Royal = & $semanticColor 'primary'
        SurfaceGlass = & $semanticColor 'surface-shell'
        SurfaceHover = & $semanticColor 'surface-hover'
        SurfacePressed = & $semanticColor 'surface-pressed'
        Divider = & $semanticColor 'border-default'
        Shadow = [string]$primitive.'shadow-polar'
        Track = [string]$primitive.'track-dark'
        SegmentOff = [string]$primitive.'segment-off'
        White = [string]$primitive.'frost-50'
    }
    $brush = { param([string]$Value) [Windows.Media.BrushConverter]::new().ConvertFromString($Value) }

    # 五槽圣遗物：商品原名只用于来源说明，游戏化物名与“极夜甜品宫”均为桌宠原创。
    $artifactSlots = @(
        [pscustomobject]@{ Id='flower';  Name='永冻之花'; Genshin='生之花'; Icon='❄' },
        [pscustomobject]@{ Id='plume';   Name='赤羽之翎'; Genshin='死之羽'; Icon='✦' },
        [pscustomobject]@{ Id='sands';   Name='柠光之刻'; Genshin='时之沙'; Icon='◇' },
        [pscustomobject]@{ Id='goblet';  Name='皇室御盏'; Genshin='空之杯'; Icon='♢' },
        [pscustomobject]@{ Id='circlet'; Name='初雪之冠'; Genshin='理之冠'; Icon='♛' }
    )
    $artifactSets = [ordered]@{
        evergreen = [pscustomobject]@{
            Name='雪王·国民常青'; Short='国民常青'; Tone='identity'; Source='2025 年度销量前五'
            Two=[ordered]@{ FeedFullnessBonus=2; FeedCravingRelief=5 }
            Four=[ordered]@{ FeedAffectionBonus=1; SweetCareRelief=6; SweetCareCooldown=30 }
        }
        shake = [pscustomobject]@{
            Name='摇摇雪顶'; Short='摇摇雪顶'; Tone='trust'; Source='官方产品或曾推出系列'
            Two=[ordered]@{ PlayEnergyDiscount=2 }
            Four=[ordered]@{ PlayAffectionBonus=1; SnackCravingMitigation=4; ShakeBuffDuration=12; ShakeBuffCooldown=35; ShakeComboEnergyGain=2; ShakeComboAffectionBonus=1 }
        }
        'polar-night' = [pscustomobject]@{
            Name='极夜甜品宫'; Short='极夜甜品宫'; Tone='energy'; Source='桌宠原创，不是官方新品'
            Two=[ordered]@{ ComfortGrievanceRelief=5; LongPressGrievanceRelief=2 }
            Four=[ordered]@{ ComboGrievanceRelief=4; LowFeedEnergyBonus=4; LowFeedAffectionBonus=1; LowFeedCooldown=60 }
        }
    }
    $artifactItems = @(
        [pscustomobject]@{Id='evergreen-flower';Slot='flower';Set='evergreen';Name='鲜橙绽瓣';Product='棒打鲜橙';SourceKind='official-top5';EffectText='投喂御体 +1';Effects=[ordered]@{FeedHealthBonus=1}},
        [pscustomobject]@{Id='shake-flower';Slot='flower';Set='shake';Name='摇摇莓心';Product='草莓摇摇奶昔';SourceKind='official-product';EffectText='投喂御体 +1';Effects=[ordered]@{FeedHealthBonus=1}},
        [pscustomobject]@{Id='night-flower';Slot='flower';Set='polar-night';Name='极夜莓晶露';Product='';SourceKind='pet-original';EffectText='投喂御体 +1';Effects=[ordered]@{FeedHealthBonus=1}},
        [pscustomobject]@{Id='evergreen-plume';Slot='plume';Set='evergreen';Name='冰柠翎叶';Product='冰鲜柠檬水';SourceKind='official-top5';EffectText='玩耍霜能消耗 -1';Effects=[ordered]@{PlayEnergyDiscount=1}},
        [pscustomobject]@{Id='shake-plume';Slot='plume';Set='shake';Name='椰风白羽';Product='生打椰椰';SourceKind='official-product';EffectText='玩耍霜能消耗 -1';Effects=[ordered]@{PlayEnergyDiscount=1}},
        [pscustomobject]@{Id='night-plume';Slot='plume';Set='polar-night';Name='青提冰翎';Product='';SourceKind='pet-original';EffectText='玩耍霜能消耗 -1';Effects=[ordered]@{PlayEnergyDiscount=1}},
        [pscustomobject]@{Id='evergreen-sands';Slot='sands';Set='evergreen';Name='珍珠流刻';Product='珍珠奶茶';SourceKind='official-top5';EffectText='投喂馋嘴额外 -4';Effects=[ordered]@{FeedCravingRelief=4}},
        [pscustomobject]@{Id='shake-sands';Slot='sands';Set='shake';Name='雪顶晨刻';Product='雪王雪顶咖啡';SourceKind='official-product';EffectText='玩耍霜能消耗再 -1';Effects=[ordered]@{PlayEnergyDiscount=1}},
        [pscustomobject]@{Id='night-sands';Slot='sands';Set='polar-night';Name='苹果雪砂';Product='';SourceKind='pet-original';EffectText='长按委屈额外 -2';Effects=[ordered]@{LongPressGrievanceRelief=2}},
        [pscustomobject]@{Id='evergreen-goblet';Slot='goblet';Set='evergreen';Name='茉莉御盏';Product='茉莉奶绿';SourceKind='official-top5';EffectText='投喂饱食 +2';Effects=[ordered]@{FeedFullnessBonus=2}},
        [pscustomobject]@{Id='shake-goblet';Slot='goblet';Set='shake';Name='蓝莓星盏';Product='蓝莓系列';SourceKind='official-series';EffectText='玩耍信赖 +1';Effects=[ordered]@{PlayAffectionBonus=1}},
        [pscustomobject]@{Id='night-goblet';Slot='goblet';Set='polar-night';Name='白桦蜜乳盏';Product='';SourceKind='pet-original';EffectText='安抚委屈额外 -3';Effects=[ordered]@{ComfortGrievanceRelief=3}},
        [pscustomobject]@{Id='evergreen-circlet';Slot='circlet';Set='evergreen';Name='初雪冠冕';Product='新鲜冰淇淋';SourceKind='official-top5';EffectText='组合技信赖 +1';Effects=[ordered]@{ComboAffectionBonus=1}},
        [pscustomobject]@{Id='shake-circlet';Slot='circlet';Set='shake';Name='香芋绒冠';Product='香芋系列冰淇淋';SourceKind='official-series';EffectText='长按信赖 +1（冷却）';Effects=[ordered]@{LongPressAffectionBonus=1}},
        [pscustomobject]@{Id='night-circlet';Slot='circlet';Set='polar-night';Name='女皇香芋雪冠';Product='';SourceKind='pet-original';EffectText='组合技委屈额外 -3';Effects=[ordered]@{ComboGrievanceRelief=3}}
    )
    $artifactById = @{}
    foreach ($artifactItem in $artifactItems) { $artifactById[[string]$artifactItem.Id] = $artifactItem }
    $artifactEquipped = [ordered]@{
        flower='evergreen-flower'; plume='evergreen-plume'; sands='evergreen-sands'; goblet='evergreen-goblet'; circlet='evergreen-circlet'
    }
    $artifactEffectCaps = [ordered]@{
        FeedHealthBonus=2; FeedFullnessBonus=4; FeedAffectionBonus=2; FeedCravingRelief=12
        PlayEnergyDiscount=4; PlayAffectionBonus=2; SnackCravingMitigation=4
        ComfortGrievanceRelief=10; LongPressGrievanceRelief=5; LongPressAffectionBonus=1
        ComboEnergyGain=3; ComboAffectionBonus=2; ComboGrievanceRelief=8; ShakeComboEnergyGain=3; ShakeComboAffectionBonus=2
        SweetCareRelief=6; SweetCareCooldown=30; ShakeBuffDuration=12; ShakeBuffCooldown=35
        LowFeedEnergyBonus=4; LowFeedAffectionBonus=1; LowFeedCooldown=60
    }
    $artifactEffects = [ordered]@{}
    $artifactSetCounts = [ordered]@{ evergreen=0; shake=0; 'polar-night'=0 }
    $artifactShakeBuffUntil = [datetime]::MinValue
    $artifactCooldowns = [ordered]@{
        sweetCare=[datetime]::MinValue; shakeBuff=[datetime]::MinValue; longPressAffinity=[datetime]::MinValue; midnightFeast=[datetime]::MinValue
    }
    # 所有圣遗物事件闭包共享同一个引用对象，避免 WPF 回调进入动态模块后把 `$script:` 解析到错误作用域。
    $artifactUiState = [pscustomobject]@{
        SelectedSlot='flower'
        Equipped=$artifactEquipped
        Effects=$artifactEffects
        SetCounts=$artifactSetCounts
        ShakeBuffUntil=$artifactShakeBuffUntil
        Cooldowns=$artifactCooldowns
        Refresh=$null
    }
    $script:artifactRuntime = $artifactUiState
    $rebuildArtifactEffects = {
        $effects = [ordered]@{}
        foreach ($effectKey in $artifactEffectCaps.Keys) { $effects[$effectKey] = 0 }
        $counts = [ordered]@{ evergreen=0; shake=0; 'polar-night'=0 }
        $mergeEffects = {
            param([Collections.IDictionary]$Source)
            foreach ($entry in $Source.GetEnumerator()) {
                if ($effects.Contains($entry.Key)) { $effects[$entry.Key] = [int]$effects[$entry.Key] + [int]$entry.Value }
            }
        }
        foreach ($slot in $artifactSlots) {
            $slotId = [string]$slot.Id
            $itemId = [string]$artifactUiState.Equipped[$slotId]
            if (-not $itemId -or -not $artifactById.ContainsKey($itemId)) { continue }
            $item = $artifactById[$itemId]
            if ([string]$item.Slot -ne $slotId) { continue }
            $counts[[string]$item.Set] = [int]$counts[[string]$item.Set] + 1
            & $mergeEffects $item.Effects
        }
        foreach ($setId in $artifactSets.Keys) {
            $set = $artifactSets[$setId]
            if ([int]$counts[$setId] -ge 2) { & $mergeEffects $set.Two }
            if ([int]$counts[$setId] -ge 4) { & $mergeEffects $set.Four }
        }
        foreach ($effectKey in $artifactEffectCaps.Keys) {
            $effects[$effectKey] = [Math]::Min([int]$artifactEffectCaps[$effectKey], [Math]::Max(0, [int]$effects[$effectKey]))
        }
        $effects['Evergreen4'] = ([int]$counts['evergreen'] -ge 4)
        $effects['Shake4'] = ([int]$counts['shake'] -ge 4)
        $effects['Night4'] = ([int]$counts['polar-night'] -ge 4)
        if (-not [bool]$effects['Shake4']) { $artifactUiState.ShakeBuffUntil = [datetime]::MinValue }
        $artifactUiState.Effects = $effects
        $artifactUiState.SetCounts = $counts
    }.GetNewClosure()
    & $rebuildArtifactEffects

    $script:frames = @{}
    $script:frameIntervals = @{}
    foreach ($property in $manifest.PSObject.Properties) {
        $stateName = $property.Name
        $entry = $property.Value
        $loaded = [Collections.Generic.List[Windows.Media.Imaging.BitmapImage]]::new()
        foreach ($relative in $entry.frames) {
            $path = Join-Path $assetDir ([string]$relative)
            if (-not (Test-Path -LiteralPath $path)) { throw "缺少高清帧：$path" }
            $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit()
            $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.UriSource = [Uri]::new($path, [UriKind]::Absolute)
            $bitmap.EndInit()
            $bitmap.Freeze()
            $loaded.Add($bitmap)
        }
        if ($loaded.Count -lt 2) { throw "高清动画帧数不足：$stateName" }
        $script:frames[$stateName] = $loaded
        $script:frameIntervals[$stateName] = [int]$entry.intervalMs
    }

    $script:affection = 52
    $script:fullness = 72
    $script:energy = 78
    $script:health = 100
    $script:craving = 68
    $script:grievance = 0
    $script:petStatus = 'home'
    $script:departureReason = ''
    $script:departedAt = $null
    $script:lowHungerTicks = 0
    $script:starvationTicks = 0
    $script:recoveryTicks = 0
    $script:interactionCount = 0
    $script:ignoredNudges = 0
    $script:feedRefusals = 0
    $script:lastInteraction = Get-Date
    $script:lastBondDecay = Get-Date
    $script:lastBondEvent = '刚刚见面，正在熟悉彼此'
    $script:recentEvents = [Collections.Generic.List[string]]::new()
    $script:recentEvents.Add("$(Get-Date -Format 'HH:mm') · 初次建档 · 女皇已抵达桌面")
    $script:savedPetWidth = [double]$tokens.component.'pet-width'
    $script:savedAutoMood = $true
    $script:welcomeSeen = $false
    $script:soundEnabled = $true
    $script:autoStartEnabled = $false
    $script:lastSoundAt = [datetime]::MinValue
    $normalizeSavedState = {
        param($Raw)
        if ($null -eq $Raw) { throw '空存档' }
        $names = @($Raw.PSObject.Properties.Name)
        if ($names -notcontains 'affection' -or $names -notcontains 'fullness' -or ($names -notcontains 'stamina' -and $names -notcontains 'energy')) { throw '存档缺少必要字段' }
        $status = if ($names -contains 'petStatus') { [string]$Raw.petStatus } else { 'home' }
        if ($status -notin @('home','departed','deceased')) { throw '无效的生命状态' }
        $events = @()
        if ($names -contains 'recentEvents' -and $null -ne $Raw.recentEvents) { $events = @($Raw.recentEvents | ForEach-Object { [string]$_ }) }
        $normalized = [pscustomobject]@{
            Affection = [int]$Raw.affection
            Fullness = [int]$Raw.fullness
            Energy = if ($names -contains 'stamina') { [int]$Raw.stamina } else { [int]$Raw.energy }
            Health = if ($names -contains 'health') { [int]$Raw.health } else { 100 }
            Craving = if ($names -contains 'craving') { [int]$Raw.craving } else { 68 }
            Grievance = if ($names -contains 'grievance') { [int]$Raw.grievance } else { 0 }
            PetStatus = $status
            DepartureReason = if ($names -contains 'departureReason') { [string]$Raw.departureReason } else { '' }
            DepartedAt = if ($names -contains 'departedAt' -and $Raw.departedAt) { [datetime]$Raw.departedAt } else { $null }
            LowHungerTicks = if ($names -contains 'lowHungerTicks') { [int]$Raw.lowHungerTicks } else { 0 }
            StarvationTicks = if ($names -contains 'starvationTicks') { [int]$Raw.starvationTicks } else { 0 }
            RecoveryTicks = if ($names -contains 'recoveryTicks') { [int]$Raw.recoveryTicks } else { 0 }
            Interactions = if ($names -contains 'interactions') { [int]$Raw.interactions } else { 0 }
            IgnoredNudges = if ($names -contains 'ignoredNudges') { [int]$Raw.ignoredNudges } else { 0 }
            FeedRefusals = if ($names -contains 'feedRefusals') { [int]$Raw.feedRefusals } else { 0 }
            LastInteraction = if ($names -contains 'lastInteraction' -and $Raw.lastInteraction) { [datetime]$Raw.lastInteraction } else { Get-Date }
            LastBondDecay = if ($names -contains 'lastBondDecay' -and $Raw.lastBondDecay) { [datetime]$Raw.lastBondDecay } else { Get-Date }
            LastBondEvent = if ($names -contains 'lastBondEvent') { [string]$Raw.lastBondEvent } else { '恢复存档' }
            RecentEvents = $events
            LastUpdated = if ($names -contains 'lastUpdated' -and $Raw.lastUpdated) { [datetime]$Raw.lastUpdated } else { $null }
            Artifacts = $null
            Preferences = [pscustomobject]@{ PetWidth=[double]$tokens.component.'pet-width'; AutoMood=$true; WelcomeSeen=$false; SoundEnabled=$true; AutoStart=$false }
        }
        if ($names -contains 'preferences' -and $null -ne $Raw.preferences) {
            $preferenceNames = @($Raw.preferences.PSObject.Properties.Name)
            if ($preferenceNames -contains 'petWidth') {
                $normalized.Preferences.PetWidth = [Math]::Min(192, [Math]::Max(72, [double]$Raw.preferences.petWidth))
            }
            if ($preferenceNames -contains 'autoMood' -and $Raw.preferences.autoMood -is [bool]) { $normalized.Preferences.AutoMood = [bool]$Raw.preferences.autoMood }
            if ($preferenceNames -contains 'welcomeSeen' -and $Raw.preferences.welcomeSeen -is [bool]) { $normalized.Preferences.WelcomeSeen = [bool]$Raw.preferences.welcomeSeen }
            if ($preferenceNames -contains 'soundEnabled' -and $Raw.preferences.soundEnabled -is [bool]) { $normalized.Preferences.SoundEnabled = [bool]$Raw.preferences.soundEnabled }
            if ($preferenceNames -contains 'autoStart' -and $Raw.preferences.autoStart -is [bool]) { $normalized.Preferences.AutoStart = [bool]$Raw.preferences.autoStart }
        }
        if ($names -contains 'artifacts' -and $null -ne $Raw.artifacts) {
            $rawArtifacts = $Raw.artifacts
            $artifactNames = @($rawArtifacts.PSObject.Properties.Name)
            $normalizedEquipped = [ordered]@{}
            if ($artifactNames -contains 'equipped' -and $null -ne $rawArtifacts.equipped) {
                foreach ($slot in $artifactSlots) {
                    $slotId = [string]$slot.Id
                    $property = $rawArtifacts.equipped.PSObject.Properties[$slotId]
                    if ($null -eq $property) { continue }
                    $itemId = [string]$property.Value
                    if ([string]::IsNullOrEmpty($itemId)) { $normalizedEquipped[$slotId] = '' }
                    elseif ($artifactById.ContainsKey($itemId) -and [string]$artifactById[$itemId].Slot -eq $slotId) { $normalizedEquipped[$slotId] = $itemId }
                }
            }
            $normalizedCooldowns = [ordered]@{ sweetCare=[datetime]::MinValue; shakeBuff=[datetime]::MinValue; longPressAffinity=[datetime]::MinValue; midnightFeast=[datetime]::MinValue }
            if ($artifactNames -contains 'cooldowns' -and $null -ne $rawArtifacts.cooldowns) {
                foreach ($cooldownId in @('sweetCare','shakeBuff','longPressAffinity','midnightFeast')) {
                    $property = $rawArtifacts.cooldowns.PSObject.Properties[$cooldownId]
                    if ($null -ne $property -and $property.Value) { $normalizedCooldowns[$cooldownId] = [datetime]$property.Value }
                }
            }
            $normalized.Artifacts = [pscustomobject]@{
                Equipped = $normalizedEquipped
                Cooldowns = $normalizedCooldowns
                ShakeBuffUntil = if ($artifactNames -contains 'shakeBuffUntil' -and $rawArtifacts.shakeBuffUntil) { [datetime]$rawArtifacts.shakeBuffUntil } else { [datetime]::MinValue }
            }
        }
        return $normalized
    }.GetNewClosure()
    $saved = $null
    $script:stateRecoveredFromBackup = $false
    $script:stateLoadSource = 'defaults'
    foreach ($candidateStatePath in @($statePath, "$statePath.bak", "$statePath.tmp")) {
        if (-not (Test-Path -LiteralPath $candidateStatePath)) { continue }
        try {
            $rawSaved = Get-Content -Raw -LiteralPath $candidateStatePath -Encoding UTF8 | ConvertFrom-Json
            $saved = & $normalizeSavedState $rawSaved
            $script:stateLoadSource = $candidateStatePath
            $script:stateRecoveredFromBackup = ($candidateStatePath -ne $statePath)
            break
        } catch {}
    }
    if ($null -ne $saved) {
        $script:affection = $saved.Affection
        $script:fullness = $saved.Fullness
        $script:energy = $saved.Energy
        $script:health = $saved.Health
        $script:craving = $saved.Craving
        $script:grievance = $saved.Grievance
        $script:petStatus = $saved.PetStatus
        $script:departureReason = $saved.DepartureReason
        $script:departedAt = $saved.DepartedAt
        $script:lowHungerTicks = $saved.LowHungerTicks
        $script:starvationTicks = $saved.StarvationTicks
        $script:recoveryTicks = $saved.RecoveryTicks
        $script:interactionCount = $saved.Interactions
        $script:ignoredNudges = $saved.IgnoredNudges
        $script:feedRefusals = $saved.FeedRefusals
        $script:lastInteraction = $saved.LastInteraction
        $script:lastBondDecay = $saved.LastBondDecay
        $script:lastBondEvent = $saved.LastBondEvent
        $script:savedPetWidth = $saved.Preferences.PetWidth
        $script:savedAutoMood = $saved.Preferences.AutoMood
        $script:welcomeSeen = $saved.Preferences.WelcomeSeen
        $script:soundEnabled = $saved.Preferences.SoundEnabled
        $script:autoStartEnabled = $saved.Preferences.AutoStart
        $script:recentEvents.Clear()
        foreach ($eventText in @($saved.RecentEvents)) { $script:recentEvents.Add([string]$eventText) }
        if ($null -ne $saved.Artifacts) {
            foreach ($slotId in $saved.Artifacts.Equipped.Keys) { $artifactUiState.Equipped[[string]$slotId] = [string]$saved.Artifacts.Equipped[$slotId] }
            foreach ($cooldownId in $saved.Artifacts.Cooldowns.Keys) { $artifactUiState.Cooldowns[[string]$cooldownId] = [datetime]$saved.Artifacts.Cooldowns[$cooldownId] }
            $artifactUiState.ShakeBuffUntil = [datetime]$saved.Artifacts.ShakeBuffUntil
        }
        & $rebuildArtifactEffects
        if ($null -ne $saved.LastUpdated -and $script:petStatus -eq 'home') {
            $remainingHours = [Math]::Max(0, ((Get-Date) - $saved.LastUpdated).TotalHours)
            $offlineHours = $remainingHours
            $script:craving = [Math]::Min(100, $script:craving + [int][Math]::Floor($offlineHours * 4))
            $script:grievance = [Math]::Max(0, $script:grievance - [int][Math]::Floor($offlineHours * 6))
            if ($script:fullness -gt 25 -and $remainingHours -ge 1) { $drop=[Math]::Min($script:fullness-25,[int][Math]::Floor($remainingHours));$script:fullness-=$drop;$remainingHours-=$drop }
            if ($script:fullness -gt 10 -and $remainingHours -ge 2) { $drop=[Math]::Min($script:fullness-10,[int][Math]::Floor($remainingHours/2));$script:fullness-=$drop;$remainingHours-=($drop*2) }
            if ($script:fullness -gt 0 -and $remainingHours -ge 4) { $drop=[Math]::Min($script:fullness,[int][Math]::Floor($remainingHours/4));$script:fullness-=$drop;$remainingHours-=($drop*4) }
            if ($script:fullness -le 0 -and $remainingHours -ge 6) { $script:health -= [Math]::Min(100,[int][Math]::Floor($remainingHours/6)) }
        }
        $now = Get-Date
        $decayReference = $script:lastBondDecay
        $graceEnd = $script:lastInteraction.AddHours(6)
        if ($decayReference -lt $graceEnd) { $decayReference = $graceEnd }
        if (($now - $script:lastInteraction).TotalHours -ge 12) {
            $bondLoss = [Math]::Min(12, [int][Math]::Floor(($now - $decayReference).TotalHours / 6))
            if ($bondLoss -gt 0) { $script:affection-=$bondLoss;$script:lastBondDecay=$decayReference.AddHours($bondLoss*6);$script:lastBondEvent="很久没等到回应，关系 -$bondLoss" }
        }
    }
    $script:affection = [Math]::Min(100, [Math]::Max(0, $script:affection))
    $script:fullness = [Math]::Min(100, [Math]::Max(0, $script:fullness))
    $script:energy = [Math]::Min(100, [Math]::Max(0, $script:energy))
    $script:health = [Math]::Min(100, [Math]::Max(0, $script:health))
    $script:craving = [Math]::Min(100, [Math]::Max(0, $script:craving))
    $script:grievance = [Math]::Min(100, [Math]::Max(0, $script:grievance))
    if ($script:health -le 0) {
        $script:petStatus = 'deceased'
        if (-not $script:departureReason) { $script:departureReason = '长期饥饿让生命值归零' }
    } elseif ($script:affection -le 5 -and $script:petStatus -eq 'home') {
        $script:petStatus = 'departed'
        if (-not $script:departureReason) { $script:departureReason = '长期得不到照顾，选择离开' }
    }
    $script:artifactLoadSnapshot = [pscustomobject]@{
        Plume = [string]$artifactUiState.Equipped['plume']
        ShakeBuffUntil = $artifactUiState.ShakeBuffUntil
        SetCounts = [ordered]@{
            evergreen=[int]$artifactUiState.SetCounts['evergreen']
            shake=[int]$artifactUiState.SetCounts['shake']
            'polar-night'=[int]$artifactUiState.SetCounts['polar-night']
        }
    }
    $script:stateLoadSnapshot = [pscustomobject]@{
        Affection=[int]$script:affection
        Fullness=[int]$script:fullness
        Energy=[int]$script:energy
        Health=[int]$script:health
    }
    if ($SelfTest) {
        $script:petStatus = 'home'
        $script:departureReason = ''
        $script:health = [Math]::Max(50, $script:health)
        $script:affection = [Math]::Max(40, $script:affection)
        $script:fullness = [Math]::Max(40, $script:fullness)
        $script:energy = [Math]::Max(40, $script:energy)
        $script:craving = 55
        $script:grievance = 0
    }

    $window = [Windows.Window]::new()
    $window.Title = '雪王现代桌宠'
    $window.Width = [double]$script:savedPetWidth
    $window.Height = [Math]::Round($window.Width * 1.103)
    $window.WindowStyle = [Windows.WindowStyle]::None
    $window.ResizeMode = [Windows.ResizeMode]::NoResize
    $window.AllowsTransparency = $true
    $window.Background = [Windows.Media.Brushes]::Transparent
    $window.ShowInTaskbar = $false
    $window.Topmost = $true
    $window.ShowActivated = $false

    $root = [Windows.Controls.Grid]::new()
    $window.Content = $root

    $groundShadow = [Windows.Shapes.Ellipse]::new()
    $groundShadow.Width = 54
    $groundShadow.Height = 9
    $groundShadow.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $groundShadow.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
    $groundShadow.Margin = [Windows.Thickness]::new(0, 0, 0, 5)
    $groundShadow.Fill = & $brush $color.Shadow
    $groundShadow.IsHitTestVisible = $false
    $groundShadow.Effect = [Windows.Media.Effects.BlurEffect]@{ Radius = 5 }
    [void]$root.Children.Add($groundShadow)

    $petImage = [Windows.Controls.Image]::new()
    $petImage.Stretch = [Windows.Media.Stretch]::Uniform
    $petImage.Margin = [Windows.Thickness]::new(1)
    $petImage.Cursor = [Windows.Input.Cursors]::Hand
    $petImage.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.62)
    $petScale = [Windows.Media.ScaleTransform]::new(1, 1)
    $petRotate = [Windows.Media.RotateTransform]::new(0)
    $petTranslate = [Windows.Media.TranslateTransform]::new(0, 0)
    $petTransform = [Windows.Media.TransformGroup]::new()
    [void]$petTransform.Children.Add($petScale)
    [void]$petTransform.Children.Add($petRotate)
    [void]$petTransform.Children.Add($petTranslate)
    $petImage.RenderTransform = $petTransform
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($petImage, [Windows.Media.BitmapScalingMode]::HighQuality)
    [void]$root.Children.Add($petImage)

    $particleCanvas = [Windows.Controls.Canvas]::new()
    $particleCanvas.IsHitTestVisible = $false
    [void]$root.Children.Add($particleCanvas)

    $hitGlow = [Windows.Shapes.Ellipse]::new()
    $hitGlow.Width = 22
    $hitGlow.Height = 16
    $hitGlow.Stroke = & $brush $color.Accent
    $hitGlow.StrokeThickness = 1.4
    $hitGlow.Fill = & $brush '#2238C8E8'
    $hitGlow.Opacity = 0
    $hitGlow.IsHitTestVisible = $false
    $hitGlow.Effect = [Windows.Media.Effects.DropShadowEffect]@{ BlurRadius=8; ShadowDepth=0; Opacity=.8; Color=[Windows.Media.ColorConverter]::ConvertFromString($color.Accent) }
    [void]$particleCanvas.Children.Add($hitGlow)

    $controlWindow = $null
    $updateControlPanel = $null
    $hideControlPanel = $null
    $toggleControlPanel = $null
    $panelFeedbackHost = $null
    $panelFeedbackTitle = $null
    $panelFeedbackBody = $null
    $panelFeedbackMeta = $null
    $script:lastFeedback = $null
    $script:feedbackPresentation = 'none'
    $feedbackWindow = [Windows.Window]::new()
    $feedbackWindow.Title = '雪王反馈'
    $feedbackWindow.WindowStyle = [Windows.WindowStyle]::None
    $feedbackWindow.ResizeMode = [Windows.ResizeMode]::NoResize
    $feedbackWindow.AllowsTransparency = $true
    $feedbackWindow.Background = [Windows.Media.Brushes]::Transparent
    $feedbackWindow.ShowInTaskbar = $false
    $feedbackWindow.Topmost = $true
    $feedbackWindow.ShowActivated = $false
    $feedbackWindow.SizeToContent = [Windows.SizeToContent]::WidthAndHeight

    $feedbackTransform = [Windows.Media.TranslateTransform]::new(0, 8)
    $feedbackCard = [Windows.Controls.Border]::new()
    $feedbackCard.Name = 'feedbackCard'
    $feedbackCard.Width = 320
    $feedbackCard.MinHeight = 90
    $feedbackCard.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'feedback-radius')
    $feedbackCard.Padding = [Windows.Thickness]::new([double]$tokens.component.'feedback-padding')
    $feedbackCard.Background = & $brush $color.Surface
    $feedbackCard.BorderBrush = & $brush $color.SurfaceBorder
    $feedbackCard.BorderThickness = [Windows.Thickness]::new(1)
    $feedbackCard.RenderTransform = $feedbackTransform
    $feedbackCard.Effect = [Windows.Media.Effects.DropShadowEffect]@{
        BlurRadius = [double]$tokens.component.'feedback-shadow-blur'
        ShadowDepth = 3
        Opacity = 0.24
        Color = [Windows.Media.ColorConverter]::ConvertFromString($color.Shadow)
    }
    $feedbackWindow.Content = $feedbackCard

    $feedbackStack = [Windows.Controls.StackPanel]::new()
    $feedbackCard.Child = $feedbackStack
    $feedbackTitle = [Windows.Controls.TextBlock]::new()
    $feedbackTitle.FontFamily = [Windows.Media.FontFamily]::new('Microsoft YaHei UI')
    $feedbackTitle.FontSize = 13
    $feedbackTitle.FontWeight = [Windows.FontWeights]::SemiBold
    $feedbackTitle.Foreground = & $brush $color.Ink
    [void]$feedbackStack.Children.Add($feedbackTitle)
    $feedbackBody = [Windows.Controls.TextBlock]::new()
    $feedbackBody.FontFamily = [Windows.Media.FontFamily]::new('Microsoft YaHei UI')
    $feedbackBody.FontSize = 12
    $feedbackBody.Foreground = & $brush $color.Muted
    $feedbackBody.TextWrapping = [Windows.TextWrapping]::Wrap
    $feedbackBody.LineHeight = 19
    $feedbackBody.Margin = [Windows.Thickness]::new(0, 5, 0, 9)
    [void]$feedbackStack.Children.Add($feedbackBody)
    $badgePanel = [Windows.Controls.WrapPanel]::new()
    [void]$feedbackStack.Children.Add($badgePanel)

    $script:currentState = 'sleeping'
    $script:frameIndex = 0
    $script:autoMood = [bool]$script:savedAutoMood
    $script:dragging = $false
    $script:dragMoved = $false
    $script:dragOffset = [Windows.Point]::new(0, 0)
    $script:dragStartedAt = [datetime]::MinValue
    $script:dragOriginLeft = 0.0
    $script:dragOriginTop = 0.0
    $script:suppressNextClick = $false
    $script:chaseMode = $false
    $script:chaseTicks = 0
    $script:followMode = $false
    $script:returnHomeMode = $false
    $script:lastFollowCostAt = Get-Date
    $script:statusHandled = $false
    $script:nudgeActive = $false
    $script:petStreak = 0
    $script:lastPetAt = [datetime]::MinValue
    $script:petCooldownUntil = [datetime]::MinValue
    $script:teaseStreak = 0
    $script:lastTeaseAt = [datetime]::MinValue
    $script:teaseCooldownUntil = [datetime]::MinValue
    $script:bodyReactionCount = 0
    $script:regionTapCounts = @{}
    $script:regionLastTap = @{}
    $script:regionCooldownUntil = @{}
    $script:lastRegion = ''
    $script:lastRegionAt = [datetime]::MinValue
    $script:lastInteractionKind = ''
    $script:comboReactionCount = 0
    $script:longPressCount = 0
    $script:reactionSteps = @()
    $script:reactionStepIndex = 0
    $script:reactionActive = $false
    $script:nextNudgeAt = (Get-Date).AddMinutes((Get-Random -Minimum 40 -Maximum 76))
    $script:activityPhase = 'quiet'
    $script:activityPhaseEndsAt = (Get-Date).AddMinutes((Get-Random -Minimum 10 -Maximum 26))
    $script:nextAmbientAt = (Get-Date).AddMinutes((Get-Random -Minimum 3 -Maximum 8))
    $script:ambientActive = $false
    $script:ambientSteps = @()
    $script:ambientStepIndex = 0
    $script:ambientLastRoutine = ''
    $script:ambientBag = [Collections.Generic.Queue[string]]::new()
    $script:ambientActionsSinceEnergyTick = 0
    $script:lastAmbientBubbleAt = [datetime]::MinValue
    $script:selfTestResult = $null
    $script:persistenceProbeResult = $null

    $saveState = {
        if ($script:petStatus -eq 'home' -and $script:health -le 0) {
            $script:petStatus = 'deceased'
            $script:departureReason = '长期饥饿让生命值归零'
            $script:departedAt = Get-Date
        } elseif ($script:petStatus -eq 'home' -and $script:affection -le 5) {
            $script:petStatus = 'departed'
            $script:departureReason = '长期得不到照顾，选择离开'
            $script:departedAt = Get-Date
        }
        if ($SelfTest) { return }
        $payload = [ordered]@{
            affection = [int]$script:affection
            fullness = [int]$script:fullness
            stamina = [int]$script:energy
            energy = [int]$script:energy
            health = [int]$script:health
            craving = [int]$script:craving
            grievance = [int]$script:grievance
            petStatus = [string]$script:petStatus
            departureReason = [string]$script:departureReason
            departedAt = if ($script:departedAt) { $script:departedAt.ToString('o') } else { $null }
            lowHungerTicks = [int]$script:lowHungerTicks
            starvationTicks = [int]$script:starvationTicks
            recoveryTicks = [int]$script:recoveryTicks
            interactions = [int]$script:interactionCount
            ignoredNudges = [int]$script:ignoredNudges
            feedRefusals = [int]$script:feedRefusals
            preferences = [ordered]@{
                petWidth = [Math]::Round($window.Width)
                autoMood = [bool]$script:autoMood
                welcomeSeen = [bool]$script:welcomeSeen
                soundEnabled = [bool]$script:soundEnabled
                autoStart = [bool]$script:autoStartEnabled
            }
            lastInteraction = $script:lastInteraction.ToString('o')
            lastBondDecay = $script:lastBondDecay.ToString('o')
            lastBondEvent = $script:lastBondEvent
            recentEvents = @($script:recentEvents)
            artifacts = [ordered]@{
                version = 1
                equipped = [ordered]@{
                    flower = [string]$script:artifactRuntime.Equipped['flower']
                    plume = [string]$script:artifactRuntime.Equipped['plume']
                    sands = [string]$script:artifactRuntime.Equipped['sands']
                    goblet = [string]$script:artifactRuntime.Equipped['goblet']
                    circlet = [string]$script:artifactRuntime.Equipped['circlet']
                }
                cooldowns = [ordered]@{
                    sweetCare = $script:artifactRuntime.Cooldowns['sweetCare'].ToString('o')
                    shakeBuff = $script:artifactRuntime.Cooldowns['shakeBuff'].ToString('o')
                    longPressAffinity = $script:artifactRuntime.Cooldowns['longPressAffinity'].ToString('o')
                    midnightFeast = $script:artifactRuntime.Cooldowns['midnightFeast'].ToString('o')
                }
                shakeBuffUntil = $script:artifactRuntime.ShakeBuffUntil.ToString('o')
            }
            lastUpdated = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 7
        $temporaryStatePath = "$statePath.tmp"
        $backupStatePath = "$statePath.bak"
        $stateCommitSucceeded = $false
        try {
            [IO.File]::WriteAllText($temporaryStatePath, $payload, [Text.UTF8Encoding]::new($false))
            if (Test-Path -LiteralPath $statePath) {
                if ($script:stateRecoveredFromBackup) {
                    try {
                        [IO.File]::Replace($temporaryStatePath, $statePath, $null, $true)
                    } catch {
                        Move-Item -LiteralPath $temporaryStatePath -Destination $statePath -Force
                    }
                } else {
                    try {
                        [IO.File]::Replace($temporaryStatePath, $statePath, $backupStatePath, $true)
                    } catch {
                        Copy-Item -LiteralPath $statePath -Destination $backupStatePath -Force
                        Move-Item -LiteralPath $temporaryStatePath -Destination $statePath -Force
                    }
                }
            } else {
                Move-Item -LiteralPath $temporaryStatePath -Destination $statePath
            }
            $stateCommitSucceeded = $true
            $script:stateRecoveredFromBackup = $false
        } finally {
            if ($stateCommitSucceeded -and (Test-Path -LiteralPath $temporaryStatePath)) { Remove-Item -LiteralPath $temporaryStatePath -Force -ErrorAction SilentlyContinue }
        }
    }

    # 系统音异步播放；不阻塞 WPF 线程，也不在每次互动时重新加载程序集。
    $getPetSound = {
        param([string]$Kind = 'click')
        switch ($Kind) {
            { $_ -in @('happy','success','pet') } { return [System.Media.SystemSounds]::Asterisk }
            { $_ -in @('sad','error') } { return [System.Media.SystemSounds]::Exclamation }
            { $_ -in @('feed','wake') } { return [System.Media.SystemSounds]::Question }
            default { return [System.Media.SystemSounds]::Beep }
        }
    }
    $playPetSound = {
        param([string]$Kind = 'click')
        if (-not $script:soundEnabled -or $SelfTest -or $PersistenceProbe) { return }
        $now = Get-Date
        if (($now - $script:lastSoundAt).TotalMilliseconds -lt 120) { return }
        try {
            (& $getPetSound $Kind).Play()
            $script:lastSoundAt = $now
        } catch { Write-Verbose "系统音效不可用：$($_.Exception.Message)" }
    }

    # === 开机自启管理 ===
    $autoStartRegKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $autoStartValueName = 'XueWangDesktopPet'
    $getAutoStartCommand = {
        $vbsPath = Join-Path $PSScriptRoot '启动动态雪王.vbs'
        if (Test-Path -LiteralPath $vbsPath) {
            return "wscript.exe `"$vbsPath`""
        }
        $ps1Path = Join-Path $PSScriptRoot '雪王现代桌宠.ps1'
        return "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$ps1Path`""
    }
    $isAutoStartEnabled = {
        try {
            $val = Get-ItemProperty -Path $autoStartRegKey -Name $autoStartValueName -ErrorAction SilentlyContinue
            return ($null -ne $val -and [string]$val.$autoStartValueName -eq (& $getAutoStartCommand))
        } catch { return $false }
    }
    $setAutoStart = {
        param([bool]$Enable)
        try {
            if ($Enable) {
                $cmd = & $getAutoStartCommand
                Set-ItemProperty -Path $autoStartRegKey -Name $autoStartValueName -Value $cmd -Force
            } else {
                Remove-ItemProperty -Path $autoStartRegKey -Name $autoStartValueName -ErrorAction SilentlyContinue
            }
            $script:autoStartEnabled = $Enable
            & $saveState
            return $true
        } catch { return $false }
    }

    # === 时段感知 ===
    $getTimeOfDay = {
        $hour = (Get-Date).Hour
        if ($hour -ge 5 -and $hour -lt 9) { return 'morning' }
        if ($hour -ge 9 -and $hour -lt 12) { return 'forenoon' }
        if ($hour -ge 12 -and $hour -lt 14) { return 'noon' }
        if ($hour -ge 14 -and $hour -lt 18) { return 'afternoon' }
        if ($hour -ge 18 -and $hour -lt 22) { return 'evening' }
        return 'night'
    }
    $getSeasonalGreeting = {
        $now = Get-Date
        $month = $now.Month; $day = $now.Day
        if ($month -eq 1 -and $day -eq 1) { return '元旦快乐，新的一年也请多关照' }
        if ($month -eq 2 -and $day -ge 10 -and $day -le 17) { return '情人节快到了，要一起吃甜筒吗' }
        if ($month -eq 3 -and $day -ge 20 -and $day -le 22) { return '春分啦，冰雪开始融化了' }
        if ($month -eq 5 -and $day -eq 1) { return '劳动节快乐，辛苦啦' }
        if ($month -eq 6 -and $day -ge 1 -and $day -le 2) { return '儿童节，要保持童心哦' }
        if ($month -eq 8 -and $day -ge 10 -and $day -le 17) { return '七夕快乐，有人陪你吗' }
        if ($month -eq 9 -and $day -ge 28 -and $day -le 30) { return '中秋快乐，记得吃月饼' }
        if ($month -eq 10 -and $day -eq 1) { return '国庆节快乐，出去玩了吗' }
        if ($month -eq 10 -and $day -ge 31) { return '万圣夜，要糖果还是甜筒' }
        if ($month -eq 11 -and $day -ge 20 -and $day -le 25) { return '感恩节，谢谢你一直陪着我' }
        if ($month -eq 12 -and $day -ge 24 -and $day -le 25) { return '圣诞快乐，要一起堆雪人吗' }
        if ($month -eq 12 -and $day -ge 30) { return '年末啦，这一年辛苦你了' }
        return ''
    }
    $getTimeBasedBubble = {
        $tod = & $getTimeOfDay
        $greeting = & $getSeasonalGreeting
        if (-not [string]::IsNullOrWhiteSpace($greeting)) { return $greeting }
        $bubbles = @{
            morning = @('早安，今天也要加油哦','睡得好吗？我刚醒','清晨的空气最适合打哈欠了','要不要先喝杯温水')
            forenoon = @('上午好，工作顺利吗','偷偷看你一眼','今天的阳光不错呢','有点想吃甜筒了')
            noon = @('午饭时间到！','吃了什么好吃的？','午休一下吧，我陪你','吃饱了才有力气')
            afternoon = @('下午有点困呢','要不要休息一下','我在旁边守着你','下午茶时间到')
            evening = @('晚上好，今天辛苦啦','晚饭吃了吗？','一起放松一下吧','夜晚的冰宫最安静')
            night = @('这么晚还不睡？','熬夜对身体不好哦','我先打个盹','夜深了，注意休息')
        }
        $pool = $bubbles[$tod]
        if ($pool) { return $pool[(Get-Random -Minimum 0 -Maximum $pool.Count)] }
        return '在你身边呢'
    }

    # === 系统状态监控 ===
    $getSystemHealthComment = {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average
            $cpuLoad = [int]$cpu.Average
            $memFree = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $memUsedPct = [math]::Round((1 - $memFree / $memTotal) * 100)
            $comments = @()
            if ($cpuLoad -ge 85) { $comments += '电脑跑得好快，像在滑冰一样' }
            elseif ($cpuLoad -ge 60) { $comments += '你在忙什么呢？我安静陪着' }
            if ($memUsedPct -ge 85) { $comments += '内存有点满了，要不要休息一下' }
            if ($comments.Count -gt 0) { return $comments[(Get-Random -Minimum 0 -Maximum $comments.Count)] }
        } catch {}
        return ''
    }

    $screenToDip = {
        param([Drawing.Point]$ScreenPoint)
        $point = [Windows.Point]::new($ScreenPoint.X, $ScreenPoint.Y)
        $source = [Windows.PresentationSource]::FromVisual($window)
        if ($null -ne $source -and $null -ne $source.CompositionTarget) {
            return $source.CompositionTarget.TransformFromDevice.Transform($point)
        }
        return $point
    }

    $getCursorWorkAreaDip = {
        $workingArea = [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
        $topLeft = & $screenToDip ([Drawing.Point]::new($workingArea.Left, $workingArea.Top))
        $bottomRight = & $screenToDip ([Drawing.Point]::new($workingArea.Right, $workingArea.Bottom))
        return [Windows.Rect]::new($topLeft.X, $topLeft.Y, $bottomRight.X - $topLeft.X, $bottomRight.Y - $topLeft.Y)
    }

    $placeAtHome = {
        $area = & $getCursorWorkAreaDip
        $window.Left = $area.Right - $window.Width - 18
        $window.Top = $area.Bottom - $window.Height - 12
    }

    $animationTimer = [Windows.Threading.DispatcherTimer]::new()
    $animationTimer.Add_Tick({
        $list = $script:frames[$script:currentState]
        $script:frameIndex = ($script:frameIndex + 1) % $list.Count
        $petImage.Source = $list[$script:frameIndex]
    })

    $playState = {
        param([string]$Name)
        if ($script:frames.ContainsKey($Name)) {
            $script:currentState = $Name
            $script:frameIndex = 0
            $petImage.Source = $script:frames[$Name][0]
            $animationTimer.Interval = [TimeSpan]::FromMilliseconds($script:frameIntervals[$Name])
            if (-not $animationTimer.IsEnabled) { $animationTimer.Start() }
        }
    }

    $holdState = {
        param([string]$Name, [int]$Frame = -1)
        if (-not $script:frames.ContainsKey($Name)) { return }
        $animationTimer.Stop()
        $script:currentState = $Name
        $list = $script:frames[$Name]
        $script:frameIndex = if ($Frame -ge 0) { [Math]::Min($Frame, $list.Count - 1) } else { Get-Random -Minimum 0 -Maximum $list.Count }
        $petImage.Source = $list[$script:frameIndex]
    }

    $feedbackTimer = [Windows.Threading.DispatcherTimer]::new()
    $feedbackTimer.Add_Tick({
        $feedbackTimer.Stop()
        $feedbackWindow.Hide()
        if ($null -ne $panelFeedbackHost) { $panelFeedbackHost.Visibility = [Windows.Visibility]::Collapsed }
        $script:feedbackPresentation = 'none'
    })

    $positionFeedbackWindow = {
        if (-not $feedbackWindow.IsVisible) { return }
        $feedbackWindow.UpdateLayout()
        $area = & $getCursorWorkAreaDip
        $feedbackWidth = $feedbackWindow.ActualWidth
        $feedbackHeight = $feedbackWindow.ActualHeight

        if ($null -ne $controlWindow -and $controlWindow.IsVisible) {
            $panelWidth = $controlWindow.ActualWidth
            $panelHeight = $controlWindow.ActualHeight
            $panelRect = [Windows.Rect]::new($controlWindow.Left, $controlWindow.Top, $panelWidth, $panelHeight)
            $oppositeX = if ($controlWindow.Left -lt $window.Left) { $window.Left + $window.Width + 12 } else { $window.Left - $feedbackWidth - 12 }
            $candidates = @(
                [Windows.Point]::new($controlWindow.Left + $panelWidth - $feedbackWidth, $controlWindow.Top - $feedbackHeight - 10),
                [Windows.Point]::new($oppositeX, $window.Top - $feedbackHeight + 48),
                [Windows.Point]::new($controlWindow.Left + $panelWidth - $feedbackWidth, $controlWindow.Top + $panelHeight + 10)
            )
            foreach ($candidate in $candidates) {
                $candidateRect = [Windows.Rect]::new($candidate.X, $candidate.Y, $feedbackWidth, $feedbackHeight)
                $insideArea = ($candidateRect.Left -ge $area.Left -and $candidateRect.Right -le $area.Right -and $candidateRect.Top -ge $area.Top -and $candidateRect.Bottom -le $area.Bottom)
                if ($insideArea -and -not $candidateRect.IntersectsWith($panelRect)) {
                    $feedbackWindow.Left = $candidate.X
                    $feedbackWindow.Top = $candidate.Y
                    return
                }
            }
        }

        $left = $window.Left + $window.Width - $feedbackWidth
        $feedbackWindow.Left = [Math]::Min([Math]::Max($left, $area.Left), $area.Right - $feedbackWidth)
        $feedbackWindow.Top = [Math]::Max($area.Top, $window.Top - $feedbackHeight - 8)
    }

    $newBadge = {
        param([string]$Text, [string]$Tone)
        $palette = switch ($Tone) {
            'positive' { @($color.PositiveSoft, $color.Positive) }
            'need' { @($color.NeedSoft, $color.Need) }
            'energy' { @($color.EnergySoft, $color.Energy) }
            'health' { @($color.HealthSoft, $color.HealthDark) }
            'boundary' { @($color.BoundarySoft, $color.Boundary) }
            default { @($color.PositiveSoft, $color.Muted) }
        }
        $badge = [Windows.Controls.Border]::new()
        $badge.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'badge-radius')
        $badge.Background = & $brush $palette[0]
        $badge.Padding = [Windows.Thickness]::new(8, 3, 8, 3)
        $badge.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
        $textBlock = [Windows.Controls.TextBlock]::new()
        $textBlock.Text = $Text
        $textBlock.FontFamily = [Windows.Media.FontFamily]::new('Microsoft YaHei UI')
        $textBlock.FontSize = 10.5
        $textBlock.FontWeight = [Windows.FontWeights]::SemiBold
        $textBlock.Foreground = & $brush $palette[1]
        $badge.Child = $textBlock
        return $badge
    }

    $showFeedback = {
        param(
            [string]$Title,
            [string]$Message,
            [string]$Tone = 'neutral',
            [int]$AffectionDelta = 0,
            [int]$FullnessDelta = 0,
            [int]$EnergyDelta = 0,
            [int]$Milliseconds = 3400,
            [switch]$ShowCurrent,
            [int]$HealthDelta = 0,
            [int]$CravingDelta = 0,
            [int]$GrievanceDelta = 0
        )
        $feedbackTimer.Stop()
        # 根据语气播放交互音效
        $soundKind = switch ($Tone) {
            'positive' { 'happy' }
            'need' { 'feed' }
            'energy' { 'success' }
            'health' { 'wake' }
            'boundary' { 'sad' }
            'danger' { 'error' }
            default { 'click' }
        }
        & $playPetSound $soundKind
        $feedbackTitle.Text = $Title
        $feedbackBody.Text = $Message
        $feedbackCard.BorderBrush = & $brush $(switch ($Tone) {
            'positive' { $color.Accent }
            'need' { $color.Need }
            'energy' { $color.Energy }
            'health' { $color.Health }
            'boundary' { $color.Boundary }
            default { $color.SurfaceBorder }
        })
        $badgePanel.Children.Clear()
        if ($ShowCurrent) {
            [void]$badgePanel.Children.Add((& $newBadge "生命 $($script:health)" 'health'))
            [void]$badgePanel.Children.Add((& $newBadge "亲密 $($script:affection)" 'positive'))
            [void]$badgePanel.Children.Add((& $newBadge "饱食 $($script:fullness)" 'need'))
            [void]$badgePanel.Children.Add((& $newBadge "体力 $($script:energy)" 'energy'))
            [void]$badgePanel.Children.Add((& $newBadge "馋嘴 $($script:craving)" 'need'))
            [void]$badgePanel.Children.Add((& $newBadge "委屈 $($script:grievance)" 'boundary'))
        } else {
            if ($AffectionDelta -ne 0) { [void]$badgePanel.Children.Add((& $newBadge "亲密 $(if($AffectionDelta -gt 0){'+'})$AffectionDelta" $(if($AffectionDelta -gt 0){'positive'}else{'boundary'}))) }
            if ($FullnessDelta -ne 0) { [void]$badgePanel.Children.Add((& $newBadge "饱食 $(if($FullnessDelta -gt 0){'+'})$FullnessDelta" 'need')) }
            if ($EnergyDelta -ne 0) { [void]$badgePanel.Children.Add((& $newBadge "体力 $(if($EnergyDelta -gt 0){'+'})$EnergyDelta" 'energy')) }
            if ($HealthDelta -ne 0) { [void]$badgePanel.Children.Add((& $newBadge "生命 $(if($HealthDelta -gt 0){'+'})$HealthDelta" $(if($HealthDelta -gt 0){'health'}else{'boundary'}))) }
            if ($CravingDelta -ne 0) { [void]$badgePanel.Children.Add((& $newBadge "馋嘴 $(if($CravingDelta -gt 0){'+'})$CravingDelta" 'need')) }
            if ($GrievanceDelta -ne 0) { [void]$badgePanel.Children.Add((& $newBadge "委屈 $(if($GrievanceDelta -gt 0){'+'})$GrievanceDelta" 'boundary')) }
            if ($badgePanel.Children.Count -eq 0) { [void]$badgePanel.Children.Add((& $newBadge '关系不变' 'neutral')) }
        }

        $deltaText = if ($ShowCurrent) {
            "御体 $($script:health) · 胃袋 $($script:fullness) · 霜能 $($script:energy) · 信赖 $($script:affection) · 委屈 $($script:grievance)"
        } else {
            @(
                if($AffectionDelta -ne 0){"信赖 $(if($AffectionDelta -gt 0){'+'})$AffectionDelta"}
                if($FullnessDelta -ne 0){"胃袋 $(if($FullnessDelta -gt 0){'+'})$FullnessDelta"}
                if($EnergyDelta -ne 0){"霜能 $(if($EnergyDelta -gt 0){'+'})$EnergyDelta"}
                if($HealthDelta -ne 0){"御体 $(if($HealthDelta -gt 0){'+'})$HealthDelta"}
                if($CravingDelta -ne 0){"馋嘴 $(if($CravingDelta -gt 0){'+'})$CravingDelta"}
                if($GrievanceDelta -ne 0){"委屈 $(if($GrievanceDelta -gt 0){'+'})$GrievanceDelta"}
            ) -join ' · '
        }
        if (-not $deltaText) { $deltaText = '关系不变' }
        $script:lastFeedback = [pscustomobject]@{ Title=$Title; Message=$Message; Tone=$Tone; Meta=$deltaText }

        if ($null -ne $controlWindow -and $controlWindow.IsVisible -and $null -ne $panelFeedbackHost) {
            $panelFeedbackTitle.Text = $Title
            $panelFeedbackBody.Text = $Message
            $panelFeedbackMeta.Text = $deltaText
            $panelFeedbackHost.BorderBrush = & $brush $(switch ($Tone) {
                'positive' { $color.Accent }; 'need' { $color.Need }; 'energy' { $color.Energy }
                'health' { $color.Health }; 'boundary' { $color.Boundary }; default { $color.SurfaceBorder }
            })
            $panelFeedbackHost.Visibility = [Windows.Visibility]::Visible
            $feedbackWindow.Hide()
            $script:feedbackPresentation = 'inline'
            $feedbackTimer.Interval = [TimeSpan]::FromMilliseconds($Milliseconds)
            $feedbackTimer.Start()
            return
        }

        if (-not $feedbackWindow.IsVisible) { $feedbackWindow.Show() }
        $feedbackWindow.UpdateLayout()
        & $positionFeedbackWindow
        $feedbackWindow.Opacity = 0
        $feedbackTransform.Y = 8
        $opacityAnimation = [Windows.Media.Animation.DoubleAnimation]::new(0, 1, [Windows.Duration]::new([TimeSpan]::FromMilliseconds([double]$tokens.component.'motion-normal-ms')))
        $moveAnimation = [Windows.Media.Animation.DoubleAnimation]::new(8, 0, [Windows.Duration]::new([TimeSpan]::FromMilliseconds([double]$tokens.component.'motion-normal-ms')))
        $feedbackWindow.BeginAnimation([Windows.Window]::OpacityProperty, $opacityAnimation)
        $feedbackTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $moveAnimation)
        $script:feedbackPresentation = 'floating'
        $feedbackTimer.Interval = [TimeSpan]::FromMilliseconds($Milliseconds)
        $feedbackTimer.Start()
    }

    $emitParticles = {
        param([string]$Symbol, [string]$Tone)
        $particleColor = switch ($Tone) {
            'positive' { $color.Accent }
            'need' { $color.Need }
            'boundary' { $color.Boundary }
            default { $color.Energy }
        }
        1..3 | ForEach-Object {
            $particle = [Windows.Controls.TextBlock]::new()
            $particle.Text = $Symbol
            $particle.FontFamily = [Windows.Media.FontFamily]::new('Segoe UI Symbol')
            $particle.FontSize = Get-Random -Minimum 10 -Maximum 15
            $particle.Foreground = & $brush $particleColor
            [Windows.Controls.Canvas]::SetLeft($particle, (Get-Random -Minimum 24 -Maximum 66))
            [Windows.Controls.Canvas]::SetTop($particle, (Get-Random -Minimum 28 -Maximum 62))
            [void]$particleCanvas.Children.Add($particle)
            $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds((Get-Random -Minimum 650 -Maximum 950)))
            $topAnimation = [Windows.Media.Animation.DoubleAnimation]::new([Windows.Controls.Canvas]::GetTop($particle), [Windows.Controls.Canvas]::GetTop($particle) - 24, $duration)
            $opacityAnimation = [Windows.Media.Animation.DoubleAnimation]::new(1, 0, $duration)
            $opacityAnimation.Add_Completed({ param($sender, $eventArgs) [void]$particleCanvas.Children.Remove($particle) }.GetNewClosure())
            $particle.BeginAnimation([Windows.Controls.Canvas]::TopProperty, $topAnimation)
            $particle.BeginAnimation([Windows.UIElement]::OpacityProperty, $opacityAnimation)
        }
    }

    # 自主生活层：结合通用动作与馋嘴、嘴硬、委屈等人格表情。
    $ambientRoutineNames = @(
        'curious-left', 'curious-right', 'double-tilt', 'paw-wave', 'tiny-hop',
        'play-bow', 'sniff-left', 'sniff-right', 'look-behind', 'proud-stance',
        'happy-shimmy', 'ice-wand-shake', 'toe-taps', 'peek-up', 'zoom-left',
        'zoom-right', 'circle-left', 'circle-right', 'sit-watch', 'patient-wait',
        'air-sniff', 'bow-and-wave', 'bounce-wave', 'cursor-curious', 'clumsy-stumble',
        'sleepy-yawn', 'wake-stretch', 'cheek-rub', 'star-pose', 'patrol-edge',
        'icecream-stare', 'drool-sneak', 'belly-rub', 'food-guard', 'pout-practice', 'smug-queen',
        'crown-maintenance', 'cape-cocoon', 'snack-puzzle', 'food-scout', 'midnight-picnic', 'pretend-nothing',
        'doro-dash', 'snowball-ride', 'ice-decree', 'spell-accident', 'crown-chase-show', 'pancake-recover'
    )
    $quietRoutineNames = @(
        'curious-left', 'curious-right', 'double-tilt', 'sniff-left', 'sniff-right',
        'look-behind', 'proud-stance', 'toe-taps', 'peek-up', 'sit-watch',
        'patient-wait', 'air-sniff', 'cursor-curious', 'sleepy-yawn', 'cheek-rub',
        'icecream-stare', 'belly-rub', 'pout-practice',
        'crown-maintenance', 'cape-cocoon', 'snack-puzzle', 'food-scout', 'midnight-picnic', 'pretend-nothing'
    )
    $activeRoutineNames = @(
        'paw-wave', 'tiny-hop', 'play-bow', 'happy-shimmy', 'ice-wand-shake',
        'zoom-left', 'zoom-right', 'circle-left', 'circle-right', 'bow-and-wave',
        'bounce-wave', 'clumsy-stumble', 'wake-stretch', 'star-pose', 'patrol-edge',
        'drool-sneak', 'food-guard', 'smug-queen',
        'doro-dash', 'snowball-ride', 'ice-decree', 'spell-accident', 'crown-chase-show', 'pancake-recover'
    )
    $sleepRoutineNames = @('dream-twitch', 'sleep-snuffle', 'sleep-paw', 'sleep-snack-dream', 'nightmare-cocoon')
    $ambientLines = @(
        @{ Title = '女皇突然精神'; Text = '没什么事，只是想让你看一下我有多可爱。'; Tone = 'positive' },
        @{ Title = '至冬巡逻员'; Text = '认真检查了一圈，桌面一切正常。'; Tone = 'neutral' },
        @{ Title = '偷偷练企鹅步'; Text = '趁你忙的时候，练了一个新的卖萌动作。'; Tone = 'positive' },
        @{ Title = '在观察你'; Text = '歪着脑袋研究：你现在是不是很专注？'; Tone = 'neutral' },
        @{ Title = '披风有想法'; Text = '没有要打扰你，只是披风自己晃得很开心。'; Tone = 'positive' },
        @{ Title = '女皇哲学'; Text = '站一会儿，扶扶王冠，再决定下一步做什么。'; Tone = 'neutral' },
        @{ Title = '今日份咕咕嘎嘎'; Text = '表演结束，假装刚才什么也没有发生。'; Tone = 'positive' },
        @{ Title = '企鹅步路过'; Text = '从这边晃到那边，又乖乖回来了。'; Tone = 'neutral' },
        @{ Title = '雪王广播'; Text = '咕咕嘎嘎——你忙你的，我负责给桌面降一点可爱的小雪。'; Tone = 'positive' },
        @{ Title = '捕捉到视线'; Text = '你是不是刚好看过来了？那我再摆个姿势。'; Tone = 'positive' },
        @{ Title = '其实不饿'; Text = '只是甜筒从眼前路过，本王就顺便盯了一会儿。'; Tone = 'need' },
        @{ Title = '护食模式'; Text = '这是我的甜筒。你的也可以先放在我这里。'; Tone = 'need' },
        @{ Title = '刚才没有四足狂奔'; Text = '本王只是用比较低的姿势巡视了一下桌面。'; Tone = 'neutral' },
        @{ Title = '零食袋拒绝觐见'; Text = '咬、踩、权杖撬都失败了，问题一定在包装。'; Tone = 'need' },
        @{ Title = '至冬冰术很稳定'; Text = '刚刚那张雪饼不是摔倒，是施法后的标准礼仪。'; Tone = 'positive' }
    )

    $animatePose = {
        param(
            [double]$ScaleX = 1,
            [double]$ScaleY = 1,
            [double]$Angle = 0,
            [double]$X = 0,
            [double]$Y = 0,
            [int]$Milliseconds = 180
        )
        $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($Milliseconds))
        $petScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, [Windows.Media.Animation.DoubleAnimation]::new($petScale.ScaleX, $ScaleX, $duration))
        $petScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, [Windows.Media.Animation.DoubleAnimation]::new($petScale.ScaleY, $ScaleY, $duration))
        $petRotate.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, [Windows.Media.Animation.DoubleAnimation]::new($petRotate.Angle, $Angle, $duration))
        $petTranslate.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, [Windows.Media.Animation.DoubleAnimation]::new($petTranslate.X, $X, $duration))
        $petTranslate.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, [Windows.Media.Animation.DoubleAnimation]::new($petTranslate.Y, $Y, $duration))
    }

    $resetPose = { param([int]$Milliseconds = 150) & $animatePose 1 1 0 0 0 $Milliseconds }

    $makeAmbientStep = {
        param(
            [string]$State,
            [int]$Delay = 900,
            [double]$Angle = 0,
            [double]$X = 0,
            [double]$Y = 0,
            [double]$ScaleX = 1,
            [double]$ScaleY = 1,
            [string]$Particle = '',
            [string]$Tone = 'energy'
        )
        @{ State = $State; Delay = $Delay; Angle = $Angle; X = $X; Y = $Y; ScaleX = $ScaleX; ScaleY = $ScaleY; Particle = $Particle; Tone = $Tone }
    }

    $makeAmbientPlan = {
        param([string]$Name)
        switch ($Name) {
            'curious-left'   { @(& $makeAmbientStep 'review' 900 -8 -2 0; & $makeAmbientStep 'waiting' 1100 -4 -1 0; & $makeAmbientStep 'idle' 650) }
            'curious-right'  { @(& $makeAmbientStep 'review' 900 8 2 0; & $makeAmbientStep 'waiting' 1100 4 1 0; & $makeAmbientStep 'idle' 650) }
            'double-tilt'    { @(& $makeAmbientStep 'waiting' 650 -9 -2 0; & $makeAmbientStep 'waiting' 650 9 2 0; & $makeAmbientStep 'review' 900) }
            'paw-wave'       { @(& $makeAmbientStep 'waving' 900 -3 0 -2 1.03 1.03 '✦' 'positive'; & $makeAmbientStep 'waving' 900 3 0 0; & $makeAmbientStep 'idle' 600) }
            'tiny-hop'       { @(& $makeAmbientStep 'jumping' 520 0 0 -8 1.03 0.97; & $makeAmbientStep 'jumping' 520 0 0 1 0.98 1.03 '✦' 'positive'; & $makeAmbientStep 'idle' 700) }
            'play-bow'       { @(& $makeAmbientStep 'jumping' 1200 0 0 3 1.06 0.93 '✦' 'positive'; & $makeAmbientStep 'waiting' 900 0 0 0; & $makeAmbientStep 'idle' 650) }
            'sniff-left'     { @(& $makeAmbientStep 'waiting' 850 -5 -4 2 1.02 0.98; & $makeAmbientStep 'review' 850 -7 -2 1; & $makeAmbientStep 'idle' 650) }
            'sniff-right'    { @(& $makeAmbientStep 'waiting' 850 5 4 2 1.02 0.98; & $makeAmbientStep 'review' 850 7 2 1; & $makeAmbientStep 'idle' 650) }
            'look-behind'    { @(& $makeAmbientStep 'review' 1000 11 3 0 0.96 1; & $makeAmbientStep 'waiting' 850 -4 -1 0; & $makeAmbientStep 'idle' 650) }
            'proud-stance'   { @(& $makeAmbientStep 'idle' 1400 0 0 -2 1.06 1.04 '✦' 'positive'; & $makeAmbientStep 'review' 850 0 0 0; & $makeAmbientStep 'idle' 550) }
            'happy-shimmy'   { @(& $makeAmbientStep 'waving' 430 -7 -2 0; & $makeAmbientStep 'waving' 430 7 2 0; & $makeAmbientStep 'waving' 430 -5 -1 0; & $makeAmbientStep 'idle' 700 0 0 0 1 1 '♥' 'positive') }
            'ice-wand-shake'  { @(& $makeAmbientStep 'idle' 330 -9 -2 0; & $makeAmbientStep 'idle' 330 9 2 0; & $makeAmbientStep 'idle' 330 -6 -1 0; & $makeAmbientStep 'idle' 650) }
            'toe-taps'       { @(& $makeAmbientStep 'waiting' 460 0 -3 0 0.99 1.02; & $makeAmbientStep 'waiting' 460 0 3 0 1.01 0.99; & $makeAmbientStep 'waiting' 460 0 -2 0; & $makeAmbientStep 'idle' 650) }
            'peek-up'        { @(& $makeAmbientStep 'review' 1100 0 0 -5 1.04 1.04; & $makeAmbientStep 'waiting' 850 0 0 -2; & $makeAmbientStep 'idle' 650) }
            'zoom-left'      { @(& $makeAmbientStep 'running-left' 650 -3 -7 0 0.98 1.02; & $makeAmbientStep 'running-right' 650 3 1 0; & $makeAmbientStep 'jumping' 620 0 0 -3; & $makeAmbientStep 'idle' 700) }
            'zoom-right'     { @(& $makeAmbientStep 'running-right' 650 3 7 0 0.98 1.02; & $makeAmbientStep 'running-left' 650 -3 -1 0; & $makeAmbientStep 'jumping' 620 0 0 -3; & $makeAmbientStep 'idle' 700) }
            'circle-left'    { @(& $makeAmbientStep 'running-left' 560 -5 -5 1; & $makeAmbientStep 'running' 560 0 0 -3; & $makeAmbientStep 'running-right' 560 5 5 1; & $makeAmbientStep 'idle' 750) }
            'circle-right'   { @(& $makeAmbientStep 'running-right' 560 5 5 1; & $makeAmbientStep 'running' 560 0 0 -3; & $makeAmbientStep 'running-left' 560 -5 -5 1; & $makeAmbientStep 'idle' 750) }
            'sit-watch'      { @(& $makeAmbientStep 'review' 2200 -3 0 0 1 1; & $makeAmbientStep 'review' 1200 4 0 0; & $makeAmbientStep 'idle' 650) }
            'patient-wait'   { @(& $makeAmbientStep 'waiting' 2500 0 0 0 1 1; & $makeAmbientStep 'idle' 900 0 0 0) }
            'air-sniff'      { @(& $makeAmbientStep 'waiting' 800 0 0 -4 1.03 1.04; & $makeAmbientStep 'waiting' 800 -5 -1 -2; & $makeAmbientStep 'review' 900 5 1 0; & $makeAmbientStep 'idle' 600) }
            'bow-and-wave'   { @(& $makeAmbientStep 'jumping' 950 0 0 3 1.05 0.94; & $makeAmbientStep 'waving' 1200 -3 0 -2 1.03 1.03 '✦' 'positive'; & $makeAmbientStep 'idle' 650) }
            'bounce-wave'    { @(& $makeAmbientStep 'waving' 650 -4 -2 -5 1.03 0.98; & $makeAmbientStep 'waving' 650 4 2 0 0.99 1.03; & $makeAmbientStep 'jumping' 650 0 0 -4; & $makeAmbientStep 'idle' 650) }
            'cursor-curious' {
                $cursor = & $screenToDip ([Windows.Forms.Cursor]::Position)
                $side = if ($cursor.X -lt ($window.Left + ($window.Width / 2))) { -1 } else { 1 }
                @(& $makeAmbientStep 'review' 1200 ($side * 8) ($side * 2) 0; & $makeAmbientStep 'waiting' 1100 ($side * 4) ($side * 1) -2; & $makeAmbientStep 'idle' 650)
            }
            'clumsy-stumble' { @(& $makeAmbientStep 'running' 520 6 4 1 0.97 1.03; & $makeAmbientStep 'failed' 900 -7 -2 3 1.03 0.96; & $makeAmbientStep 'waving' 950 0 0 0 1 1 '·' 'energy'; & $makeAmbientStep 'idle' 650) }
            'sleepy-yawn'    { @(& $makeAmbientStep 'review' 800 -3 0 1; & $makeAmbientStep 'sleeping' 1700 0 0 2 1.03 0.97; & $makeAmbientStep 'waiting' 800 2 0 0; & $makeAmbientStep 'idle' 650) }
            'wake-stretch'   { @(& $makeAmbientStep 'waiting' 850 0 0 2 1.02 0.97; & $makeAmbientStep 'jumping' 1200 0 0 3 1.07 0.92 '✦' 'energy'; & $makeAmbientStep 'waving' 900 -3 0 -2; & $makeAmbientStep 'idle' 650) }
            'cheek-rub'      { @(& $makeAmbientStep 'petting' 1200 -6 -2 0 1.03 1.03 '♥' 'positive'; & $makeAmbientStep 'petting' 900 5 2 0; & $makeAmbientStep 'idle' 650) }
            'star-pose'      { @(& $makeAmbientStep 'jumping' 850 0 0 -6 1.06 1.02 '✦' 'positive'; & $makeAmbientStep 'waving' 1100 -4 0 -2 1.04 1.04 '✦' 'positive'; & $makeAmbientStep 'idle' 650) }
            'patrol-edge'    { @(& $makeAmbientStep 'running-left' 720 -2 -6 0; & $makeAmbientStep 'review' 850 -6 -4 0; & $makeAmbientStep 'running-right' 720 2 6 0; & $makeAmbientStep 'review' 850 6 4 0; & $makeAmbientStep 'idle' 650) }
            'icecream-stare' { @(& $makeAmbientStep 'hungry' 1800 -2 -1 0 1.01 0.99; & $makeAmbientStep 'waiting' 900 2 1 0; & $makeAmbientStep 'idle' 650) }
            'drool-sneak'    { @(& $makeAmbientStep 'hungry' 950 -4 -2 -1 1.03 0.98 '✦' 'need'; & $makeAmbientStep 'hungry' 950 4 2 0; & $makeAmbientStep 'pout' 850; & $makeAmbientStep 'idle' 650) }
            'belly-rub'      { @(& $makeAmbientStep 'stuffed' 1500 -2 0 1 1.02 0.98; & $makeAmbientStep 'stuffed' 1200 2 0 0; & $makeAmbientStep 'idle' 650) }
            'food-guard'     { @(& $makeAmbientStep 'pout' 1000 -4 -1 0; & $makeAmbientStep 'angry' 800 4 1 -1 1.02 0.98 '❄' 'boundary'; & $makeAmbientStep 'smug' 1100; & $makeAmbientStep 'idle' 650) }
            'pout-practice'  { @(& $makeAmbientStep 'pout' 1400 -3 -1 0; & $makeAmbientStep 'shy' 1100 3 1 0 1.01 0.99 '♥' 'positive'; & $makeAmbientStep 'idle' 650) }
            'smug-queen'     { @(& $makeAmbientStep 'smug' 1500 0 0 -2 1.04 1.02 '✦' 'positive'; & $makeAmbientStep 'waving' 900 -3 0 -1; & $makeAmbientStep 'idle' 650) }
            'crown-maintenance' { @(& $makeAmbientStep 'crown-tap' 850 -3 -1 0; & $makeAmbientStep 'crown-drop' 750 3 1 -1; & $makeAmbientStep 'crown-chase' 1000 0 0 -2 1.02 .98 '✦' 'energy'; & $makeAmbientStep 'smug' 700) }
            'cape-cocoon'    { @(& $makeAmbientStep 'cape-pull' 650 -3 -1 0; & $makeAmbientStep 'cape-burrito' 1800 2 0 1; & $makeAmbientStep 'sulk-cocoon' 1200 -2 0 1; & $makeAmbientStep 'idle' 650) }
            'snack-puzzle'   { @(& $makeAmbientStep 'snack-struggle' 1300 -3 -1 0; & $makeAmbientStep 'bag-bite' 900 3 1 -1; & $makeAmbientStep 'snack-cry' 1200 0 0 1 1.01 .99 '·' 'need'; & $makeAmbientStep 'idle' 650) }
            'food-scout'     { @(& $makeAmbientStep 'doro-crawl' 850 -2 -5 1; & $makeAmbientStep 'food-sneak' 1200 2 2 -1 1.02 .98 '✦' 'need'; & $makeAmbientStep 'feast-guard' 950; & $makeAmbientStep 'idle' 650) }
            'midnight-picnic'{ @(& $makeAmbientStep 'midnight-feast' 1900 -2 0 1 .99 1.01; & $makeAmbientStep 'last-bite' 900 2 0 0; & $makeAmbientStep 'cape-burrito' 1000; & $makeAmbientStep 'idle' 650) }
            'pretend-nothing'{ @(& $makeAmbientStep 'pancake-fall' 900 0 0 2; & $makeAmbientStep 'pout' 650 -3 -1 0; & $makeAmbientStep 'smug' 900 3 1 -1 1.02 .98 '✦' 'positive'; & $makeAmbientStep 'idle' 650) }
            'doro-dash'      { @(& $makeAmbientStep 'doro-crawl' 520 -4 -7 1; & $makeAmbientStep 'doro-crawl' 520 4 7 -1; & $makeAmbientStep 'guard-pounce' 700 0 0 -5 1.04 .96 '✦' 'energy'; & $makeAmbientStep 'smug' 650) }
            'snowball-ride'  { @(& $makeAmbientStep 'snowball-play' 750 -4 -3 -2; & $makeAmbientStep 'snowball-slide' 900 5 6 -4 1.03 .97 '❄' 'energy'; & $makeAmbientStep 'pancake-fall' 750 0 0 2; & $makeAmbientStep 'waving' 650) }
            'ice-decree'     { @(& $makeAmbientStep 'crown-tap' 480 -2 0 0; & $makeAmbientStep 'queen-decree' 1050 2 0 -5 1.04 1.03 '❄' 'positive'; & $makeAmbientStep 'ice-spell' 900 -2 0 -6 1.03 1.03 '✦' 'energy'; & $makeAmbientStep 'smug' 700) }
            'spell-accident' { @(& $makeAmbientStep 'ice-spell' 750 -3 -1 -4; & $makeAmbientStep 'wand-backfire' 600 6 3 -5 1.05 .95 '✦' 'boundary'; & $makeAmbientStep 'pancake-fall' 900 0 0 3; & $makeAmbientStep 'dizzy' 650) }
            'crown-chase-show'{ @(& $makeAmbientStep 'crown-drop' 600 -4 -3 0; & $makeAmbientStep 'crown-chase' 900 4 5 -3 1.03 .97 '✦' 'energy'; & $makeAmbientStep 'smug' 700; & $makeAmbientStep 'idle' 600) }
            'pancake-recover'{ @(& $makeAmbientStep 'foot-slip' 520 -5 -3 -2; & $makeAmbientStep 'pancake-fall' 950 0 0 3 1.07 .93; & $makeAmbientStep 'cheek-boing' 650 4 2 -2; & $makeAmbientStep 'smug' 700) }
            'dream-twitch'   { @(& $makeAmbientStep 'sleeping' 900 -2 -1 1 1 0.99; & $makeAmbientStep 'sleeping' 1200 2 1 1 1 1.01; & $makeAmbientStep 'sleeping' 900) }
            'sleep-snuffle'  { @(& $makeAmbientStep 'sleeping' 850 0 0 2 1.02 0.98; & $makeAmbientStep 'sleeping' 850 0 0 0 0.99 1.02; & $makeAmbientStep 'sleeping' 1100) }
            'sleep-paw'      { @(& $makeAmbientStep 'sleeping' 700 -3 -2 0; & $makeAmbientStep 'sleeping' 700 3 2 0; & $makeAmbientStep 'sleeping' 1200 0 0 1) }
            'sleep-snack-dream' { @(& $makeAmbientStep 'sleeping' 1000 0 0 1; & $makeAmbientStep 'hungry' 850 -2 -1 0 .99 1.01; & $makeAmbientStep 'cape-burrito' 900 2 1 1; & $makeAmbientStep 'sleeping' 1100) }
            'nightmare-cocoon' { @(& $makeAmbientStep 'nightmare-hide' 850 -3 -2 1 .99 1.01; & $makeAmbientStep 'cape-burrito' 1000 3 2 1; & $makeAmbientStep 'sleeping' 1200 0 0 1) }
            default          { @(& $makeAmbientStep 'idle' 1200) }
        }
    }

    $getRestState = {
        if ($script:energy -lt 24 -or $script:activityPhase -eq 'sleep') { return 'sleeping' }
        if ($script:grievance -ge 65) { return 'bullied' }
        if ($script:grievance -ge 35) { return 'pout' }
        if ($script:craving -ge 78) { return 'hungry' }
        if ($script:activityPhase -eq 'active') { return (@('idle', 'idle', 'waiting') | Get-Random) }
        return (@('idle', 'idle', 'idle', 'idle', 'review', 'waiting') | Get-Random)
    }

    $refillAmbientBag = {
        $pool = if ($script:activityPhase -eq 'active') { $activeRoutineNames } else { $quietRoutineNames }
        foreach ($name in ($pool | Sort-Object { Get-Random })) { $script:ambientBag.Enqueue($name) }
    }

    $getNextAmbientRoutine = {
        if ($script:ambientBag.Count -eq 0) { & $refillAmbientBag }
        $next = $script:ambientBag.Dequeue()
        if ($next -eq $script:ambientLastRoutine -and $script:ambientBag.Count -gt 0) {
            $replacement = $script:ambientBag.Dequeue()
            $script:ambientBag.Enqueue($next)
            $next = $replacement
        }
        return $next
    }

    $selectInitialPhase = {
        $hour = (Get-Date).Hour
        $roll = Get-Random -Minimum 0 -Maximum 100
        if ($script:energy -lt 28) { return 'sleep' }
        if ($hour -ge 23 -or $hour -lt 7) { return $(if ($roll -lt 82) { 'sleep' } else { 'quiet' }) }
        if ($hour -ge 12 -and $hour -lt 15) { return $(if ($roll -lt 52) { 'sleep' } elseif ($roll -lt 94) { 'quiet' } else { 'active' }) }
        if (($hour -ge 7 -and $hour -lt 10) -or ($hour -ge 17 -and $hour -lt 22)) {
            return $(if ($roll -lt 24) { 'sleep' } elseif ($roll -lt 78) { 'quiet' } else { 'active' })
        }
        return $(if ($roll -lt 38) { 'sleep' } elseif ($roll -lt 90) { 'quiet' } else { 'active' })
    }

    $selectNextPhase = {
        $hour = (Get-Date).Hour
        $roll = Get-Random -Minimum 0 -Maximum 100
        if ($script:energy -lt 25) { return 'sleep' }
        if ($hour -ge 23 -or $hour -lt 7) {
            return $(if ($roll -lt 78) { 'sleep' } elseif ($roll -lt 98) { 'quiet' } else { 'active' })
        }
        if ($script:activityPhase -eq 'sleep') { return $(if ($roll -lt 88) { 'quiet' } else { 'active' }) }
        if ($script:activityPhase -eq 'active') { return $(if ($roll -lt 76) { 'quiet' } else { 'sleep' }) }
        if ($hour -ge 12 -and $hour -lt 15) {
            return $(if ($roll -lt 54) { 'sleep' } elseif ($roll -lt 94) { 'quiet' } else { 'active' })
        }
        if (($hour -ge 7 -and $hour -lt 10) -or ($hour -ge 17 -and $hour -lt 22)) {
            return $(if ($roll -lt 27) { 'sleep' } elseif ($roll -lt 78) { 'quiet' } else { 'active' })
        }
        return $(if ($roll -lt 43) { 'sleep' } elseif ($roll -lt 90) { 'quiet' } else { 'active' })
    }

    $enterActivityPhase = {
        param([ValidateSet('sleep', 'quiet', 'active')][string]$Phase)
        $script:activityPhase = $Phase
        $script:ambientBag.Clear()
        $now = Get-Date
        switch ($Phase) {
            'sleep' {
                $hour = $now.Hour
                $minutes = if ($script:energy -lt 35) { Get-Random -Minimum 35 -Maximum 76 } elseif ($hour -ge 23 -or $hour -lt 7) { Get-Random -Minimum 45 -Maximum 121 } else { Get-Random -Minimum 18 -Maximum 46 }
                $script:activityPhaseEndsAt = $now.AddMinutes($minutes)
                $script:nextAmbientAt = $now.AddMinutes((Get-Random -Minimum 6 -Maximum 15))
            }
            'quiet' {
                $script:activityPhaseEndsAt = $now.AddMinutes((Get-Random -Minimum 10 -Maximum 26))
                $script:nextAmbientAt = $now.AddMinutes((Get-Random -Minimum 3 -Maximum 8))
            }
            'active' {
                $script:activityPhaseEndsAt = $now.AddMinutes((Get-Random -Minimum 2 -Maximum 5))
                $script:nextAmbientAt = $now.AddSeconds((Get-Random -Minimum 28 -Maximum 61))
            }
        }
    }

    $ambientStepTimer = [Windows.Threading.DispatcherTimer]::new()
    $advanceAmbientStep = $null
    $advanceAmbientStep = {
        if (-not $script:ambientActive) { $ambientStepTimer.Stop(); return }
        if ($script:ambientStepIndex -ge $script:ambientSteps.Count) {
            $ambientStepTimer.Stop()
            $script:ambientActive = $false
            & $resetPose 170
            & $holdState (& $getRestState)
            if ($script:activityPhase -eq 'active') {
                $script:ambientActionsSinceEnergyTick++
                if ($script:ambientActionsSinceEnergyTick -ge 4) {
                    $script:ambientActionsSinceEnergyTick = 0
                    $script:energy = [Math]::Max(0, $script:energy - 1)
                    & $saveState
                }
                $script:nextAmbientAt = (Get-Date).AddSeconds((Get-Random -Minimum 28 -Maximum 66))
            } elseif ($script:activityPhase -eq 'quiet') {
                $script:nextAmbientAt = (Get-Date).AddMinutes((Get-Random -Minimum 3 -Maximum 8))
            } else {
                $script:nextAmbientAt = (Get-Date).AddMinutes((Get-Random -Minimum 6 -Maximum 15))
            }
            return
        }
        $step = $script:ambientSteps[$script:ambientStepIndex]
        $script:ambientStepIndex++
        & $playState ([string]$step.State)
        & $animatePose ([double]$step.ScaleX) ([double]$step.ScaleY) ([double]$step.Angle) ([double]$step.X) ([double]$step.Y) 170
        if ($step.Particle) { & $emitParticles ([string]$step.Particle) ([string]$step.Tone) }
        $ambientStepTimer.Interval = [TimeSpan]::FromMilliseconds([int]$step.Delay)
        $ambientStepTimer.Start()
    }
    $ambientStepTimer.Add_Tick({ $ambientStepTimer.Stop(); & $advanceAmbientStep })

    $startAmbientRoutine = {
        param([string]$Name)
        if ($script:ambientActive -or $script:dragging -or $script:chaseMode -or $script:followMode -or $script:returnHomeMode -or $returnTimer.IsEnabled) { return }
        $script:ambientSteps = @(& $makeAmbientPlan $Name)
        if ($script:ambientSteps.Count -eq 0) { return }
        $script:ambientLastRoutine = $Name
        $script:ambientStepIndex = 0
        $script:ambientActive = $true
        if (-not $SelfTest -and $script:autoMood -and $script:activityPhase -eq 'active' -and ((Get-Date) - $script:lastAmbientBubbleAt).TotalMinutes -ge 45 -and (Get-Random -Minimum 0 -Maximum 100) -lt 18) {
            # 优先使用时段/节日/系统状态感知台词
            $dynamicLine = ''
            $sysComment = & $getSystemHealthComment
            if (-not [string]::IsNullOrWhiteSpace($sysComment) -and (Get-Random -Minimum 0 -Maximum 100) -lt 35) {
                $dynamicLine = $sysComment
                $line = @{ Title = '雪王观察'; Text = $dynamicLine; Tone = 'neutral' }
            } else {
                $timeBubble = & $getTimeBasedBubble
                if (-not [string]::IsNullOrWhiteSpace($timeBubble) -and (Get-Random -Minimum 0 -Maximum 100) -lt 55) {
                    $tod = & $getTimeOfDay
                    $todTitle = switch ($tod) {
                        'morning' { '清晨问候' }
                        'forenoon' { '上午时分' }
                        'noon' { '午间小憩' }
                        'afternoon' { '下午时光' }
                        'evening' { '傍晚陪伴' }
                        'night' { '深夜低语' }
                        default { '雪王碎碎念' }
                    }
                    $line = @{ Title = $todTitle; Text = $timeBubble; Tone = 'neutral' }
                } else {
                    $line = $ambientLines | Get-Random
                }
            }
            & $showFeedback $line.Title $line.Text $line.Tone 0 0 0 2300
            $script:lastAmbientBubbleAt = Get-Date
        }
        & $advanceAmbientStep
    }

    $stopAmbientRoutine = {
        $ambientStepTimer.Stop()
        $script:ambientActive = $false
        $script:ambientSteps = @()
        $script:ambientStepIndex = 0
        & $resetPose 120
    }

    $ambientTimer = [Windows.Threading.DispatcherTimer]::new()
    $ambientTimer.Interval = [TimeSpan]::FromSeconds(5)
    $ambientTimer.Add_Tick({
        if ($SelfTest -or $script:dragging -or $script:chaseMode -or $script:followMode -or $script:returnHomeMode -or $returnTimer.IsEnabled -or $script:ambientActive) { return }
        $now = Get-Date
        if ($script:energy -lt 25 -and $script:activityPhase -ne 'sleep') {
            & $enterActivityPhase 'sleep'
            & $holdState 'sleeping'
            return
        }
        if ($now -ge $script:activityPhaseEndsAt) {
            $previousPhase = $script:activityPhase
            $nextPhase = & $selectNextPhase
            & $enterActivityPhase $nextPhase
            if ($nextPhase -eq 'sleep') {
                & $startAmbientRoutine 'sleepy-yawn'
            } elseif ($previousPhase -eq 'sleep') {
                $script:energy = [Math]::Min(100, $script:energy + 2)
                & $startAmbientRoutine 'wake-stretch'
                & $saveState
            } else {
                & $holdState (& $getRestState)
            }
            return
        }
        if ($now -lt $script:nextAmbientAt) { return }
        if ($script:activityPhase -eq 'sleep') {
            & $startAmbientRoutine ($sleepRoutineNames | Get-Random)
        } else {
            & $startAmbientRoutine (& $getNextAmbientRoutine)
        }
    })

    $returnTimer = [Windows.Threading.DispatcherTimer]::new()
    $returnTimer.Add_Tick({
        $returnTimer.Stop()
        if ($script:nudgeActive) {
            $script:nudgeActive = $false
            $script:ignoredNudges++
            if ($script:ignoredNudges -ge 3) {
                $script:affection = [Math]::Max(0, $script:affection - 1)
                $script:ignoredNudges = 0
                $script:lastBondEvent = '连续三次求关注没回应，关系 -1'
                & $scheduleNextNudge 75 151
            }
            & $saveState
        }
        & $holdState (& $getRestState)
        switch ($script:activityPhase) {
            'active' { $script:nextAmbientAt = (Get-Date).AddSeconds((Get-Random -Minimum 28 -Maximum 61)) }
            'quiet'  { $script:nextAmbientAt = (Get-Date).AddMinutes((Get-Random -Minimum 3 -Maximum 8)) }
            default  { $script:nextAmbientAt = (Get-Date).AddMinutes((Get-Random -Minimum 6 -Maximum 15)) }
        }
    })

    $reactionTimer = $null
    $showBriefState = {
        param([string]$Name, [int]$Milliseconds = 1700)
        if ($null -ne $reactionTimer) { $reactionTimer.Stop(); $script:reactionActive = $false }
        & $stopAmbientRoutine
        $returnTimer.Stop()
        & $playState $Name
        $returnTimer.Interval = [TimeSpan]::FromMilliseconds($Milliseconds)
        $returnTimer.Start()
    }

    $newReactionStep = {
        param([string]$State, [int]$Delay = 700, [string]$Particle = '', [string]$Tone = 'neutral')
        [pscustomobject]@{ State=$State; Delay=$Delay; Particle=$Particle; Tone=$Tone }
    }
    $reactionTimer = [Windows.Threading.DispatcherTimer]::new()
    $advanceReactionStep = $null
    $advanceReactionStep = {
        $reactionTimer.Stop()
        if (-not $script:reactionActive) { return }
        if ($script:reactionStepIndex -ge $script:reactionSteps.Count) {
            $script:reactionActive = $false
            $returnTimer.Interval = [TimeSpan]::FromMilliseconds(850)
            $returnTimer.Start()
            return
        }
        $step = $script:reactionSteps[$script:reactionStepIndex]
        $script:reactionStepIndex++
        & $playState ([string]$step.State)
        if ($step.Particle) { & $emitParticles ([string]$step.Particle) ([string]$step.Tone) }
        $reactionTimer.Interval = [TimeSpan]::FromMilliseconds([int]$step.Delay)
        $reactionTimer.Start()
    }
    $reactionTimer.Add_Tick({ & $advanceReactionStep })
    $startReactionSequence = {
        param([object[]]$Steps)
        & $stopAmbientRoutine
        $returnTimer.Stop()
        $reactionTimer.Stop()
        $script:reactionSteps = @($Steps)
        $script:reactionStepIndex = 0
        $script:reactionActive = $true
        & $advanceReactionStep
    }

    $addEventLog = {
        param([string]$Region, [string]$Action)
        $entry = "$(Get-Date -Format 'HH:mm') · $Region · $Action"
        $script:recentEvents.Insert(0, $entry)
        while ($script:recentEvents.Count -gt 3) { $script:recentEvents.RemoveAt(3) }
        if ($updateControlPanel -is [scriptblock]) { & $updateControlPanel }
    }

    $resolveHitRegion = {
        param([Windows.Point]$Point, [double]$Width, [double]$Height)
        $x = $Point.X / [Math]::Max(1, $Width)
        $y = $Point.Y / [Math]::Max(1, $Height)
        if ($x -lt .20 -and $y -ge .22 -and $y -le .86) { return 'wand' }
        if ($y -lt .18 -and $x -ge .25 -and $x -le .78) { return 'crown' }
        if ($y -ge .18 -and $y -lt .34 -and $x -ge .18 -and $x -lt .38) { return 'left-ear' }
        if ($y -ge .18 -and $y -lt .34 -and $x -gt .66 -and $x -le .91) { return 'right-ear' }
        if ($y -ge .32 -and $y -lt .51 -and $x -ge .25 -and $x -lt .50) { return 'left-cheek' }
        if ($y -ge .32 -and $y -lt .51 -and $x -ge .50 -and $x -le .75) { return 'right-cheek' }
        if ($x -gt .77 -and $y -ge .45 -and $y -lt .86) { return 'cape' }
        if ($y -ge .49 -and $y -lt .82 -and $x -ge .21 -and $x -le .77) { return 'belly' }
        if ($y -ge .80) { return 'foot' }
        return 'head'
    }

    $scheduleNextNudge = {
        param([int]$MinimumMinutes = 40, [int]$MaximumMinutes = 76)
        $script:nextNudgeAt = (Get-Date).AddMinutes((Get-Random -Minimum $MinimumMinutes -Maximum $MaximumMinutes))
    }

    $markInteraction = {
        & $stopAmbientRoutine
        $script:lastInteraction = Get-Date
        $script:lastBondDecay = Get-Date
        $script:nudgeActive = $false
        $script:ignoredNudges = 0
        & $enterActivityPhase 'active'
        & $scheduleNextNudge 40 76
    }

    $openCodex = { Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList 'shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App' }

    $applyArtifactSweetCare = {
        if (-not [bool]$script:artifactRuntime.Effects['Evergreen4']) { return 0 }
        $now = Get-Date
        if ($now -lt $script:artifactRuntime.Cooldowns['sweetCare']) { return 0 }
        $before = $script:grievance
        $script:grievance = [Math]::Max(0, $script:grievance - [int]$script:artifactRuntime.Effects['SweetCareRelief'])
        $relief = $before - $script:grievance
        if ($relief -gt 0) { $script:artifactRuntime.Cooldowns['sweetCare'] = $now.AddSeconds([int]$script:artifactRuntime.Effects['SweetCareCooldown']) }
        return $relief
    }

    $applyArtifactPlay = {
        param([int]$BaseCost, [int]$BaseAffection)
        $beforeAffection = $script:affection
        $beforeEnergy = $script:energy
        $cost = [Math]::Max(1, $BaseCost - [int]$script:artifactRuntime.Effects['PlayEnergyDiscount'])
        $gain = [Math]::Max(0, $BaseAffection + [int]$script:artifactRuntime.Effects['PlayAffectionBonus'])
        $script:energy = [Math]::Max(0, $script:energy - $cost)
        $script:affection = [Math]::Min(100, $script:affection + $gain)
        $shakeStarted = $false
        $now = Get-Date
        if ([bool]$script:artifactRuntime.Effects['Shake4'] -and $now -ge $script:artifactRuntime.Cooldowns['shakeBuff']) {
            $script:artifactRuntime.ShakeBuffUntil = $now.AddSeconds([int]$script:artifactRuntime.Effects['ShakeBuffDuration'])
            $script:artifactRuntime.Cooldowns['shakeBuff'] = $now.AddSeconds([int]$script:artifactRuntime.Effects['ShakeBuffCooldown'])
            $shakeStarted = $true
        }
        return [pscustomobject]@{
            AffectionDelta=($script:affection-$beforeAffection); EnergyDelta=($script:energy-$beforeEnergy); ShakeStarted=$shakeStarted
        }
    }

    $applyArtifactCombo = {
        $beforeAffection = $script:affection
        $beforeEnergy = $script:energy
        $beforeGrievance = $script:grievance
        $script:affection = [Math]::Min(100, $script:affection + [int]$script:artifactRuntime.Effects['ComboAffectionBonus'])
        $script:grievance = [Math]::Max(0, $script:grievance - [int]$script:artifactRuntime.Effects['ComboGrievanceRelief'])
        $consumedShake = $false
        if ([bool]$script:artifactRuntime.Effects['Shake4'] -and (Get-Date) -lt $script:artifactRuntime.ShakeBuffUntil) {
            $script:energy = [Math]::Min(100, $script:energy + [int]$script:artifactRuntime.Effects['ShakeComboEnergyGain'])
            $script:affection = [Math]::Min(100, $script:affection + [int]$script:artifactRuntime.Effects['ShakeComboAffectionBonus'])
            $script:artifactRuntime.ShakeBuffUntil = [datetime]::MinValue
            $consumedShake = $true
        }
        return [pscustomobject]@{
            AffectionDelta=($script:affection-$beforeAffection); EnergyDelta=($script:energy-$beforeEnergy)
            GrievanceDelta=($script:grievance-$beforeGrievance); ConsumedShake=$consumedShake
        }
    }

    $applyArtifactLongPress = {
        $beforeAffection = $script:affection
        $beforeGrievance = $script:grievance
        $script:grievance = [Math]::Max(0, $script:grievance - [int]$script:artifactRuntime.Effects['LongPressGrievanceRelief'])
        $now = Get-Date
        if ([int]$script:artifactRuntime.Effects['LongPressAffectionBonus'] -gt 0 -and $now -ge $script:artifactRuntime.Cooldowns['longPressAffinity']) {
            $script:affection = [Math]::Min(100, $script:affection + [int]$script:artifactRuntime.Effects['LongPressAffectionBonus'])
            $script:artifactRuntime.Cooldowns['longPressAffinity'] = $now.AddSeconds(45)
        }
        return [pscustomobject]@{
            AffectionDelta=($script:affection-$beforeAffection); GrievanceDelta=($script:grievance-$beforeGrievance)
        }
    }

    $invokePetHead = {
        & $markInteraction
        $script:interactionCount++
        $now = Get-Date
        if ($now -lt $script:petCooldownUntil) {
            & $showBriefState 'review' 2400
            & $showFeedback '需要一点空间' '我转开头、扶正王冠：先让本王缓一缓。' 'boundary' 0 0 0 3200
            & $emitParticles '·' 'boundary'
        } else {
            if (($now - $script:lastPetAt).TotalSeconds -le 18) { $script:petStreak++ } else { $script:petStreak = 1 }
            $script:lastPetAt = $now
            if ($script:petStreak -ge 4) {
                $script:affection = [Math]::Max(0, $script:affection - 1)
                $script:petCooldownUntil = $now.AddSeconds(45)
                $script:lastBondEvent = '连续摸头越过边界，关系 -1'
                & $showBriefState 'review' 3000
                & $showFeedback '摸得有点多了' '我打个哈欠、把头转开。尊重停下来的信号会更亲近。' 'boundary' -1 0 0 3800
                & $emitParticles '·' 'boundary'
            } else {
                $gain = if ($script:petStreak -eq 1) { 4 } elseif ($script:petStreak -eq 2) { 2 } else { 1 }
                $before = $script:affection
                $beforeGrievance = $script:grievance
                $script:affection = [Math]::Min(100, $script:affection + $gain)
                $script:grievance = [Math]::Max(0, $script:grievance - 12)
                $sweetCareRelief = & $applyArtifactSweetCare
                if ($beforeGrievance -gt 0) { $script:teaseStreak = 0 }
                $actual = $script:affection - $before
                $script:energy = [Math]::Min(100, $script:energy + 1)
                $script:lastBondEvent = if ($actual -gt 0) { "尊重节奏地摸头，关系 +$actual" } else { '尊重节奏地摸头，亲密已满' }
                & $showBriefState $(if($beforeGrievance -gt 0){'shy'}else{'petting'}) 2700
                $petMessage = if($beforeGrievance -gt 0){'确认你是在安慰后，眼泪收回去一点，悄悄把脑袋靠过来。'}elseif($script:affection -ge 85){'眯起眼睛，把脑袋主动靠到手边。'}else{'身体慢慢放松，没有躲开。'}
                if ($sweetCareRelief -gt 0) { $petMessage += " 国民常青共鸣融掉了 $sweetCareRelief 点委屈霜。" }
                & $showFeedback '轻轻贴近' $petMessage 'positive' $actual 0 1 3200 -GrievanceDelta ($script:grievance - $beforeGrievance)
                & $emitParticles '❄' 'positive'
            }
        }
        & $saveState
    }

    $invokeFeed = {
        & $markInteraction
        $script:interactionCount++
        $beforeAffection = $script:affection
        $beforeFullness = $script:fullness
        $beforeEnergy = $script:energy
        $beforeHealth = $script:health
        $beforeCraving = $script:craving
        $beforeGrievance = $script:grievance
        $script:feedRefusals = 0
        $gain = if ($beforeFullness -lt 30) { 4 } elseif ($beforeCraving -ge 70) { 3 } else { 2 }
        $foodGain = if ($beforeFullness -ge 94) { 3 } else { 12 }
        $script:fullness = [Math]::Min(100, $script:fullness + $foodGain + [int]$script:artifactRuntime.Effects['FeedFullnessBonus'])
        $script:affection = [Math]::Min(100, $script:affection + $gain + [int]$script:artifactRuntime.Effects['FeedAffectionBonus'])
        $script:energy = [Math]::Min(100, $script:energy + 2)
        $script:craving = [Math]::Max(0, $script:craving - $(if($beforeFullness -ge 94){18}else{40}) - [int]$script:artifactRuntime.Effects['FeedCravingRelief'])
        $script:grievance = [Math]::Max(0, $script:grievance - 14)
        $script:teaseStreak = 0
        $script:teaseCooldownUntil = [datetime]::MinValue
        $healthGain = if ($beforeFullness -lt 10) { 5 } elseif ($beforeFullness -lt 30) { 3 } else { 1 }
        $script:health = [Math]::Min(100, $script:health + $healthGain + [int]$script:artifactRuntime.Effects['FeedHealthBonus'])
        $sweetCareRelief = & $applyArtifactSweetCare
        $midnightFeastTriggered = $false
        if ([bool]$script:artifactRuntime.Effects['Night4'] -and $beforeFullness -lt 35 -and (Get-Date) -ge $script:artifactRuntime.Cooldowns['midnightFeast']) {
            $script:energy = [Math]::Min(100, $script:energy + [int]$script:artifactRuntime.Effects['LowFeedEnergyBonus'])
            $script:affection = [Math]::Min(100, $script:affection + [int]$script:artifactRuntime.Effects['LowFeedAffectionBonus'])
            $script:artifactRuntime.Cooldowns['midnightFeast'] = (Get-Date).AddSeconds([int]$script:artifactRuntime.Effects['LowFeedCooldown'])
            $midnightFeastTriggered = $true
        }
        if ($script:fullness -gt 0) { $script:starvationTicks = 0 }
        $actualAffection = $script:affection - $beforeAffection
        $artifactFeedNote = ''
        if ([int]$script:artifactRuntime.Effects['FeedFullnessBonus'] -gt 0 -or [int]$script:artifactRuntime.Effects['FeedCravingRelief'] -gt 0) { $artifactFeedNote += ' 国民常青的甜香共鸣让这份御膳更满足。' }
        if ($sweetCareRelief -gt 0) { $artifactFeedNote += " 又融掉了 $sweetCareRelief 点委屈霜。" }
        if ($midnightFeastTriggered) { $artifactFeedNote += ' 极夜四件套触发“午夜御宴”，额外恢复霜能与信赖。' }
        $script:lastBondEvent = if ($beforeFullness -ge 94) { '明明已经吃撑，还是舔了一口甜筒' } elseif ($actualAffection -gt 0) { "得到最喜欢的甜筒，关系 +$actualAffection" } else { '抱着甜筒吃得很满足' }
        $script:lastRegion = 'feed'
        $script:lastRegionAt = Get-Date
        $script:lastInteractionKind = 'feed'
        if ($beforeFullness -ge 94) {
            & $startReactionSequence @(& $newReactionStep 'last-bite' 850 '✦' 'need'; & $newReactionStep 'stuffed' 850; & $newReactionStep 'belly-flop' 850; & $newReactionStep 'pout' 600)
            & $addEventLog '御膳' '吃撑仍偷舔最后一口'
            & $showFeedback '已经很撑了，但还是想尝一口' ('嘴上说只舔一下，结果抱住甜筒不肯撒手，吃完才揉着圆肚皮发呆。' + $artifactFeedNote) 'need' $actualAffection ($script:fullness - $beforeFullness) ($script:energy - $beforeEnergy) 3900 -HealthDelta ($script:health - $beforeHealth) -CravingDelta ($script:craving - $beforeCraving) -GrievanceDelta ($script:grievance - $beforeGrievance)
        } else {
            if ($beforeCraving -ge 70) {
                $feedSequence = @(& $newReactionStep 'doro-crawl' 650; & $newReactionStep 'food-sneak' 750 '✦' 'need'; & $newReactionStep 'feeding' 900; & $newReactionStep 'feast-guard' 720)
                if ($midnightFeastTriggered) { $feedSequence = @(& $newReactionStep 'midnight-feast' 950 '✦' 'energy') + $feedSequence }
                & $startReactionSequence $feedSequence
                & $addEventLog '御膳' '四足扑向甜筒并护食'
            } else {
                $feedSequence = @(& $newReactionStep 'feeding' 900 '✦' 'need'; & $newReactionStep $(if($script:fullness -ge 92){'stuffed'}else{'waving'}) 750)
                if ($midnightFeastTriggered) { $feedSequence = @(& $newReactionStep 'midnight-feast' 950 '✦' 'energy') + $feedSequence }
                & $startReactionSequence $feedSequence
                & $addEventLog '御膳' '认真吃完小甜筒'
            }
            $feedMessage = $(if($beforeHealth -lt 45){'终于吃到东西，身体也慢慢缓过来了。'}else{'捧紧小甜筒大口舔，像怕下一秒会被抢走。'}) + $artifactFeedNote
            & $showFeedback $(if($beforeCraving -ge 70){'甜筒雷达命中！'}else{'认真开饭'}) $feedMessage 'need' $actualAffection ($script:fullness - $beforeFullness) ($script:energy - $beforeEnergy) 3700 -HealthDelta ($script:health - $beforeHealth) -CravingDelta ($script:craving - $beforeCraving) -GrievanceDelta ($script:grievance - $beforeGrievance)
        }
        & $emitParticles '✦' 'need'
        & $saveState
    }

    $bodyHitRegions = @('crown', 'left-cheek', 'right-cheek', 'left-ear', 'right-ear', 'belly', 'wand', 'cape', 'foot')
    $regionLabels = @{
        crown='王冠'; 'left-cheek'='左脸颊'; 'right-cheek'='右脸颊';
        'left-ear'='左耳'; 'right-ear'='右耳'; belly='肚皮'; wand='甜筒权杖'; cape='披风'; foot='小脚'; head='头发'
    }

    $invokeRegionInteraction = {
        param([string]$Region, [switch]$LongPress, [switch]$FromSleep)
        if ($Region -eq 'head' -and -not $FromSleep -and -not $LongPress) { & $invokePetHead; return }
        & $markInteraction
        $script:interactionCount++
        $script:bodyReactionCount++
        if ($LongPress) { $script:longPressCount++ }
        $now = Get-Date
        if (-not $script:regionTapCounts.ContainsKey($Region)) {
            $script:regionTapCounts[$Region] = 0
            $script:regionLastTap[$Region] = [datetime]::MinValue
            $script:regionCooldownUntil[$Region] = [datetime]::MinValue
        }
        if (($now - [datetime]$script:regionLastTap[$Region]).TotalSeconds -le 2.2 -and -not $LongPress) {
            $script:regionTapCounts[$Region] = [int]$script:regionTapCounts[$Region] + 1
        } else {
            $script:regionTapCounts[$Region] = 1
        }
        $script:regionLastTap[$Region] = $now
        $stage = [int]$script:regionTapCounts[$Region]
        $label = [string]$regionLabels[$Region]
        $base = if ($Region -like '*cheek') { 'cheek' } elseif ($Region -like '*ear') { 'ear' } else { $Region }
        $beforeGrievance = $script:grievance
        $beforeAffection = $script:affection
        $tone = 'neutral'
        $title = "$label 有反应"
        $message = '她停了一拍，认真确认刚才碰到的是哪里。'
        $eventAction = '做出专属反应'
        $sequence = @()

        $combo = ''
        if (($now - $script:lastRegionAt).TotalSeconds -le 6) {
            if ($script:lastRegion -eq 'crown' -and $Region -eq 'wand') { $combo = 'queen-decree' }
            elseif ($script:lastRegion -eq 'wand' -and $Region -eq 'cape') { $combo = 'spell-flight' }
            elseif ($script:lastRegion -eq 'cape' -and $Region -eq 'foot') { $combo = 'cape-trip' }
            elseif ($script:lastRegion -eq 'feed' -and $Region -eq 'belly') { $combo = 'full-belly' }
            elseif (($script:lastRegion -eq 'left-ear' -and $Region -eq 'right-ear') -or ($script:lastRegion -eq 'right-ear' -and $Region -eq 'left-ear')) { $combo = 'ear-dance' }
        }

        if ($combo) {
            $script:comboReactionCount++
            switch ($combo) {
                'queen-decree' {
                    $title='至冬女皇宣旨'; $message='王冠叮一声亮起，甜筒权杖随即展开冰晶法阵。'; $eventAction='触发王冠×权杖组合'
                    $sequence=@(& $newReactionStep 'crown-tap' 420 '✦' 'neutral'; & $newReactionStep 'queen-decree' 900 '❄' 'positive'; & $newReactionStep 'ice-spell' 1050 '✦' 'energy'; & $newReactionStep 'smug' 650)
                }
                'spell-flight' {
                    $title='披风飞行术……失败'; $message='权杖点亮披风，刚飞半秒就滚成雪团落地。'; $eventAction='触发权杖×披风组合'
                    $sequence=@(& $newReactionStep 'ice-spell' 650 '❄' 'energy'; & $newReactionStep 'snowball-slide' 900 '✦' 'energy'; & $newReactionStep 'pancake-fall' 850 '·' 'boundary'; & $newReactionStep 'dizzy' 600)
                }
                'cape-trip' {
                    $title='披风把小脚缠住了'; $message='想帅气转身，结果自己踩住披风，啪叽摊成雪饼。'; $eventAction='触发披风×小脚组合'
                    $sequence=@(& $newReactionStep 'cape-pull' 480; & $newReactionStep 'foot-slip' 620 '·' 'energy'; & $newReactionStep 'pancake-fall' 950; & $newReactionStep 'pout' 650)
                }
                'full-belly' {
                    $title='甜筒之后不要拍肚皮'; $message='先满足地拍拍肚子，下一秒整只向前扑倒，还护着最后一口。'; $eventAction='触发投喂×肚皮组合'
                    $sequence=@(& $newReactionStep 'stuffed' 650 '✦' 'need'; & $newReactionStep 'belly-flop' 850 '·' 'energy'; & $newReactionStep 'feast-guard' 850)
                }
                'ear-dance' {
                    $title='左右耳输入成功'; $message='两只尖耳交替抖动，身体不受控制地跳起企鹅摆摆舞。'; $eventAction='触发双耳组合'
                    $sequence=@(& $newReactionStep 'ear-touch' 420; & $newReactionStep 'shy' 520 '♥' 'positive'; & $newReactionStep 'jumping' 720 '✦' 'positive'; & $newReactionStep 'waving' 620)
                }
            }
        } elseif ($FromSleep) {
            $title = "熟睡时碰了$label"
            switch ($base) {
                'crown' { $message='王冠先弹起来，她才惊醒，手脚并用追着滚走的王冠。'; $eventAction='惊醒追王冠'; $sequence=@(& $newReactionStep 'wake-startle' 420; & $newReactionStep 'crown-drop' 650 '·' 'boundary'; & $newReactionStep 'crown-chase' 900 '✦' 'energy') }
                'cheek' { $message='脸颊被压出睡痕，睁一只眼看你，又把自己裹回披风。'; $eventAction='睡脸被戳'; $sequence=@(& $newReactionStep 'cheek-squish' 620; & $newReactionStep 'shy' 620; & $newReactionStep 'cape-burrito' 900) }
                'ear' { $message='尖耳以为有小虫，快速抖三下，捂住耳朵继续犯困。'; $eventAction='睡耳抖动'; $sequence=@(& $newReactionStep 'sleeping' 420; & $newReactionStep 'ear-touch' 620; & $newReactionStep 'cape-burrito' 850) }
                'belly' { $message='肚皮咕噜一声，她闭着眼把权杖往嘴边抱得更紧。'; $eventAction='梦中护食'; $sequence=@(& $newReactionStep 'sleeping' 450; & $newReactionStep 'stuffed' 650; & $newReactionStep 'feast-guard' 850) }
                'wand' { $message='没有睁眼就准确抱住权杖，确认甜筒还在才缩回披风。'; $eventAction='梦中抱权杖'; $sequence=@(& $newReactionStep 'cape-burrito' 650; & $newReactionStep 'wand-touch' 600; & $newReactionStep 'sulk-cocoon' 850) }
                'cape' { $message='把披风往上拽过头顶，只留王冠尖和一只偷看的眼睛。'; $eventAction='卷成披风团'; $sequence=@(& $newReactionStep 'sleeping' 420; & $newReactionStep 'cape-burrito' 900; & $newReactionStep 'nightmare-hide' 700) }
                'foot' { $message='小脚在梦里踢了两下，随后踩空，自己把自己吓醒。'; $eventAction='梦中踢腿'; $sequence=@(& $newReactionStep 'sleeping' 420; & $newReactionStep 'foot-tickle' 520; & $newReactionStep 'foot-slip' 650; & $newReactionStep 'dizzy' 620) }
                default { $message='整只炸毛坐起，看清是你后又害羞地缩回披风。'; $eventAction='被轻轻叫醒'; $sequence=@(& $newReactionStep 'wake-startle' 520; & $newReactionStep 'shy' 620; & $newReactionStep 'cape-burrito' 850) }
            }
        } elseif ($LongPress) {
            $title = "长按$label"
            switch ($base) {
                'crown' { $message='王冠持续发亮，她顺势站上冰晶法阵，认真完成一次女皇巡视。'; $eventAction='长按进入女皇巡视'; $sequence=@(& $newReactionStep 'crown-tap' 420; & $newReactionStep 'queen-decree' 950 '❄' 'positive'; & $newReactionStep 'smug' 650) }
                'cheek' { $message='脸颊像软团子一样越压越扁，松开后啵地弹回原形。'; $eventAction='长按脸颊回弹'; $sequence=@(& $newReactionStep 'cheek-squish' 900; & $newReactionStep 'cheek-boing' 650 '✦' 'neutral'; & $newReactionStep 'pout' 600) }
                'ear' { $message='先缩起耳朵，确认手很温柔后，害羞地把另一边也凑过来。'; $eventAction='长按耳朵安抚'; $sequence=@(& $newReactionStep 'ear-touch' 650; & $newReactionStep 'shy' 850 '♥' 'positive') }
                'belly' { $message='警惕地捂住肚皮，慢慢被揉成一只舒服的披风团。'; $eventAction='揉肚皮放松'; $sequence=@(& $newReactionStep 'belly-poke' 520; & $newReactionStep 'stuffed' 720; & $newReactionStep 'cape-burrito' 900 '♥' 'positive'); $script:grievance=[Math]::Max(0,$script:grievance-6) }
                'wand' { $message='甜筒权杖蓄力太久，冰术反弹，把施法者自己拍成了雪饼。'; $eventAction='权杖蓄力反噬'; $sequence=@(& $newReactionStep 'wand-touch' 450; & $newReactionStep 'ice-spell' 900 '❄' 'energy'; & $newReactionStep 'wand-backfire' 650 '✦' 'boundary'; & $newReactionStep 'pancake-fall' 850) }
                'cape' { $message='她顺势把披风围紧，变成一只只露眼睛的红色雪团。'; $eventAction='长按整理披风'; $sequence=@(& $newReactionStep 'cape-pull' 420; & $newReactionStep 'cape-burrito' 950; & $newReactionStep 'sulk-cocoon' 700) }
                'foot' { $message='小脚越挠越痒，笑着乱蹬，最后抱住雪球一路滑走。'; $eventAction='长按小脚滑雪'; $sequence=@(& $newReactionStep 'foot-tickle' 520; & $newReactionStep 'snowball-play' 750 '✦' 'positive'; & $newReactionStep 'snowball-slide' 850) }
                default { $message='长时间的温柔摸摸让她彻底放松，主动贴近一点。'; $eventAction='长按摸头安抚'; $sequence=@(& $newReactionStep 'petting' 850 '♥' 'positive'; & $newReactionStep 'shy' 700); $script:grievance=[Math]::Max(0,$script:grievance-8) }
            }
        } else {
            switch ($base) {
                'crown' {
                    if ($stage -eq 1) { $title='叮——王冠晃了三下'; $message='眼睛跟着王冠左右移动，最后一本正经地扶正。'; $eventAction='扶正王冠'; $sequence=@(& $newReactionStep 'crown-tap' 720 '✦' 'neutral'; & $newReactionStep 'smug' 560) }
                    else { $title='王冠真的掉了！'; $message='先愣住一拍，随后四脚着地追过去，捡回后假装无事发生。'; $eventAction='追赶滚走的王冠'; $sequence=@(& $newReactionStep 'crown-drop' 620 '·' 'boundary'; & $newReactionStep 'crown-chase' 920 '✦' 'energy'; & $newReactionStep 'smug' 650) }
                }
                'cheek' {
                    if ($stage -eq 1) { $title='啵——脸颊凹下去了'; $message='身体向另一侧软软偏移，回弹后难以置信地看着你。'; $eventAction='脸颊软弹'; $sequence=@(& $newReactionStep 'cheek-poke' 520; & $newReactionStep 'cheek-squish' 720; & $newReactionStep 'pout' 520) }
                    else { $title='团子脸回弹警告'; $message='两边脸颊被挤成扁团，松开后啵地弹回来，辫子都飞起来了。'; $eventAction='脸颊夸张回弹'; $sequence=@(& $newReactionStep 'cheek-squish' 650; & $newReactionStep 'cheek-boing' 700 '✦' 'neutral'; & $newReactionStep 'pout' 520) }
                }
                'ear' {
                    if ($stage -eq 1) { $title='冰铃一样抖了一下'; $message='尖耳先缩起，肩膀跟着一抖，脸颊悄悄变红。'; $eventAction='耳朵轻抖'; $sequence=@(& $newReactionStep 'ear-touch' 650; & $newReactionStep 'shy' 720 '♥' 'positive') }
                    else { $title='不许一直摸耳朵'; $message='双手捂住耳朵，整只缩进披风，只留一只眼睛偷看。'; $eventAction='捂耳躲进披风'; $sequence=@(& $newReactionStep 'ear-touch' 520; & $newReactionStep 'cape-burrito' 880; & $newReactionStep 'sulk-cocoon' 650) }
                }
                'belly' {
                    if ($script:craving -ge 70) { $title='肚皮里藏着零食计划'; $message='咚的一声后掏出零食袋，咬、踩、拿权杖撬，还是打不开。'; $eventAction='触发零食袋剧情'; $sequence=@(& $newReactionStep 'belly-poke' 450; & $newReactionStep 'snack-struggle' 950 '·' 'need'; & $newReactionStep 'snack-cry' 750) }
                    elseif ($script:fullness -ge 85) { $title='圆滚滚的肚皮回音'; $message='满足地打个小嗝，想站稳却向前扑成一张雪饼。'; $eventAction='吃撑后扑倒'; $sequence=@(& $newReactionStep 'stuffed' 650; & $newReactionStep 'belly-flop' 850; & $newReactionStep 'pancake-fall' 700) }
                    else { $title='咚——这里不是按钮'; $message='肚皮像果冻一样回弹，两只手赶紧护住储存甜筒的位置。'; $eventAction='肚皮回弹'; $sequence=@(& $newReactionStep 'belly-poke' 620; & $newReactionStep 'stuffed' 650) }
                }
                'wand' {
                    if ($stage -eq 1) { $title='权杖立即进入护食模式'; $message='把甜筒抱到身后，脚边亮起一圈细小冰晶。'; $eventAction='抱紧甜筒权杖'; $sequence=@(& $newReactionStep 'wand-touch' 650 '❄' 'boundary'; & $newReactionStep 'feast-guard' 720) }
                    else { $title='冰术反弹事故'; $message='想用权杖冻住你，结果法阵转回来，把自己弹成了扁雪团。'; $eventAction='权杖施法反弹'; $sequence=@(& $newReactionStep 'ice-spell' 850 '❄' 'energy'; & $newReactionStep 'wand-backfire' 650 '✦' 'boundary'; & $newReactionStep 'pancake-fall' 800) }
                }
                'cape' {
                    if ($stage -eq 1) { $title='披风扑簌一下'; $message='回头抓住披风，脚下打滑，坐稳后才委屈地瞪你。'; $eventAction='披风被轻拉'; $sequence=@(& $newReactionStep 'cape-pull' 520; & $newReactionStep 'foot-slip' 620; & $newReactionStep 'pout' 620) }
                    else { $title='披风防御形态'; $message='迅速把自己卷成红色披风团，抱住权杖拒绝继续拉扯。'; $eventAction='卷起披风防御'; $sequence=@(& $newReactionStep 'cape-pull' 480; & $newReactionStep 'cape-burrito' 920; & $newReactionStep 'sulk-cocoon' 650) }
                }
                'foot' {
                    if ($stage -eq 1) { $title='小短腿真的怕痒'; $message='单脚乱蹦、笑到站不稳，落地后赶紧把脚藏到肚皮下面。'; $eventAction='小脚怕痒乱蹦'; $sequence=@(& $newReactionStep 'foot-tickle' 520; & $newReactionStep 'foot-slip' 650; & $newReactionStep 'dizzy' 620) }
                    else { $title='啪叽——什么都没发生'; $message='想帅气躲开，结果原地滑倒成一张雪饼，又飞快装作没事。'; $eventAction='小脚滑倒装傻'; $sequence=@(& $newReactionStep 'foot-slip' 520; & $newReactionStep 'pancake-fall' 900; & $newReactionStep 'smug' 620) }
                }
                default { $title='轻轻摸到头发'; $message='确认不是敲王冠后，慢慢眯起眼睛靠过来。'; $eventAction='温柔摸头'; $sequence=@(& $newReactionStep 'petting' 850 '♥' 'positive') }
            }
        }

        if (-not $LongPress -and -not $FromSleep -and $stage -ge 3) {
            $script:lastTeaseAt = $now
            $griefGain = [Math]::Min(14, 4 + (($stage - 3) * 3))
            $script:grievance = [Math]::Min(100, $script:grievance + $griefGain)
            $tone = 'boundary'
            $message += ' 连续快速戳已经让她明显不高兴了。'
            if ($stage -ge 5) {
                $script:affection = [Math]::Max(0, $script:affection - 1)
                $script:regionCooldownUntil[$Region] = $now.AddSeconds(18)
                $message += ' 她记住了这个部位，暂时不许再碰。'
            }
        }
        if ($combo) {
            $artifactComboResult = & $applyArtifactCombo
            if ($artifactComboResult.AffectionDelta -gt 0 -or $artifactComboResult.EnergyDelta -gt 0 -or $artifactComboResult.GrievanceDelta -lt 0) {
                $message += ' 圣遗物共鸣接入组合技：'
                $message += @(
                    if($artifactComboResult.AffectionDelta -gt 0){"信赖 +$($artifactComboResult.AffectionDelta)"}
                    if($artifactComboResult.EnergyDelta -gt 0){"霜能 +$($artifactComboResult.EnergyDelta)"}
                    if($artifactComboResult.GrievanceDelta -lt 0){"委屈 $($artifactComboResult.GrievanceDelta)"}
                ) -join '、'
                $message += '。'
            }
            if ($artifactComboResult.ConsumedShake) { $message += ' “摇摇狂欢”已消耗。' }
        } elseif ($LongPress) {
            $artifactLongPressResult = & $applyArtifactLongPress
            if ($artifactLongPressResult.AffectionDelta -gt 0 -or $artifactLongPressResult.GrievanceDelta -lt 0) {
                $message += ' 圣遗物让这次长按更舒服。'
            }
        }
        $script:lastRegion = $Region
        $script:lastRegionAt = $now
        $script:lastInteractionKind = if($LongPress){'long-press'}elseif($FromSleep){'sleep-touch'}else{'tap'}
        $script:lastBondEvent = "$label：$eventAction"
        & $addEventLog $label $eventAction
        if ($Region -like '*cheek') {
            $push = if($Region -eq 'left-cheek'){4.5}else{-4.5}
            $directionCue = [Windows.Media.Animation.DoubleAnimation]::new(0, $push, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(135)))
            $directionCue.AutoReverse = $true
            $petTranslate.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $directionCue)
        } elseif ($Region -like '*ear') {
            $tilt = if($Region -eq 'left-ear'){-4.5}else{4.5}
            $directionCue = [Windows.Media.Animation.DoubleAnimation]::new(0, $tilt, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(145)))
            $directionCue.AutoReverse = $true
            $petRotate.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $directionCue)
        }
        if ($sequence.Count -gt 0) { & $startReactionSequence $sequence }
        & $showFeedback $title $message $tone ($script:affection - $beforeAffection) 0 0 3900 -GrievanceDelta ($script:grievance - $beforeGrievance)
        & $saveState
    }

    $invokeCrownTap = { & $invokeRegionInteraction 'crown' }
    $invokeCheekPoke = { & $invokeRegionInteraction 'left-cheek' }
    $invokeEarTouch = { & $invokeRegionInteraction 'left-ear' }
    $invokeBellyPoke = { & $invokeRegionInteraction 'belly' }
    $invokeWandTouch = { & $invokeRegionInteraction 'wand' }
    $invokeCapePull = { & $invokeRegionInteraction 'cape' }
    $invokeFootTickle = { & $invokeRegionInteraction 'foot' }
    $invokeWakeStartle = { & $invokeRegionInteraction 'head' -FromSleep }

    $invokeSnowballGame = {
        & $markInteraction; $script:interactionCount++
        $beforeAffection=$script:affection; $beforeEnergy=$script:energy
        $artifactPlayResult = & $applyArtifactPlay 5 3
        & $startReactionSequence @(& $newReactionStep 'snowball-play' 900 '❄' 'positive'; & $newReactionStep 'snowball-slide' 950 '✦' 'energy'; & $newReactionStep 'pancake-fall' 750; & $newReactionStep 'waving' 600)
        & $addEventLog '雪球游戏' '抱着雪球滑出冰道'
        $playNote = if($artifactPlayResult.ShakeStarted){' 摇摇雪顶四件套点亮了 12 秒“摇摇狂欢”。'}else{''}
        & $showFeedback '雪球巡游开始' ('抱住比自己还大的雪球一路滑行，摔倒后立刻挥手假装这是计划的一部分。' + $playNote) 'positive' ($script:affection-$beforeAffection) 0 ($script:energy-$beforeEnergy) 4100
        & $saveState
    }
    $invokeSnackChallenge = {
        & $markInteraction; $script:interactionCount++
        $beforeCraving=$script:craving
        $snackGain = [Math]::Max(0, 8 - [int]$script:artifactRuntime.Effects['SnackCravingMitigation'])
        $script:craving=[Math]::Min(100,$script:craving+$snackGain)
        & $startReactionSequence @(& $newReactionStep 'snack-struggle' 1100 '·' 'need'; & $newReactionStep 'bag-bite' 850; & $newReactionStep 'snack-cry' 800; & $newReactionStep 'food-sneak' 750)
        & $addEventLog '零食袋' '咬踩撬全失败后急哭'
        $snackNote = if($snackGain -lt 8){' 摇摇雪顶四件套把馋嘴增长压低了一半。'}else{''}
        & $showFeedback '打不开零食袋！' ('先拉、再咬、最后拿权杖撬；全都失败后急得掉眼泪，又偷偷把袋子拖走继续研究。' + $snackNote) 'need' 0 0 0 4300 -CravingDelta ($script:craving-$beforeCraving)
        & $saveState
    }
    $invokeCapeComfort = {
        & $markInteraction; $script:interactionCount++
        $beforeGrievance=$script:grievance
        $comfortRelief = 18 + [int]$script:artifactRuntime.Effects['ComfortGrievanceRelief']
        $script:grievance=[Math]::Max(0,$script:grievance-$comfortRelief); $script:teaseStreak=0
        & $startReactionSequence @(& $newReactionStep 'bullied' 620; & $newReactionStep 'cape-burrito' 950 '♥' 'positive'; & $newReactionStep 'shy' 700)
        & $addEventLog '安抚' '盖好披风并慢慢消气'
        $comfortNote = if($comfortRelief -gt 18){" 极夜甜品宫额外融掉 $($comfortRelief-18) 点委屈霜。"}else{''}
        & $showFeedback '盖好披风，慢慢消气' ('先躲在披风里偷看，确认你不是继续欺负后，才红着脸把脑袋探出来。' + $comfortNote) 'positive' 0 0 0 4000 -GrievanceDelta ($script:grievance-$beforeGrievance)
        & $saveState
    }
    $invokeQueenCeremony = {
        & $markInteraction; $script:interactionCount++
        $beforeAffection=$script:affection; $beforeEnergy=$script:energy
        $artifactPlayResult = & $applyArtifactPlay 4 0
        & $startReactionSequence @(& $newReactionStep 'crown-tap' 420; & $newReactionStep 'queen-decree' 1000 '❄' 'positive'; & $newReactionStep 'ice-spell' 1050 '✦' 'energy'; & $newReactionStep 'smug' 700)
        & $addEventLog '觐见仪式' '完成一次至冬女皇宣旨'
        $ceremonyNote = if($artifactPlayResult.ShakeStarted){' 摇摇雪顶四件套点亮了 12 秒“摇摇狂欢”。'}else{''}
        & $showFeedback '至冬觐见仪式' ('扶正王冠、举起甜筒权杖，冰晶法阵展开——仪式很威严，施法者还是圆滚滚的。' + $ceremonyNote) 'positive' ($script:affection-$beforeAffection) 0 ($script:energy-$beforeEnergy) 4300
        & $saveState
    }

    $invokeBodyPlay = {
        & $markInteraction
        $script:interactionCount++
        if ($script:energy -lt 25) {
            $script:lastBondEvent = '疲惫时允许休息，关系不变'
            & $showBriefState 'sleeping' 3400
            & $showFeedback '今天先休息' '打着哈欠趴回去了，精力不够时不会勉强玩。' 'energy' 0 0 0 3500
        } elseif ($script:fullness -lt 20) {
            $script:lastBondEvent = '饥饿时先表达进食需求'
            & $showBriefState 'waiting' 3200
            & $showFeedback '想吃小甜筒' '看看权杖又看看你：先吃点东西再跳舞吧。' 'need' 0 0 0 3500
        } else {
            $gain = if ($script:energy -ge 70) { 4 } else { 2 }
            $beforeAffection = $script:affection
            $beforeEnergy = $script:energy
            $artifactPlayResult = & $applyArtifactPlay 6 $gain
            $actualAffection = $script:affection - $beforeAffection
            $script:lastBondEvent = if ($actualAffection -gt 0) { "接受玩耍邀请，关系 +$actualAffection" } else { '接受玩耍邀请，亲密已满' }
            & $showBriefState 'jumping' 2300
            $danceNote = if($artifactPlayResult.ShakeStarted){' 摇摇雪顶四件套点亮了 12 秒“摇摇狂欢”。'}else{''}
            & $showFeedback '咕咕嘎嘎！' ('踮起小短腿跳起企鹅舞，披风一摆又回头等你。' + $danceNote) 'positive' $actualAffection 0 ($script:energy - $beforeEnergy) 3300
            & $emitParticles '✦' 'positive'
        }
        & $saveState
    }

    $showStatus = {
        $relationship = if ($script:affection -ge 85) { '非常信任，会主动靠近' } elseif ($script:affection -ge 65) { '亲近放松' } elseif ($script:affection -ge 40) { '熟悉但仍会观察' } else { '有些疏远，需要耐心' }
        $need = if ($script:health -lt 30) { '生命状态危险，需要尽快喂食和休息' } elseif ($script:fullness -lt 20) { '现在非常饥饿' } elseif ($script:energy -lt 25) { '体力不足，需要休息' } else { '身体状态稳定' }
        $emotion = if ($script:grievance -ge 65) { '还很委屈，需要安慰和一点空间' } elseif ($script:grievance -ge 35) { '正在鼓腮闹别扭' } elseif ($script:craving -ge 78) { '不一定饿，但非常馋甜筒' } else { '心情平稳' }
        & $showFeedback '今日状态' "$relationship；$need；$emotion。`n最近：$($script:lastBondEvent)" $(if($script:health -lt 30){'health'}elseif($script:grievance -ge 35){'boundary'}elseif($script:craving -ge 78){'need'}else{'neutral'}) 0 0 0 5200 -ShowCurrent
    }

    $moodTimer = [Windows.Threading.DispatcherTimer]::new()
    $moodTimer.Interval = [TimeSpan]::FromMinutes(1)
    $moodTimer.Add_Tick({
        if ($script:petStatus -ne 'home' -or -not $script:autoMood -or $script:dragging -or $script:chaseMode -or $script:followMode -or $returnTimer.IsEnabled -or $script:ambientActive) { return }
        if ($script:grievance -gt 0 -and ((Get-Date) - $script:lastTeaseAt).TotalMinutes -ge 3) {
            $script:grievance = [Math]::Max(0, $script:grievance - 2)
        }
        if ((Get-Date) -lt $script:nextNudgeAt) { return }
        if ($script:activityPhase -eq 'sleep' -and $script:fullness -ge 20 -and $script:craving -lt 88) {
            & $scheduleNextNudge 30 61
            return
        }
        if ($script:fullness -le 5) {
            $script:nudgeActive = $true
            & $showBriefState 'failed' 5200
            & $showFeedback '已经非常饿了' '饥饿下降会变慢，但继续不喂食会开始损失生命。' 'health' 0 0 0 5200
            & $scheduleNextNudge 4 10
        } elseif ($script:health -le 20) {
            $script:nudgeActive = $true
            & $showBriefState 'failed' 5200
            & $showFeedback '生命状态危险' '身体已经很虚弱，需要连续几次适量喂食慢慢恢复。' 'health' 0 0 0 5200 -ShowCurrent
            & $scheduleNextNudge 5 13
        } elseif ($script:fullness -le 15) {
            $script:nudgeActive = $true
            & $showBriefState 'hungry' 4600
            & $showFeedback '肚子一直在叫' '我会更频繁地来找你，但饥饿值已经开始减缓下降。' 'need' 0 0 0 4600
            & $scheduleNextNudge 8 17
        } elseif ($script:energy -lt 28) {
            $script:nudgeActive = $false
            & $enterActivityPhase 'sleep'
            & $holdState 'sleeping'
            & $scheduleNextNudge 30 61
        } elseif ($script:fullness -lt 30) {
            $script:nudgeActive = $true
            & $showBriefState 'hungry' 4200
            & $showFeedback '小声提醒' '看看冰杯又看看你……方便时送我一口甜筒好吗？' 'need' 0 0 0 4200
            & $scheduleNextNudge 12 25
        } elseif ($script:craving -ge 72) {
            $script:nudgeActive = $true
            & $showBriefState 'hungry' 4400
            & $showFeedback $(if($script:fullness -ge 60){'其实不饿，就是馋'}else{'甜筒雷达启动'}) '已经吃过饭了，但还是盯着权杖顶端的奶油，口水一点点挂下来。' 'need' 0 0 0 4400 -ShowCurrent
            & $scheduleNextNudge 18 37
        } elseif ($script:affection -lt 68) {
            $script:nudgeActive = $true
            & $showBriefState 'review' 4000
            & $showFeedback $(if($script:affection -le 15){'关系已经很疏远'}else{'在旁边等一会儿'}) $(if($script:affection -le 15){'如果长期继续这样，我可能会选择离开桌面。'}else{'我没有扑过来；愿意的话，轻轻摸一下就好。'}) $(if($script:affection -le 15){'boundary'}else{'neutral'}) 0 0 0 4200
            if ($script:affection -le 15) { & $scheduleNextNudge 20 41 } else { & $scheduleNextNudge 45 81 }
        } else {
            $request = @(
                @{ State = 'waiting'; Title = '王冠醒了一小会儿'; Text = '咕咕嘎嘎？要不要陪本王玩一下，没有空也没关系。'; Tone = 'neutral' },
                @{ State = 'jumping'; Title = '咕咕嘎嘎！'; Text = '小短腿一抬，咕咕嘎嘎：要跳企鹅舞吗？'; Tone = 'positive' },
                @{ State = 'review'; Title = '安静看看你'; Text = '你忙完了吗？我会继续乖乖等。'; Tone = 'neutral' }
            ) | Get-Random
            $script:nudgeActive = $true
            & $showBriefState $request.State 4200
            & $showFeedback $request.Title $request.Text $request.Tone 0 0 0 4200
            & $scheduleNextNudge 50 91
        }
    })

    $applyNeedsTick = {
        if ($script:petStatus -ne 'home') { return }
        $script:craving = [Math]::Min(100, $script:craving + $(if($script:activityPhase -eq 'active' -or $script:followMode){16}else{10}))
        if ($script:grievance -gt 0 -and ((Get-Date) - $script:lastTeaseAt).TotalMinutes -ge 10) {
            $script:grievance = [Math]::Max(0, $script:grievance - 8)
        }
        if ($script:fullness -gt 25) {
            $script:fullness = [Math]::Max(0, $script:fullness - 1)
            $script:lowHungerTicks = 0
        } elseif ($script:fullness -gt 10) {
            $script:lowHungerTicks++
            if (($script:lowHungerTicks % 2) -eq 0) { $script:fullness = [Math]::Max(0, $script:fullness - 1) }
        } elseif ($script:fullness -gt 0) {
            $script:lowHungerTicks++
            if (($script:lowHungerTicks % 4) -eq 0) { $script:fullness = [Math]::Max(0, $script:fullness - 1) }
        } else {
            $script:starvationTicks++
            if (($script:starvationTicks % 6) -eq 0) {
                $script:health = [Math]::Max(0, $script:health - 1)
                $script:lastBondEvent = '长期挨饿，生命 -1'
            }
        }

        if ($script:currentState -eq 'sleeping') {
            $script:energy = [Math]::Min(100, $script:energy + 2)
        } elseif ($script:activityPhase -eq 'active' -or $script:followMode) {
            $script:energy = [Math]::Max(0, $script:energy - 1)
        } elseif ($script:energy -lt 100) {
            $script:energy = [Math]::Min(100, $script:energy + 1)
        }

        if ($script:fullness -ge 65 -and $script:health -lt 100) {
            $script:recoveryTicks++
            if (($script:recoveryTicks % 4) -eq 0) { $script:health = [Math]::Min(100, $script:health + 1) }
        } else {
            $script:recoveryTicks = 0
        }

        $now = Get-Date
        if (($now - $script:lastInteraction).TotalHours -ge 12 -and ($now - $script:lastBondDecay).TotalHours -ge 6) {
            $script:affection = [Math]::Max(0, $script:affection - 1)
            $script:lastBondDecay = $now
            $script:lastBondEvent = '长时间没有陪伴，关系 -1'
        }
        if ($script:fullness -le 5) { & $scheduleNextNudge 4 10 }
        elseif ($script:fullness -le 15) { & $scheduleNextNudge 8 17 }
        elseif ($script:fullness -le 25) { & $scheduleNextNudge 12 25 }
        elseif ($script:craving -ge 80) { & $scheduleNextNudge 18 37 }
        if ($script:energy -le 0 -and -not $script:followMode) {
            & $enterActivityPhase 'sleep'
            & $holdState 'sleeping'
        }
        & $saveState
    }
    $needsTimer = [Windows.Threading.DispatcherTimer]::new()
    $needsTimer.Interval = [TimeSpan]::FromMinutes(60)
    $needsTimer.Add_Tick({ & $applyNeedsTick })

    $chaseTimer = [Windows.Threading.DispatcherTimer]::new()
    $chaseTimer.Interval = [TimeSpan]::FromMilliseconds(45)
    $chaseTimer.Add_Tick({
        if (-not $script:chaseMode) { $chaseTimer.Stop(); return }
        $script:chaseTicks--
        $cursor = & $screenToDip ([Windows.Forms.Cursor]::Position)
        $targetX = $cursor.X - ($window.Width / 2)
        $targetY = $cursor.Y - ($window.Height / 2)
        $dx = $targetX - $window.Left
        $dy = $targetY - $window.Top
        if ([Math]::Abs($dx) -gt 8) {
            $stepX = [Math]::Sign($dx) * [Math]::Min(4, [Math]::Abs($dx))
            $window.Left += $stepX
            & $playState $(if ($stepX -lt 0) { 'running-left' } else { 'running-right' })
        }
        if ([Math]::Abs($dy) -gt 8) { $window.Top += [Math]::Sign($dy) * [Math]::Min(3, [Math]::Abs($dy)) }
        if ($script:chaseTicks -le 0 -or ([Math]::Abs($dx) -lt 12 -and [Math]::Abs($dy) -lt 12)) {
            $script:chaseMode = $false
            $chaseTimer.Stop()
            $beforeAffection = $script:affection
            $beforeEnergy = $script:energy
            $script:affection = [Math]::Min(100, $script:affection + 4)
            $script:energy = [Math]::Max(0, $script:energy - 5)
            $actualAffection = $script:affection - $beforeAffection
            $script:lastBondEvent = if ($actualAffection -gt 0) { "完成追逐游戏，关系 +$actualAffection" } else { '完成追逐游戏，亲密已满' }
            & $showBriefState 'jumping' 1800
            & $showFeedback '抓到你啦' '停下来回头看你，披风还在开心地晃。' 'positive' $actualAffection 0 ($script:energy - $beforeEnergy) 3000
            & $emitParticles '✦' 'positive'
            & $saveState
        }
    })

    $absenceWindow = $null
    $autoStartTrayItem = $null
    $soundTrayItem = $null
    $exitTrayItem = $null
    $updateControlPanel = {}

    $followTimer = [Windows.Threading.DispatcherTimer]::new()
    $followTimer.Interval = [TimeSpan]::FromMilliseconds(42)
    $followTimer.Add_Tick({
        if ($script:petStatus -ne 'home') { $followTimer.Stop(); return }
        if (-not $script:followMode -and -not $script:returnHomeMode) { $followTimer.Stop(); return }
        if ($script:dragging) { return }
        if ($null -ne $controlWindow -and $controlWindow.IsVisible) { return }

        $area = & $getCursorWorkAreaDip
        if ($script:followMode) {
            if ($script:energy -le 5 -or $script:fullness -le 3 -or $script:health -le 12) {
                $script:followMode = $false
                $script:returnHomeMode = $true
                & $showFeedback '先回冰窝休息' $(if($script:fullness -le 3){'已经太饿了，没力气继续陪跑。'}else{'体力或生命状态不足，先回右下角休息。'}) 'health' 0 0 0 3600
            } else {
                $cursor = & $screenToDip ([Windows.Forms.Cursor]::Position)
                $targetX = $cursor.X + 30
                if (($targetX + $window.Width) -gt $area.Right) { $targetX = $cursor.X - $window.Width - 30 }
                $targetY = [Math]::Min($area.Bottom - $window.Height, $cursor.Y + 28)
                $targetX = [Math]::Min([Math]::Max($targetX, $area.Left), $area.Right - $window.Width)
                $targetY = [Math]::Min([Math]::Max($targetY, $area.Top), $area.Bottom - $window.Height)
            }
        }
        if ($script:returnHomeMode) {
            $targetX = $area.Right - $window.Width - 18
            $targetY = $area.Bottom - $window.Height - 12
        }

        $dx = $targetX - $window.Left
        $dy = $targetY - $window.Top
        $distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
        if ($distance -gt 10) {
            $stepX = [Math]::Sign($dx) * [Math]::Min(7, [Math]::Max(1.2, [Math]::Abs($dx) * 0.13))
            $stepY = [Math]::Sign($dy) * [Math]::Min(5.5, [Math]::Max(1.0, [Math]::Abs($dy) * 0.13))
            $window.Left += $stepX
            $window.Top += $stepY
            $moveState = if ($stepX -lt 0) { 'running-left' } else { 'running-right' }
            if ($script:currentState -ne $moveState) { & $playState $moveState }
        } else {
            if ($script:returnHomeMode) {
                & $placeAtHome
                $script:returnHomeMode = $false
                & $enterActivityPhase 'quiet'
            }
            if ($animationTimer.IsEnabled -or $script:currentState -ne 'idle') { & $holdState 'idle' }
        }

        if ($script:followMode -and ((Get-Date) - $script:lastFollowCostAt).TotalMinutes -ge 5) {
            $script:lastFollowCostAt = Get-Date
            $script:energy = [Math]::Max(0, $script:energy - 2)
            & $saveState
            & $updateControlPanel
        }
    })

    $startFollowing = {
        if ($script:petStatus -ne 'home') { return }
        if ($script:energy -lt 15 -or $script:fullness -lt 5 -or $script:health -lt 15) {
            & $showFeedback '现在不适合陪跑' '先喂一点东西并让生命和体力恢复，再一起走。' 'health' 0 0 0 3600 -ShowCurrent
            return
        }
        & $markInteraction
        $script:chaseMode = $false
        $chaseTimer.Stop()
        $script:followMode = $true
        $script:returnHomeMode = $false
        $script:lastFollowCostAt = Get-Date
        if ($null -ne $controlWindow -and $controlWindow.IsVisible) { & $hideControlPanel }
        $followTimer.Start()
        & $showFeedback '开始陪着你' '移动时不会打扰；档案仪只在你右键召唤时出现，不会因停驻自动弹出。' 'positive' 0 0 0 3600
        & $updateControlPanel
    }

    $stopFollowing = {
        param([switch]$Silent)
        $wasFollowing = $script:followMode
        $script:followMode = $false
        $script:returnHomeMode = $true
        $followTimer.Start()
        if ($wasFollowing -and -not $Silent) { & $showFeedback '回冰窝待着' '不再跟随鼠标，我自己跑回右下角。' 'neutral' 0 0 0 2800 }
        & $updateControlPanel
    }

    $returnHome = {
        $script:followMode = $false
        $script:returnHomeMode = $true
        $followTimer.Start()
        & $updateControlPanel
    }

    $newPanelText = {
        param([string]$Text, [double]$Size = 12, [string]$Weight = 'Normal', [string]$Tone = 'ink')
        $tb = [Windows.Controls.TextBlock]::new()
        $tb.Text = $Text
        $tb.FontFamily = [Windows.Media.FontFamily]::new('Microsoft YaHei UI')
        $tb.FontSize = $Size
        $tb.FontWeight = if ($Weight -eq 'SemiBold') { [Windows.FontWeights]::SemiBold } else { [Windows.FontWeights]::Normal }
        $tb.Foreground = & $brush $(switch ($Tone) {
            'muted' { $color.Muted }
            'danger' { $color.Health }
            'positive' { $color.Positive }
            'need' { $color.Need }
            'energy' { $color.Energy }
            'identity' { $color.Identity }
            'boundary' { $color.Boundary }
            'trust' { $color.Trust }
            'accent' { $color.Accent }
            default { $color.Ink }
        })
        return $tb
    }

    $newActionTile = {
        param([string]$Title, [string]$Subtitle, [scriptblock]$Action, [string]$Variant = 'neutral', [double]$Height = 52)
        $baseHex = switch ($Variant) { 'primary' { $color.Royal }; 'danger' { $color.HealthSoft }; default { $color.Surface } }
        $hoverHex = switch ($Variant) { 'danger' { $color.SurfacePressed }; default { $color.SurfacePressed } }
        $titleTone = switch ($Variant) { 'danger' { 'danger' }; default { 'ink' } }
        $tile = [Windows.Controls.Border]::new()
        $tile.Height = $Height
        $tile.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'action-radius')
        $tile.Background = & $brush $baseHex
        $tile.BorderBrush = & $brush $color.SurfaceBorder
        $tile.BorderThickness = [Windows.Thickness]::new(1)
        $tile.Padding = [Windows.Thickness]::new(10, 6, 10, 6)
        $tile.Margin = [Windows.Thickness]::new(3)
        $tile.Cursor = [Windows.Input.Cursors]::Hand
        $tile.Focusable = $true
        [Windows.Automation.AutomationProperties]::SetName($tile, $(if($Subtitle){"$Title，$Subtitle"}else{$Title}))
        $tile.DataContext = [pscustomobject]@{
            Selected=$false; Base=$baseHex; Hover=$hoverHex; SelectedBackground=$color.Royal; SelectedBorder=$color.Accent
        }
        $stack = [Windows.Controls.StackPanel]::new()
        $stack.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $titleBlock = & $newPanelText $Title 11.8 'SemiBold' $titleTone
        $titleBlock.TextWrapping = [Windows.TextWrapping]::Wrap
        $stack.Children.Add($titleBlock) | Out-Null
        if ($Subtitle) {
            $subBlock = & $newPanelText $Subtitle 9.2 'Normal' 'muted'
            $subBlock.TextWrapping = [Windows.TextWrapping]::Wrap
            $subBlock.Margin = [Windows.Thickness]::new(0, 2, 0, 0)
            $stack.Children.Add($subBlock) | Out-Null
        }
        $tile.Child = $stack
        $tile.Tag = $titleBlock
        $tile.Add_MouseEnter({ param($sender,$eventArgs) $sender.Background = & $brush ([string]$sender.DataContext.Hover); $sender.BorderBrush = & $brush $color.Accent }.GetNewClosure())
        $tile.Add_MouseLeave({
            param($sender,$eventArgs)
            $sender.Opacity = 1
            $selected = [bool]$sender.DataContext.Selected
            $sender.Background = & $brush $(if($selected){[string]$sender.DataContext.SelectedBackground}else{[string]$sender.DataContext.Base})
            $sender.BorderBrush = & $brush $(if($selected){[string]$sender.DataContext.SelectedBorder}else{$color.SurfaceBorder})
        }.GetNewClosure())
        $tile.Add_GotKeyboardFocus({ param($sender,$eventArgs) $sender.BorderBrush = & $brush $color.Accent; $sender.BorderThickness = [Windows.Thickness]::new(2) }.GetNewClosure())
        $tile.Add_LostKeyboardFocus({
            param($sender,$eventArgs)
            $selected = [bool]$sender.DataContext.Selected
            $sender.BorderBrush = & $brush $(if($selected){[string]$sender.DataContext.SelectedBorder}else{$color.SurfaceBorder})
            $sender.BorderThickness = [Windows.Thickness]::new($(if($selected){2}else{1}))
        }.GetNewClosure())
        $tile.Add_KeyDown({
            param($sender,$eventArgs)
            if ($eventArgs.Key -in @([Windows.Input.Key]::Enter,[Windows.Input.Key]::Space)) { & $Action $sender; $eventArgs.Handled = $true }
        }.GetNewClosure())
        $tile.Add_MouseLeftButtonDown({ param($sender,$eventArgs) $sender.Focus() | Out-Null; $sender.Opacity = 0.78 }.GetNewClosure())
        $tile.Add_MouseLeftButtonUp({ param($sender,$eventArgs) $sender.Opacity = 1; & $Action $sender; $eventArgs.Handled = $true }.GetNewClosure())
        return $tile
    }

    $controlWindow = [Windows.Window]::new()
    $controlWindow.Title = '雪王陪伴屋'
    $controlWindow.WindowStyle = [Windows.WindowStyle]::None
    $controlWindow.ResizeMode = [Windows.ResizeMode]::NoResize
    $controlWindow.AllowsTransparency = $true
    $controlWindow.Background = [Windows.Media.Brushes]::Transparent
    $controlWindow.ShowInTaskbar = $false
    $controlWindow.Topmost = $true
    $controlWindow.ShowActivated = $false
    $controlWindow.SizeToContent = [Windows.SizeToContent]::WidthAndHeight

    $controlCard = [Windows.Controls.Border]::new()
    $controlCard.Width = [double]$tokens.component.'control-width'
    $controlCard.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'control-radius')
    $panelGradient = [Windows.Media.LinearGradientBrush]::new()
    $panelGradient.StartPoint = [Windows.Point]::new(0, 0)
    $panelGradient.EndPoint = [Windows.Point]::new(1, 1)
    $panelGradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString([string]$primitive.'polar-800'), 0.0)) | Out-Null
    $panelGradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString([string]$primitive.'polar-900'), 0.42)) | Out-Null
    $panelGradient.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString([string]$primitive.'polar-950'), 1.0)) | Out-Null
    $controlCard.Background = $panelGradient
    $controlCard.BorderBrush = & $brush $color.SurfaceBorder
    $controlCard.BorderThickness = [Windows.Thickness]::new(1)
    $controlCard.Padding = [Windows.Thickness]::new([double]$tokens.component.'control-padding')
    $controlCard.Effect = [Windows.Media.Effects.DropShadowEffect]@{ BlurRadius = [double]$tokens.component.'control-shadow-blur'; ShadowDepth = 5; Opacity = 0.36; Color = [Windows.Media.ColorConverter]::ConvertFromString($color.Shadow) }
    $controlTransform = [Windows.Media.TranslateTransform]::new(0, 10)
    $controlCard.RenderTransform = $controlTransform
    $controlWindow.Content = $controlCard
    $controlRoot = [Windows.Controls.Grid]::new()
    $controlRoot.RowDefinitions.Add([Windows.Controls.RowDefinition]@{Height=[Windows.GridLength]::Auto}) | Out-Null
    $controlRoot.RowDefinitions.Add([Windows.Controls.RowDefinition]@{Height=[Windows.GridLength]::Auto}) | Out-Null
    $controlRoot.RowDefinitions.Add([Windows.Controls.RowDefinition]@{Height=[Windows.GridLength]::Auto}) | Out-Null
    $controlCard.Child = $controlRoot
    $controlScroll = [Windows.Controls.ScrollViewer]::new()
    $controlScroll.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Hidden
    $controlScroll.HorizontalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Disabled
    $controlScroll.MaxHeight = [Math]::Max(330, [Math]::Min(620, [Windows.SystemParameters]::WorkArea.Height - 118))
    [Windows.Controls.Grid]::SetRow($controlScroll,2)
    $controlRoot.Children.Add($controlScroll) | Out-Null
    $controlStack = [Windows.Controls.StackPanel]::new()
    $controlScroll.Content = $controlStack

    $headerGrid = [Windows.Controls.Grid]::new()
    $headerGrid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::new(50) }) | Out-Null
    $headerGrid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star) }) | Out-Null
    $headerGrid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::Auto }) | Out-Null
    $brandMark = [Windows.Controls.Border]::new()
    $brandMark.Width = 40
    $brandMark.Height = 40
    $brandMark.CornerRadius = [Windows.CornerRadius]::new(14)
    $brandMark.Background = & $brush $color.Royal
    $brandMark.BorderBrush = & $brush $color.Accent
    $brandMark.BorderThickness = [Windows.Thickness]::new(1)
    $brandGlyph = & $newPanelText '❄' 18 'SemiBold' 'ink'
    $brandGlyph.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $brandGlyph.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $brandMark.Child = $brandGlyph
    [Windows.Controls.Grid]::SetColumn($brandMark,0)
    $headerGrid.Children.Add($brandMark) | Out-Null
    $headerLeft = [Windows.Controls.StackPanel]::new()
    $headerEyebrow = & $newPanelText 'SNOWCOURT · DESKTOP COMPANION' 8.5 'SemiBold' 'identity'
    $headerTitle = & $newPanelText '雪王陪伴屋' 18 'SemiBold' 'ink'
    $headerTitle.Margin = [Windows.Thickness]::new(0, 2, 0, 0)
    $controlStatusText = & $newPanelText '正在看看今天过得怎么样' 10 'Normal' 'muted'
    $controlStatusText.Margin = [Windows.Thickness]::new(0, 2, 0, 0)
    $headerLeft.Children.Add($headerEyebrow) | Out-Null
    $headerLeft.Children.Add($headerTitle) | Out-Null
    $headerLeft.Children.Add($controlStatusText) | Out-Null
    [Windows.Controls.Grid]::SetColumn($headerLeft,1)
    $headerGrid.Children.Add($headerLeft) | Out-Null
    $closeTile = & $newActionTile '×' '' { & $hideControlPanel } 'neutral' 34
    $closeTile.Width = 34
    $closeTile.Padding = [Windows.Thickness]::new(9,4,9,4)
    [Windows.Controls.Grid]::SetColumn($closeTile,2)
    $headerGrid.Children.Add($closeTile) | Out-Null
    [Windows.Controls.Grid]::SetRow($headerGrid,0)
    $controlRoot.Children.Add($headerGrid) | Out-Null

    $panelFeedbackHost = [Windows.Controls.Border]::new()
    $panelFeedbackHost.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'panel-feedback-radius')
    $panelFeedbackHost.Background = & $brush ([string]$primitive.'polar-800')
    $panelFeedbackHost.BorderBrush = & $brush $color.Accent
    $panelFeedbackHost.BorderThickness = [Windows.Thickness]::new(1)
    $panelFeedbackHost.Padding = [Windows.Thickness]::new([double]$tokens.component.'panel-feedback-padding')
    $panelFeedbackHost.Margin = [Windows.Thickness]::new(0,10,0,7)
    $panelFeedbackHost.Visibility = [Windows.Visibility]::Collapsed
    $panelFeedbackStack = [Windows.Controls.StackPanel]::new()
    $panelFeedbackEyebrow = & $newPanelText '刚刚发生' 8.8 'SemiBold' 'identity'
    $panelFeedbackTitle = & $newPanelText '' 11.8 'SemiBold' 'ink'
    $panelFeedbackTitle.Margin = [Windows.Thickness]::new(0,4,0,0)
    $panelFeedbackBody = & $newPanelText '' 9.8 'Normal' 'muted'
    $panelFeedbackBody.TextWrapping = [Windows.TextWrapping]::Wrap
    $panelFeedbackBody.Margin = [Windows.Thickness]::new(0,3,0,0)
    $panelFeedbackMeta = & $newPanelText '' 9.2 'SemiBold' 'accent'
    $panelFeedbackMeta.TextWrapping = [Windows.TextWrapping]::Wrap
    $panelFeedbackMeta.Margin = [Windows.Thickness]::new(0,5,0,0)
    $panelFeedbackStack.Children.Add($panelFeedbackEyebrow) | Out-Null
    $panelFeedbackStack.Children.Add($panelFeedbackTitle) | Out-Null
    $panelFeedbackStack.Children.Add($panelFeedbackBody) | Out-Null
    $panelFeedbackStack.Children.Add($panelFeedbackMeta) | Out-Null
    $panelFeedbackHost.Child = $panelFeedbackStack
    [Windows.Controls.Grid]::SetRow($panelFeedbackHost,1)
    $controlRoot.Children.Add($panelFeedbackHost) | Out-Null

    $heroCard = [Windows.Controls.Border]::new()
    $heroCard.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'archive-card-radius')
    $heroCard.Background = & $brush $color.Surface
    $heroCard.BorderBrush = & $brush $color.SurfaceBorder
    $heroCard.BorderThickness = [Windows.Thickness]::new(1)
    $heroCard.Padding = [Windows.Thickness]::new(11)
    $heroCard.Margin = [Windows.Thickness]::new(0, 14, 0, 10)
    $heroGrid = [Windows.Controls.Grid]::new()
    $heroGrid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::new(98) }) | Out-Null
    $heroGrid.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star) }) | Out-Null
    $portraitFrame = [Windows.Controls.Border]::new()
    $portraitFrame.Width = 86
    $portraitFrame.Height = 94
    $portraitFrame.CornerRadius = [Windows.CornerRadius]::new(18)
    $portraitFrame.Background = & $brush $color.SurfaceHover
    $portraitFrame.BorderBrush = & $brush $color.Accent
    $portraitFrame.BorderThickness = [Windows.Thickness]::new(1)
    $panelPortrait = [Windows.Controls.Image]::new()
    $panelPortrait.Stretch = [Windows.Media.Stretch]::Uniform
    $panelPortrait.Margin = [Windows.Thickness]::new(5)
    $portraitFrame.Child = $panelPortrait
    $heroGrid.Children.Add($portraitFrame) | Out-Null
    $heroCopy = [Windows.Controls.StackPanel]::new()
    $heroCopy.Margin = [Windows.Thickness]::new(10,2,0,0)
    $heroModeText = & $newPanelText '此刻 · 安静清醒' 9.2 'SemiBold' 'identity'
    $panelConclusion = & $newPanelText '安静地待在你身边，偶尔偷看一眼甜筒。' 12.4 'SemiBold' 'ink'
    $panelConclusion.TextWrapping = [Windows.TextWrapping]::Wrap
    $panelConclusion.LineHeight = 17
    $panelConclusion.Margin = [Windows.Thickness]::new(0,5,0,0)
    $heroNote = & $newPanelText '拖动换位置 · 长按解锁隐藏动作' 9.2 'Normal' 'muted'
    $heroNote.TextWrapping = [Windows.TextWrapping]::Wrap
    $heroNote.Margin = [Windows.Thickness]::new(0,5,0,0)
    $heroCopy.Children.Add($heroModeText) | Out-Null
    $heroCopy.Children.Add($panelConclusion) | Out-Null
    $heroCopy.Children.Add($heroNote) | Out-Null
    [Windows.Controls.Grid]::SetColumn($heroCopy,1)
    $heroGrid.Children.Add($heroCopy) | Out-Null
    $heroCard.Child = $heroGrid

    $archivePage = [Windows.Controls.StackPanel]::new()
    $interactionPage = [Windows.Controls.StackPanel]::new()
    $artifactPage = [Windows.Controls.StackPanel]::new()
    $settingsPage = [Windows.Controls.StackPanel]::new()
    $archivePage.Children.Add($heroCard) | Out-Null
    $quickCareGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $quickCareGrid.Columns = 3
    $quickCareGrid.Margin = [Windows.Thickness]::new(0,-3,0,8)
    $quickCareGrid.Children.Add((& $newActionTile '奉上甜筒' '' { & $invokeFeed; & $updateControlPanel } 'primary' 42)) | Out-Null
    $quickCareGrid.Children.Add((& $newActionTile '温柔摸头' '' { & $invokePetHead; & $updateControlPanel } 'neutral' 42)) | Out-Null
    $quickCareGrid.Children.Add((& $newActionTile '一起玩雪' '' { & $invokeSnowballGame; & $updateControlPanel } 'neutral' 42)) | Out-Null
    $archivePage.Children.Add($quickCareGrid) | Out-Null
    $archiveTab = $null
    $interactionTab = $null
    $artifactTab = $null
    $settingsTab = $null
    $setPanelPage = {
        param([string]$Page)
        $script:panelPage = if($Page -in @('archive','interaction','artifact','settings')){$Page}else{'archive'}
        $archivePage.Visibility = if($script:panelPage -eq 'archive'){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
        $interactionPage.Visibility = if($script:panelPage -eq 'interaction'){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
        $artifactPage.Visibility = if($script:panelPage -eq 'artifact'){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
        $settingsPage.Visibility = if($script:panelPage -eq 'settings'){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
        if ($archiveTab) {
            foreach($tabEntry in @(@{Id='archive';Tile=$archiveTab},@{Id='interaction';Tile=$interactionTab},@{Id='artifact';Tile=$artifactTab},@{Id='settings';Tile=$settingsTab})) {
                $selected = ($script:panelPage -eq $tabEntry.Id)
                $tabEntry.Tile.DataContext.Selected = $selected
                $tabEntry.Tile.DataContext.SelectedBackground = $color.Royal
                $tabEntry.Tile.DataContext.SelectedBorder = $color.Accent
                $tabEntry.Tile.Background = & $brush $(if($selected){$color.Royal}else{$color.Surface})
                $tabEntry.Tile.BorderBrush = & $brush $(if($selected){$color.Accent}else{$color.SurfaceBorder})
                $tabEntry.Tile.Opacity = if($selected){1}else{.88}
            }
        }
    }
    $tabGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $tabGrid.Columns = 4
    $tabGrid.Margin = [Windows.Thickness]::new(0,0,0,10)
    $archiveTab = & $newActionTile '● 近况' '' { & $setPanelPage 'archive' } 'neutral' ([double]$tokens.component.'panel-tab-height')
    $interactionTab = & $newActionTile '✦ 互动' '' { & $setPanelPage 'interaction' } 'neutral' ([double]$tokens.component.'panel-tab-height')
    $artifactTab = & $newActionTile '◇ 珍藏' '' { & $setPanelPage 'artifact' } 'neutral' ([double]$tokens.component.'panel-tab-height')
    $settingsTab = & $newActionTile '⚙ 设置' '' { & $setPanelPage 'settings' } 'neutral' ([double]$tokens.component.'panel-tab-height')
    $tabGrid.Children.Add($archiveTab) | Out-Null
    $tabGrid.Children.Add($interactionTab) | Out-Null
    $tabGrid.Children.Add($artifactTab) | Out-Null
    $tabGrid.Children.Add($settingsTab) | Out-Null
    $controlStack.Children.Add($tabGrid) | Out-Null

    $statWidgets = @{}
    $statsPanel = [Windows.Controls.Primitives.UniformGrid]::new()
    $statsPanel.Columns = 2
    $archivePage.Children.Add($statsPanel) | Out-Null
    $newStatRow = {
        param([string]$Key, [string]$Label, [string]$FillColor, [string]$Tone)
        $card = [Windows.Controls.Border]::new()
        $card.MinHeight = 74
        $card.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'archive-card-radius')
        $card.Background = & $brush $color.Surface
        $card.BorderBrush = & $brush $color.SurfaceBorder
        $card.BorderThickness = [Windows.Thickness]::new(1)
        $card.Padding = [Windows.Thickness]::new(10,8,10,9)
        $card.Margin = [Windows.Thickness]::new(3)
        $stack = [Windows.Controls.StackPanel]::new()
        $head = [Windows.Controls.Grid]::new()
        $head.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star) }) | Out-Null
        $head.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]@{ Width = [Windows.GridLength]::Auto }) | Out-Null
        $labelBlock = & $newPanelText $Label 10.4 'SemiBold' $Tone
        $valueBlock = & $newPanelText '100' 10.2 'SemiBold' 'ink'
        [Windows.Controls.Grid]::SetColumn($valueBlock,1)
        $head.Children.Add($labelBlock) | Out-Null
        $head.Children.Add($valueBlock) | Out-Null
        $descriptorBlock = & $newPanelText '正在读取' 9.3 'Normal' 'muted'
        $descriptorBlock.Margin = [Windows.Thickness]::new(0,3,0,5)
        $segmentsGrid = [Windows.Controls.Primitives.UniformGrid]::new()
        $segmentsGrid.Columns = 5
        $segmentsGrid.Height = [double]$tokens.component.'segment-height'
        $segments = [Collections.Generic.List[Windows.Controls.Border]]::new()
        for($i=0;$i -lt 5;$i++) {
            $segment = [Windows.Controls.Border]::new()
            $segment.CornerRadius = [Windows.CornerRadius]::new(3)
            $segment.Background = & $brush $color.SegmentOff
            $segment.Margin = [Windows.Thickness]::new(1.5,0,1.5,0)
            $segments.Add($segment)
            $segmentsGrid.Children.Add($segment) | Out-Null
        }
        $stack.Children.Add($head) | Out-Null
        $stack.Children.Add($descriptorBlock) | Out-Null
        $stack.Children.Add($segmentsGrid) | Out-Null
        $card.Child = $stack
        $statsPanel.Children.Add($card) | Out-Null
        $statWidgets[$Key] = @{ Value=$valueBlock; Descriptor=$descriptorBlock; Segments=$segments; Color=$FillColor }
    }
    & $newStatRow 'health' '活力' $color.Health 'danger'
    & $newStatRow 'fullness' '饱腹' $color.Need 'need'
    & $newStatRow 'stamina' '霜能' $color.Energy 'energy'
    & $newStatRow 'affection' '亲密' $color.Trust 'trust'
    & $newStatRow 'craving' '馋嘴' $color.Need 'need'
    & $newStatRow 'grievance' '委屈' $color.Boundary 'boundary'

    $eventsCard = [Windows.Controls.Border]::new()
    $eventsCard.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'archive-card-radius')
    $eventsCard.Background = & $brush $color.Surface
    $eventsCard.BorderBrush = & $brush $color.SurfaceBorder
    $eventsCard.BorderThickness = [Windows.Thickness]::new(1)
    $eventsCard.Padding = [Windows.Thickness]::new(11)
    $eventsCard.Margin = [Windows.Thickness]::new(3,9,3,3)
    $eventsStack = [Windows.Controls.StackPanel]::new()
    $eventsTitle = & $newPanelText '最近发生' 10.5 'SemiBold' 'identity'
    $eventsStack.Children.Add($eventsTitle) | Out-Null
    $eventTextBlocks = [Collections.Generic.List[Windows.Controls.TextBlock]]::new()
    for($i=0;$i -lt 3;$i++) {
        $eventLine = & $newPanelText '— · 暂无新记录' 9.4 'Normal' 'muted'
        $eventLine.TextWrapping = [Windows.TextWrapping]::Wrap
        $eventLine.Margin = [Windows.Thickness]::new(0,5,0,0)
        $eventTextBlocks.Add($eventLine)
        $eventsStack.Children.Add($eventLine) | Out-Null
    }
    $eventsCard.Child = $eventsStack
    $archivePage.Children.Add($eventsCard) | Out-Null

    $interactionIntro = & $newPanelText '今天想怎么玩？' 12 'SemiBold' 'ink'
    $interactionPage.Children.Add($interactionIntro) | Out-Null
    $bodyHint = & $newPanelText '点不同部位会有不同反应；连戳、长按和熟睡时还藏着小剧情。' 9.6 'Normal' 'muted'
    $bodyHint.TextWrapping = [Windows.TextWrapping]::Wrap
    $bodyHint.Margin = [Windows.Thickness]::new(0,4,0,5)
    $interactionPage.Children.Add($bodyHint) | Out-Null
    $interactionRegionGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $interactionRegionGrid.Columns = 3
    $interactionPage.Children.Add($interactionRegionGrid) | Out-Null
    $regionTileDefinitions = @(
        @{Region='crown';Title='王冠';Subtitle='歪冠／追冠'},
        @{Region='left-cheek';Title='左脸颊';Subtitle='挤脸／回弹'},
        @{Region='right-cheek';Title='右脸颊';Subtitle='鼓腮／偷看'},
        @{Region='left-ear';Title='左耳';Subtitle='轻抖／害羞'},
        @{Region='right-ear';Title='右耳';Subtitle='捂耳／企鹅舞'},
        @{Region='belly';Title='肚皮';Subtitle='肚响／吃撑'},
        @{Region='wand';Title='权杖';Subtitle='护杖／反噬'},
        @{Region='cape';Title='披风';Subtitle='裹团／飞行'},
        @{Region='foot';Title='小脚';Subtitle='乱踢／摔扁'}
    )
    foreach($regionDef in $regionTileDefinitions) {
        $regionName = [string]$regionDef.Region
        $regionAction = { & $invokeRegionInteraction $regionName; & $updateControlPanel }.GetNewClosure()
        $interactionRegionGrid.Children.Add((& $newActionTile ([string]$regionDef.Title) ([string]$regionDef.Subtitle) $regionAction 'neutral' 58)) | Out-Null
    }

    $playLabel = & $newPanelText '陪伴动作' 10.5 'SemiBold' 'identity'
    $playLabel.Margin = [Windows.Thickness]::new(0,10,0,3)
    $interactionPage.Children.Add($playLabel) | Out-Null
    $actionGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $actionGrid.Columns = 2
    $interactionPage.Children.Add($actionGrid) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '奉上甜筒' '馋嘴会四足冲过来' { & $invokeFeed; & $updateControlPanel } 'primary' 58)) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '安抚披风' '委屈时裹好她' { & $invokeCapeComfort; & $updateControlPanel } 'neutral' 58)) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '雪球游戏' '滑倒也要装高冷' { & $invokeSnowballGame; & $updateControlPanel } 'neutral' 58)) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '拆零食袋' '咬袋失败急哭' { & $invokeSnackChallenge; & $updateControlPanel } 'neutral' 58)) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '女皇仪式' '王冠与权杖联动' { & $invokeQueenCeremony; & $updateControlPanel } 'neutral' 58)) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '企鹅舞会' '跳累会摔成扁团' { & $invokeBodyPlay; & $updateControlPanel } 'neutral' 58)) | Out-Null
    $followTile = & $newActionTile '随行巡游' '迈着企鹅步陪跑' { if($script:followMode){ & $stopFollowing }else{ & $startFollowing }; & $updateControlPanel } 'primary' 58
    $followTileText = $followTile.Tag
    $actionGrid.Children.Add($followTile) | Out-Null
    $actionGrid.Children.Add((& $newActionTile '温柔摸头' '单次触摸不会结霜' { & $invokePetHead; & $updateControlPanel } 'neutral' 58)) | Out-Null

    $artifactIntro = & $newPanelText '甜品珍藏柜' 12 'SemiBold' 'ink'
    $artifactPage.Children.Add($artifactIntro) | Out-Null
    $artifactHint = & $newPanelText '五个位置各选一件；凑齐 2／4 件同系列，会真正改变投喂、玩耍和安抚效果。' 9.5 'Normal' 'muted'
    $artifactHint.TextWrapping = [Windows.TextWrapping]::Wrap
    $artifactHint.Margin = [Windows.Thickness]::new(0,4,0,7)
    $artifactPage.Children.Add($artifactHint) | Out-Null

    $artifactSetSummaryGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $artifactSetSummaryGrid.Columns = 3
    $artifactSetSummaryGrid.Margin = [Windows.Thickness]::new(0,0,0,7)
    $artifactPage.Children.Add($artifactSetSummaryGrid) | Out-Null
    $artifactSetStatusBlocks = @{}
    foreach($setId in $artifactSets.Keys) {
        $setInfo = $artifactSets[$setId]
        $setCard = [Windows.Controls.Border]::new()
        $setCard.CornerRadius = [Windows.CornerRadius]::new([double]$tokens.component.'artifact-card-radius')
        $setCard.Background = & $brush $color.Surface
        $setCard.BorderBrush = & $brush $(switch($setId){'evergreen'{$color.Identity}'shake'{$color.Trust}default{$color.Energy}})
        $setCard.BorderThickness = [Windows.Thickness]::new(1)
        $setCard.Padding = [Windows.Thickness]::new(7)
        $setCard.Margin = [Windows.Thickness]::new(2)
        $setStack = [Windows.Controls.StackPanel]::new()
        $setTitle = & $newPanelText ([string]$setInfo.Short) 9.3 'SemiBold' ([string]$setInfo.Tone)
        $setStatus = & $newPanelText '0/5 · 2件— · 4件—' 8.6 'Normal' 'muted'
        $setStatus.Margin = [Windows.Thickness]::new(0,3,0,0)
        $setStatus.TextWrapping = [Windows.TextWrapping]::Wrap
        $setStack.Children.Add($setTitle) | Out-Null
        $setStack.Children.Add($setStatus) | Out-Null
        $setCard.Child = $setStack
        $artifactSetSummaryGrid.Children.Add($setCard) | Out-Null
        $artifactSetStatusBlocks[$setId] = $setStatus
    }

    $artifactSlotLabel = & $newPanelText '当前搭配' 10.2 'SemiBold' 'identity'
    $artifactPage.Children.Add($artifactSlotLabel) | Out-Null
    $artifactSlotGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $artifactSlotGrid.Columns = 1
    $artifactSlotGrid.Margin = [Windows.Thickness]::new(0,2,0,6)
    $artifactPage.Children.Add($artifactSlotGrid) | Out-Null
    $artifactSlotTiles = @{}
    $artifactSlotDetailBlocks = @{}
    $refreshArtifactPage = $null
    $selectArtifactSlot = {
        param([string]$SlotId)
        if ($SlotId -notin @($artifactSlots.Id)) { return }
        $artifactUiState.SelectedSlot = $SlotId
        if ($artifactUiState.Refresh -is [scriptblock]) { & $artifactUiState.Refresh }
    }.GetNewClosure()
    $slotAction = {
        param($tile)
        $artifactUiState.SelectedSlot = [string]$tile.Uid
        if ($artifactUiState.Refresh -is [scriptblock]) { & $artifactUiState.Refresh }
    }.GetNewClosure()
    foreach($slot in $artifactSlots) {
        $slotId = [string]$slot.Id
        $slotTile = & $newActionTile "$($slot.Icon) $($slot.Name)" '正在读取搭配' $slotAction 'neutral' ([double]$tokens.component.'artifact-slot-height')
        $slotTile.Uid = $slotId
        $artifactSlotGrid.Children.Add($slotTile) | Out-Null
        $artifactSlotTiles[$slotId] = $slotTile
        $artifactSlotDetailBlocks[$slotId] = $slotTile.Child.Children[1]
    }

    $artifactChoiceTitle = & $newPanelText '可选珍藏（点击即换上）' 10.2 'SemiBold' 'identity'
    $artifactChoiceTitle.Margin = [Windows.Thickness]::new(0,3,0,2)
    $artifactPage.Children.Add($artifactChoiceTitle) | Out-Null
    $artifactChoiceGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $artifactChoiceGrid.Columns = 1
    $artifactPage.Children.Add($artifactChoiceGrid) | Out-Null

    $artifactQuickLabel = & $newPanelText '一键搭配' 10.2 'SemiBold' 'identity'
    $artifactQuickLabel.Margin = [Windows.Thickness]::new(0,7,0,2)
    $artifactPage.Children.Add($artifactQuickLabel) | Out-Null
    $artifactSetQuickGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $artifactSetQuickGrid.Columns = 3
    $artifactPage.Children.Add($artifactSetQuickGrid) | Out-Null
    $artifactNoticeText = & $newPanelText '可以整套换上，也可以自由混搭成 4+1 或 2+2+1。' 9.3 'Normal' 'accent'
    $artifactNoticeText.TextWrapping = [Windows.TextWrapping]::Wrap
    $artifactNoticeText.Margin = [Windows.Thickness]::new(3,5,3,2)
    $equipArtifactSet = {
        param([string]$SetId)
        foreach($slot in $artifactSlots) {
            $match = @($artifactItems | Where-Object { $_.Set -eq $SetId -and $_.Slot -eq $slot.Id })[0]
            if ($null -ne $match) { $artifactUiState.Equipped[[string]$slot.Id] = [string]$match.Id }
        }
        & $rebuildArtifactEffects
        $artifactNoticeText.Text = "已换上「$(($artifactSets[$SetId]).Name)」五件套；2 件与 4 件效果均已生效。"
        & $saveState
        if ($artifactUiState.Refresh -is [scriptblock]) { & $artifactUiState.Refresh }
    }.GetNewClosure()
    $quickAction = { param($tile) & $equipArtifactSet ([string]$tile.Uid) }.GetNewClosure()
    foreach($setId in $artifactSets.Keys) {
        $quickTile = & $newActionTile ([string]$artifactSets[$setId].Short) '' $quickAction 'neutral' 34
        $quickTile.Uid = [string]$setId
        $artifactSetQuickGrid.Children.Add($quickTile) | Out-Null
    }
    $unequipArtifactSlot = {
        $artifactUiState.Equipped[[string]$artifactUiState.SelectedSlot] = ''
        & $rebuildArtifactEffects
        $artifactNoticeText.Text = '当前槽位已卸下；套装计数与效果已即时重算。'
        & $saveState
        if ($artifactUiState.Refresh -is [scriptblock]) { & $artifactUiState.Refresh }
    }.GetNewClosure()
    $artifactUnequipTile = & $newActionTile '清空当前位置' '给混搭留一点空间' $unequipArtifactSlot 'neutral' 40
    $artifactPage.Children.Add($artifactUnequipTile) | Out-Null
    $artifactPage.Children.Add($artifactNoticeText) | Out-Null

    # === 设置页面 ===
    $settingsIntro = & $newPanelText '雪王偏好设置' 12 'SemiBold' 'ink'
    $settingsIntro.Margin = [Windows.Thickness]::new(0,0,0,4)
    $settingsPage.Children.Add($settingsIntro) | Out-Null
    $settingsHint = & $newPanelText '调整陪伴方式，所有设置会自动保存。' 9.5 'Normal' 'muted'
    $settingsHint.TextWrapping = [Windows.TextWrapping]::Wrap
    $settingsHint.Margin = [Windows.Thickness]::new(0,0,0,10)
    $settingsPage.Children.Add($settingsHint) | Out-Null

    # 陪伴模式
    $settingsMoodLabel = & $newPanelText '陪伴模式' 10 'SemiBold' 'muted'
    $settingsMoodLabel.Margin = [Windows.Thickness]::new(3,4,0,3)
    $settingsPage.Children.Add($settingsMoodLabel) | Out-Null
    $settingsMoodGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $settingsMoodGrid.Columns = 2
    $settingsMoodGrid.Children.Add((& $newActionTile '自然作息' '偶尔主动来找你' {
        $script:autoMood = $true
        & $scheduleNextNudge 40 76; $moodTimer.Start()
        & $showFeedback '已恢复自然作息' '雪王会按自己的节奏生活，偶尔来看看你。' 'neutral' 0 0 0 2500
        & $saveState; & $updateControlPanel
    } 'neutral' 44)) | Out-Null
    $settingsMoodGrid.Children.Add((& $newActionTile '免打扰' '只在你互动时回应' {
        $script:autoMood = $false
        $moodTimer.Stop(); & $holdState (& $getRestState)
        & $showFeedback '已开启免打扰' '雪王会安静待着，等你来找它。' 'neutral' 0 0 0 2500
        & $saveState; & $updateControlPanel
    } 'neutral' 44)) | Out-Null
    $settingsPage.Children.Add($settingsMoodGrid) | Out-Null

    # 桌宠大小
    $settingsSizeLabel = & $newPanelText '桌宠大小' 10 'SemiBold' 'muted'
    $settingsSizeLabel.Margin = [Windows.Thickness]::new(3,10,0,3)
    $settingsPage.Children.Add($settingsSizeLabel) | Out-Null
    $settingsSizeGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $settingsSizeGrid.Columns = 3
    foreach ($size in @(@{Label='小巧 88px';Value=88}, @{Label='标准 116px';Value=116}, @{Label='放大 148px';Value=148})) {
        $sizeValue = $size.Value
        $sizeTile = & $newActionTile $size.Label '' {
            $window.Width = [double]$sizeValue
            $window.Height = [Math]::Round($window.Width * 1.103)
            $area = & $getCursorWorkAreaDip
            $window.Left = [Math]::Min([Math]::Max($window.Left, $area.Left), $area.Right - $window.Width)
            $window.Top = [Math]::Min([Math]::Max($window.Top, $area.Top), $area.Bottom - $window.Height)
            & $saveState
            & $playPetSound 'success'
        }.GetNewClosure() 'neutral' 38
        $settingsSizeGrid.Children.Add($sizeTile) | Out-Null
    }
    $settingsPage.Children.Add($settingsSizeGrid) | Out-Null

    # 系统设置
    $settingsSysLabel = & $newPanelText '系统' 10 'SemiBold' 'muted'
    $settingsSysLabel.Margin = [Windows.Thickness]::new(3,10,0,3)
    $settingsPage.Children.Add($settingsSysLabel) | Out-Null
    $settingsSysGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $settingsSysGrid.Columns = 2
    # 面板与托盘共用主脚本作用域中的动作，避免事件闭包中的 $script: 指向动态模块。
    $toggleAutoStartSetting = {
        $newVal = -not (& $isAutoStartEnabled)
        $ok = & $setAutoStart $newVal
        if ($ok) {
            & $showFeedback '开机自启' $(if($newVal){'已开启，登录后雪王会自动出现。'}else{'已关闭，需要手动启动。'}) 'neutral' 0 0 0 2500
        } else {
            & $showFeedback '设置失败' '无法修改注册表，请检查权限。' 'danger' 0 0 0 2500
        }
        & $updateControlPanel
    }
    $toggleSoundSetting = {
        $script:soundEnabled = -not $script:soundEnabled
        & $saveState
        & $showFeedback '音效' $(if($script:soundEnabled){'已开启，互动时会有轻量提示音。'}else{'已关闭，完全静音陪伴。'}) 'neutral' 0 0 0 2500
        & $updateControlPanel
    }
    $settingsAutoStartTile = & $newActionTile '开机自启' '' $toggleAutoStartSetting 'neutral' 44
    $settingsSysGrid.Children.Add($settingsAutoStartTile) | Out-Null
    $settingsSoundTile = & $newActionTile '交互音效' '' $toggleSoundSetting 'neutral' 44
    $settingsSysGrid.Children.Add($settingsSoundTile) | Out-Null
    $settingsPage.Children.Add($settingsSysGrid) | Out-Null

    # 快捷操作
    $settingsQuickLabel = & $newPanelText '快捷操作' 10 'SemiBold' 'muted'
    $settingsQuickLabel.Margin = [Windows.Thickness]::new(3,10,0,3)
    $settingsPage.Children.Add($settingsQuickLabel) | Out-Null
    $settingsQuickGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $settingsQuickGrid.Columns = 2
    $settingsQuickGrid.Children.Add((& $newActionTile '回到角落' '把雪王送回屏幕右下角' {
        & $returnHome; & $hideControlPanel
    } 'neutral' 44)) | Out-Null
    $settingsQuickGrid.Children.Add((& $newActionTile '重置欢迎' '重新显示首次引导' {
        $script:welcomeSeen = $false
        & $saveState
        & $showFeedback '已重置' '下次启动会重新显示欢迎引导。' 'neutral' 0 0 0 2500
    } 'neutral' 44)) | Out-Null
    $settingsPage.Children.Add($settingsQuickGrid) | Out-Null

    # 关于
    $settingsAboutDivider = [Windows.Controls.Border]::new()
    $settingsAboutDivider.Height = 1
    $settingsAboutDivider.Background = & $brush $color.Divider
    $settingsAboutDivider.Margin = [Windows.Thickness]::new(3,12,3,8)
    $settingsPage.Children.Add($settingsAboutDivider) | Out-Null
    $settingsAboutTitle = & $newPanelText '关于雪王桌宠' 10.5 'SemiBold' 'identity'
    $settingsPage.Children.Add($settingsAboutTitle) | Out-Null
    $versionText = if (Test-Path (Join-Path $PSScriptRoot 'VERSION')) { Get-Content (Join-Path $PSScriptRoot 'VERSION') -Raw } else { '0.9.0' }
    $settingsAboutVer = & $newPanelText "版本 $versionText" 9.5 'Normal' 'muted'
    $settingsAboutVer.Margin = [Windows.Thickness]::new(0,3,0,0)
    $settingsPage.Children.Add($settingsAboutVer) | Out-Null
    $settingsAboutDesc = & $newPanelText '非官方二创预览版 · 52 组透明动画 · 九部位交互 · 六项长期状态 · 甜品珍藏系统' 9 'Normal' 'muted'
    $settingsAboutDesc.TextWrapping = [Windows.TextWrapping]::Wrap
    $settingsAboutDesc.Margin = [Windows.Thickness]::new(0,4,0,0)
    $settingsPage.Children.Add($settingsAboutDesc) | Out-Null
    $settingsExitTile = & $newActionTile '暂别并退出' '保存进度并关闭桌宠' { $window.Close() } 'danger' 44
    $settingsExitTile.Margin = [Windows.Thickness]::new(3,10,3,0)
    $settingsPage.Children.Add($settingsExitTile) | Out-Null

    $equipArtifactItem = {
        param([string]$ItemId)
        if (-not $artifactById.ContainsKey($ItemId)) { return }
        $item = $artifactById[$ItemId]
        if ([string]$item.Slot -ne [string]$artifactUiState.SelectedSlot) { return }
        $artifactUiState.Equipped[[string]$artifactUiState.SelectedSlot] = $ItemId
        & $rebuildArtifactEffects
        $artifactNoticeText.Text = "已装备「$($item.Name)」；换装只在面板内回执，不弹语言条。"
        & $saveState
        if ($artifactUiState.Refresh -is [scriptblock]) { & $artifactUiState.Refresh }
    }.GetNewClosure()
    $artifactChoiceAction = {
        param($tile)
        $itemId = [string]$tile.Uid
        if (-not $artifactById.ContainsKey($itemId)) { return }
        $item = $artifactById[$itemId]
        if ([string]$item.Slot -ne [string]$artifactUiState.SelectedSlot) { return }
        $artifactUiState.Equipped[[string]$artifactUiState.SelectedSlot] = $itemId
        & $rebuildArtifactEffects
        $artifactNoticeText.Text = "已装备「$($item.Name)」；换装只在面板内回执，不弹语言条。"
        & $saveState
        if ($artifactUiState.Refresh -is [scriptblock]) { & $artifactUiState.Refresh }
    }.GetNewClosure()

    $refreshArtifactPage = {
        foreach($setId in $artifactSets.Keys) {
            $count = [int]$artifactUiState.SetCounts[$setId]
            $artifactSetStatusBlocks[$setId].Text = "$count/5 · 2件$(if($count -ge 2){'✓'}else{'—'}) · 4件$(if($count -ge 4){'✓'}else{'—'})"
        }
        foreach($slot in $artifactSlots) {
            $slotId = [string]$slot.Id
            $itemId = [string]$artifactUiState.Equipped[$slotId]
            $item = if($itemId -and $artifactById.ContainsKey($itemId)){$artifactById[$itemId]}else{$null}
            $artifactSlotTiles[$slotId].Tag.Text = "$($slot.Icon) $($slot.Genshin) · $(if($item){$item.Name}else{'未装备'})"
            $artifactSlotDetailBlocks[$slotId].Text = if($item){"$($artifactSets[[string]$item.Set].Short) · $($item.EffectText)"}else{'空槽 · 不计入套装'}
            $selected = ($artifactUiState.SelectedSlot -eq $slotId)
            $artifactSlotTiles[$slotId].DataContext.Selected = $selected
            $artifactSlotTiles[$slotId].DataContext.SelectedBackground = $color.SurfacePressed
            $artifactSlotTiles[$slotId].DataContext.SelectedBorder = $color.Positive
            $artifactSlotTiles[$slotId].BorderBrush = & $brush $(if($selected){$color.Positive}else{$color.SurfaceBorder})
            $artifactSlotTiles[$slotId].BorderThickness = [Windows.Thickness]::new($(if($selected){2}else{1}))
        }
        $artifactChoiceGrid.Children.Clear()
        $selectedSlot = $artifactUiState.SelectedSlot
        $selectedSlotDef = @($artifactSlots | Where-Object { $_.Id -eq $selectedSlot })[0]
        $artifactChoiceTitle.Text = "$($selectedSlotDef.Name) · 3 个可选珍藏"
        foreach($item in @($artifactItems | Where-Object { $_.Slot -eq $selectedSlot })) {
            $itemId = [string]$item.Id
            $equipped = ([string]$artifactUiState.Equipped[$selectedSlot] -eq $itemId)
            $sourceLabel = switch([string]$item.SourceKind) {
                'official-top5' { '官方产品 · 年度销量前五' }
                'official-product' { '官方产品' }
                'official-series' { '官方曾推出系列' }
                default { '桌宠原创 · 非官方新品' }
            }
            $productLabel = if([string]$item.Product){"商品依据：$($item.Product)"}else{'无同名官方商品'}
            $choiceTitle = "$($item.Name)$(if($equipped){' · 已装备'}else{''})"
            $choiceSubtitle = "$sourceLabel · $productLabel`n$($item.EffectText)"
            $choiceTile = & $newActionTile $choiceTitle $choiceSubtitle $artifactChoiceAction $(if($equipped){'primary'}else{'neutral'}) ([double]$tokens.component.'artifact-choice-height')
            $choiceTile.Uid = $itemId
            if($equipped){
                $choiceTile.DataContext.Selected=$true
                $choiceTile.DataContext.SelectedBackground=$color.Royal
                $choiceTile.DataContext.SelectedBorder=$color.Positive
                $choiceTile.BorderBrush=& $brush $color.Positive
                $choiceTile.BorderThickness=[Windows.Thickness]::new(2)
            }
            $artifactChoiceGrid.Children.Add($choiceTile) | Out-Null
        }
    }.GetNewClosure()
    $artifactUiState.Refresh = $refreshArtifactPage

    $controlStack.Children.Add($archivePage) | Out-Null
    $controlStack.Children.Add($artifactPage) | Out-Null
    $controlStack.Children.Add($interactionPage) | Out-Null
    & $setPanelPage 'archive'
    & $refreshArtifactPage

    $divider = [Windows.Controls.Border]::new()
    $divider.Height = 1
    $divider.Background = & $brush $color.Divider
    $divider.Margin = [Windows.Thickness]::new(3,12,3,7)
    $controlStack.Children.Add($divider) | Out-Null
    $controlGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $controlGrid.Columns = 3
    $controlStack.Children.Add($controlGrid) | Out-Null
    $controlGrid.Children.Add((& $newActionTile '回到角落' '' { & $returnHome; & $hideControlPanel } 'neutral' 38)) | Out-Null
    $quietTile = & $newActionTile '免打扰' '' {
        $script:autoMood = -not $script:autoMood
        if ($script:autoMood) { & $scheduleNextNudge 40 76; $moodTimer.Start() } else { $moodTimer.Stop(); & $holdState (& $getRestState) }
        & $showFeedback '陪伴模式已更新' $(if($script:autoMood){'恢复自然作息，偶尔会来找你。'}else{'不主动冒泡，只保留安静作息和直接互动。'}) 'neutral' 0 0 0 2800
        & $saveState
        & $updateControlPanel
    } 'neutral' 38
    $quietTileText = $quietTile.Tag
    $controlGrid.Children.Add($quietTile) | Out-Null
    $controlGrid.Children.Add((& $newActionTile '打开 Codex' '' { & $markInteraction; & $showBriefState 'waving' 1200; & $openCodex } 'neutral' 38)) | Out-Null

    $sizeLabel = & $newPanelText '桌宠大小' 9.5 'SemiBold' 'muted'
    $sizeLabel.Margin = [Windows.Thickness]::new(3,9,0,2)
    $controlStack.Children.Add($sizeLabel) | Out-Null
    $sizeGrid = [Windows.Controls.Primitives.UniformGrid]::new()
    $sizeGrid.Columns = 3
    foreach ($size in @(@{Label='小巧';Value=88}, @{Label='标准';Value=116}, @{Label='放大';Value=148})) {
        $sizeValue = $size.Value
        $sizeTile = & $newActionTile $size.Label '' {
            $window.Width = [double]$sizeValue
            $window.Height = [Math]::Round($window.Width * 1.103)
            $area = & $getCursorWorkAreaDip
            $window.Left = [Math]::Min([Math]::Max($window.Left, $area.Left), $area.Right - $window.Width)
            $window.Top = [Math]::Min([Math]::Max($window.Top, $area.Top), $area.Bottom - $window.Height)
            & $saveState
        }.GetNewClosure() 'neutral' 32
        $sizeGrid.Children.Add($sizeTile) | Out-Null
    }
    $controlStack.Children.Add($sizeGrid) | Out-Null
    $exitTile = & $newActionTile '暂别啦' '保存进度并退出桌宠' { $window.Close() } 'danger' 44
    $exitTile.Margin = [Windows.Thickness]::new(3,8,3,0)
    $controlStack.Children.Add($exitTile) | Out-Null

    $describeStat = {
        param([string]$Key,[int]$Value)
        switch($Key) {
            'health' { if($Value -le 20){'需要立即照看'}elseif($Value -le 55){'有些受寒'}else{'御体安康'} }
            'fullness' { if($Value -le 25){'胃袋空空'}elseif($Value -ge 88){'已经圆滚滚'}else{'御膳正合适'} }
            'stamina' { if($Value -le 25){'低温待机'}elseif($Value -ge 78){'霜能活跃'}else{'霜能稳定'} }
            'affection' { if($Value -le 25){'仍有些生疏'}elseif($Value -le 50){'正在熟悉'}elseif($Value -le 78){'明显偏爱'}else{'御前眷恋'} }
            'craving' { if($Value -le 20){'雷达安静'}elseif($Value -le 50){'正在搜寻'}elseif($Value -le 80){'锁定甜筒'}else{'甜筒暴走'} }
            'grievance' { if($Value -le 0){'心绪无霜'}elseif($Value -le 25){'结了一层薄霜'}elseif($Value -le 55){'正在鼓腮'}elseif($Value -le 80){'眼泪快冻住'}else{'暂时闭门不见'} }
        }
    }
    $updateControlPanel = {
        foreach ($entry in @(
            @{Key='health';Value=$script:health}, @{Key='fullness';Value=$script:fullness},
            @{Key='stamina';Value=$script:energy}, @{Key='affection';Value=$script:affection},
            @{Key='craving';Value=$script:craving}, @{Key='grievance';Value=$script:grievance}
        )) {
            $widget = $statWidgets[$entry.Key]
            $value = [Math]::Min(100,[Math]::Max(0,[int]$entry.Value))
            $widget.Value.Text = "$value"
            $widget.Descriptor.Text = & $describeStat $entry.Key $value
            $litSegments = [Math]::Min(5,[Math]::Max(0,[int][Math]::Ceiling($value / 20.0)))
            for($i=0;$i -lt $widget.Segments.Count;$i++) {
                $widget.Segments[$i].Background = & $brush $(if($i -lt $litSegments){$widget.Color}else{$color.SegmentOff})
            }
        }
        $controlStatusText.Text = if ($script:followMode) { '正在跟着你的鼠标散步' } elseif ($script:returnHomeMode) { '正在跑回熟悉的角落' } else { switch($script:activityPhase){ 'sleep' {'已经缩进披风里睡着了'} 'active' {'正在桌面边缘短暂巡视'} default {'安静醒着，偶尔看看你'} } }
        $panelConclusion.Text = if($script:health -le 20) {
            '看起来有点难受，需要马上照看。'
        } elseif($script:grievance -ge 60) {
            '心里结了厚厚一层霜，先温柔安抚一下吧。'
        } elseif($script:activityPhase -eq 'sleep') {
            '夜巡结束，已经在披风冰窝里睡熟了。'
        } elseif($script:craving -ge 78) {
            '甜筒雷达已经锁定你了，明显在等一口好吃的。'
        } elseif($script:currentState -in @('stuffed','belly-flop','last-bite')) {
            '嘴上说还能吃，圆滚滚的肚皮已经不同意。'
        } elseif($script:activityPhase -eq 'active') {
            '精神正好，正在巡视桌面边缘。'
        } else {
            '安静地待在你身边，偶尔偷看一眼甜筒。'
        }
        $heroModeText.Text = if($script:health -le 20 -or $script:grievance -ge 80){'此刻 · 需要照看'}elseif($script:activityPhase -eq 'sleep'){'此刻 · 熟睡中'}elseif($script:followMode){'此刻 · 随行中'}else{'此刻 · 安静清醒'}
        $heroModeText.Foreground = & $brush $(if($script:health -le 20){$color.Health}elseif($script:grievance -ge 60){$color.Boundary}else{$color.Identity})
        $panelPortrait.Source = $petImage.Source
        for($i=0;$i -lt $eventTextBlocks.Count;$i++) {
            $eventTextBlocks[$i].Text = if($i -lt $script:recentEvents.Count){[string]$script:recentEvents[$i]}else{'— · 暂无新记录'}
        }
        $followTileText.Text = if ($script:followMode) { '停止巡游' } else { '随行巡游' }
        $quietTileText.Text = if ($script:autoMood) { '免打扰' } else { '恢复自然作息' }
        # 更新设置页面按钮状态
        if ($null -ne $settingsAutoStartTile -and $null -ne $settingsAutoStartTile.Tag) {
            $settingsAutoStartTile.Tag.Text = if ($script:autoStartEnabled) { '✓ 开机自启' } else { '开机自启' }
        }
        if ($null -ne $settingsSoundTile -and $null -ne $settingsSoundTile.Tag) {
            $settingsSoundTile.Tag.Text = if ($script:soundEnabled) { '✓ 交互音效' } else { '交互音效' }
        }
        if ($null -ne $autoStartTrayItem) { $autoStartTrayItem.Checked = $script:autoStartEnabled }
        if ($null -ne $soundTrayItem) { $soundTrayItem.Checked = $script:soundEnabled }
        $controlCard.BorderBrush = & $brush $(if($script:health -le 20){$color.Health}elseif($script:grievance -ge 80){$color.Boundary}else{$color.SurfaceBorder})
        if ($refreshArtifactPage -is [scriptblock]) { & $refreshArtifactPage }
    }

    $showControlPanel = {
        if ($script:petStatus -ne 'home') { return }
        & $updateControlPanel
        $wasHidden = -not $controlWindow.IsVisible
        if ($wasHidden) { $controlWindow.Opacity = 0; $controlTransform.Y = 10; $controlWindow.Show() }
        $controlWindow.UpdateLayout()
        $area = & $getCursorWorkAreaDip
        $controlScroll.MaxHeight = [Math]::Max(330, [Math]::Min(640, $area.Height - 132))
        $controlCard.Measure([Windows.Size]::new([double]$tokens.component.'control-width', [double]::PositiveInfinity))
        $panelWidth = [Math]::Max([double]$tokens.component.'control-width', [Math]::Max($controlWindow.ActualWidth, $controlCard.DesiredSize.Width))
        $panelHeight = [Math]::Max(1, [Math]::Max($controlWindow.ActualHeight, $controlCard.DesiredSize.Height))
        $panelHeight = [Math]::Min($panelHeight, $area.Height - 16)
        $left = $window.Left - $panelWidth - 10
        if ($left -lt $area.Left) { $left = $window.Left + $window.Width + 10 }
        $controlWindow.Left = [Math]::Min([Math]::Max($left,$area.Left),$area.Right-$panelWidth)
        $maximumTop = [Math]::Max($area.Top + 8, $area.Bottom - $panelHeight - 8)
        $controlWindow.Top = [Math]::Min([Math]::Max($window.Top-$panelHeight+80,$area.Top+8),$maximumTop)
        if ($wasHidden) {
            $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds([double]$tokens.component.'motion-normal-ms'))
            $controlWindow.BeginAnimation([Windows.Window]::OpacityProperty, [Windows.Media.Animation.DoubleAnimation]::new(0, 1, $duration))
            $controlTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, [Windows.Media.Animation.DoubleAnimation]::new(10, 0, $duration))
        }
        if ($feedbackTimer.IsEnabled -and $null -ne $script:lastFeedback) {
            $panelFeedbackTitle.Text = [string]$script:lastFeedback.Title
            $panelFeedbackBody.Text = [string]$script:lastFeedback.Message
            $panelFeedbackMeta.Text = [string]$script:lastFeedback.Meta
            $panelFeedbackHost.Visibility = [Windows.Visibility]::Visible
            $feedbackWindow.Hide()
            $script:feedbackPresentation = 'inline'
        }
    }

    $hideControlPanel = {
        if ($controlWindow.IsVisible) { $controlWindow.Hide() }
        $panelFeedbackHost.Visibility = [Windows.Visibility]::Collapsed
        if ($feedbackTimer.IsEnabled -and $null -ne $script:lastFeedback) {
            if (-not $feedbackWindow.IsVisible) { $feedbackWindow.Show() }
            $feedbackWindow.UpdateLayout()
            & $positionFeedbackWindow
            $feedbackWindow.Opacity = 1
            $script:feedbackPresentation = 'floating'
        }
    }

    $toggleControlPanel = {
        param([string]$Page = '')
        if ($controlWindow.IsVisible) { & $hideControlPanel; return }
        if ($Page) { & $setPanelPage $Page }
        & $showControlPanel
    }

    $notifyIcon = $null
    $trayContextMenu = $null
    $trayIcon = $null
    $autoStartTrayItem = [Windows.Forms.ToolStripMenuItem]::new('开机自启')
    $autoStartTrayItem.Checked = $script:autoStartEnabled
    $autoStartTrayItem.Add_Click({ & $toggleAutoStartSetting }.GetNewClosure())
    $soundTrayItem = [Windows.Forms.ToolStripMenuItem]::new('音效')
    $soundTrayItem.Checked = $script:soundEnabled
    $soundTrayItem.Add_Click({ & $toggleSoundSetting }.GetNewClosure())
    $exitTrayItem = [Windows.Forms.ToolStripMenuItem]::new('暂别并退出')
    $exitTrayItem.Add_Click({ $window.Close() }.GetNewClosure())
    if (-not $SelfTest -and -not $PersistenceProbe) {
        try {
            $traySource = [Drawing.Bitmap]::new((Join-Path $assetDir 'idle\frame-00.png'))
            $trayBitmap = [Drawing.Bitmap]::new(64, 64, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try {
                $trayGraphics = [Drawing.Graphics]::FromImage($trayBitmap)
                try {
                    $trayGraphics.Clear([Drawing.Color]::Transparent)
                    $trayGraphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $trayGraphics.DrawImage($traySource, [Drawing.Rectangle]::new(2, 0, 59, 64))
                } finally { $trayGraphics.Dispose() }
                $iconHandle = $trayBitmap.GetHicon()
                try { $trayIcon = [Drawing.Icon]::FromHandle($iconHandle).Clone() } finally { [XueWangDesktopPet.NativeIcon]::DestroyIcon($iconHandle) | Out-Null }
            } finally {
                $trayBitmap.Dispose()
                $traySource.Dispose()
            }

            $trayContextMenu = [Windows.Forms.ContextMenuStrip]::new()
            $openTrayItem = [Windows.Forms.ToolStripMenuItem]::new('打开陪伴屋')
            $homeTrayItem = [Windows.Forms.ToolStripMenuItem]::new('回到屏幕角落')
            $openTrayItem.Add_Click({ & $showControlPanel }.GetNewClosure())
            $homeTrayItem.Add_Click({ & $placeAtHome }.GetNewClosure())
            $trayContextMenu.Items.Add($openTrayItem) | Out-Null
            $trayContextMenu.Items.Add($homeTrayItem) | Out-Null
            $trayContextMenu.Items.Add([Windows.Forms.ToolStripSeparator]::new()) | Out-Null
            $trayContextMenu.Items.Add($autoStartTrayItem) | Out-Null
            $trayContextMenu.Items.Add($soundTrayItem) | Out-Null
            $trayContextMenu.Items.Add([Windows.Forms.ToolStripSeparator]::new()) | Out-Null
            $trayContextMenu.Items.Add($exitTrayItem) | Out-Null

            $notifyIcon = [Windows.Forms.NotifyIcon]::new()
            $notifyIcon.Icon = $trayIcon
            $notifyIcon.Text = '雪王桌宠 · 双击打开陪伴屋'
            $notifyIcon.ContextMenuStrip = $trayContextMenu
            $notifyIcon.Add_DoubleClick({ & $showControlPanel }.GetNewClosure())
            $notifyIcon.Visible = $true
        } catch {
            if ($null -ne $trayContextMenu) { $trayContextMenu.Dispose(); $trayContextMenu = $null }
            if ($null -ne $trayIcon) { $trayIcon.Dispose(); $trayIcon = $null }
            $notifyIcon = $null
        }
    }

    $absenceWindow = [Windows.Window]::new()
    $absenceWindow.Title = '雪王不在桌面'
    $absenceWindow.WindowStyle = [Windows.WindowStyle]::None
    $absenceWindow.ResizeMode = [Windows.ResizeMode]::NoResize
    $absenceWindow.AllowsTransparency = $true
    $absenceWindow.Background = [Windows.Media.Brushes]::Transparent
    $absenceWindow.ShowInTaskbar = $false
    $absenceWindow.Topmost = $true
    $absenceWindow.SizeToContent = [Windows.SizeToContent]::WidthAndHeight
    $absenceCard = [Windows.Controls.Border]::new()
    $absenceCard.Width = 352
    $absenceCard.CornerRadius = [Windows.CornerRadius]::new(24)
    $absenceCard.Background = & $brush $color.SurfaceGlass
    $absenceCard.BorderBrush = & $brush $color.Health
    $absenceCard.BorderThickness = [Windows.Thickness]::new(1)
    $absenceCard.Padding = [Windows.Thickness]::new(22)
    $absenceCard.Effect = [Windows.Media.Effects.DropShadowEffect]@{ BlurRadius=30; ShadowDepth=6; Opacity=0.3; Color=[Windows.Media.ColorConverter]::ConvertFromString($color.Shadow) }
    $absenceWindow.Content = $absenceCard
    $absenceStack = [Windows.Controls.StackPanel]::new()
    $absenceCard.Child = $absenceStack
    $absenceEyebrow = & $newPanelText '一封留在桌面的信' 10.5 'SemiBold' 'danger'
    $absenceTitle = & $newPanelText '雪王离开了' 18 'SemiBold' 'ink'
    $absenceTitle.Margin = [Windows.Thickness]::new(0,7,0,0)
    $absenceBody = & $newPanelText '' 12 'Normal' 'muted'
    $absenceBody.TextWrapping = [Windows.TextWrapping]::Wrap
    $absenceBody.LineHeight = 20
    $absenceBody.Margin = [Windows.Thickness]::new(0,9,0,14)
    $absenceStack.Children.Add($absenceEyebrow) | Out-Null
    $absenceStack.Children.Add($absenceTitle) | Out-Null
    $absenceStack.Children.Add($absenceBody) | Out-Null
    $absenceStack.Children.Add((& $newActionTile '迎接一只新雪王' '旧关系保留在备份，新伙伴重新开始' {
        $script:affection = 35
        $script:fullness = 65
        $script:energy = 70
        $script:health = 100
        $script:craving = 68
        $script:grievance = 0
        $script:petStatus = 'home'
        $script:departureReason = ''
        $script:departedAt = $null
        $script:ignoredNudges = 0
        $script:feedRefusals = 0
        $script:lowHungerTicks = 0
        $script:starvationTicks = 0
        $script:recoveryTicks = 0
        $script:teaseStreak = 0
        $script:lastTeaseAt = [datetime]::MinValue
        $script:teaseCooldownUntil = [datetime]::MinValue
        $script:bodyReactionCount = 0
        $script:regionTapCounts = @{}
        $script:regionLastTap = @{}
        $script:regionCooldownUntil = @{}
        $script:lastRegion = ''
        $script:lastRegionAt = [datetime]::MinValue
        $script:lastInteractionKind = ''
        $script:comboReactionCount = 0
        $script:longPressCount = 0
        $script:recentEvents.Clear()
        $script:recentEvents.Add("$(Get-Date -Format 'HH:mm') · 重新建档 · 新雪王抵达冰宫")
        $script:lastInteraction = Get-Date
        $script:lastBondDecay = Get-Date
        $script:lastBondEvent = '新的相遇，正在建立新的关系'
        $script:statusHandled = $false
        & $saveState
        $absenceWindow.Hide()
        $window.Show()
        & $placeAtHome
        & $enterActivityPhase 'quiet'
        & $holdState 'idle'
        $moodTimer.Start(); $ambientTimer.Start(); $needsTimer.Start()
        & $scheduleNextNudge 40 76
        & $showFeedback '新的开始' '这是一位新来的雪王，请慢慢重新建立信任。' 'positive' 0 0 0 4200 -ShowCurrent
    } 'primary' 56)) | Out-Null
    $absenceStack.Children.Add((& $newActionTile '保留记录并关闭' '' { $window.Close() } 'neutral' 40)) | Out-Null

    $showAbsence = {
        $script:statusHandled = $true
        $script:followMode = $false
        $script:returnHomeMode = $false
        $animationTimer.Stop(); $ambientTimer.Stop(); $ambientStepTimer.Stop(); $reactionTimer.Stop(); $moodTimer.Stop(); $needsTimer.Stop(); $followTimer.Stop(); $chaseTimer.Stop(); $returnTimer.Stop()
        $controlWindow.Hide(); $feedbackWindow.Hide(); $window.Hide()
        if ($script:petStatus -eq 'deceased') {
            $absenceEyebrow.Text = '生命已经走到终点'
            $absenceTitle.Text = '这只雪王不会再回来了'
            $absenceBody.Text = "原因：$($script:departureReason)。`n她的生命值已经归零；迎接新伙伴会建立一段新的关系。"
        } else {
            $absenceEyebrow.Text = '关系已经耗尽'
            $absenceTitle.Text = '雪王离开了桌面'
            $absenceBody.Text = "原因：$($script:departureReason)。`n亲密度降到离家阈值后，它选择去别处生活。"
        }
        if (-not $absenceWindow.IsVisible) { $absenceWindow.Show(); $absenceWindow.UpdateLayout() }
        $area = & $getCursorWorkAreaDip
        $absenceWindow.Left = $area.Left + (($area.Width - $absenceWindow.ActualWidth) / 2)
        $absenceWindow.Top = $area.Top + (($area.Height - $absenceWindow.ActualHeight) / 2)
    }

    $statusTimer = [Windows.Threading.DispatcherTimer]::new()
    $statusTimer.Interval = [TimeSpan]::FromSeconds(1)
    $statusTimer.Add_Tick({ if($script:petStatus -ne 'home' -and -not $script:statusHandled){ & $showAbsence } })

    $petImage.Add_MouseEnter({
        $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds([double]$tokens.component.'motion-fast-ms'))
        $petScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, [Windows.Media.Animation.DoubleAnimation]::new($petScale.ScaleX, 1.025, $duration))
        $petScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, [Windows.Media.Animation.DoubleAnimation]::new($petScale.ScaleY, 1.025, $duration))
    })
    $petImage.Add_MouseLeave({
        $duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds([double]$tokens.component.'motion-fast-ms'))
        $petScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, [Windows.Media.Animation.DoubleAnimation]::new($petScale.ScaleX, 1, $duration))
        $petScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, [Windows.Media.Animation.DoubleAnimation]::new($petScale.ScaleY, 1, $duration))
        $hitGlow.Opacity = 0
    })
    $petImage.Add_MouseRightButtonUp({
        param($sender,$eventArgs)
        & $toggleControlPanel
        $eventArgs.Handled = $true
    })
    $petImage.Add_MouseLeftButtonDown({
        param($sender, $eventArgs)
        $ctrlDown = (([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0)
        if ($eventArgs.ClickCount -ge 2 -and $ctrlDown) {
            $script:suppressNextClick = $true
            & $markInteraction
            & $showBriefState 'waving' 1200
            & $showFeedback '一起去聊天' 'Ctrl + 双击保留为打开 Codex；普通快速连点会继续触发身体互动。' 'positive' 0 0 0 2400
            & $openCodex
            $eventArgs.Handled = $true
            return
        }
        $script:dragging = $true
        $script:dragMoved = $false
        $script:dragOffset = $eventArgs.GetPosition($window)
        $script:dragStartedAt = Get-Date
        $script:dragOriginLeft = $window.Left
        $script:dragOriginTop = $window.Top
        [void]$petImage.CaptureMouse()
    })
    $petImage.Add_MouseMove({
        param($sender, $eventArgs)
        if (-not $script:dragging -or $eventArgs.LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) {
            $point = $eventArgs.GetPosition($petImage)
            [Windows.Controls.Canvas]::SetLeft($hitGlow, [Math]::Max(0,$point.X-11))
            [Windows.Controls.Canvas]::SetTop($hitGlow, [Math]::Max(0,$point.Y-8))
            $hitGlow.Opacity = .82
            return
        }
        $hitGlow.Opacity = 0
        $cursor = & $screenToDip ([Windows.Forms.Cursor]::Position)
        if ([Math]::Abs(($cursor.X - $script:dragOffset.X) - $window.Left) -gt 2 -or [Math]::Abs(($cursor.Y - $script:dragOffset.Y) - $window.Top) -gt 2) { $script:dragMoved = $true }
        $area = & $getCursorWorkAreaDip
        $window.Left = [Math]::Min([Math]::Max($cursor.X - $script:dragOffset.X, $area.Left), $area.Right - $window.Width)
        $window.Top = [Math]::Min([Math]::Max($cursor.Y - $script:dragOffset.Y, $area.Top), $area.Bottom - $window.Height)
        if ($script:dragMoved) { & $playState 'running' }
    })
    $petImage.Add_MouseLeftButtonUp({
        param($sender, $eventArgs)
        $petImage.ReleaseMouseCapture()
        if ($script:suppressNextClick) { $script:suppressNextClick = $false; $script:dragging = $false; return }
        $wasMoved = $script:dragMoved
        $script:dragging = $false
        if ($wasMoved) {
            & $markInteraction
            $script:interactionCount++
            $dragSeconds = ((Get-Date) - $script:dragStartedAt).TotalSeconds
            $dragDistance = [Math]::Sqrt((($window.Left-$script:dragOriginLeft)*($window.Left-$script:dragOriginLeft))+(($window.Top-$script:dragOriginTop)*($window.Top-$script:dragOriginTop)))
            if ($dragSeconds -lt 1.4 -and $dragDistance -gt 120) {
                $script:lastBondEvent = '被快速甩出一条冰道，关系不变'
                & $startReactionSequence @(& $newReactionStep 'snowball-slide' 850 '❄' 'energy'; & $newReactionStep 'foot-slip' 600; & $newReactionStep 'pancake-fall' 800; & $newReactionStep 'smug' 600)
                & $addEventLog '拖动' '高速滑行后假装帅气着陆'
                & $showFeedback '桌面冰道滑行' '披风在身后拉成一条红线，急刹失败摊成雪饼，然后立刻装高冷。' 'energy' 0 0 -1 3700
            } elseif ($dragSeconds -gt 4) {
                $script:affection = [Math]::Max(0, $script:affection - 1)
                $script:lastBondEvent = '被长时间拎着不舒服，关系 -1'
                & $startReactionSequence @(& $newReactionStep 'cape-pull' 650; & $newReactionStep 'bullied' 850; & $newReactionStep 'sulk-cocoon' 750)
                & $addEventLog '拖动' '被拎太久后缩进披风'
                & $showFeedback '想回到地面' '被拎得有点久，我扭开身体想落地。' 'boundary' -1 0 0 3400
            } else {
                $script:lastBondEvent = '短暂移动位置，关系不变'
                & $startReactionSequence @(& $newReactionStep 'waiting' 650; & $newReactionStep 'waving' 600)
                & $addEventLog '拖动' '换到新位置后站稳回头'
                & $showFeedback '换了个舒服的位置' '站稳后回头看看你，关系不变。' 'neutral' 0 0 0 2200
            }
            & $saveState
        } else {
            $point = $eventArgs.GetPosition($petImage)
            $region = & $resolveHitRegion $point $petImage.ActualWidth $petImage.ActualHeight
            $wasSleeping = ($script:activityPhase -eq 'sleep' -or $script:currentState -eq 'sleeping')
            $heldSeconds = ((Get-Date) - $script:dragStartedAt).TotalSeconds
            if ($wasSleeping) {
                & $invokeRegionInteraction $region -FromSleep
            } elseif ($heldSeconds -ge .85) {
                & $invokeRegionInteraction $region -LongPress
            } else {
                & $invokeRegionInteraction $region
            }
            & $updateControlPanel
        }
    })

    $window.Add_Loaded({
        & $placeAtHome
        if ($PersistenceProbe) {
            $probeRecovered = [bool]$script:stateRecoveredFromBackup
            $script:petStatus = 'home'
            $script:departureReason = ''
            $script:departedAt = $null
            $script:affection = 61
            $script:fullness = 62
            $script:energy = 63
            $script:health = 64
            $script:craving = 65
            $script:grievance = 6
            $script:lastInteraction = Get-Date
            $script:lastBondDecay = Get-Date
            foreach ($slot in $artifactSlots) {
                $match = @($artifactItems | Where-Object { $_.Set -eq 'evergreen' -and $_.Slot -eq $slot.Id })[0]
                $artifactUiState.Equipped[[string]$slot.Id] = [string]$match.Id
            }
            $artifactUiState.Equipped['plume'] = ''
            $artifactUiState.ShakeBuffUntil = [datetime]::MinValue
            & $rebuildArtifactEffects
            & $saveState
            $probeSaved = Get-Content -Raw -LiteralPath $statePath -Encoding UTF8 | ConvertFrom-Json
            $probeOk = (
                [int]$probeSaved.affection -eq 61 -and [int]$probeSaved.fullness -eq 62 -and
                [string]$probeSaved.artifacts.equipped.plume -eq '' -and
                [int]$probeSaved.artifacts.version -eq 1 -and
                -not (Test-Path -LiteralPath "$statePath.tmp")
            )
            $probeEmptySlot = ([string]$probeSaved.artifacts.equipped.plume -eq '')
            $probeAtomic = -not (Test-Path -LiteralPath "$statePath.tmp")
            $probeBackupValid = $false
            if (Test-Path -LiteralPath "$statePath.bak") {
                try { $null = Get-Content -Raw -LiteralPath "$statePath.bak" -Encoding UTF8 | ConvertFrom-Json; $probeBackupValid = $true } catch {}
            }
            $script:persistenceProbeResult = "PERSISTENCE_PROBE_OK write=$probeOk emptySlot=$probeEmptySlot atomic=$probeAtomic recovered=$probeRecovered backupValid=$probeBackupValid"
            $window.Close()
            return
        }
        $statusTimer.Start()
        if ($script:petStatus -ne 'home') {
            & $showAbsence
            return
        }
        $initialPhase = & $selectInitialPhase
        & $enterActivityPhase $initialPhase
        switch ($initialPhase) {
            'sleep'  { & $holdState 'sleeping' }
            'active' { & $holdState 'waiting' }
            default  { & $holdState 'idle' }
        }
        $moodTimer.Start()
        $ambientTimer.Start()
        $needsTimer.Start()
        if (-not $SelfTest) {
            # 同步注册表中的开机自启状态
            $script:autoStartEnabled = & $isAutoStartEnabled
            $autoStartTrayItem.Checked = $script:autoStartEnabled
            & $scheduleNextNudge 40 76
            & $saveState
            if ($OpenPanel) {
                if ($OpenArtifacts) { & $setPanelPage 'artifact' }
                elseif ($OpenInteraction) { & $setPanelPage 'interaction' }
                & $showControlPanel
            }
            if (-not $script:welcomeSeen) {
                $script:welcomeSeen = $true
                if ($script:interactionCount -eq 0) {
                    & $showFeedback '欢迎来到雪王陪伴屋' '点她会回应，长按藏着小剧情；右键或双击托盘图标可以随时打开陪伴屋。' 'positive' 0 0 0 5600
                }
                & $saveState
            }
        }
    })
    $window.Add_Closed({
        $animationTimer.Stop()
        $feedbackTimer.Stop()
        $returnTimer.Stop()
        $moodTimer.Stop()
        $ambientTimer.Stop()
        $ambientStepTimer.Stop()
        $reactionTimer.Stop()
        $needsTimer.Stop()
        $chaseTimer.Stop()
        $followTimer.Stop()
        $statusTimer.Stop()
        & $saveState
        if ($null -ne $notifyIcon) { $notifyIcon.Visible = $false; $notifyIcon.Dispose() }
        if ($null -ne $trayContextMenu) { $trayContextMenu.Dispose() }
        if ($null -ne $trayIcon) { $trayIcon.Dispose() }
        $feedbackWindow.Close()
        $controlWindow.Close()
        $absenceWindow.Close()
    })

    if ($SelfTest) {
        $testTimer = [Windows.Threading.DispatcherTimer]::new()
        $testTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
        $testTimer.Add_Tick({
            $testTimer.Stop()
            $naturalStartOk = switch ($script:activityPhase) {
                'sleep' { $script:currentState -eq 'sleeping' }
                'active' { $script:currentState -eq 'waiting' }
                'quiet' { $script:currentState -eq 'idle' }
                default { $false }
            }
            $staticRestOk = (-not $animationTimer.IsEnabled)
            $hqFramesOk = ($script:frames.Count -eq 52 -and $script:frames['sleeping'].Count -eq 2 -and $script:frames['failed'].Count -ge 8 -and $script:frames['doro-crawl'].Count -ge 6 -and $script:frames['pancake-fall'].Count -ge 5)
            $expressionStates = @(
                'hungry','bullied','angry','smug','stuffed','shy','dizzy','pout','crown-tap','cheek-poke','ear-touch','belly-poke','wand-touch','cape-pull','foot-tickle','wake-startle',
                'doro-crawl','food-sneak','guard-pounce','cape-burrito','nightmare-hide','sulk-cocoon','pancake-fall','foot-slip','belly-flop','ice-spell','queen-decree','wand-backfire',
                'snack-struggle','snack-cry','bag-bite','crown-drop','crown-chase','snowball-play','snowball-slide','cheek-squish','cheek-boing','feast-guard','midnight-feast','last-bite'
            )
            $expressionStatesOk = (@($expressionStates | Where-Object { -not $script:frames.ContainsKey($_) }).Count -eq 0)
            $modernFeedbackOk = ($feedbackCard.CornerRadius.TopLeft -ge 14 -and $feedbackCard.Effect.BlurRadius -ge 18)
            $modernPanelOk = ($controlCard.CornerRadius.TopLeft -ge 24 -and $controlCard.Width -ge 420 -and $statWidgets.Count -eq 6 -and $quickCareGrid.Children.Count -eq 3 -and $actionGrid.Children.Count -eq 8 -and $interactionRegionGrid.Children.Count -eq 9 -and $controlGrid.Children.Count -eq 3 -and $tabGrid.Children.Count -eq 4 -and $settingsPage.Children.Count -ge 5 -and $panelPortrait -ne $null -and $eventTextBlocks.Count -eq 3 -and $archiveTab.Focusable -and [Windows.Automation.AutomationProperties]::GetName($archiveTab) -match '近况' -and $null -eq $petImage.ContextMenu)
            $soundSystemOk = $true
            foreach ($kind in @('click','pet','feed','happy','sad','sleep','wake','error','success')) {
                if ((& $getPetSound $kind) -isnot [System.Media.SystemSound]) { $soundSystemOk = $false }
            }
            $initialSoundEnabled = $script:soundEnabled
            $soundTrayItem.PerformClick()
            $traySoundOk = ($script:soundEnabled -ne $initialSoundEnabled -and $soundTrayItem.Checked -eq $script:soundEnabled -and ($settingsSoundTile.Tag.Text.StartsWith('✓')) -eq $script:soundEnabled)
            $soundClick = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 0, [Windows.Input.MouseButton]::Left)
            $soundClick.RoutedEvent = [Windows.UIElement]::MouseLeftButtonUpEvent
            $settingsSoundTile.RaiseEvent($soundClick)
            $traySoundOk = ($traySoundOk -and $script:soundEnabled -eq $initialSoundEnabled -and $soundTrayItem.Checked -eq $initialSoundEnabled)
            $cleanHoverHintOk = ($null -eq $petImage.ToolTip)
            $initialPanelHidden = (-not $controlWindow.IsVisible)
            $script:followMode = $false
            & $toggleControlPanel 'artifact'
            $manualOpenOk = ($controlWindow.IsVisible -and $artifactPage.Visibility -eq [Windows.Visibility]::Visible)
            & $showFeedback '测试回执' '面板打开时语言应进入固定回执卡。' 'neutral' 0 0 0 800
            $inlineFeedbackOk = ($panelFeedbackHost.Visibility -eq [Windows.Visibility]::Visible -and -not $feedbackWindow.IsVisible -and $script:feedbackPresentation -eq 'inline')
            & $toggleControlPanel
            $manualCloseOk = (-not $controlWindow.IsVisible)
            $floatingFeedbackOk = ($feedbackWindow.IsVisible -and $script:feedbackPresentation -eq 'floating')
            $manualPanelOk = ($initialPanelHidden -and $manualOpenOk -and $manualCloseOk)
            $panelFeedbackOk = ($inlineFeedbackOk -and $floatingFeedbackOk)
            $feedbackTimer.Stop(); $feedbackWindow.Hide(); $panelFeedbackHost.Visibility=[Windows.Visibility]::Collapsed
            $allAmbientNames = @($ambientRoutineNames) + @($sleepRoutineNames)
            $ambientPlansOk = ($allAmbientNames.Count -eq 53 -and @($allAmbientNames | Select-Object -Unique).Count -eq 53 -and $quietRoutineNames.Count -eq 24 -and $activeRoutineNames.Count -eq 24 -and $sleepRoutineNames.Count -eq 5)
            $naturalScheduleOk = ($ambientTimer.Interval.TotalSeconds -eq 5 -and $script:activityPhaseEndsAt -gt (Get-Date).AddMinutes(1) -and $script:nextAmbientAt -gt (Get-Date).AddSeconds(20))
            foreach ($routineName in $allAmbientNames) {
                $plan = @(& $makeAmbientPlan $routineName)
                if ($plan.Count -lt 2) { $ambientPlansOk = $false; break }
                foreach ($planStep in $plan) {
                    if (-not $script:frames.ContainsKey([string]$planStep.State)) { $ambientPlansOk = $false; break }
                }
            }
            $script:lastInteraction = Get-Date
            $script:lastBondDecay = Get-Date
            $script:petStatus = 'home'
            $script:fullness = 60
            $script:affection = 60
            $script:followMode = $false
            $script:activityPhase = 'quiet'
            $script:currentState = 'idle'
            $script:energy = 70
            & $applyNeedsTick
            $quietRecoveryOk = ($script:energy -eq 71)
            $script:currentState = 'sleeping'
            $script:energy = 70
            & $applyNeedsTick
            $sleepRecoveryOk = ($script:energy -eq 72)
            $staminaRecoveryOk = ($quietRecoveryOk -and $sleepRecoveryOk)

            $artifactCatalogOk = (
                $artifactSlots.Count -eq 5 -and $artifactItems.Count -eq 15 -and $artifactSets.Count -eq 3 -and
                @($artifactItems.Id | Select-Object -Unique).Count -eq 15 -and
                @($artifactSlots | Where-Object { @($artifactItems | Where-Object Slot -eq $_.Id).Count -ne 3 }).Count -eq 0 -and
                @($artifactSets.Keys | Where-Object { @($artifactItems | Where-Object Set -eq $_).Count -ne 5 }).Count -eq 0
            )
            $artifactDiskLoadOk = if ([string]::IsNullOrWhiteSpace($StatePathOverride)) { $true } else { [string]$script:artifactLoadSnapshot.Plume -eq '' }
            $stateBackupRecoveryOk = if ([string]::IsNullOrWhiteSpace($StatePathOverride)) { $true } else { [bool]$script:stateRecoveredFromBackup }
            $stateTransactionalLoadOk = if ([string]::IsNullOrWhiteSpace($StatePathOverride)) { $true } else { [int]$script:stateLoadSnapshot.Affection -eq 61 -and [int]$script:stateLoadSnapshot.Fullness -eq 62 -and [int]$script:stateLoadSnapshot.Health -eq 64 }
            $raiseArtifactTileClick = {
                param([Windows.UIElement]$Element)
                $mouseUp = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, [Environment]::TickCount, [Windows.Input.MouseButton]::Left)
                $mouseUp.RoutedEvent = [Windows.UIElement]::MouseLeftButtonUpEvent
                $Element.RaiseEvent($mouseUp)
            }
            & $raiseArtifactTileClick $artifactSlotTiles['plume']
            $artifactSlotSelectionOk = ($artifactUiState.SelectedSlot -eq 'plume' -and $artifactChoiceTitle.Text -match '赤羽之翎')
            $nightPlumeTile = @($artifactChoiceGrid.Children | Where-Object { [string]$_.Uid -eq 'night-plume' })[0]
            & $raiseArtifactTileClick $nightPlumeTile
            $artifactSingleEquipOk = ([string]$artifactUiState.Equipped['plume'] -eq 'night-plume')
            & $raiseArtifactTileClick $artifactUnequipTile
            $artifactUnequipOk = ([string]$artifactUiState.Equipped['plume'] -eq '')
            & $raiseArtifactTileClick $artifactSlotTiles['flower']
            $artifactUiOk = ($artifactSlotGrid.Children.Count -eq 5 -and $artifactChoiceGrid.Children.Count -eq 3 -and $artifactSetQuickGrid.Children.Count -eq 3 -and $artifactSetSummaryGrid.Children.Count -eq 3 -and $tabGrid.Children.Count -eq 4 -and $artifactSlotSelectionOk -and $artifactSingleEquipOk -and $artifactUnequipOk)

            foreach($slot in $artifactSlots) {
                $match = @($artifactItems | Where-Object { $_.Set -eq 'evergreen' -and $_.Slot -eq $slot.Id })[0]
                $artifactUiState.Equipped[[string]$slot.Id] = [string]$match.Id
            }
            & $rebuildArtifactEffects
            $artifactReducerOk = ([int]$artifactUiState.SetCounts['evergreen'] -eq 5 -and [bool]$artifactUiState.Effects['Evergreen4'] -and [int]$artifactUiState.Effects['FeedFullnessBonus'] -eq 4 -and [int]$artifactUiState.Effects['FeedCravingRelief'] -eq 9)
            $artifactUiState.Cooldowns['sweetCare'] = [datetime]::MinValue
            $artifactUiState.Cooldowns['midnightFeast'] = [datetime]::MinValue
            $script:grievance = 0
            $zeroSweetCareRelief = & $applyArtifactSweetCare
            $sweetCareZeroOk = ($zeroSweetCareRelief -eq 0 -and $artifactUiState.Cooldowns['sweetCare'] -eq [datetime]::MinValue)
            $script:affection=50; $script:fullness=50; $script:energy=50; $script:health=50; $script:craving=90; $script:grievance=20
            & $invokeFeed
            $artifactFeedOk = ($script:fullness -eq 66 -and $script:craving -eq 41 -and $script:health -eq 52 -and $script:affection -eq 54 -and $script:grievance -eq 0)

            foreach($slot in $artifactSlots) {
                $match = @($artifactItems | Where-Object { $_.Set -eq 'shake' -and $_.Slot -eq $slot.Id })[0]
                $artifactUiState.Equipped[[string]$slot.Id] = [string]$match.Id
            }
            & $rebuildArtifactEffects
            $artifactUiState.Cooldowns['shakeBuff'] = [datetime]::MinValue
            $artifactUiState.ShakeBuffUntil = [datetime]::MinValue
            $script:affection=50; $script:energy=50; $script:grievance=20
            $dismantlePlayResult = & $applyArtifactPlay 5 3
            $artifactUiState.Equipped['plume'] = ''
            $artifactUiState.Equipped['flower'] = ''
            & $rebuildArtifactEffects
            $dismantleComboResult = & $applyArtifactCombo
            $shakeDismantleOk = (
                $dismantlePlayResult.ShakeStarted -and $artifactUiState.ShakeBuffUntil -eq [datetime]::MinValue -and
                -not $dismantleComboResult.ConsumedShake -and $dismantleComboResult.EnergyDelta -eq 0 -and $dismantleComboResult.AffectionDelta -eq 0
            )
            $shakePlume = @($artifactItems | Where-Object { $_.Set -eq 'shake' -and $_.Slot -eq 'plume' })[0]
            $shakeFlower = @($artifactItems | Where-Object { $_.Set -eq 'shake' -and $_.Slot -eq 'flower' })[0]
            $artifactUiState.Equipped['plume'] = [string]$shakePlume.Id
            $artifactUiState.Equipped['flower'] = [string]$shakeFlower.Id
            & $rebuildArtifactEffects
            $artifactUiState.Cooldowns['shakeBuff'] = [datetime]::MinValue
            $artifactUiState.ShakeBuffUntil = [datetime]::MinValue
            $script:affection=50; $script:energy=50; $script:grievance=20
            $shakePlayResult = & $applyArtifactPlay 5 3
            $shakeComboResult = & $applyArtifactCombo
            $artifactShakeOk = ($shakeDismantleOk -and $shakePlayResult.EnergyDelta -eq -1 -and $shakePlayResult.AffectionDelta -eq 5 -and $shakePlayResult.ShakeStarted -and $shakeComboResult.EnergyDelta -eq 2 -and $shakeComboResult.AffectionDelta -eq 1 -and $shakeComboResult.ConsumedShake)

            foreach($slot in $artifactSlots) {
                $match = @($artifactItems | Where-Object { $_.Set -eq 'polar-night' -and $_.Slot -eq $slot.Id })[0]
                $artifactUiState.Equipped[[string]$slot.Id] = [string]$match.Id
            }
            & $rebuildArtifactEffects
            $script:grievance=50
            & $invokeCapeComfort
            $artifactNightOk = ($script:grievance -eq 24 -and [int]$artifactUiState.Effects['LongPressGrievanceRelief'] -eq 4 -and [int]$artifactUiState.Effects['ComboGrievanceRelief'] -eq 7)
            $artifactUiState.Equipped['plume'] = ''
            $artifactUiState.ShakeBuffUntil = (Get-Date).AddSeconds(10)
            $artifactRoundTrip = [ordered]@{ artifacts=[ordered]@{ version=1; equipped=$artifactUiState.Equipped; cooldowns=[ordered]@{sweetCare=$artifactUiState.Cooldowns['sweetCare'].ToString('o')}; shakeBuffUntil=$artifactUiState.ShakeBuffUntil.ToString('o') } } | ConvertTo-Json -Depth 7 | ConvertFrom-Json
            $artifactPersistenceOk = ([string]$artifactRoundTrip.artifacts.equipped.flower -eq [string]$artifactUiState.Equipped['flower'] -and [string]$artifactRoundTrip.artifacts.equipped.plume -eq '' -and [datetime]$artifactRoundTrip.artifacts.shakeBuffUntil -gt (Get-Date) -and [int]$artifactRoundTrip.artifacts.version -eq 1 -and $artifactDiskLoadOk -and $stateBackupRecoveryOk -and $stateTransactionalLoadOk)
            $artifactSystemOk = ($artifactCatalogOk -and $artifactReducerOk -and $artifactFeedOk -and $artifactShakeOk -and $artifactNightOk -and $artifactPersistenceOk -and $sweetCareZeroOk)

            foreach($slot in $artifactSlots) { $artifactUiState.Equipped[[string]$slot.Id] = '' }
            & $rebuildArtifactEffects
            $artifactUiState.ShakeBuffUntil = [datetime]::MinValue
            foreach($cooldownId in @('sweetCare','shakeBuff','longPressAffinity','midnightFeast')) { $artifactUiState.Cooldowns[$cooldownId] = [datetime]::MinValue }
            $script:affection = 40
            $script:fullness = 50
            $script:energy = 70
            $script:craving = 50
            $script:grievance = 0
            $script:interactionCount = 0
            $script:feedRefusals = 0
            $script:petStreak = 0
            $script:lastPetAt = [datetime]::MinValue
            $script:petCooldownUntil = [datetime]::MinValue
            $startAffection = $script:affection
            $startFullness = $script:fullness
            $startEnergy = $script:energy
            & $invokePetHead
            & $invokeFeed
            & $invokeBodyPlay
            $baseInteractions = $script:interactionCount
            $interactionOk = ($baseInteractions -eq 3 -and $script:affection -eq ($startAffection + 10) -and $script:fullness -eq ($startFullness + 12) -and $script:energy -eq ($startEnergy - 3))
            $script:petStreak = 3
            $script:lastPetAt = Get-Date
            $script:petCooldownUntil = [datetime]::MinValue
            $beforeBoundary = $script:affection
            & $invokePetHead
            $boundaryOk = ($script:affection -eq ($beforeBoundary - 1))
            $script:fullness = 50
            $script:craving = 90
            $script:grievance = 20
            $beforeGreedFullness = $script:fullness
            $beforeGreedCraving = $script:craving
            $beforeGreedGrievance = $script:grievance
            & $invokeFeed
            $greedSystemOk = ($script:fullness -eq ($beforeGreedFullness + 12) -and $script:craving -lt $beforeGreedCraving -and $script:grievance -lt $beforeGreedGrievance)

            $script:affection = 60
            $script:grievance = 0
            $script:teaseStreak = 0
            $script:lastTeaseAt = [datetime]::MinValue
            $script:teaseCooldownUntil = [datetime]::MinValue
            $script:bodyReactionCount = 0
            $script:regionTapCounts = @{}
            $script:regionLastTap = @{}
            $script:regionCooldownUntil = @{}
            $script:lastRegion = ''
            $script:lastRegionAt = [datetime]::MinValue
            $beforeGentleAffection = $script:affection
            & $invokeRegionInteraction 'crown'
            $crownState = $script:currentState
            $gentleTouchOk = ($script:grievance -eq 0 -and $script:affection -eq $beforeGentleAffection -and $crownState -eq 'crown-tap')
            $script:craving = 45
            $script:fullness = 55
            & $invokeRegionInteraction 'belly'
            $bellyState = $script:currentState
            $regionSpecificOk = ($crownState -eq 'crown-tap' -and $bellyState -eq 'belly-poke' -and $script:lastBondEvent -match '肚皮')

            $script:regionTapCounts = @{}
            $script:regionLastTap = @{}
            $script:regionCooldownUntil = @{}
            $script:lastRegion = ''
            $script:lastRegionAt = [datetime]::MinValue
            $script:grievance = 0
            $script:affection = 60
            $beforeBullyAffection = $script:affection
            for($i=0;$i -lt 5;$i++) { & $invokeRegionInteraction 'left-cheek' }
            $bullySystemOk = ($script:affection -eq ($beforeBullyAffection - 1) -and $script:grievance -ge 20 -and [int]$script:regionTapCounts['left-cheek'] -eq 5 -and $script:currentState -eq 'cheek-squish')

            $resolvedRegions = @(
                & $resolveHitRegion ([Windows.Point]::new(50,10)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(22,25)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(80,25)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(35,40)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(65,40)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(50,65)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(10,50)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(85,65)) 100 100
                & $resolveHitRegion ([Windows.Point]::new(50,90)) 100 100
            )
            $hitRegionsOk = ($bodyHitRegions.Count -eq 9 -and @($bodyHitRegions | Select-Object -Unique).Count -eq 9 -and @($resolvedRegions | Select-Object -Unique).Count -eq 9 -and @($bodyHitRegions | Where-Object { $_ -notin $resolvedRegions }).Count -eq 0)

            $script:lastRegion = ''
            $script:lastRegionAt = [datetime]::MinValue
            & $invokeRegionInteraction 'foot' -FromSleep
            $sleepRegionOk = ($script:lastBondEvent -match '梦中踢腿' -and @($script:reactionSteps | Where-Object { $_.State -eq 'foot-tickle' }).Count -eq 1)
            $script:longPressCount = 0
            $script:grievance = 20
            & $invokeRegionInteraction 'belly' -LongPress
            $longPressOk = ($script:longPressCount -eq 1 -and $script:lastBondEvent -match '揉肚皮放松' -and $script:grievance -lt 20)
            $script:comboReactionCount = 0
            $script:lastRegion = 'crown'
            $script:lastRegionAt = Get-Date
            & $invokeRegionInteraction 'wand'
            $comboSystemOk = ($script:comboReactionCount -eq 1 -and $script:lastBondEvent -match '王冠×权杖组合' -and @($script:reactionSteps | Where-Object { $_.State -eq 'queen-decree' }).Count -eq 1)
            $script:lastInteraction = (Get-Date).AddHours(-14)
            $script:lastBondDecay = (Get-Date).AddHours(-7)
            $script:currentState = 'sleeping'
            $beforeNeglect = $script:affection
            & $applyNeedsTick
            $neglectOk = ($script:affection -eq ($beforeNeglect - 1))
            $affectionCanDecrease = ($boundaryOk -and $bullySystemOk -and $neglectOk)

            $script:lastInteraction = Get-Date
            $script:lastBondDecay = Get-Date
            $script:petStatus = 'home'
            $script:affection = 40
            $script:fullness = 11
            $script:lowHungerTicks = 1
            $script:health = 20
            $script:starvationTicks = 0
            & $applyNeedsTick
            $slowHungerOk = ($script:fullness -eq 10 -and $script:health -eq 20)
            $script:fullness = 0
            $script:starvationTicks = 5
            $beforeStarvationHealth = $script:health
            & $applyNeedsTick
            $starvationDamageOk = ($script:health -eq ($beforeStarvationHealth - 1))
            $lifeSystemOk = ($slowHungerOk -and $starvationDamageOk)

            $script:petStatus = 'home'
            $script:health = 50
            $script:affection = 5
            & $saveState
            $departureReachable = ($script:petStatus -eq 'departed')

            $script:petStatus = 'home'
            $script:departureReason = ''
            $script:departedAt = $null
            $script:health = 50
            $script:affection = 40
            $script:fullness = 50
            $script:energy = 50
            & $startFollowing
            $followStartedOk = ($script:followMode -and $followTimer.IsEnabled)
            & $stopFollowing -Silent
            $followStoppedOk = (-not $script:followMode -and $script:returnHomeMode)
            $followModeOk = ($followStartedOk -and $followStoppedOk)
            $script:returnHomeMode = $false
            $followTimer.Stop()
            $nudgeWindowOk = ($script:nextNudgeAt -gt (Get-Date).AddMinutes(39))
            $persistenceOk = $statePath.EndsWith('state.json')
            $script:selfTestResult = "SELF_TEST_OK renderer=WPF hqFrames=$hqFramesOk expressionStates=$($script:frames.Count) expressionLogic=$expressionStatesOk hitRegions=$($bodyHitRegions.Count) regionSpecific=$regionSpecificOk gentleTouch=$gentleTouchOk sleepRegions=$sleepRegionOk longPress=$longPressOk comboSystem=$comboSystemOk greedSystem=$greedSystemOk bullySystem=$bullySystemOk modernFeedback=$modernFeedbackOk modernPanel=$modernPanelOk manualPanel=$manualPanelOk panelFeedback=$panelFeedbackOk cleanHoverHint=$cleanHoverHintOk settingsPage=$modernPanelOk soundSystem=$soundSystemOk traySound=$traySoundOk artifactSlots=$($artifactSlots.Count) artifactItems=$($artifactItems.Count) artifactSets=$($artifactSets.Count) artifactSystem=$artifactSystemOk artifactUi=$artifactUiOk artifactPersistence=$artifactPersistenceOk artifactDiskLoad=$artifactDiskLoadOk stateBackupRecovery=$stateBackupRecoveryOk stateTransactionalLoad=$stateTransactionalLoadOk sweetCareZero=$sweetCareZeroOk shakeDismantle=$shakeDismantleOk staminaRecovery=$staminaRecoveryOk ambientRoutines=$($allAmbientNames.Count) ambientVariety=$ambientPlansOk naturalSchedule=$naturalScheduleOk naturalStart=$naturalStartOk staticRest=$staticRestOk interactions=$baseInteractions interactionLogic=$interactionOk affectionCanDecrease=$affectionCanDecrease lifeSystem=$lifeSystemOk departureReachable=$departureReachable followMode=$followModeOk nudgeWindow=$nudgeWindowOk persistence=$persistenceOk"
            $exitTrayItem.PerformClick()
            $script:selfTestResult += " trayExit=$(-not $window.IsVisible)"
        })
        $testTimer.Start()
    }

    [void]$app.Run($window)
    if ($SelfTest) { Write-Output $script:selfTestResult }
    if ($PersistenceProbe) { Write-Output $script:persistenceProbeResult }
} catch {
    $errorText = "[$(Get-Date -Format s)]`r`n$($_ | Out-String)"
    $logRoot = if (Get-Variable -Name appDataDir -ErrorAction SilentlyContinue) { $appDataDir } else { [IO.Path]::GetTempPath() }
    try {
        [IO.Directory]::CreateDirectory($logRoot) | Out-Null
        $log = Join-Path $logRoot 'xuewang-modern-error.log'
        [IO.File]::WriteAllText($log, $errorText, [Text.Encoding]::UTF8)
    } catch {
        $log = Join-Path ([IO.Path]::GetTempPath()) 'xuewang-modern-error.log'
        [IO.File]::WriteAllText($log, $errorText, [Text.Encoding]::UTF8)
    }
    if (-not $SelfTest -and -not $PersistenceProbe) { [Windows.MessageBox]::Show("雪王启动失败，详情见：`r`n$log", '雪王现代桌宠') | Out-Null }
    throw
} finally {
    if ($script:createdNew) { try { $script:mutex.ReleaseMutex() } catch {} }
    $script:mutex.Dispose()
}
