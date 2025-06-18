try(destroyDialog ExportSelectedGroups) catch()

rollout ExportSelectedGroups "Export Selected Groups" width:400 height:300
(
    -- UI Elements
    editText txtFolderPath "Save Folder:" width:300 pos:[10,10] readonly:true
    button btnBrowse "Browse..." width:80 pos:[320,8]
    button btnExport "Export Selected Groups" width:380 pos:[10,40] height:30
    editText txtLog "Log:" width:380 height:200 pos:[10,80] readonly:true multiLine:true

    -- Global variables
    local saveFolder = ""

    -- Function to log messages to the UI
    function logMessage msg =
    (
        txtLog.text += ((timestamp() as string) + ": " + msg + "\n")
        redrawViews()
    )

    -- Function to collect group members recursively
    function collectGroupMembers node members =
    (
        if isValidNode node do
        (
            append members node
            for child in node.children do
            (
                collectGroupMembers child members
            )
        )
        members
    )

    -- Browse folder button handler
    on btnBrowse pressed do
    (
        saveFolder = getSavePath caption:"Select Save Folder"
        if saveFolder != undefined do
        (
            txtFolderPath.text = saveFolder
            logMessage ("Save folder set to: " + saveFolder)
        )
    )

    -- Export button handler
    on btnExport pressed do
    (
        if saveFolder == "" or saveFolder == undefined do
        (
            logMessage "Error: Please select a valid save folder."
            return false
        )

        -- Get all selected group heads
        local selectedGroupHeads = for obj in selection where isGroupHead obj collect obj
        
        -- Filter for only top-level parent groups among the selected group heads
        local topLevelParentGroups = #()
        for grp in selectedGroupHeads do
        (
            local isTopLevel = true
            -- Check if this group is a child of any other selected group head
            for otherGrp in selectedGroupHeads where otherGrp != grp do
            (
                if (findItem (collectGroupMembers otherGrp #()) grp) != 0 then
                (
                    isTopLevel = false
                    break
                )
            )
            if isTopLevel then
            (
                append topLevelParentGroups grp
            )
        )

        if topLevelParentGroups.count == 0 do
        (
            logMessage "Error: No top-level parent groups found in selection."
            return false
        )

        logMessage ("Found " + topLevelParentGroups.count as string + " top-level parent group(s) to process.")

        -- Process each top-level parent group
        for grp in topLevelParentGroups do
        (
            local groupName = grp.name
            logMessage ("Processing group: " + groupName)

            -- Create individual folder for this group
            local groupFolderPath = saveFolder + "\\" + groupName
            
            -- Check if folder exists, if not create it
            if not doesDirectoryExist groupFolderPath then
            (
                try
                (
                    makeDir groupFolderPath
                    logMessage ("Created folder: " + groupFolderPath)
                )
                catch
                (
                    logMessage ("Error creating folder for " + groupName + ": " + getCurrentException())
                    continue -- Skip this group if folder creation fails
                )
            )
            else
            (
                logMessage ("Folder already exists: " + groupFolderPath)
            )

            -- Collect all group members (including nested groups and their children)
            local groupMembers = #()
            groupMembers = collectGroupMembers grp #()

            -- Select all collected members for export
            select groupMembers

            -- Define file paths (now within the group's folder)
            local max2017File = groupFolderPath + "\\" + groupName + "_max2017.max"
            local max2020File = groupFolderPath + "\\" + groupName + "_max2020.max"
            local objFile = groupFolderPath + "\\" + groupName + ".obj"

            -- Save Max 2017 version (selected objects only)
            try
            (
                saveNodes selection max2017File saveAsVersion:2017 quiet:true
                logMessage ("Saved Max 2017 file: " + max2017File)
            )
            catch
            (
                logMessage ("Error saving Max 2017 file for " + groupName + ": " + getCurrentException())
            )

            -- Save Max 2020 version (selected objects only)
            try
            (
                saveNodes selection max2020File saveAsVersion:2020 quiet:true
                logMessage ("Saved Max 2020 file: " + max2020File)
            )
            catch
            (
                logMessage ("Error saving Max 2020 file for " + groupName + ": " + getCurrentException())
            )

            -- Export OBJ
            try
            (
                exportFile objFile #noPrompt using:ObjExp quiet:true
                logMessage ("Exported OBJ file: " + objFile)
            )
            catch
            (
                logMessage ("Error exporting OBJ file for " + groupName + ": " + getCurrentException())
            )

            -- Deselect to prepare for next group
            deselect selection
        )

        logMessage "Export process completed."
    )
)

-- Create the dialog
createDialog ExportSelectedGroups