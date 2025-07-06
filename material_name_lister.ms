-- Material Names Lister Script
-- Simple UI to display all material names from selected objects
-- Handles VRay materials, Multi-materials, and standard materials

global materialNamesDialog

fn getMaterialNamesFromObjects objs =
(
    local materialNames = #()
    local uniqueNames = #()
    
    for obj in objs do
    (
        if obj.material != undefined then
        (
            local matName = ""
            
            -- Handle different material types
            if classof obj.material == VRayMtl then
            (
                matName = obj.material.name
                if matName == "" then matName = "Unnamed VRay Material"
                
                -- Check if already in list
                if findItem uniqueNames matName == 0 then
                (
                    append uniqueNames matName
                    append materialNames ("VRay Material: " + matName)
                )
            )
            else if classof obj.material == Multimaterial then
            (
                -- Handle multi-materials
                local multiMatName = obj.material.name
                if multiMatName == "" then multiMatName = "Unnamed Multi-Material"
                
                if findItem uniqueNames multiMatName == 0 then
                (
                    append uniqueNames multiMatName
                    append materialNames ("Multi-Material: " + multiMatName)
                )
                
                -- Also list sub-materials
                for i = 1 to obj.material.materialList.count do
                (
                    local subMat = obj.material.materialList[i]
                    if subMat != undefined then
                    (
                        local subMatName = subMat.name
                        if subMatName == "" then subMatName = ("Sub-Material " + i as string)
                        
                        local fullSubName = multiMatName + " -> " + subMatName
                        if findItem uniqueNames fullSubName == 0 then
                        (
                            append uniqueNames fullSubName
                            local matType = "Standard"
                            if classof subMat == VRayMtl then matType = "VRay"
                            append materialNames ("  " + matType + " Sub-Material: " + subMatName)
                        )
                    )
                )
            )
            else
            (
                -- Handle standard materials and others
                matName = obj.material.name
                if matName == "" then matName = "Unnamed Material"
                
                if findItem uniqueNames matName == 0 then
                (
                    append uniqueNames matName
                    local matType = classof obj.material as string
                    append materialNames (matType + ": " + matName)
                )
            )
        )
    )
    
    return materialNames
)

fn createMaterialNamesUI =
(
    -- Close existing dialog if open
    try (destroyDialog materialNamesDialog) catch()
    
    rollout materialNamesDialog "Material Names Lister" width:400 height:500
    (
        button btnRun "Get Material Names" width:380 height:30 pos:[10,10]
        label lblCount "Select objects and click the button above" pos:[10,50]
        listbox lstMaterials "" width:380 height:25 pos:[10,70]
        button btnClear "Clear List" width:180 height:25 pos:[10,450]
        button btnExport "Export to File" width:180 height:25 pos:[200,450]
        
        on btnRun pressed do
        (
            local selectedObjs = getCurrentSelection()
            
            if selectedObjs.count == 0 then
            (
                lblCount.text = "No objects selected!"
                lstMaterials.items = #()
                return()
            )
            
            local materialNames = getMaterialNamesFromObjects selectedObjs
            
            if materialNames.count > 0 then
            (
                lstMaterials.items = materialNames
                lblCount.text = (materialNames.count as string + " unique materials found from " + selectedObjs.count as string + " objects")
            )
            else
            (
                lstMaterials.items = #("No materials found on selected objects")
                lblCount.text = "No materials found on " + selectedObjs.count as string + " selected objects"
            )
        )
        
        on btnClear pressed do
        (
            lstMaterials.items = #()
            lblCount.text = "List cleared - Select objects and click 'Get Material Names'"
        )
        
        on btnExport pressed do
        (
            if lstMaterials.items.count > 0 and lstMaterials.items[1] != "No materials found on selected objects" then
            (
                local fileName = getSaveFileName caption:"Export Material Names" types:"Text Files (*.txt)|*.txt"
                
                if fileName != undefined then
                (
                    try
                    (
                        local file = createFile fileName
                        if file != undefined then
                        (
                            format "Material Names Report\n" to:file
                            format "Generated: %\n" (localTime) to:file
                            format "==========================================\n\n" to:file
                            
                            for matName in lstMaterials.items do
                                format "%\n" matName to:file
                            
                            close file
                            messageBox ("Material names exported to:\n" + fileName) title:"Export Complete"
                        )
                        else
                        (
                            messageBox "Error: Could not create file" title:"Export Error"
                        )
                    )
                    catch
                    (
                        messageBox "Error: Failed to export file" title:"Export Error"
                    )
                )
            )
            else
            (
                messageBox "No material data to export" title:"Export"
            )
        )
        
        on materialNamesDialog open do
        (
            lblCount.text = "Select objects and click 'Get Material Names' to start"
        )
    )
    
    createDialog materialNamesDialog
)

-- Run the UI
createMaterialNamesUI()