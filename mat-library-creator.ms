-- Group Material Library Generator
-- Creates VRay and Corona .mat files for selected group head nodes

fn createMaterialLibraries = (
    -- Target folder path
    local targetFolder = "R:\\18_PERSONAL\\PROJECTS\\BuzziModels\\TEST\\libraries\\"
    
    -- Check if target folder exists
    if not doesFileExist targetFolder then (
        messageBox ("Target folder does not exist:\n" + targetFolder) title:"Error"
        return false
    )
    
    -- Get current selection
    local sel = selection as array
    
    -- Check if anything is selected
    if sel.count == 0 then (
        messageBox "No objects selected. Please select groups to process." title:"No Selection"
        return false
    )
    
    -- Array to store head node names (to avoid duplicates)
    local headNodes = #()
    local processedNames = #()
    
    -- Find head nodes (top-most parent groups)
    for obj in sel do (
        local headNode = obj
        
        -- Traverse up the hierarchy to find the top-most parent
        while headNode.parent != undefined do (
            headNode = headNode.parent
        )
        
        -- Check if this head node is a group and not already processed
        if isGroupHead headNode and (findItem processedNames headNode.name) == 0 then (
            append headNodes headNode
            append processedNames headNode.name
        )
    )
    
    -- Check if we found any group head nodes
    if headNodes.count == 0 then (
        messageBox "No group head nodes found in selection. Please select objects that belong to groups." title:"No Groups Found"
        return false
    )
    
    -- Process each head node
    local createdFiles = #()
    local errors = #()
    
    for headNode in headNodes do (
        local groupName = headNode.name
        local vrayFileName = targetFolder + groupName + "_vray.mat"
        local coronaFileName = targetFolder + groupName + "_corona.mat"
        
        -- Check if files already exist
        if doesFileExist vrayFileName then (
            append errors ("File already exists: " + vrayFileName)
            continue
        )
        
        if doesFileExist coronaFileName then (
            append errors ("File already exists: " + coronaFileName)
            continue
        )
        
        -- Create empty material libraries
        try (
            -- Create VRay material library
            local vrayLib = materialLibrary()
            saveMaterialLibrary vrayFileName
            append createdFiles vrayFileName
            
            -- Create Corona material library  
            local coronaLib = materialLibrary()
            saveMaterialLibrary coronaFileName
            append createdFiles coronaFileName
            
        ) catch (
            append errors ("Failed to create libraries for: " + groupName + " - " + getCurrentException())
        )
    )
    
    -- Report results
    local resultMessage = ""
    
    if createdFiles.count > 0 then (
        resultMessage += "Successfully created " + (createdFiles.count as string) + " material libraries:\n\n"
        for file in createdFiles do (
            resultMessage += (filenameFromPath file) + "\n"
        )
    )
    
    if errors.count > 0 then (
        if resultMessage != "" then resultMessage += "\n"
        resultMessage += "Errors encountered:\n\n"
        for error in errors do (
            resultMessage += error + "\n"
        )
    )
    
    if resultMessage != "" then (
        messageBox resultMessage title:"Material Library Generator Results"
    )
    
    return (errors.count == 0)
)

-- Execute the function
createMaterialLibraries()