;why are you here?
#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2
#WinActivateForce RobloxPlayerBeta.exe

defaultTerrainColors := Map()

resolutionConfigs := Map(
    "1920x1080", {width: 1920, height: 1080, scanLeft: 512, scanTop: 916, scanRight: 1397, scanBottom: 926, reconnectX: 1085, reconnectY: 626, moveDistance: 30},
    "2560x1440", {width: 2560, height: 1440, scanLeft: 682, scanTop: 1214, scanRight: 1862, scanBottom: 1230, reconnectX: 1339, reconnectY: 807, moveDistance: 40},
    "1366x768", {width: 1366, height: 768, scanLeft: 364, scanTop: 651, scanRight: 994, scanBottom: 661, reconnectX: 740, reconnectY: 471, moveDistance: 20}
)

selectedResolution := "1920x1080"
webhookURL := ""
webhookMessageId := ""
macroStartTime := 0
uiNavigationKey := "\"
movementType := "Stable Mode"
donationAmount := "10"
donationLinks := Map(
    "10", "https://www.roblox.com/catalog/13790965350/Donation-10",
    "50", "https://www.roblox.com/catalog/13790067716/Donation-50",
    "100", "https://www.roblox.com/catalog/124883742268645/katze",
    "200", "https://www.roblox.com/catalog/13790059767/Donation-200",
    "500", "https://www.roblox.com/catalog/13790109084/Donation-500"
)

autoReconnectEnabled := false
reconnectColor := 0x232527
alwaysOnTopEnabled := true
darkModeEnabled := false

defaultClickDelay := 5
defaultClickScanRadius := 15
defaultClickCooldown := 200
defaultFollowInterval := 10
defaultSpinDelay := 20
defaultUINavigationKey := "\"

DarkBG := "0x2D2D30"
DarkControl := "0x1E1E1E"
WhiteText := "0xFFFFFF"
LightGrey := "0x404040"

LightBG := "0xF0F0F0"
LightControl := "0xFFFFFF"
BlackText := "0x000000"
DarkGrey := "0x808080"

universalUi(o, e := 0, c := 0) {
    if (!c) {
        SendInput(uiNavigationKey)
        Sleep(200)
    }
    Loop Parse, o {
        if (A_LoopField = "u")
            SendInput("{Up}")
        else if (A_LoopField = "d")
            SendInput("{Down}")
        else if (A_LoopField = "l")
            SendInput("{Left}")
        else if (A_LoopField = "r")
            SendInput("{Right}")
        else if (A_LoopField = "e")
            SendInput("{Enter}")
        else if (A_LoopField = "1")
            Sleep(100)
        else if (A_LoopField = "2")
            Sleep(200)
        else if (A_LoopField = "n") {
            SendInput(uiNavigationKey)
        }
        else if (A_LoopField = "x") {
            SendInput(uiNavigationKey)
            Sleep(50)
            return
        }
        Sleep(50)
    }
    if (e) {
        Sleep(50)
        SendInput(uiNavigationKey)
    }
}

terrainColors := Map()
settingsFile := A_ScriptDir . "\settings.ini"

SendWebhook(message) {
    global webhookURL, webhookMessageId, macroStartTime, successfulCycles, unsuccessfulCycles, recoveryCycleCount
    
    if (webhookURL = "" || Trim(webhookURL) = "")
        return

    timeElapsed := A_TickCount - macroStartTime
    hours := Floor(timeElapsed / 3600000)
    minutes := Floor((timeElapsed - hours * 3600000) / 60000)
    seconds := Floor((timeElapsed - hours * 3600000 - minutes * 60000) / 1000)
    timeString := Format("{:02d}:{:02d}:{:02d}", hours, minutes, seconds)

    totalCycles := successfulCycles + unsuccessfulCycles
    successRate := totalCycles > 0 ? Round((successfulCycles / totalCycles) * 100, 1) : 0

    embedJson := '{"embeds":[{"title":"__Macro Status__","color":5814783,"fields":[{"name":"__Time Elapsed__","value":"' . timeString . '","inline":true},{"name":"__Successful Cycles__","value":"' . successfulCycles . '","inline":true},{"name":"__Unsuccessful Cycles__","value":"' . unsuccessfulCycles . '","inline":true},{"name":"__Success Rate__","value":"' . successRate . '%","inline":true},{"name":"__Total Cycles__","value":"' . recoveryCycleCount . '","inline":true},{"name":"__Status__","value":"' . message . '","inline":true}]}]}'
    
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")

        if (webhookMessageId != "") {
            http.Open("PATCH", webhookURL . "/messages/" . webhookMessageId, false)
        } else {
            http.Open("POST", webhookURL . "?wait=true", false)
        }
        
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(embedJson)

        if (webhookMessageId = "") {
            response := http.ResponseText
            if (RegExMatch(response, '"id":"(\d+)"', &match)) {
                webhookMessageId := match[1]
            }
        }
    } catch {
        webhookMessageId := ""
    }
}

SendSimpleWebhook(message) {
    global webhookURL
    if (webhookURL = "" || Trim(webhookURL) = "")
        return
    
    json := '{"content":"' . message . '"}'
    
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", webhookURL, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(json)
    } catch {

    }
}

CheckAutoReconnect() {
    global autoReconnectEnabled, selectedResolution, resolutionConfigs, reconnectColor, scanning
    global followInterval, recoveryCycleEnabled
    
    if (!autoReconnectEnabled || !scanning) {
        return
    }
    
    config := resolutionConfigs[selectedResolution]
    reconnectX := config.reconnectX
    reconnectY := config.reconnectY
    moveDistance := config.moveDistance
    
    try {
        pixelColor := PixelGetColor(reconnectX, reconnectY)
        
        if (pixelColor = reconnectColor) {
            ToolTip("Disconnect detected! Auto reconnecting...", 10, 190)
            SendSimpleWebhook("Disconnect detected - Auto reconnecting")

            SetTimer(ScanForColor, 0)
            SetTimer(CheckPixelTimeout, 0)

            wasScanning := scanning
            wasRecoveryEnabled := recoveryCycleEnabled

            scanning := false
            recoveryActive := false
            clickLoopActive := false

            startX := reconnectX
            currentX := startX
            clickCount := 0
            maxClicks := 50
            
            Loop maxClicks {
                Click currentX, reconnectY
                currentX += moveDistance
                clickCount++
                Sleep(100)

                newPixelColor := PixelGetColor(reconnectX, reconnectY)
                if (newPixelColor != reconnectColor) {
                    ToolTip("Auto reconnect successful after " . clickCount . " clicks - Starting realignment...", 10, 190)
                    SendSimpleWebhook("Auto reconnect successful after " . clickCount . " clicks - Starting realignment")
                    break
                }
            }

            Sleep 35000

            Loop 18 {
                Send "{WheelUp}"
                Sleep 50
            }

            Sleep 300
            Send "{2}"
            Sleep 300
            Send "{1}"
            Sleep 600
            Click "Left"

            if (wasScanning) {
                scanning := true
                lastPixelFoundTime := A_TickCount

                SetTimer(ScanForColor, followInterval)

                if (wasRecoveryEnabled) {
                    SetTimer(CheckPixelTimeout, 1000)
                }
                
                ToolTip("Auto reconnect and realignment completed", 10, 190)
                SendSimpleWebhook("Auto reconnect and realignment completed")
            } else {
                ToolTip("Auto reconnect and realignment completed - " . maxClicks . " clicks attempted", 10, 190)
                SendSimpleWebhook("Auto reconnect and realignment completed - " . maxClicks . " clicks attempted")
            }
            
            SetTimer(() => ToolTip(), -3000)
        }
    } catch as err {
    }
}

