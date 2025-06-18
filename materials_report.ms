-- VRay Map Inspector Script
-- Shows map information for VRay materials in selected groups
-- Exports results to a text file

fn getAllObjectsFromGroup grp =
(
    local allObjects = #()
    
    for i = 1 to grp.children.count do
    (
        local child = grp.children[i]
        
        -- If child is a group, recursively get its objects
        if isGroupHead child then
        (
            local subObjects = getAllObjectsFromGroup child
            join allObjects subObjects
        )
        else
        (
            -- Add regular object to array
            append allObjects child
        )
    )
    
    return allObjects
)

fn findBitmapInMap map =
(
    local bitmapFiles = #()
    
    if map == undefined then
        return bitmapFiles
    
    -- Check if this is a bitmap map itself
    if classof map == VRayBitmap then
    (
        if map.HDRIMapName != "" then
        (
            local fileName = filenameFromPath map.HDRIMapName
            append bitmapFiles fileName
        )
    )
    else if classof map == Bitmaptexture then
    (
        if map.filename != "" then
        (
            local fileName = filenameFromPath map.filename
            append bitmapFiles fileName
        )
    )
    else if classof map == VRayHDRI then
    (
        if map.HDRIMapName != "" then
        (
            local fileName = filenameFromPath map.HDRIMapName
            append bitmapFiles fileName
        )
    )
    else
    (
        -- For composite maps, recursively search their sub-maps
        try
        (
            -- Get all properties of the map
            local props = getPropNames map
            
            for prop in props do
            (
                try
                (
                    local propValue = getProperty map prop
                    
                    -- Check if property contains a map
                    if propValue != undefined then
                    (
                        -- Check if it's a single map
                        if isKindOf propValue TextureMap then
                        (
                            local subBitmaps = findBitmapInMap propValue
                            join bitmapFiles subBitmaps
                        )
                        -- Check if it's an array of maps
                        else if classof propValue == Array then
                        (
                            for item in propValue do
                            (
                                if isKindOf item TextureMap then
                                (
                                    local subBitmaps = findBitmapInMap item
                                    join bitmapFiles subBitmaps
                                )
                            )
                        )
                    )
                )
                catch
                (
                    -- Skip properties that can't be accessed
                    continue
                )
            )
        )
        catch
        (
            -- If we can't get properties, skip this map
        )
    )
    
    return bitmapFiles
)

fn getMaterialMaps mat =
(
    local mapList = #()
    
    if classof mat == VRayMtl then
    (
        -- Define map slots to check with their display names
        local mapSlots = #(
            #("texmap_diffuse", "Diffuse"),
            #("texmap_bump", "Bump"),
            #("texmap_normal", "Normal"),
            #("bumpMap", "Bump Map"),
            #("texmap_reflectionGlossiness", "Reflection Glossiness"),
            #("texmap_reflection", "Reflection"),
            #("texmap_opacity", "Opacity"),
            #("texmap_displacement", "Displacement"),
            #("texmap_refraction", "Refraction"),
            #("texmap_translucency", "Translucency"),
            #("texmap_self_illumination", "Self Illumination"),
            #("texmap_environment", "Environment")
        )
        
        -- Check each map slot if it exists on this material
        for slot in mapSlots do
        (
            local propName = slot[1]
            local displayName = slot[2]
            
            try
            (
                local mapTexture = getProperty mat propName
                if mapTexture != undefined then
                (
                    local bitmapFiles = findBitmapInMap mapTexture
                    if bitmapFiles.count > 0 then
                    (
                        for bitmapFile in bitmapFiles do
                        (
                            append mapList (displayName + ": " + bitmapFile)
                        )
                    )
                )
            )
            catch
            (
                -- Property doesn't exist in this VRay version, skip it
                continue
            )
        )
    )
    
    return mapList
)

fn inspectGroupMaps =
(
    local selectedGroups = getCurrentSelection()
    local outputLines = #()
    
    if selectedGroups.count == 0 then
    (
        return false
    )
    
    -- Filter to only process top-level selected groups
    local topLevelGroups = #()
    
    for grp in selectedGroups do
    (
        if isGroupHead grp then
        (
            local isChildOfSelected = false
            local currentParent = grp.parent
            
            while currentParent != undefined do
            (
                for selectedGrp in selectedGroups do
                (
                    if currentParent == selectedGrp then
                    (
                        isChildOfSelected = true
                        exit
                    )
                )
                if isChildOfSelected then exit
                currentParent = currentParent.parent
            )
            
            if not isChildOfSelected then
                append topLevelGroups grp
        )
    )
    
    -- Process only the top-level groups
    for grp in topLevelGroups do
    (
        local allObjects = getAllObjectsFromGroup grp
        local uniqueMaterialMaps = #()
        
        -- Collect all unique material-map combinations
        for obj in allObjects do
        (
            if obj.material != undefined then
            (
                if classof obj.material == VRayMtl then
                (
                    local mapList = getMaterialMaps obj.material
                    if mapList.count > 0 then
                    (
                        local materialEntry = obj.material.name + ":"
                        
                        -- Check if this material is already processed
                        local matFound = false
                        for entry in uniqueMaterialMaps do
                        (
                            if entry[1] == materialEntry then
                            (
                                matFound = true
                                exit
                            )
                        )
                        
                        if not matFound then
                            append uniqueMaterialMaps #(materialEntry, mapList)
                    )
                )
                else if classof obj.material == Multimaterial then
                (
                    -- Check sub-materials in multi-material
                    for j = 1 to obj.material.materialList.count do
                    (
                        local subMat = obj.material.materialList[j]
                        if subMat != undefined and classof subMat == VRayMtl then
                        (
                            local mapList = getMaterialMaps subMat
                            if mapList.count > 0 then
                            (
                                local materialEntry = subMat.name + ":"
                                
                                local matFound = false
                                for entry in uniqueMaterialMaps do
                                (
                                    if entry[1] == materialEntry then
                                    (
                                        matFound = true
                                        exit
                                    )
                                )
                                
                                if not matFound then
                                    append uniqueMaterialMaps #(materialEntry, mapList)
                            )
                        )
                    )
                )
            )
        )
        
        -- Prepare output
        if uniqueMaterialMaps.count > 0 then
        (
            local line1 = "Product: " + grp.name + ":"
            
            -- Print to console
            print line1
            append outputLines line1
            
            for entry in uniqueMaterialMaps do
            (
                local materialName = entry[1]
                local mapList = entry[2]
                
                print ("  " + materialName)
                append outputLines ("  " + "Material-name: " + materialName)
                
                for mapEntry in mapList do
                (
                    print ("    " + mapEntry)
                    append outputLines ("    " + mapEntry)
                )
            )
            
            print ""
            append outputLines ""
        )
        else
        (
            local line1 = "The parent group '" + grp.name + "' has no VRay materials with maps."
            
            print line1
            print ""
            
            append outputLines line1
            append outputLines ""
        )
        append outputLines ("  " + "Additional-materials-and-maps:")
        append outputLines ""
    )
    
    -- Export to file
    if outputLines.count > 0 then
    (
        local fileName = "VRay-Maps-Report.txt"
        local filePath = "R:\\18_PERSONAL\\PROJECTS\\BuzziModels" + "\\" + fileName
        
        try
        (
            local file = createFile filePath
            if file != undefined then
            (
                for line in outputLines do
                    format "%\n" line to:file
                close file
                print ("Results exported to: " + filePath)
            )
            else
            (
                print "Error: Could not create output file"
            )
        )
        catch
        (
            print "Error: Failed to export results to file"
        )
    )
)

-- Run the script
inspectGroupMaps()