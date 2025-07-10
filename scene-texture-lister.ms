-- Function to collect texture file paths from a material or map
fn collectTexturePaths mat texturePaths debugLevel:0 =
(
    if mat != undefined do
    (
        local indent = ""
        for i = 1 to debugLevel do indent += "  "
        
        -- Log material being processed
        format "%Processing material: % (class: %)\n" indent (mat.name as string) (classOf mat)
        
        -- Check for Bitmaptexture and other map types
        for prop in (getPropNames mat) do
        (
            propVal = getProperty mat prop
            -- Handle Bitmaptexture directly
            if (classOf propVal == Bitmaptexture and propVal.filename != undefined and propVal.filename != "") do
            (
                format "%Found Bitmaptexture: %\n" indent propVal.filename
                appendIfUnique texturePaths propVal.filename
            )
            -- Handle V-Ray specific maps
            if (classOf propVal == VRayMap or 
                classOf propVal == VRayBitmap or 
                classOf propVal == VRayNormalMap or 
                classOf propVal == VRayColor or 
                classOf propVal == VRayTriplanar or 
                classOf propVal == VRayMultiSubTex or 
                classOf propVal == VRayCompTex) do
            (
                if propVal != undefined do
                (
                    -- Check for bitmap property in V-Ray maps
                    if (hasProperty propVal "bitmap") and propVal.bitmap != undefined and propVal.bitmap.filename != undefined do
                    (
                        format "%Found V-Ray map bitmap: %\n" indent propVal.bitmap.filename
                        appendIfUnique texturePaths propVal.bitmap.filename
                    )
                    -- Recursively check sub-maps
                    for subProp in (getPropNames propVal) do
                    (
                        subPropVal = getProperty propVal subProp
                        if (superClassOf subPropVal == textureMap) do
                        (
                            format "%Recursing into sub-map: % (class: %)\n" indent (subPropVal as string) (classOf subPropVal)
                            collectTexturePaths subPropVal texturePaths debugLevel:(debugLevel + 1)
                        )
                    )
                )
            )
            -- Recursively check if property is a material or map
            if (superClassOf propVal == material or superClassOf propVal == textureMap) do
            (
                format "%Recursing into property: % (class: %)\n" indent (propVal as string) (classOf propVal)
                collectTexturePaths propVal texturePaths debugLevel:(debugLevel + 1)
            )
        )
        
        -- Handle specific material types
        if (classOf mat == Multimaterial) do
        (
            format "%Processing Multimaterial sub-materials\n" indent
            for subMat in mat.materialList where subMat != undefined do
            (
                collectTexturePaths subMat texturePaths debugLevel:(debugLevel + 1)
            )
        )
        if (classOf mat == VRayBlendMtl) do
        (
            format "%Processing VRayBlendMtl\n" indent
            if mat.baseMtl != undefined do
            (
                collectTexturePaths mat.baseMtl texturePaths debugLevel:(debugLevel + 1)
            )
            for subMat in mat.blend where subMat != undefined do
            (
                collectTexturePaths subMat texturePaths debugLevel:(debugLevel + 1)
            )
        )
        if (classOf mat == VRay2SidedMtl) do
        (
            format "%Processing VRay2SidedMtl\n" indent
            if mat.frontMtl != undefined do (collectTexturePaths mat.frontMtl texturePaths debugLevel:(debugLevel + 1))
            if mat.backMtl != undefined do (collectTexturePaths mat.backMtl texturePaths debugLevel:(debugLevel + 1))
        )
    )
)

-- Main script
(
    texturePaths = #() -- Array to store texture file paths
    
    -- Collect textures from scene materials
    format "Scanning scene objects...\n"
    for obj in objects where obj.material != undefined do
    (
        format "Object: % has material: %\n" obj.name (obj.material.name as string)
        collectTexturePaths obj.material texturePaths
    )
    
    -- Collect textures from scene environment map
    format "Checking environment map...\n"
    if environmentMap != undefined do
    (
        if (classOf environmentMap == Bitmaptexture and environmentMap.filename != undefined) do
        (
            format "Found environment map texture: %\n" environmentMap.filename
            appendIfUnique texturePaths environmentMap.filename
        )
        -- Recursively check environment map for sub-maps
        collectTexturePaths environmentMap texturePaths
    )
    
    -- Output textures to the listener, separated by commas
    if texturePaths.count > 0 then
    (
        print (texturePaths as string)
        format "Textures found: %\n" (join texturePaths ", ")
    )
    else
    (
        print "No textures found in the scene."
    )
)