LoadSettings() {
    global settingsFile, clickDelay, clickScanRadius, clickCooldown, followInterval, spinDelay, selectedTerrainIndex
    global recoveryCycleEnabled, terrainColors, defaultTerrainColors, recoveryCycleCount, autoSellEnabled, lastAutoSellCycle
    global webhookURL, uiNavigationKey, lastRecoveryTime, pixelFoundAfterRecovery, successfulCycles, unsuccessfulCycles
    global selectedResolution, movementType, autoReconnectEnabled, donationAmount
    global alwaysOnTopEnabled, darkModeEnabled
    global lastShovelFixCycle

    clickDelay := 5
    clickScanRadius := 15
    clickCooldown := 200
    followInterval := 10
    spinDelay := 20
    selectedTerrainIndex := 1
    recoveryCycleEnabled := false
    recoveryCycleCount := 0
    autoSellEnabled := false
    lastAutoSellCycle := 0
    webhookURL := ""
    uiNavigationKey := "\"
    selectedResolution := "1920x1080"
    movementType := "Stable Mode"
    lastRecoveryTime := 0
    pixelFoundAfterRecovery := false
    successfulCycles := 0
    unsuccessfulCycles := 0
    autoReconnectEnabled := false
    donationAmount := "10"
    alwaysOnTopEnabled := true
    darkModeEnabled := false
    lastShovelFixCycle := 0

    terrainColors := Map()

    if (FileExist(settingsFile)) {
        clickDelay := IniRead(settingsFile, "Settings", "ClickDelay", clickDelay)
        clickScanRadius := IniRead(settingsFile, "Settings", "ScanRadius", clickScanRadius)
        clickCooldown := IniRead(settingsFile, "Settings", "ClickCooldown", clickCooldown)
        followInterval := IniRead(settingsFile, "Settings", "FollowInterval", followInterval)
        spinDelay := IniRead(settingsFile, "Settings", "SpinDelay", spinDelay)
        selectedTerrainIndex := IniRead(settingsFile, "Settings", "SelectedTerrain", selectedTerrainIndex)
        recoveryCycleEnabled := IniRead(settingsFile, "Settings", "RecoveryCycleEnabled", recoveryCycleEnabled)
        recoveryCycleCount := IniRead(settingsFile, "Settings", "RecoveryCycleCount", recoveryCycleCount)
        autoSellEnabled := IniRead(settingsFile, "Settings", "AutoSellEnabled", autoSellEnabled)
        lastAutoSellCycle := IniRead(settingsFile, "Settings", "LastAutoSellCycle", lastAutoSellCycle)
        webhookURL := IniRead(settingsFile, "Settings", "WebhookURL", webhookURL)
        uiNavigationKey := IniRead(settingsFile, "Settings", "UINavigationKey", uiNavigationKey)
        selectedResolution := IniRead(settingsFile, "Settings", "SelectedResolution", selectedResolution)
        movementType := IniRead(settingsFile, "Settings", "MovementType", movementType)
        autoReconnectEnabled := IniRead(settingsFile, "Settings", "AutoReconnectEnabled", autoReconnectEnabled)
        donationAmount := IniRead(settingsFile, "Settings", "DonationAmount", donationAmount)
        alwaysOnTopEnabled := IniRead(settingsFile, "Settings", "AlwaysOnTopEnabled", alwaysOnTopEnabled)
        darkModeEnabled := IniRead(settingsFile, "Settings", "DarkModeEnabled", darkModeEnabled)
        
        LoadAllTerrains()
    }
}

SaveGuiPosition() {
    global settingsFile, MyGui
    try {
        MyGui.GetPos(&guiX, &guiY)
        IniWrite(guiX, settingsFile, "GUI", "X")
        IniWrite(guiY, settingsFile, "GUI", "Y")
    } catch {
    }
}

LoadGuiPosition() {
    global settingsFile
    try {
        guiX := IniRead(settingsFile, "GUI", "X", -1)
        guiY := IniRead(settingsFile, "GUI", "Y", -1)

        if (guiX != -1 && guiY != -1) {
            if (guiX >= 0 && guiY >= 0 && guiX < A_ScreenWidth - 300 && guiY < A_ScreenHeight - 245) {
                return {x: guiX, y: guiY}
            }
        }
    } catch {
    }
    return {x: -1, y: -1}
}

LoadAllTerrains() {
    global settingsFile, terrainColors, defaultTerrainColors
    
    try {
        allTerrainNames := IniRead(settingsFile, "TerrainColors", "AllTerrains", "")
        if (allTerrainNames != "") {
            terrainList := StrSplit(allTerrainNames, "|")
            for terrainName in terrainList {
                if (terrainName != "") {
                    colorsString := IniRead(settingsFile, "TerrainColors", terrainName, "")
                    if (colorsString != "") {
                        if (colorsString = "EMPTY") {
                            terrainColors[terrainName] := []
                        } else {
                            colorStrings := StrSplit(colorsString, ",")
                            colors := []
                            for colorString in colorStrings {
                                if (colorString != "") {
                                    colors.Push(Integer(colorString))
                                }
                            }
                            terrainColors[terrainName] := colors
                        }
                    }
                }
            }
        }
    } catch {
    }
}

