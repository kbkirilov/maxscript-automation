-- Advanced Group Material Library Generator with UI
-- Creates VRay and Corona .mat files for selected group head nodes

rollout MaterialLibraryGeneratorUI "Material Library Generator" width:500 height:400 (
    
    -- UI Controls
    groupBox grp1 "Processing Options" pos:[10,10] width:480 height:60
    checkbox chkVRay "Process VRay Materials" pos:[20,30] checked:true
    checkbox chkCorona "Process Corona Materials" pos:[20,50] checked:true
    
    groupBox grp2 "Target Folder" pos:[10,80] width:480 height:50
    editText edtFolder "Folder:" pos:[20,100] width:450 text:"R:\\18_PERSONAL\\PROJECTS\\BuzziModels\\TEST\\libraries\\"
    
    button btnProcess "Generate Material Libraries" pos:[10,140] width:200 height:30
    button btnClear "Clear Log" pos:[220,140] width:100 height:30
    
    groupBox grp3 "Log" pos:[10,180] width:480 height:210
    editText edtLog "" pos:[20,200] width:460 height:180 readonly:true
    
    -- Global variables
    local processedMaterials = #()
    local vrayMaterials = #()
    local coronaMaterials = #()
    
    -- Function to check if material is VRay
    fn isVRayMaterial mat = (
        local className = classOf mat as string
        return (matchPattern className pattern:"*VRay*" or matchPattern className pattern:"*vray*")
    )
    
    -- Function to check if material is Corona
    fn isCoronaMaterial mat = (
        local className = classOf mat as string
        return (matchPattern className pattern:"*Corona*" or matchPattern className pattern:"*corona*")
    )
    
    -- Function to recursively collect materials from MultiSub
    fn collectMultiSubMaterials multiMat = (
        local subMats = #()
        if multiMat != undefined then (
            for i = 1 to multiMat.materialList.count do (
                if multiMat.materialList[i] != undefined then (
                    append subMats multiMat.materialList[i]
                    -- Recursively check if sub-material is also MultiSub
                    if classOf multiMat.materialList[i] == MultiSubMaterial then (
                        join subMats (collectMultiSubMaterials multiMat.materialList[i])
                    )
                )
            )
        )
        return subMats
    )
    
    -- Function to determine MultiSub material type
    fn getMultiSubType multiMat = (
        local subMats = collectMultiSubMaterials multiMat
        local hasVRay = false
        local hasCorona = false
        
        for subMat in subMats do (
            if isVRayMaterial subMat then hasVRay = true
            if isCoronaMaterial subMat then hasCorona = true
        )
        
        if hasVRay and not hasCorona then return "vray"
        if hasCorona and not hasVRay then return "corona"
        return "mixed" -- This shouldn't happen according to requirements
    )
    
    -- Function to recursively collect all materials from an object
    fn collectObjectMaterials obj = (
        local materials = #()
        
        if obj.material != undefined then (
            local mat = obj.material
            
            -- Check if we've already processed this material
            if (findItem processedMaterials mat) == 0 then (
                append processedMaterials mat
                
                if classOf mat == MultiSubMaterial then (
                    -- Determine if MultiSub is VRay or Corona based
                    local multiSubType = getMultiSubType mat
                    if multiSubType == "vray" and chkVRay.checked then (
                        append vrayMaterials mat
                        edtLog.text += "Added MultiSub (VRay): " + mat.name + "\n"
                    )
                    else if multiSubType == "corona" and chkCorona.checked then (
                        append coronaMaterials mat
                        edtLog.text += "Added MultiSub (Corona): " + mat.name + "\n"
                    )
                )
                else if isVRayMaterial mat and chkVRay.checked then (
                    append vrayMaterials mat
                    edtLog.text += "Added VRay material: " + mat.name + "\n"
                )
                else if isCoronaMaterial mat and chkCorona.checked then (
                    append coronaMaterials mat
                    edtLog.text += "Added Corona material: " + mat.name + "\n"
                )
            )
        )
        
        return materials
    )
    
    -- Function to recursively process group and all children
    fn processGroupRecursively grp = (
        -- Process current group members
        for i = 1 to grp.children.count do (
            local child = grp.children[i]
            
            -- Collect materials from this object
            collectObjectMaterials child
            
            -- If child is also a group, process it recursively
            if isGroupHead child then (
                processGroupRecursively child
            )
        )
    )
    
    -- Function to save VRay material library with improved error handling
    fn saveVRayMaterialLibrary fileName materials = (
        local result = false
        
        edtLog.text += "Attempting to save " + materials.count as string + " VRay materials\n"
        
        -- Method 1: Try Slate Material Editor (if available)
        try (
            -- Check if SME functions are available
            if (SME != undefined and SME.CreateMtlLib != undefined) then (
                edtLog.text += "Using Slate Material Editor method\n"
                
                -- Ensure we're using the Slate Material Editor
                MatEditor.mode = #slate
                MatEditor.Open()
                
                -- Small delay to ensure slate editor is loaded
                windows.processPostedMessages()
                sleep 0.5
                
                -- Create a new material library in the slate editor
                SME.CreateMtlLib fileName
                
                -- Add each material to the library
                for i = 1 to materials.count do (
                    local mat = materials[i]
                    edtLog.text += "Adding material: " + mat.name + "\n"
                    SME.AddMtlToMtlLib mat fileName
                )
                
                -- Save the library
                result = SME.SaveMtlLib fileName
                
                if result then (
                    edtLog.text += "Slate Editor save successful\n"
                ) else (
                    edtLog.text += "Slate Editor save returned false\n"
                )
            ) else (
                edtLog.text += "SME functions not available, skipping to fallback method\n"
            )
            
        ) catch (ex1) (
            edtLog.text += "Slate Editor method failed: " + ex1 as string + "\n"
            result = false
        )
        
        -- Method 2: Fallback to Compact Material Editor if Slate failed
        if not result then (
            try (
                edtLog.text += "Using Compact Material Editor fallback method\n"
                
                -- Switch to compact material editor
                MatEditor.mode = #basic
                MatEditor.Open()
                
                -- Store current material editor state
                local originalMats = #()
                for i = 1 to 24 do (
                    originalMats[i] = meditMaterials[i]
                )
                
                -- Calculate how many materials we can save (max 24 slots)
                local matsToSave = amin #(materials.count, 24)
                edtLog.text += "Placing " + matsToSave as string + " materials in editor slots\n"
                
                -- Put materials in slots
                for i = 1 to matsToSave do (
                    meditMaterials[i] = materials[i]
                    activeMeditSlot = i
                )
                
                -- Fill remaining slots with empty materials to avoid issues
                for i = (matsToSave + 1) to 24 do (
                    meditMaterials[i] = standard name:("Empty_Slot_" + i as string)
                )
                
                -- Force update
                windows.processPostedMessages()
                sleep 0.3
                
                -- Try to save using the compact editor method
                result = saveMaterialLibrary fileName
                
                if result then (
                    edtLog.text += "Compact Editor save successful\n"
                ) else (
                    edtLog.text += "Compact Editor save failed\n"
                )
                
                -- Restore original materials
                for i = 1 to 24 do (
                    meditMaterials[i] = originalMats[i]
                )
                
            ) catch (ex2) (
                edtLog.text += "Compact Editor method also failed: " + ex2 as string + "\n"
                result = false
            )
        )
        
        -- Method 3: Last resort - direct file writing (if other methods fail)
        if not result then (
            try (
                edtLog.text += "Attempting direct material library creation\n"
                
                -- Use materialLibrary global array method
                local originalCount = materialLibrary.count
                local originalLib = #()
                
                -- Backup original library
                for i = 1 to originalCount do (
                    originalLib[i] = materialLibrary[i]
                )
                
                -- Set new materials
                materialLibrary.count = materials.count
                for i = 1 to materials.count do (
                    materialLibrary[i] = materials[i]
                )
                
                -- Try to save
                result = saveMaterialLibrary fileName
                
                -- Restore original library
                materialLibrary.count = originalCount
                for i = 1 to originalCount do (
                    materialLibrary[i] = originalLib[i]
                )
                
                if result then (
                    edtLog.text += "Direct library method successful\n"
                ) else (
                    edtLog.text += "All save methods failed\n"
                )
                
            ) catch (ex3) (
                edtLog.text += "Direct method also failed: " + ex3 as string + "\n"
                result = false
            )
        )
        
        -- Verify file was created and has reasonable size
        if result and (doesFileExist fileName) then (
            local fileSize = getFileSize fileName
            edtLog.text += "File created: " + (filenameFromPath fileName) + " (" + fileSize as string + " bytes)\n"
            if fileSize < 100 then (
                edtLog.text += "Warning: File size seems too small, may be corrupted\n"
            )
        ) else if result then (
            edtLog.text += "Save reported success but file doesn't exist\n"
            result = false
        )
        
        return result
    )
    
    -- Function to save Corona material library with better error handling
    fn saveCoronaMaterialLibrary fileName materials = (
        try (
            -- Store current material library state
            local originalCount = materialLibrary.count
            local originalLib = #()
            
            for i = 1 to originalCount do (
                originalLib[i] = materialLibrary[i]
            )
            
            -- Set new materials
            materialLibrary.count = materials.count
            for i = 1 to materials.count do (
                materialLibrary[i] = materials[i]
            )
            
            -- Try to save
            local result = false
            try (
                result = saveMaterialLibrary fileName
                edtLog.text += "Corona library saved successfully\n"
            ) catch (ex) (
                edtLog.text += "Corona save failed: " + ex as string + "\n"
            )
            
            -- Restore original library
            materialLibrary.count = originalCount
            for i = 1 to originalCount do (
                materialLibrary[i] = originalLib[i]
            )
            
            return result
            
        ) catch (ex) (
            edtLog.text += "Exception in saveCoronaMaterialLibrary: " + ex as string + "\n"
            return false
        )
    )
    
    -- Main processing function
    fn createMaterialLibraries = (
        -- Clear previous results
        processedMaterials = #()
        vrayMaterials = #()
        coronaMaterials = #()
        edtLog.text = ""
        
        -- Check processing options
        if not chkVRay.checked and not chkCorona.checked then (
            edtLog.text = "Error: Please check at least one material type to process.\n"
            return false
        )
        
        -- Target folder path
        local targetFolder = edtFolder.text
        if targetFolder[targetFolder.count] != "\\" then targetFolder += "\\"
        
        -- Check if target folder exists
        if not doesFileExist targetFolder then (
            edtLog.text = "Error: Target folder does not exist: " + targetFolder + "\n"
            return false
        )
        
        -- Get current selection
        local sel = selection as array
        
        -- Check if anything is selected
        if sel.count == 0 then (
            edtLog.text = "Error: No objects selected. Please select groups to process.\n"
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
            edtLog.text = "Error: No group head nodes found in selection.\n"
            return false
        )
        
        edtLog.text = "Processing " + (headNodes.count as string) + " group(s)...\n\n"
        
        -- Process each head node
        for headNode in headNodes do (
            edtLog.text += "Processing group: " + headNode.name + "\n"
            
            -- Reset material arrays for this group
            processedMaterials = #()
            vrayMaterials = #()
            coronaMaterials = #()
            
            -- Recursively collect all materials from the group
            processGroupRecursively headNode
            
            local groupName = headNode.name
            local filesCreated = 0
            local errors = #()
            
            -- Create VRay material library if needed
            if chkVRay.checked and vrayMaterials.count > 0 then (
                local vrayFileName = targetFolder + groupName + "_vray.mat"
                
                if doesFileExist vrayFileName then (
                    append errors ("VRay file already exists: " + vrayFileName)
                ) else (
                    if (saveVRayMaterialLibrary vrayFileName vrayMaterials) then (
                        filesCreated += 1
                        edtLog.text += "Created: " + (filenameFromPath vrayFileName) + " (" + (vrayMaterials.count as string) + " materials)\n"
                    ) else (
                        append errors ("Failed to create VRay library: " + vrayFileName)
                    )
                )
            )
            
            -- Create Corona material library if needed
            if chkCorona.checked and coronaMaterials.count > 0 then (
                local coronaFileName = targetFolder + groupName + "_corona.mat"
                
                if doesFileExist coronaFileName then (
                    append errors ("Corona file already exists: " + coronaFileName)
                ) else (
                    if (saveCoronaMaterialLibrary coronaFileName coronaMaterials) then (
                        filesCreated += 1
                        edtLog.text += "Created: " + (filenameFromPath coronaFileName) + " (" + (coronaMaterials.count as string) + " materials)\n"
                    ) else (
                        append errors ("Failed to create Corona library: " + coronaFileName)
                    )
                )
            )
            
            -- Report results for this group
            if filesCreated == 0 and errors.count == 0 then (
                edtLog.text += "No materials found for selected types in this group.\n"
            )
            
            for error in errors do (
                edtLog.text += "Error: " + error + "\n"
            )
            
            edtLog.text += "\n"
        )
        
        edtLog.text += "Processing complete!\n"
        return true
    )
    
    -- Event handlers
    on btnProcess pressed do (
        createMaterialLibraries()
    )
    
    on btnClear pressed do (
        edtLog.text = ""
    )
)

-- Create and show the dialog
createDialog MaterialLibraryGeneratorUI