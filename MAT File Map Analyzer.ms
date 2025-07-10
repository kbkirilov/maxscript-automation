-- MAT File Map Analyzer
-- Opens .mat files and recursively finds all maps in the materials

global matFileAnalyzer

struct MatFileAnalyzerStruct (
    -- UI elements
    rolloutObj,
    foundMaps = #(),
    loadedMaterials = #(),
    
    -- Initialize the tool
    fn init = (
        this.createUI()
    ),
    
    -- Create the user interface
    fn createUI = (
        rollout matFileAnalyzerRollout "MAT File Map Analyzer" width:450 height:600 (
            group "MAT File Selection" (
                editText etMatFile "" width:350 height:20 across:2
                button btnBrowse "Browse" width:80 height:20
                button btnLoadMat "Load MAT File" width:430 height:30
            )
            
            group "Loaded Materials" (
                listBox lbMaterials "" width:430 height:8
                button btnAnalyzeSelected "Analyze Selected Material" width:210 height:25 across:2
                button btnAnalyzeAll "Analyze All Materials" width:210 height:25
            )
            
            group "Found Maps" (
                listBox lbMaps "" width:430 height:12
                button btnCopyPath "Copy Path to Clipboard" width:140 height:23 across:3
                button btnShowInExplorer "Show in Explorer" width:140 height:23
                button btnCheckExists "Check if File Exists" width:140 height:23
            )
            
            group "Export Options" (
                button btnExportTxt "Export as TXT" width:140 height:25 across:3
                button btnExportCsv "Export as CSV" width:140 height:25
                button btnExportJson "Export as JSON" width:140 height:25
            )
            
            group "Options" (
                checkBox chkShowPaths "Show Full File Paths" checked:true
                checkBox chkShowEmpty "Include Missing Maps" checked:false
                checkBox chkGroupByMaterial "Group by Material" checked:true
            )
            
            label lblStatus "Ready - Select a .mat file to begin" align:#left
            
            -- Browse for MAT file
            on btnBrowse pressed do (
                local matFile = getOpenFileName caption:"Select MAT File" types:"Material Files (*.mat)|*.mat"
                if matFile != undefined then (
                    etMatFile.text = matFile
                )
            )
            
            -- Load MAT file
            on btnLoadMat pressed do (
                if etMatFile.text == "" then (
                    messageBox "Please select a MAT file first"
                    return false
                )
                
                if not doesFileExist etMatFile.text then (
                    messageBox "MAT file does not exist"
                    return false
                )
                
                lblStatus.text = "Loading MAT file..."
                matFileAnalyzer.loadedMaterials = #()
                
                try (
                    -- Load the material library
                    loadMaterialLibrary etMatFile.text
                    
                    -- Get all materials from the loaded library
                    local matLib = currentMaterialLibrary
                    for i = 1 to matLib.count do (
                        append matFileAnalyzer.loadedMaterials matLib[i]
                    )
                    
                    -- Update materials list
                    local matNames = #()
                    for mat in matFileAnalyzer.loadedMaterials do (
                        append matNames mat.name
                    )
                    lbMaterials.items = matNames
                    
                    lblStatus.text = ("Loaded " + matFileAnalyzer.loadedMaterials.count as string + " materials")
                    
                ) catch (
                    lblStatus.text = "Error loading MAT file"
                    messageBox ("Error loading MAT file: " + getCurrentException())
                )
            )
            
            -- Analyze selected material
            on btnAnalyzeSelected pressed do (
                local sel = lbMaterials.selection
                if sel == 0 then (
                    messageBox "Please select a material from the list"
                    return false
                )
                
                matFileAnalyzer.foundMaps = #()
                lbMaps.items = #()
                
                local selectedMat = matFileAnalyzer.loadedMaterials[sel]
                lblStatus.text = "Analyzing material: " + selectedMat.name
                
                matFileAnalyzer.analyzeMaterial selectedMat ""
                matFileAnalyzer.updateMapsList()
                
                lblStatus.text = ("Found " + matFileAnalyzer.foundMaps.count as string + " maps in " + selectedMat.name)
            )
            
            -- Analyze all materials
            on btnAnalyzeAll pressed do (
                if matFileAnalyzer.loadedMaterials.count == 0 then (
                    messageBox "No materials loaded"
                    return false
                )
                
                matFileAnalyzer.foundMaps = #()
                lbMaps.items = #()
                lblStatus.text = "Analyzing all materials..."
                
                for mat in matFileAnalyzer.loadedMaterials do (
                    matFileAnalyzer.analyzeMaterial mat ""
                )
                
                matFileAnalyzer.updateMapsList()
                lblStatus.text = ("Found " + matFileAnalyzer.foundMaps.count as string + " total maps")
            )
            
            -- Copy selected map path
            on btnCopyPath pressed do (
                local sel = lbMaps.selection
                if sel.count == 0 then (
                    messageBox "Please select a map from the list"
                    return false
                )
                
                local mapInfo = matFileAnalyzer.foundMaps[sel[1]]
                setClipBoardText mapInfo.filename
                lblStatus.text = "Path copied to clipboard"
            )
            
            -- Show in Windows Explorer
            on btnShowInExplorer pressed do (
                local sel = lbMaps.selection
                if sel.count == 0 then (
                    messageBox "Please select a map from the list"
                    return false
                )
                
                local selectedMapInfo = matFileAnalyzer.foundMaps[sel[1]]
                if selectedMapInfo[3] != "" and doesFileExist selectedMapInfo[3] then (
                    shellLaunch "explorer.exe" ("/select,\"" + selectedMapInfo[3] + "\"")
                    lblStatus.text = "Opened in Explorer"
                ) else (
                    lblStatus.text = "File does not exist"
                )
            )
            
            -- Check if file exists
            on btnCheckExists pressed do (
                local sel = lbMaps.selection
                if sel.count == 0 then (
                    messageBox "Please select a map from the list"
                    return false
                )
                
                local selectedMapInfo = matFileAnalyzer.foundMaps[sel[1]]
                if selectedMapInfo[3] != "" then (
                    if doesFileExist selectedMapInfo[3] then (
                        lblStatus.text = "File exists: " + selectedMapInfo[3]
                    ) else (
                        lblStatus.text = "File MISSING: " + selectedMapInfo[3]
                    )
                ) else (
                    lblStatus.text = "No filename specified"
                )
            )
            
            -- Export as TXT
            on btnExportTxt pressed do (
                local filename = getSaveFileName caption:"Export Maps List" types:"Text Files (*.txt)|*.txt"
                if filename != undefined then (
                    matFileAnalyzer.exportAsTxt filename
                    lblStatus.text = "Exported to: " + filename
                )
            )
            
            -- Export as CSV
            on btnExportCsv pressed do (
                local filename = getSaveFileName caption:"Export Maps List" types:"CSV Files (*.csv)|*.csv"
                if filename != undefined then (
                    matFileAnalyzer.exportAsCsv filename
                    lblStatus.text = "Exported to: " + filename
                )
            )
            
            -- Export as JSON
            on btnExportJson pressed do (
                local filename = getSaveFileName caption:"Export Maps List" types:"JSON Files (*.json)|*.json"
                if filename != undefined then (
                    matFileAnalyzer.exportAsJson filename
                    lblStatus.text = "Exported to: " + filename
                )
            )
        )
        
        this.rolloutObj = matFileAnalyzerRollout
        createDialog this.rolloutObj
    ),
    
    -- Update the maps list display
    fn updateMapsList = (
        local displayItems = #()
        local showPaths = this.rolloutObj.chkShowPaths.checked
        local showEmpty = this.rolloutObj.chkShowEmpty.checked
        local groupByMaterial = this.rolloutObj.chkGroupByMaterial.checked
        
        if groupByMaterial then (
            -- Group by material
            local currentMat = ""
            for mapInfo in this.foundMaps do (
                if mapInfo.materialName != currentMat then (
                    append displayItems ("=== " + mapInfo.materialName + " ===")
                    currentMat = mapInfo.materialName
                )
                
                if showEmpty or (mapInfo.filename != "" and mapInfo.filename != undefined) then (
                    local displayText = "  " + mapInfo.mapType + ": "
                    if showPaths then (
                        displayText += mapInfo.filename
                    ) else (
                        displayText += filenameFromPath mapInfo.filename
                    )
                    
                    if mapInfo.filename != "" and not doesFileExist mapInfo.filename then (
                        displayText += " [MISSING]"
                    )
                    
                    append displayItems displayText
                )
            )
        ) else (
            -- Flat list
            for mapInfo in this.foundMaps do (
                if showEmpty or (mapInfo[3] != "" and mapInfo[3] != undefined) then (
                    local displayText = mapInfo[4] + " > " + mapInfo[2] + ": "
                    if showPaths then (
                        displayText += mapInfo[3]
                    ) else (
                        displayText += filenameFromPath mapInfo[3]
                    )
                    
                    if mapInfo[3] != "" and not doesFileExist mapInfo[3] then (
                        displayText += " [MISSING]"
                    )
                    
                    append displayItems displayText
                )
            )
        )
        
        this.rolloutObj.lbMaps.items = displayItems
    ),
    
    -- Recursively analyze material for maps
    fn analyzeMaterial mat path = (
        if mat == undefined then return false
        
        local currentPath = path
        if currentPath != "" then currentPath += " > "
        currentPath += mat.name
        
        case classOf mat of (
            -- MultiSubObject Material
            Multimaterial: (
                for i = 1 to mat.materialList.count do (
                    local subMat = mat.materialList[i]
                    if subMat != undefined then (
                        this.analyzeMaterial subMat (currentPath + " [" + i as string + "]")
                    )
                )
            )
            
            -- VRay Materials
            VRayMtl: (
                this.analyzeVRayMaterial mat currentPath
            )
            
            VRayLightMtl: (
                if mat.texmap != undefined then this.addMap mat.texmap "Color" mat.name currentPath
                if mat.opacity_texmap != undefined then this.addMap mat.opacity_texmap "Opacity" mat.name currentPath
            )
            
            VRayFastSSS2: (
                if mat.overall_color_texmap != undefined then this.addMap mat.overall_color_texmap "Overall Color" mat.name currentPath
                if mat.diffuse_color_texmap != undefined then this.addMap mat.diffuse_color_texmap "Diffuse Color" mat.name currentPath
                if mat.sub_surface_color_texmap != undefined then this.addMap mat.sub_surface_color_texmap "Sub Surface Color" mat.name currentPath
                if mat.scatter_radius_texmap != undefined then this.addMap mat.scatter_radius_texmap "Scatter Radius" mat.name currentPath
                if mat.specular_color_texmap != undefined then this.addMap mat.specular_color_texmap "Specular Color" mat.name currentPath
                if mat.specular_glossiness_texmap != undefined then this.addMap mat.specular_glossiness_texmap "Specular Glossiness" mat.name currentPath
            )
            
            VRayCarPaintMtl: (
                if mat.base_color_texmap != undefined then this.addMap mat.base_color_texmap "Base Color" mat.name currentPath
                if mat.flake_color_texmap != undefined then this.addMap mat.flake_color_texmap "Flake Color" mat.name currentPath
                if mat.coat_color_texmap != undefined then this.addMap mat.coat_color_texmap "Coat Color" mat.name currentPath
            )
            
            VRayBlendMtl: (
                if mat.baseMtl != undefined then this.analyzeMaterial mat.baseMtl (currentPath + " > Base")
                for i = 1 to mat.coatMtl.count do (
                    if mat.coatMtl[i] != undefined then this.analyzeMaterial mat.coatMtl[i] (currentPath + " > Coat" + i as string)
                )
                for i = 1 to mat.blendMtl.count do (
                    if mat.blendMtl[i] != undefined then this.addMap mat.blendMtl[i] ("Blend" + i as string) mat.name currentPath
                )
            )
            
            VRay2SidedMtl: (
                if mat.frontMtl != undefined then this.analyzeMaterial mat.frontMtl (currentPath + " > Front")
                if mat.backMtl != undefined then this.analyzeMaterial mat.backMtl (currentPath + " > Back")
                if mat.translucencyTex != undefined then this.addMap mat.translucencyTex "Translucency" mat.name currentPath
            )
            
            -- Standard 3ds Max Materials
            Standardmaterial: (
                this.analyzeStandardMaterial mat currentPath
            )
            
            -- Physical Material
            PhysicalMaterial: (
                this.analyzePhysicalMaterial mat currentPath
            )
            
            -- Blend Material
            Blend: (
                if mat.material1 != undefined then this.analyzeMaterial mat.material1 (currentPath + " > Material1")
                if mat.material2 != undefined then this.analyzeMaterial mat.material2 (currentPath + " > Material2")
                if mat.mask != undefined then this.addMap mat.mask "Mask" mat.name currentPath
            )
            
            -- Composite Material
            Composite: (
                if mat.baseMaterial != undefined then this.analyzeMaterial mat.baseMaterial (currentPath + " > Base")
                for i = 1 to mat.materialList.count do (
                    if mat.materialList[i] != undefined then this.analyzeMaterial mat.materialList[i] (currentPath + " > Layer" + i as string)
                )
            )
            
            -- Shell Material
            Shell_Material: (
                if mat.originalMaterial != undefined then this.analyzeMaterial mat.originalMaterial (currentPath + " > Original")
                if mat.bakedMaterial != undefined then this.analyzeMaterial mat.bakedMaterial (currentPath + " > Baked")
            )
            
            -- Architectural Material
            Arch___Design__mi: (
                if mat.diff_color_map != undefined then this.addMap mat.diff_color_map "Diffuse Color" mat.name currentPath
                if mat.refl_color_map != undefined then this.addMap mat.refl_color_map "Reflection Color" mat.name currentPath
                if mat.refr_color_map != undefined then this.addMap mat.refr_color_map "Refraction Color" mat.name currentPath
                if mat.bump_map != undefined then this.addMap mat.bump_map "Bump" mat.name currentPath
                if mat.cutout_map != undefined then this.addMap mat.cutout_map "Cutout" mat.name currentPath
            )
            
            -- Default case - try to find common map properties
            default: (
                this.analyzeGenericMaterial mat currentPath
            )
        )
    ),
    
    -- Analyze VRay material
    fn analyzeVRayMaterial mat currentPath = (
        if mat.texmap_diffuse != undefined then this.addMap mat.texmap_diffuse "Diffuse" mat.name currentPath
        if mat.texmap_reflection != undefined then this.addMap mat.texmap_reflection "Reflection" mat.name currentPath
        if mat.texmap_refraction != undefined then this.addMap mat.texmap_refraction "Refraction" mat.name currentPath
        if mat.texmap_bump != undefined then this.addMap mat.texmap_bump "Bump" mat.name currentPath
        if mat.texmap_opacity != undefined then this.addMap mat.texmap_opacity "Opacity" mat.name currentPath
        if mat.texmap_reflectionGlossiness != undefined then this.addMap mat.texmap_reflectionGlossiness "Reflection Glossiness" mat.name currentPath
        if mat.texmap_refractionGlossiness != undefined then this.addMap mat.texmap_refractionGlossiness "Refraction Glossiness" mat.name currentPath
        if mat.texmap_displacement != undefined then this.addMap mat.texmap_displacement "Displacement" mat.name currentPath
        if mat.texmap_environment != undefined then this.addMap mat.texmap_environment "Environment" mat.name currentPath
        if mat.texmap_selfIllumination != undefined then this.addMap mat.texmap_selfIllumination "Self Illumination" mat.name currentPath
    ),
    
    -- Analyze Standard material
    fn analyzeStandardMaterial mat currentPath = (
        if mat.diffuseMap != undefined then this.addMap mat.diffuseMap "Diffuse" mat.name currentPath
        if mat.specularMap != undefined then this.addMap mat.specularMap "Specular" mat.name currentPath
        if mat.glossinessMap != undefined then this.addMap mat.glossinessMap "Glossiness" mat.name currentPath
        if mat.selfIllumMap != undefined then this.addMap mat.selfIllumMap "Self Illumination" mat.name currentPath
        if mat.opacityMap != undefined then this.addMap mat.opacityMap "Opacity" mat.name currentPath
        if mat.filterMap != undefined then this.addMap mat.filterMap "Filter" mat.name currentPath
        if mat.bumpMap != undefined then this.addMap mat.bumpMap "Bump" mat.name currentPath
        if mat.reflectionMap != undefined then this.addMap mat.reflectionMap "Reflection" mat.name currentPath
        if mat.refractionMap != undefined then this.addMap mat.refractionMap "Refraction" mat.name currentPath
        if mat.displacementMap != undefined then this.addMap mat.displacementMap "Displacement" mat.name currentPath
    ),
    
    -- Analyze Physical material
    fn analyzePhysicalMaterial mat currentPath = (
        if mat.base_color_map != undefined then this.addMap mat.base_color_map "Base Color" mat.name currentPath
        if mat.reflectivity_map != undefined then this.addMap mat.reflectivity_map "Reflectivity" mat.name currentPath
        if mat.roughness_map != undefined then this.addMap mat.roughness_map "Roughness" mat.name currentPath
        if mat.metalness_map != undefined then this.addMap mat.metalness_map "Metalness" mat.name currentPath
        if mat.bump_map != undefined then this.addMap mat.bump_map "Bump" mat.name currentPath
        if mat.displacement_map != undefined then this.addMap mat.displacement_map "Displacement" mat.name currentPath
        if mat.cutout_map != undefined then this.addMap mat.cutout_map "Cutout" mat.name currentPath
        if mat.emission_map != undefined then this.addMap mat.emission_map "Emission" mat.name currentPath
    ),
    
    -- Analyze generic material (fallback)
    fn analyzeGenericMaterial mat currentPath = (
        -- Try to access common map properties using property access
        local props = getPropNames mat
        for prop in props do (
            try (
                local val = getProperty mat prop
                if isKindOf val TextureMap then (
                    this.addMap val (prop as string) mat.name currentPath
                )
            ) catch (
                -- Ignore errors accessing properties
            )
        )
    ),
    
    -- Add map to found maps array
    fn addMap mapObj mapType matName matPath = (
        if mapObj == undefined then return false
        
        local filename = ""
        
        -- Get filename based on map type
        case classOf mapObj of (
            BitmapTexture: (
                if mapObj.filename != undefined then filename = mapObj.filename
            )
            VRayHDRI: (
                if mapObj.HDRIMapName != undefined then filename = mapObj.HDRIMapName
            )
            VRayBitmap: (
                if mapObj.HDRIMapName != undefined then filename = mapObj.HDRIMapName
            )
            default: (
                -- Try to get filename property
                try (
                    if hasProperty mapObj "filename" then filename = mapObj.filename
                    else if hasProperty mapObj "HDRIMapName" then filename = mapObj.HDRIMapName
                    else if hasProperty mapObj "map" then filename = mapObj.map
                ) catch (
                    filename = ""
                )
            )
        )
        
        -- Create map info structure
        local mapInfo = #()
        mapInfo[1] = mapObj -- mapObj
        mapInfo[2] = mapType -- mapType
        mapInfo[3] = filename -- filename
        mapInfo[4] = matName -- materialName
        mapInfo[5] = matPath -- materialPath
        mapInfo[6] = (filename != "" and doesFileExist filename) -- exists
        
        append this.foundMaps mapInfo
        
        -- Recursively analyze sub-maps
        this.analyzeSubMaps mapObj mapType matName matPath
    ),
    
    -- Analyze sub-maps (like in Composite or Mix maps)
    fn analyzeSubMaps mapObj mapType matName matPath = (
        case classOf mapObj of (
            CompositeMap: (
                for i = 1 to mapObj.mapList.count do (
                    if mapObj.mapList[i] != undefined then (
                        this.addMap mapObj.mapList[i] (mapType + " > Layer" + i as string) matName matPath
                    )
                )
            )
            
            Mix: (
                if mapObj.map1 != undefined then this.addMap mapObj.map1 (mapType + " > Color1") matName matPath
                if mapObj.map2 != undefined then this.addMap mapObj.map2 (mapType + " > Color2") matName matPath
                if mapObj.mask != undefined then this.addMap mapObj.mask (mapType + " > Mask") matName matPath
            )
            
            VRayDirt: (
                if mapObj.texmap_unoccluded != undefined then this.addMap mapObj.texmap_unoccluded (mapType + " > Unoccluded") matName matPath
                if mapObj.texmap_occluded != undefined then this.addMap mapObj.texmap_occluded (mapType + " > Occluded") matName matPath
            )
            
            VRayBlendMtl: (
                if mapObj.base_material != undefined then this.addMap mapObj.base_material (mapType + " > Base") matName matPath
                for i = 1 to mapObj.coat_material.count do (
                    if mapObj.coat_material[i] != undefined then this.addMap mapObj.coat_material[i] (mapType + " > Coat" + i as string) matName matPath
                )
            )
        )
    ),
    
    -- Export as TXT
    fn exportAsTxt filename = (
        local file = createFile filename
        if file == undefined then return false
        
        format "Material Maps Analysis\n" to:file
        format "Generated: %\n" (timeStamp()) to:file
        format "Total Maps Found: %\n\n" this.foundMaps.count to:file
        
        for mapInfo in this.foundMaps do (
            format "Material: %\n" mapInfo[4] to:file
            format "Map Type: %\n" mapInfo[2] to:file
            format "Filename: %\n" mapInfo[3] to:file
            format "Exists: %\n" mapInfo[6] to:file
            format "Path: %\n" mapInfo[5] to:file
            format "\n" to:file
        )
        
        close file
    ),
    
    -- Export as CSV
    fn exportAsCsv filename = (
        local file = createFile filename
        if file == undefined then return false
        
        format "Material Name,Map Type,Filename,Exists,Material Path\n" to:file
        
        for mapInfo in this.foundMaps do (
            format "\"%\",\"%\",\"%\",\"%\",\"%\"\n" mapInfo[4] mapInfo[2] mapInfo[3] mapInfo[6] mapInfo[5] to:file
        )
        
        close file
    ),
    
    -- Export as JSON
    fn exportAsJson filename = (
        local file = createFile filename
        if file == undefined then return false
        
        format "{\n" to:file
        format "  \"analysis\": {\n" to:file
        format "    \"timestamp\": \"%\",\n" (timeStamp()) to:file
        format "    \"totalMaps\": %,\n" this.foundMaps.count to:file
        format "    \"maps\": [\n" to:file
        
        for i = 1 to this.foundMaps.count do (
            local mapInfo = this.foundMaps[i]
            format "      {\n" to:file
            format "        \"materialName\": \"%\",\n" mapInfo[4] to:file
            format "        \"mapType\": \"%\",\n" mapInfo[2] to:file
            format "        \"filename\": \"%\",\n" mapInfo[3] to:file
            format "        \"exists\": %,\n" mapInfo[6] to:file
            format "        \"materialPath\": \"%\"\n" mapInfo[5] to:file
            if i < this.foundMaps.count then (
                format "      },\n" to:file
            ) else (
                format "      }\n" to:file
            )
        )
        
        format "    ]\n" to:file
        format "  }\n" to:file
        format "}\n" to:file
        
        close file
    )
)

-- Initialize the tool
matFileAnalyzer = MatFileAnalyzerStruct()
matFileAnalyzer.init()

print "MAT File Map Analyzer loaded successfully!"