-- VRay Map Inspector Script
-- Shows map information for VRay materials in selected groups
-- Exports results to a text file
-- Updated to support VRay Blend Materials

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

fn processVRayBlendMaterial blendMat uniqueMaterialMaps =
(
    print ("Processing VRay Blend Material: " + blendMat.name)
    
    -- Debug: Print all properties of the blend material
    try
    (
        local props = getPropNames blendMat
        print ("Blend Material Properties: " + props as string)
    )
    catch()
    
    -- Process base material (VRay Blend typically has one base material)
    try
    (
        if hasProperty blendMat "baseMtl" then
        (
            local baseMat = blendMat.baseMtl
            if baseMat != undefined then
            (
                print ("Found base material: " + baseMat.name)
                processMaterial baseMat uniqueMaterialMaps ("Base Material - ")
            )
        )
    )
    catch (ex)
    (
        print ("Error accessing base material: " + ex as string)
    )
    
    -- Process coat materials (VRay Blend can have multiple coat materials)
    for i = 1 to 9 do  -- VRay Blend supports up to 9 coat materials
    (
        try
        (
            local coatPropName = "coatMtl_" + (i as string)
            if hasProperty blendMat coatPropName then
            (
                local coatMat = getProperty blendMat coatPropName
                if coatMat != undefined then
                (
                    print ("Found coat material " + i as string + ": " + coatMat.name)
                    processMaterial coatMat uniqueMaterialMaps ("Coat Material " + i as string + " - ")
                )
            )
        )
        catch (ex)
        (
            print ("Error accessing coat material " + i as string + ": " + ex as string)
        )
    )
    
    -- Alternative approach: try different naming conventions
    for i = 1 to 9 do
    (
        try
        (
            local coatPropName = "coatMtl" + (i as string)
            if hasProperty blendMat coatPropName then
            (
                local coatMat = getProperty blendMat coatPropName
                if coatMat != undefined then
                (
                    print ("Found coat material (alt) " + i as string + ": " + coatMat.name)
                    processMaterial coatMat uniqueMaterialMaps ("Coat Material " + i as string + " - ")
                )
            )
        )
        catch()
    )
    
    -- Process blend amounts (these can also have maps)
    for i = 1 to 9 do
    (
        try
        (
            local blendPropName = "blendAmount_" + (i as string)
            if hasProperty blendMat blendPropName then
            (
                local blendAmount = getProperty blendMat blendPropName
                if blendAmount != undefined and isKindOf blendAmount TextureMap then
                (
                    local bitmapFiles = findBitmapInMap blendAmount
                    if bitmapFiles.count > 0 then
                    (
                        local materialEntry = blendMat.name + " - Blend Amount " + i as string + ":"
                        local mapList = #()
                        
                        for bitmapFile in bitmapFiles do
                        (
                            append mapList ("Blend Amount: " + bitmapFile)
                        )
                        
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
        catch()
    )
    
    -- Try alternative blend amount naming
    for i = 1 to 9 do
    (
        try
        (
            local blendPropName = "blendAmount" + (i as string)
            if hasProperty blendMat blendPropName then
            (
                local blendAmount = getProperty blendMat blendPropName
                if blendAmount != undefined and isKindOf blendAmount TextureMap then
                (
                    local bitmapFiles = findBitmapInMap blendAmount
                    if bitmapFiles.count > 0 then
                    (
                        local materialEntry = blendMat.name + " - Blend Amount " + i as string + ":"
                        local mapList = #()
                        
                        for bitmapFile in bitmapFiles do
                        (
                            append mapList ("Blend Amount: " + bitmapFile)
                        )
                        
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
        catch()
    )
)

fn processMaterial mat uniqueMaterialMaps prefix:"" =
(
    if mat == undefined then
        return false
    
    if classof mat == VRayMtl then
    (
        local mapList = getMaterialMaps mat
        if mapList.count > 0 then
        (
            local materialEntry = prefix + mat.name + ":"
            
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
    else if classof mat == VRayBlendMtl then
    (
        -- Process VRay Blend Material
        processVRayBlendMaterial mat uniqueMaterialMaps
    )
    else if classof mat == Multimaterial then
    (
        -- Check sub-materials in multi-material
        for j = 1 to mat.materialList.count do
        (
            local subMat = mat.materialList[j]
            if subMat != undefined then
            (
                processMaterial subMat uniqueMaterialMaps ("SubMat " + j as string + " - ")
            )
        )
    )
    
    return true
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
                processMaterial obj.material uniqueMaterialMaps
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