SaveSettings() {
    global settingsFile, clickDelay, clickScanRadius, clickCooldown, followInterval, spinDelay, terrainDropdown
    global recoveryCycleEnabled, recoveryCycleCount, autoSellEnabled, lastAutoSellCycle, webhookURL, uiNavigationKey
    global selectedResolution, resolutionDropdown, movementType, movementTypeDropdown
    global autoReconnectEnabled, donationAmount, donationDropdown, alwaysOnTopEnabled, darkModeEnabled
    global lastShovelFixCycle

    currentClickDelay := Integer(clickDelayEdit.Value)
    currentScanRadius := Integer(scanRadiusEdit.Value)
    currentClickCooldown := Integer(clickCooldownEdit.Value)
    currentFollowInterval := Integer(followIntervalEdit.Value)
    currentSpinDelay := Integer(spinDelayEdit.Value)
    currentSelectedTerrain := terrainDropdown.Value
    currentSelectedResolution := resolutionDropdown.Text
    currentMovementType := movementTypeDropdown.Text
    currentDonationAmount := donationDropdown.Text
    guiValues := MyGui.Submit(false)
    currentRecoveryToggle := guiValues.RecoveryToggle
    currentAutoSellToggle := guiValues.AutoSellToggle
    currentWebhookURL := guiValues.WebhookURL
    currentUIKey := FormatUIKey(guiValues.UIKey)
    currentAlwaysOnTopToggle := guiValues.AlwaysOnTopToggle
    currentDarkModeToggle := guiValues.DarkModeToggle

    IniWrite(currentClickDelay, settingsFile, "Settings", "ClickDelay")
    IniWrite(currentScanRadius, settingsFile, "Settings", "ScanRadius")
    IniWrite(currentClickCooldown, settingsFile, "Settings", "ClickCooldown")
    IniWrite(currentFollowInterval, settingsFile, "Settings", "FollowInterval")
    IniWrite(currentSpinDelay, settingsFile, "Settings", "SpinDelay")
    IniWrite(currentSelectedTerrain, settingsFile, "Settings", "SelectedTerrain")
    IniWrite(currentSelectedResolution, settingsFile, "Settings", "SelectedResolution")
    IniWrite(currentMovementType, settingsFile, "Settings", "MovementType")
    IniWrite(currentRecoveryToggle, settingsFile, "Settings", "RecoveryCycleEnabled")
    IniWrite(recoveryCycleCount, settingsFile, "Settings", "RecoveryCycleCount")
    IniWrite(currentAutoSellToggle, settingsFile, "Settings", "AutoSellEnabled")
    IniWrite(lastAutoSellCycle, settingsFile, "Settings", "LastAutoSellCycle")
    IniWrite(currentWebhookURL, settingsFile, "Settings", "WebhookURL")
    IniWrite(currentUIKey, settingsFile, "Settings", "UINavigationKey")
    IniWrite(currentDonationAmount, settingsFile, "Settings", "DonationAmount")
    IniWrite(currentAlwaysOnTopToggle, settingsFile, "Settings", "AlwaysOnTopEnabled")
    IniWrite(currentDarkModeToggle, settingsFile, "Settings", "DarkModeEnabled")

    autoReconnectEnabled := currentRecoveryToggle
    IniWrite(autoReconnectEnabled, settingsFile, "Settings", "AutoReconnectEnabled")

    webhookURL := currentWebhookURL
    uiNavigationKey := currentUIKey
    selectedResolution := currentSelectedResolution
    movementType := currentMovementType
    donationAmount := currentDonationAmount
    alwaysOnTopEnabled := currentAlwaysOnTopToggle
    darkModeEnabled := currentDarkModeToggle

    UpdateAlwaysOnTop()

    SaveAllTerrains()
}

SaveAllTerrains() {
    global settingsFile, terrainColors

    allTerrainNames := ""
    
    for terrainName, colors in terrainColors {
        if (allTerrainNames != "") {
            allTerrainNames .= "|"
        }
        allTerrainNames .= terrainName

        if (colors.Length = 0) {
            IniWrite("EMPTY", settingsFile, "TerrainColors", terrainName)
        } else {
            colorString := ""
            for color in colors {
                if (colorString != "") {
                    colorString .= ","
                }
                colorString .= color
            }
            IniWrite(colorString, settingsFile, "TerrainColors", terrainName)
        }
    }

    IniWrite(allTerrainNames, settingsFile, "TerrainColors", "AllTerrains")
}

GetTerrainNames() {
    global terrainColors
    names := []
    for name, colors in terrainColors {
        names.Push(name)
    }
    return names
}

UpdateCustomTerrainList() {
    global customTerrainList, terrainColors
    
    customTerrainList.Delete()
    
    for terrainName, colors in terrainColors {
        if (colors.Length = 3) {
            colorString := Format("0x{:06X}, 0x{:06X}, 0x{:06X}", colors[1], colors[2], colors[3])
            displayText := terrainName . " - " . colorString
            customTerrainList.Add([displayText])
        } else if (colors.Length > 0) {
            colorCode := Format("0x{:06X}", colors[1])
            displayText := terrainName . " - " . colorCode . " (LEGACY " . colors.Length . " colors)"
            customTerrainList.Add([displayText])
        } else {
            customTerrainList.Add([terrainName . " - No Colors"])
        }
    }
}

AddCustomTerrain(*) {
    global terrainColors, terrainDropdown, customNameEdit, customColorEdit
    
    terrainName := Trim(customNameEdit.Text)
    colorInput := Trim(customColorEdit.Text)
    
    if (terrainName = "" || colorInput = "") {
        MsgBox("Please enter terrain name and all 3 color values.")
        return
    }

    colorStrings := StrSplit(colorInput, ",")

    for index, colorStr in colorStrings {
        colorStrings[index] := Trim(colorStr)
    }

    if (colorStrings.Length != 3) {
        MsgBox("Please enter exactly 3 colors separated by commas.`nFormat: 0xRRGGBB, 0xRRGGBB, 0xRRGGBB")
        return
    }

    colors := []
    for index, colorStr in colorStrings {
        if (!RegExMatch(colorStr, "^0x[0-9A-Fa-f]{6}$")) {
            MsgBox("Invalid format for Color " . index . ": " . colorStr . "`nPlease use format: 0xRRGGBB")
            return
        }
        colors.Push(Integer(colorStr))
    }

    if (terrainColors.Has(terrainName)) {
        result := MsgBox("Terrain '" . terrainName . "' already exists. Overwrite?", "Confirm", "YesNo")
        if (result = "No") {
            return
        }
    }

    terrainColors[terrainName] := colors

    terrainDropdown.Delete()
    terrainDropdown.Add(GetTerrainNames())

    for index, name in GetTerrainNames() {
        if (name = terrainName) {
            terrainDropdown.Value := index
            break
        }
    }

    UpdateCustomTerrainList()
    UpdateTerrainType()

    customNameEdit.Text := ""
    customColorEdit.Text := ""
    
    ToolTip("Custom terrain '" . terrainName . "' added with 3 colors!", 0, -30)
    SetTimer(() => ToolTip(), -2000)
}

DeleteCustomTerrain(*) {
    global customTerrainList, terrainColors, terrainDropdown
    
    selectedIndex := customTerrainList.Value
    if (selectedIndex = 0) {
        MsgBox("Please select a terrain to delete.")
        return
    }

    fullText := customTerrainList.Text
    terrainName := StrSplit(fullText, " - ")[1]
    
    result := MsgBox("Are you sure you want to delete terrain '" . terrainName . "'?", "Confirm Delete", "YesNo")
    if (result = "Yes") {
        terrainColors.Delete(terrainName)

        terrainDropdown.Delete()
        terrainDropdown.Add(GetTerrainNames())

        if (terrainColors.Count = 0) {
            UpdateTerrainType()
        } else {
            terrainDropdown.Value := 1
            UpdateTerrainType()
        }
        
        UpdateCustomTerrainList()
        
        ToolTip("Terrain '" . terrainName . "' deleted successfully!", 0, -30)
        SetTimer(() => ToolTip(), -2000)
    }
}

ResetCycleCount(*) {
    global recoveryCycleCount, cycleCountText, lastAutoSellCycle, successfulCycles, unsuccessfulCycles
    recoveryCycleCount := 0
    lastAutoSellCycle := 0
    successfulCycles := 0
    unsuccessfulCycles := 0
    cycleCountText.Text := String(recoveryCycleCount)
    SaveSettings()
    ToolTip("Recovery cycle count reset to 0", 0, -30)
    SetTimer(() => ToolTip(), -2000)
}

ResetSettingsToDefault(*) {
    global clickDelayEdit, scanRadiusEdit, clickCooldownEdit, followIntervalEdit, spinDelayEdit, uiKeyEdit
    global defaultClickDelay, defaultClickScanRadius, defaultClickCooldown, defaultFollowInterval, defaultSpinDelay, defaultUINavigationKey
    
    result := MsgBox("Are you sure you want to reset all settings to default values?", "Confirm Reset", "YesNo")
    if (result = "Yes") {

        clickDelayEdit.Value := defaultClickDelay
        scanRadiusEdit.Value := defaultClickScanRadius
        clickCooldownEdit.Value := defaultClickCooldown
        followIntervalEdit.Value := defaultFollowInterval
        spinDelayEdit.Value := defaultSpinDelay
        uiKeyEdit.Text := defaultUINavigationKey
        
        UpdateClickDelay()
        UpdateScanRadius()
        UpdateClickCooldown()
        UpdateFollowInterval()
        UpdateSpinDelay()

        ResetCycleCount()

        SaveSettings()
        
        ToolTip("Settings reset to default values", 0, -30)
        SetTimer(() => ToolTip(), -2000)
    }
}

UpdateCycleCountDisplay() {
    global cycleCountText, recoveryCycleCount
    cycleCountText.Text := String(recoveryCycleCount)
}

OnGuiClose(*) {
    SaveSettings()
    SaveGuiPosition()
    ExitApp
}

UpdateTerrainType(*) {
    global clickColors, terrainColors, terrainDropdown
    
    if (terrainColors.Count = 0) {
        clickColors := []
        return
    }
    
    try {
        selectedTerrain := terrainDropdown.Text
        if (terrainColors.Has(selectedTerrain)) {
            clickColors := terrainColors[selectedTerrain]
        } else {
            clickColors := []
        }
    } catch {
        clickColors := []
    }
}

UpdateResolution(*) {
    global selectedResolution, resolutionDropdown
    oldResolution := selectedResolution
    selectedResolution := resolutionDropdown.Text
    CalculateCoordinates()

    ForceFullscreenMode()
    
    ToolTip("Resolution changed to " . selectedResolution, 0, -30)
    SetTimer(() => ToolTip(), -3000)
}

UpdateMovementType(*) {
    global movementType, movementTypeDropdown
    movementType := movementTypeDropdown.Text
    ToolTip("Movement type changed to " . movementType, 0, -30)
    SetTimer(() => ToolTip(), -2000)
}

UpdateDonationAmount(*) {
    global donationAmount, donationDropdown
    donationAmount := donationDropdown.Text
    ToolTip("Donation amount changed to " . donationAmount, 0, -30)
    SetTimer(() => ToolTip(), -2000)
}

UpdateAlwaysOnTop(*) {
    global alwaysOnTopEnabled, MyGui, settingsFile
    
    try {
        guiValues := MyGui.Submit(false)
        alwaysOnTopEnabled := guiValues.AlwaysOnTopToggle
        
        if (alwaysOnTopEnabled) {
            MyGui.Opt("+AlwaysOnTop")
            ToolTip("Always on top enabled", 0, -30)
        } else {
            MyGui.Opt("-AlwaysOnTop")
            ToolTip("Always on top disabled", 0, -30)
        }
        SetTimer(() => ToolTip(), -2000)

        IniWrite(alwaysOnTopEnabled, settingsFile, "Settings", "AlwaysOnTopEnabled")
    } catch {
    }
}

UpdateDarkMode(*) {
    global darkModeEnabled, MyGui, settingsFile
    
    try {
        guiValues := MyGui.Submit(false)
        darkModeEnabled := guiValues.DarkModeToggle

        IniWrite(darkModeEnabled, settingsFile, "Settings", "DarkModeEnabled")
        
        SaveSettings()
        SaveGuiPosition()
        Reload
    } catch {
    }
}

UpdateClickDelay(*) {
    global clickDelay
    clickDelay := Integer(clickDelayEdit.Value)
}

UpdateScanRadius(*) {
    global clickScanRadius
    clickScanRadius := Integer(scanRadiusEdit.Value)
}

UpdateClickCooldown(*) {
    global clickCooldown
    clickCooldown := Integer(clickCooldownEdit.Value)
}

UpdateFollowInterval(*) {
    global followInterval
    followInterval := Integer(followIntervalEdit.Value)
    if (scanning) {
        SetTimer(ScanForColor, followInterval)
    }
}

UpdateSpinDelay(*) {
    global spinDelay
    spinDelay := Integer(spinDelayEdit.Value)
}

ApplySettings(*) {
    global recoveryCycleEnabled, autoSellEnabled, uiNavigationKey, selectedResolution, movementType, autoReconnectEnabled, donationAmount

    UpdateTerrainType()
    UpdateClickDelay()
    UpdateScanRadius()
    UpdateClickCooldown()
    UpdateFollowInterval()
    UpdateSpinDelay()
    UpdateResolution()
    UpdateMovementType()
    UpdateDonationAmount()

    guiValues := MyGui.Submit(false)
    recoveryCycleEnabled := guiValues.RecoveryToggle
    autoSellEnabled := guiValues.AutoSellToggle
    uiNavigationKey := FormatUIKey(guiValues.UIKey)

    autoReconnectEnabled := recoveryCycleEnabled
}

FormatUIKey(key) {
    specialKeys := Map(
        "backspace", "{Backspace}",
        "delete", "{Delete}",
        "insert", "{Insert}",
        "home", "{Home}",
        "end", "{End}",
        "pgup", "{PgUp}",
        "pgdn", "{PgDn}",
    )

    lowerKey := StrLower(Trim(key))

    if (specialKeys.Has(lowerKey)) {
        return specialKeys[lowerKey]
    }

    if (key = "{") {
        return "{{}"
    } else if (key = "}") {
        return "{}}"
    } else if (key = "!") {
        return "{!}"
    } else if (key = "^") {
        return "{^}"
    } else if (key = "+") {
        return "{+}"
    } else if (key = "#") {
        return "{#}"
    }

    return key
}

CheckAutoSell() {
    global autoSellEnabled, recoveryCycleCount, lastAutoSellCycle, uiNavigationKey, selectedResolution
    
    if (!autoSellEnabled) {
        return
    }
    
    if (recoveryCycleCount >= lastAutoSellCycle + 35) {
        lastAutoSellCycle := recoveryCycleCount
        
        ToolTip("Auto Sell activated!", 10, 70)
    
        Sleep 500

        if (selectedResolution = "1366x768") {
            Send "g"
            Sleep 500
            SendInput(uiNavigationKey)
            Sleep 500
            Send "{Down}"
            Sleep 500
            Send "{Up}"
            Sleep 500
            Send "{Enter}"
            Sleep 500
            SendInput(uiNavigationKey)
            Sleep 500
            Send "g"          
            ToolTip("Auto Sell completed", 10, 70)
        } else {

            Send "g"
            Sleep 500
            SendInput(uiNavigationKey)
            Sleep 500
            Send "{Down}"
            Sleep 500
            Send "{Enter}"
            Sleep 500
            SendInput(uiNavigationKey)
            Sleep 500
            Send "g"
            ToolTip("Auto Sell completed", 10, 70)
        }

        SetTimer(() => ToolTip(), -3000)
        
        SaveSettings()
    }
}

CheckShovelFix() {
    global recoveryCycleCount, lastShovelFixCycle, recoveryCycleEnabled
    
    if (!recoveryCycleEnabled) {
        return
    }
    
    if (recoveryCycleCount >= lastShovelFixCycle + 12) {
        lastShovelFixCycle := recoveryCycleCount
        
        ToolTip("Shovel Fix activated!", 10, 70)

        Sleep 300
        Send "{2}"
        Sleep 300
        Send "{1}"

        SetTimer(() => ToolTip(), -3000)
        
        SaveSettings()
    }
}

LoadSettings()

GetThemeColors() {
    global darkModeEnabled, DarkBG, DarkControl, WhiteText, LightGrey
    global LightBG, LightControl, BlackText, DarkGrey
    
    if (darkModeEnabled) {
        return {
            bgColor: DarkBG,
            controlColor: DarkControl,
            textColor: WhiteText,
            accentColor: LightGrey
        }
    } else {
        return {
            bgColor: LightBG,
            controlColor: LightControl,
            textColor: BlackText,
            accentColor: DarkGrey
        }
    }
}

ApplyThemeToGui() {
    global MyGui, TabCtrl, terrainDropdown, webhookEdit, movementTypeDropdown, resolutionDropdown
    global customNameEdit, customColorEdit, customTerrainList, clickDelayEdit, scanRadiusEdit
    global clickCooldownEdit, followIntervalEdit, spinDelayEdit, cycleCountText, uiKeyEdit
    global donationDropdown, DiscordBtn, DonateBtn
    
    colors := GetThemeColors()

    MyGui.BackColor := colors.bgColor

    TabCtrl.Opt("c" . colors.textColor . " Background" . colors.controlColor)

    terrainDropdown.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    movementTypeDropdown.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    resolutionDropdown.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    donationDropdown.Opt("c" . colors.textColor . " Background" . colors.controlColor)

    webhookEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    customNameEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    customColorEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    clickDelayEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    scanRadiusEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    clickCooldownEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    followIntervalEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    spinDelayEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    cycleCountText.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    uiKeyEdit.Opt("c" . colors.textColor . " Background" . colors.controlColor)

    customTerrainList.Opt("c" . colors.textColor . " Background" . colors.controlColor)

    DiscordBtn.Opt("c" . colors.textColor . " Background" . colors.controlColor)
    DonateBtn.Opt("c" . colors.textColor . " Background" . colors.controlColor)
}

colors := GetThemeColors()

guiOptions := alwaysOnTopEnabled ? "+AlwaysOnTop -Resize -MaximizeBox" : "-Resize -MaximizeBox"
MyGui := Gui(guiOptions, "moris dig macro v4.6")
MyGui.MarginX := 10
MyGui.MarginY := 10
MyGui.BackColor := colors.bgColor

TabCtrl := MyGui.Add("Tab3", "x10 y10 w282 h226 c" . colors.textColor . " Background" . colors.controlColor, ["   Start   ", " Create Terrain ", "  Settings  ", "  Instructions  "])

TabCtrl.UseTab("   Start   ")
MyGui.Add("Text", "x30 y45 w220 c" . colors.textColor, "Terrain:")
terrainDropdown := MyGui.Add("DropDownList", "x30 y65 w100 vSelectedTerrain c" . colors.textColor . " Background" . colors.controlColor, GetTerrainNames())
terrainDropdown.OnEvent("Change", UpdateTerrainType)
if (terrainColors.Count > 0) {
    terrainDropdown.Value := selectedTerrainIndex
}

MyGui.Add("Checkbox", "x27 y150 vRecoveryToggle c" . colors.textColor, "AFK Mode").Value := recoveryCycleEnabled
MyGui.Add("Checkbox", "x121 y150 vAutoSellToggle c" . colors.textColor, "Auto Sell").Value := autoSellEnabled

MyGui.Add("Text", "x30 y95 c" . colors.textColor, "Webhook URL:")
webhookEdit := MyGui.Add("Edit", "x30 y115 w100 r1 vWebhookURL c" . colors.textColor . " Background" . colors.controlColor, webhookURL)

MyGui.Add("Text", "x168 y45 c" . colors.textColor, "Movement Type:")
movementTypeDropdown := MyGui.Add("DropDownList", "x168 y65 w100 vMovementType c" . colors.textColor . " Background" . colors.controlColor, ["Risk Mode", "Stable Mode"])
movementTypeDropdown.OnEvent("Change", UpdateMovementType)

for index, movement in ["Risk Mode", "Stable Mode"] {
    if (movement = movementType) {
        movementTypeDropdown.Value := index
        break
    }
}

MyGui.Add("Text", "x168 y95 c" . colors.textColor, "Resolution:")
resolutionDropdown := MyGui.Add("DropDownList", "x168 y115 w100 vSelectedResolution c" . colors.textColor . " Background" . colors.controlColor, ["1920x1080", "2560x1440", "1366x768"])
resolutionDropdown.OnEvent("Change", UpdateResolution)
resolutionDropdown.OnEvent("Change", UpdateResolution)

for index, resolution in ["1920x1080", "2560x1440", "1366x768"] {
    if (resolution = selectedResolution) {
        resolutionDropdown.Value := index
        break
    }
}

MyGui.Add("Button", "x21 y179 w80 h45 c" . colors.textColor . " Background" . colors.controlColor, "Start Macro (F1)").OnEvent("Click", (*) => Send("{F1}"))
MyGui.Add("Button", "x109 y179 w80 h45 c" . colors.textColor . " Background" . colors.controlColor, "Reload Macro (F2)").OnEvent("Click", (*) => Send("{F2}"))
MyGui.Add("Button", "x196 y179 w80 h45 c" . colors.textColor . " Background" . colors.controlColor, "Scan Color  (F3)").OnEvent("Click", delayedScan)

delayedScan(*) {
    Loop 3 {
        MouseGetPos(&mouseX, &mouseY)
        ToolTip(4 - A_Index, mouseX + 20, mouseY + 20)
        Sleep(1000)
    }
    ToolTip()
    Send("{F3}")
}

TabCtrl.UseTab(" Create Terrain ")

MyGui.Add("Text", "x30 y45 w220 c" . colors.textColor, "Terrain Name:")
customNameEdit := MyGui.Add("Edit", "x30 y65 w100 c" . colors.textColor . " Background" . colors.controlColor)

MyGui.Add("Text", "x30 y95 w220 c" . colors.textColor, "Colors (3 required):")
customColorEdit := MyGui.Add("Edit", "x30 y115 w100 c" . colors.textColor . " Background" . colors.controlColor)

MyGui.Add("Button", "x30 y154 w100 h20 c" . colors.textColor . " Background" . colors.controlColor, "Add Terrain").OnEvent("Click", AddCustomTerrain)
MyGui.Add("Button", "x30 y193 w100 h20 c" . colors.textColor . " Background" . colors.controlColor, "Delete Terrain").OnEvent("Click", DeleteCustomTerrain)

MyGui.Add("Text", "x145 y45 w120 c" . colors.textColor, "Existing Terrains:")
customTerrainList := MyGui.Add("ListBox", "x145 y65 w120 h159 vCustomTerrainList c" . colors.textColor . " Background" . colors.controlColor)
UpdateCustomTerrainList()

TabCtrl.UseTab("  Settings  ")

MyGui.Add("Text", "x30 y45 w220 c" . colors.textColor, "Click Delay:")
clickDelayEdit := MyGui.Add("Edit", "x30 y65 w60 c" . colors.textColor . " Background" . colors.controlColor, clickDelay)
clickDelayEdit.OnEvent("Change", UpdateClickDelay)

MyGui.Add("Text", "x120 y45 c" . colors.textColor, "Scan Radius:")
scanRadiusEdit := MyGui.Add("Edit", "x120 y65 w60 c" . colors.textColor . " Background" . colors.controlColor, clickScanRadius)
scanRadiusEdit.OnEvent("Change", UpdateScanRadius)

MyGui.Add("Text", "x210 y45 c" . colors.textColor, "Cooldown:")
clickCooldownEdit := MyGui.Add("Edit", "x210 y65 w60 c" . colors.textColor . " Background" . colors.controlColor, clickCooldown)
clickCooldownEdit.OnEvent("Change", UpdateClickCooldown)

MyGui.Add("Text", "x30 y95 c" . colors.textColor, "Follow Interval:")
followIntervalEdit := MyGui.Add("Edit", "x30 y115 w60 c" . colors.textColor . " Background" . colors.controlColor, followInterval)
followIntervalEdit.OnEvent("Change", UpdateFollowInterval)

MyGui.Add("Text", "x120 y95 c" . colors.textColor, "Spin Delay:")
spinDelayEdit := MyGui.Add("Edit", "x120 y115 w60 c" . colors.textColor . " Background" . colors.controlColor, spinDelay)
spinDelayEdit.OnEvent("Change", UpdateSpinDelay)

MyGui.Add("Text", "x210 y95 c" . colors.textColor, "Cycles:")
cycleCountText := MyGui.Add("Edit", "x210 y115 w35 ReadOnly c" . colors.textColor . " Background" . colors.controlColor, String(recoveryCycleCount))
MyGui.Add("Button", "x247 y114 w22 h23 c" . colors.textColor . " Background" . colors.controlColor, "↻").OnEvent("Click", ResetCycleCount)

MyGui.Add("Text", "x150 y175 c" . colors.textColor, "Ui Navigation Key:")
uiKeyEdit := MyGui.Add("Edit", "x245 y171 w20 r1 Center vUIKey c" . colors.textColor . " Background" . colors.controlColor, uiNavigationKey)

MyGui.Add("Button", "x30 y195 w110 h20 c" . colors.textColor . " Background" . colors.controlColor, "Reset to Default").OnEvent("Click", ResetSettingsToDefault)

alwaysOnTopCheckbox := MyGui.Add("Checkbox", "x30 y145 vAlwaysOnTopToggle c" . colors.textColor, "Always On Top")
alwaysOnTopCheckbox.Value := alwaysOnTopEnabled
alwaysOnTopCheckbox.OnEvent("Click", UpdateAlwaysOnTop)

darkModeCheckbox := MyGui.Add("Checkbox", "x150 y145 vDarkModeToggle c" . colors.textColor, "Dark Mode")
darkModeCheckbox.Value := darkModeEnabled
darkModeCheckbox.OnEvent("Click", UpdateDarkMode)

TabCtrl.UseTab("  Instructions  ")

MyGui.Add("Text", "x40 y60 w220 Center c" . colors.textColor, "Join the Discord with the button below for instructions in the #instructions channel with a tutorial video and a written guide.")

donationDropdown := MyGui.Add("DropDownList", "x151 y143 w58 Center vDonationAmount c" . colors.textColor . " Background" . colors.controlColor, ["10", "50", "100", "200", "500"])
donationDropdown.OnEvent("Change", UpdateDonationAmount)

for index, amount in ["10", "50", "100", "200", "500"] {
    if (amount = donationAmount) {
        donationDropdown.Value := index
        break
    }
}

DiscordBtn := MyGui.Add("Button", "x80 y120 w60 h45 c" . colors.textColor . " Background" . colors.controlColor, "Discord")
DonateBtn := MyGui.Add("Button", "x150 y120 w60 h23 c" . colors.textColor . " Background" . colors.controlColor, "Donate")

MyGui.Add("Text", "x35 y190 w220 Center c" . colors.textColor, "made by moris with help of adnrealan")

DonateBtn.OnEvent("Click", DonateClick)

DonateClick(*) {
    global donationAmount, donationLinks
    if (donationLinks[donationAmount] != "") {
        Run(donationLinks[donationAmount])
    } else {
        MsgBox("Donation link for " . donationAmount . " is not set.", "Donation", "OK")
    }
}
DiscordBtn.OnEvent("Click", (*) => Run("https://discord.gg/moris"))

MyGui.OnEvent("Close", CloseApp)
CloseApp(*) {
    SaveSettings()
    SaveGuiPosition()
    ExitApp()
}

guiPos := LoadGuiPosition()
if (guiPos.x != -1 && guiPos.y != -1) {
    MyGui.Show("x" . guiPos.x . " y" . guiPos.y . " w300 h245")
} else {
    MyGui.Show("w300 h245")
}

CalculateCoordinates() {
    global scanLeft, scanTop, scanRight, scanBottom, selectedResolution, resolutionConfigs
    
    config := resolutionConfigs[selectedResolution]
    scanLeft := config.scanLeft
    scanTop := config.scanTop
    scanRight := config.scanRight
    scanBottom := config.scanBottom
}

scanLeft := 512
scanTop := 815
scanRight := 1397
scanBottom := 825
targetColor := 0x191919
clickColors := []
clickColorVariation := -10
scanning := false
minX := 99999
maxX := -1
lastClickTime := 0
lastFoundX := 0
lastFoundY := 0
lastPixelFoundTime := 0
recoveryActive := false
clickLoopActive := false
recoveryCycleEnabled := true
recoveryCycleCount := 0
autoSellEnabled := true
lastAutoSellCycle := 0
lastRecoveryTime := 0
pixelFoundAfterRecovery := false
successfulCycles := 0
unsuccessfulCycles := 0
stableModeActive := false

F1::
{
    global scanning, followInterval, recoveryCycleEnabled, terrainColors, autoReconnectEnabled
    global macroStartTime, webhookMessageId

    if (terrainColors.Count = 0) {
        MsgBox("Please add at least one custom terrain before starting the macro.")
        return
    }

    SaveSettings()
    ApplySettings()

    ForceFullscreenMode()
    Sleep(300)

    UpdateResolution()
    
    ToolTip("Running scroll sequence", 10, 10)
    
    if (recoveryCycleEnabled) {
        Loop 18 {
            Send "{WheelUp}"
            Sleep 50
        }

        Sleep 300
        Send "{2}"
        Sleep 300
        Send "{1}"
        Sleep 600
        Click "Left"
    }
    
    scanning := !scanning
    if (scanning) {
        webhookMessageId := ""
        macroStartTime := A_TickCount
        
        ToolTip("Scroll sequence completed - Starting color tracking", 10, 10)
        SetTimer(ScanForColor, followInterval)
        if (recoveryCycleEnabled) {
            SetTimer(CheckPixelTimeout, 1000)
        }

        SendWebhook("Started")

        if (autoReconnectEnabled) {
            SetTimer(CheckAutoReconnect, 45000)
        }
    } else {
        ToolTip("Color tracking stopped", 10, 10)
        SetTimer(ScanForColor, 0)
        SetTimer(CheckPixelTimeout, 0)
        SetTimer(CheckAutoReconnect, 0)
        SetTimer(() => ToolTip(), -2000)

        SendWebhook("Stopped")
    }
}

F2::
{
    SaveSettings()
    SaveGuiPosition() 
    ToolTip("Reloading script...", 10, 10)
    Sleep 100
    Reload
}

F3:: {
    try {
        MouseGetPos(&mouseX, &mouseY)

        colorMap := Map()
        scanRadius := 5

        Loop (scanRadius * 2 + 1) {
            x := mouseX - scanRadius + A_Index - 1
            Loop (scanRadius * 2 + 1) {
                y := mouseY - scanRadius + A_Index - 1

                distance := Sqrt((x - mouseX)**2 + (y - mouseY)**2)
                if (distance <= scanRadius) {
                    try {
                        pixelColor := PixelGetColor(x, y)

                        if (colorMap.Has(pixelColor)) {
                            colorMap[pixelColor] := colorMap[pixelColor] + 1
                        } else {
                            colorMap[pixelColor] := 1
                        }
                    } catch {
                        continue
                    }
                }
            }
        }

        colorArray := []
        for color, count in colorMap {
            red := (color >> 16) & 0xFF
            green := (color >> 8) & 0xFF
            blue := color & 0xFF

            luminance := (0.299 * red + 0.587 * green + 0.114 * blue)
            
            colorArray.Push({
                color: color,
                count: count,
                luminance: luminance
            })
        }

        colorArray := SortColorsByDarkness(colorArray)

        topColors := []
        maxColors := Min(3, colorArray.Length)
        
        Loop maxColors {
            topColors.Push(colorArray[A_Index].color)
        }

        colorString := ""
        for index, color in topColors {
            if (index > 1) {
                colorString .= ", "
            }
            colorString .= Format("0x{:06X}", color)
        }
        
        A_Clipboard := colorString
        
        TabCtrl.Value := 2 

        finalColorString := ""

        if (topColors.Length >= 3) {
            finalColorString := Format("0x{:06X}, 0x{:06X}, 0x{:06X}", topColors[1], topColors[2], topColors[3])
        } else if (topColors.Length = 2) {
            finalColorString := Format("0x{:06X}, 0x{:06X}, 0x{:06X}", topColors[1], topColors[2], topColors[2])
        } else if (topColors.Length = 1) {
            finalColorString := Format("0x{:06X}, 0x{:06X}, 0x{:06X}", topColors[1], topColors[1], topColors[1])
        }
        
        customColorEdit.Text := finalColorString

        tooltipText := "Top " . topColors.Length . " darkest colors found:`n"
        for index, color in topColors {
            tooltipText .= index . ": " . Format("0x{:06X}", color) . "`n"
        }
        tooltipText .= "Filled into single field with comma separation!"
        
        ToolTip(tooltipText, mouseX + 20, mouseY + 20)
        SetTimer(() => ToolTip(), -4000)
        
    } catch as err {
        MsgBox("Error getting colors: " . err.Message)
    }
}

ScanForColor() {
    global scanLeft, scanTop, scanRight, scanBottom, targetColor, scanning
    global clickColors, clickColorVariation, clickScanRadius
    global clickDelay, clickCooldown, lastClickTime, lastFoundX, lastFoundY
    global lastPixelFoundTime, recoveryActive, clickLoopActive, recoveryCycleEnabled
    global pixelFoundAfterRecovery, lastRecoveryTime, stableModeActive, movementType
    static searchDirection := "RightToLeft"
    
    if (!scanning)
        return

    mouseBuffer := 50

    if (lastFoundX >= scanRight - mouseBuffer) {
        searchDirection := "LeftToRight"
    } 
    else if (lastFoundX <= scanLeft + mouseBuffer) {
        searchDirection := "RightToLeft"
    }

    if (searchDirection = "RightToLeft") {
        startX := scanRight
        endX := scanLeft
    } else {
        startX := scanLeft
        endX := scanRight
    }

    if (PixelSearch(&foundX, &foundY, startX, scanTop, endX, scanBottom, targetColor, 0)) {
        if (recoveryActive) {
            recoveryActive := false
            clickLoopActive := false
            ToolTip("Recovery mode ended - Scrolled down", 10, 50)
            SetTimer(() => ToolTip(), -2000)
        }

        if (stableModeActive) {
            Send "{Right up}"
            stableModeActive := false
            ToolTip("Stable mode ended - Target found", 10, 50)
            SetTimer(() => ToolTip(), -2000)
        }

        if (lastRecoveryTime > 0) {
            pixelFoundAfterRecovery := true
        }

        lastPixelFoundTime := A_TickCount

        if ((A_TickCount - lastClickTime) >= clickCooldown) {
            mouseX := foundX
            mouseY := foundY - (selectedResolution = "2560x1440" ? 40 : 30)

            cLeft := Max(mouseX - clickScanRadius, 0)
            cTop := Max(mouseY - clickScanRadius, 0)
            cRight := Min(mouseX + clickScanRadius, A_ScreenWidth)
            cBottom := Min(mouseY + clickScanRadius, A_ScreenHeight)

            for color in clickColors {
                if (PixelSearch(&cX, &cY, cLeft, cTop, cRight, cBottom, color, clickColorVariation)) {
                    Click
                    lastClickTime := A_TickCount
                    break
                }
            }
        }
    }
    else {
        searchDirection := (searchDirection = "RightToLeft") ? "LeftToRight" : "RightToLeft"
    }
}

CheckPixelTimeout() {
    global lastPixelFoundTime, scanning, recoveryActive, recoveryCycleEnabled
    global recoveryCycleCount, autoSellEnabled, lastAutoSellCycle, followInterval
    global lastShovelFixCycle
    global scanLeft, scanTop, scanRight, scanBottom, targetColor, spinDelay
    global pixelFoundAfterRecovery, lastRecoveryTime, successfulCycles, unsuccessfulCycles
    global movementType, stableModeActive, clickColors, clickColorVariation, clickScanRadius

    if (!scanning || !recoveryCycleEnabled) {
        return
    }

    if (PixelSearch(&foundX, &foundY, scanLeft, scanTop, scanRight, scanBottom, targetColor, 0)) {
        lastPixelFoundTime := A_TickCount
        if (recoveryActive) {
            recoveryActive := false
            ToolTip("Target pixel found - Recovery cancelled", 10, 50)
            SetTimer(() => ToolTip(), -2000)
        }
        return
    }
    
    timeElapsed := A_TickCount - lastPixelFoundTime
    
    if (timeElapsed > 1500) {
        recoveryActive := true
        recoveryCycleCount++
        UpdateCycleCountDisplay()
        SaveSettings()

        currentTime := A_TickCount
        timeSinceLastRecovery := currentTime - lastRecoveryTime

        if (pixelFoundAfterRecovery || lastRecoveryTime = 0 || timeSinceLastRecovery > 10000) {
            successfulCycles++
            pixelFoundAfterRecovery := false
        } else {
            unsuccessfulCycles++
        }

        if (Mod(recoveryCycleCount, 5) = 0) {
            SendWebhook("Recovery Cycle #" . recoveryCycleCount)
        }

        lastRecoveryTime := currentTime

        if (autoSellEnabled && recoveryCycleCount >= lastAutoSellCycle + 35) {
            ToolTip("Auto Sell triggered - Pausing before recovery", 10, 70)
            CheckAutoSell()
            
            Sleep 4000
            
            ToolTip("Auto Sell completed - Starting recovery", 10, 70)
            SetTimer(() => ToolTip(), -2000)
        }

        if (recoveryCycleEnabled && recoveryCycleCount >= lastShovelFixCycle + 12) {
            ToolTip("Shovel Fix triggered - Pausing before recovery", 10, 70)
            CheckShovelFix()

	    Sleep 300
            
            ToolTip("Shovel Fix completed - Starting recovery", 10, 70)
            SetTimer(() => ToolTip(), -2000)
        }

        SetTimer(ScanForColor, 0)
        
        ToolTip("Pixel not found - Started recovery #" . recoveryCycleCount . " (" . movementType . ")", 10, 50)
        
        SafeMoveRelative(0.5, 0.5)
        Send "{WheelUp}"
        Sleep 300
        Click "Left"
        Sleep spinDelay

        if (movementType = "Risk Mode") {
            SmoothMoveRight()
        } else if (movementType = "Stable Mode") {
            StableModeRecovery()
        }
        
        Sleep 300

        lastPixelFoundTime := A_TickCount
        if (scanning) {
            SetTimer(ScanForColor, followInterval)
        }
        
        ToolTip("Recovery completed - Scanning restarted", 10, 50)
        SetTimer(() => ToolTip(), -2000)
        recoveryActive := false
    }
}

StableModeRecovery() {
    global stableModeActive, scanLeft, scanTop, scanRight, scanBottom, targetColor
    global clickColors, clickColorVariation, clickScanRadius, clickCooldown, lastClickTime
    
    stableModeActive := true

    Sleep 300
    Send "{Right down}"

    SetTimer(SpamLeftClick, 50)
    
    Loop {
        if (!stableModeActive) {
            break
        }
        
        if (PixelSearch(&foundX, &foundY, scanLeft, scanTop, scanRight, scanBottom, targetColor, 0)) {
            Send "{Right up}"
            SetTimer(SpamLeftClick, 0)
            stableModeActive := false
            ToolTip("Stable mode ended - Target found", 10, 50)
            SetTimer(() => ToolTip(), -2000)
            break
        }
        
        Sleep 100
    }

    SetTimer(SpamLeftClick, 0)
    Send "{Right up}"
    stableModeActive := false
}

SpamLeftClick() {
    global stableModeActive, clickColors, clickColorVariation, clickScanRadius
    
    if (!stableModeActive) {
        SetTimer(SpamLeftClick, 0)
        return
    }

    MouseGetPos(&currentMouseX, &currentMouseY)

    cLeft := Max(currentMouseX - clickScanRadius, 0)
    cTop := Max(currentMouseY - clickScanRadius, 0)
    cRight := Min(currentMouseX + clickScanRadius, A_ScreenWidth)
    cBottom := Min(currentMouseY + clickScanRadius, A_ScreenHeight)

    for color in clickColors {
        if (PixelSearch(&cX, &cY, cLeft, cTop, cRight, cBottom, color, clickColorVariation)) {
            Click cX, cY
            return
        }
    }

    Click currentMouseX, currentMouseY
}

SmoothMoveRight() {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_exe RobloxPlayerBeta.exe")

        currentXRatio := 0.5
        currentYRatio := 0.5
        
        steps := 13
        delay := 10

        stepSizeRatio := (105 / 1920) / steps
        
        Loop steps {
            newXRatio := currentXRatio + (stepSizeRatio * A_Index)

            newX := winX + Round(newXRatio * winW)
            newY := winY + Round(currentYRatio * winH)
            
            MouseMove(newX, newY, 100)
            Sleep(delay)
        }
    }
}

SafeMoveRelative(xRatio, yRatio) {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_exe RobloxPlayerBeta.exe")
        moveX := winX + Round(xRatio * winW)
        moveY := winY + Round(yRatio * winH)
        MouseMove(moveX, moveY)
    }
}

SafeClickRelative(xRatio, yRatio) {
    if WinExist("ahk_exe RobloxPlayerBeta.exe") {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_exe RobloxPlayerBeta.exe")
        clickX := winX + Round(xRatio * winW)
        clickY := winY + Round(yRatio * winH)
        Click(clickX, clickY)
    }
}

ForceFullscreenMode() {
    robloxWindow := 0

    windowTitles := [
        "ahk_exe RobloxPlayerBeta.exe",
        "ahk_class WINDOWSCLIENT", 
        "Roblox",
        "ahk_exe RobloxPlayerLauncher.exe"
    ]
    
    for title in windowTitles {
        robloxWindow := WinExist(title)
        if (robloxWindow) {
            break
        }
    }

    if (!robloxWindow) {
        activeWindow := WinGetTitle("A")
        if (InStr(activeWindow, "Roblox") || WinGetProcessName("A") = "RobloxPlayerBeta.exe") {
            robloxWindow := WinExist("A")
        }
    }
    
    if (robloxWindow) {
        windowTitle := WinGetTitle(robloxWindow)
        processName := WinGetProcessName(robloxWindow)

        if (InStr(processName, "Roblox") || InStr(windowTitle, "Roblox")) {
            WinActivate(robloxWindow)
            Sleep(500)

            WinGetPos(&winX, &winY, &winWidth, &winHeight, robloxWindow)

            MonitorGet(1, &monLeft, &monTop, &monRight, &monBottom)
            monWidth := monRight - monLeft
            monHeight := monBottom - monTop

            isExclusiveFullscreen := (winX = monLeft && winY = monTop && winWidth = monWidth && winHeight = monHeight)
            isBorderlessFullscreen := (Abs(winWidth - monWidth) <= 10 && Abs(winHeight - monHeight) <= 10 && winX <= 5 && winY <= 5)
            isWindowedMode := (winWidth < monWidth - 50 || winHeight < monHeight - 100)

            if (isWindowedMode) {
                Send("{F11}")
                Sleep(500)
                ToolTip("Switched from windowed to fullscreen mode", 0, -50)
                SetTimer(() => ToolTip(), -2000)
            } else if (isBorderlessFullscreen && !isExclusiveFullscreen) {
                Send("{F11}")
                Sleep(200)
                Send("{F11}")
                Sleep(500)
                ToolTip("Switched from windowed fullscreen to exclusive fullscreen", 0, -50)
                SetTimer(() => ToolTip(), -2000)
            } else if (isExclusiveFullscreen) {
                ToolTip("Already in exclusive fullscreen mode", 0, -50)
                SetTimer(() => ToolTip(), -2000)
            } else {
                Send("{F11}")
                Sleep(500)
                ToolTip("Forced fullscreen mode", 0, -50)
                SetTimer(() => ToolTip(), -2000)
            }
        }
    } else {
        ToolTip("Roblox window not found - Please ensure Roblox is running", 0, -30)
        SetTimer(() => ToolTip(), -3000)
    }
}

SortColorsByDarkness(colorArray) {
    n := colorArray.Length
    
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index

            if (colorArray[j].luminance > colorArray[j + 1].luminance) {
                temp := colorArray[j]
                colorArray[j] := colorArray[j + 1]
                colorArray[j + 1] := temp
            }
            else if (colorArray[j].luminance = colorArray[j + 1].luminance && 
                     colorArray[j].count < colorArray[j + 1].count) {
                temp := colorArray[j]
                colorArray[j] := colorArray[j + 1]
                colorArray[j + 1] := temp
            }
        }
    }
    
    return colorArray
}