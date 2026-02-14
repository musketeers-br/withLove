Class dc.withLove.service.ScannerService Extends %RegisteredObject
{

Query GetAllClasses() As %SQLQuery(COMPILEMODE = "IMMEDIATE", ROWSPEC = "ID:%String", SELECTMODE = "RUNTIME") [ SqlProc ]
{
    SELECT ID
    FROM %Dictionary.ClassDefinition 
    WHERE Super LIKE '%Persistent%'
    AND Name NOT LIKE '%Lib%'
    AND Name NOT LIKE '%System%'  
    AND Name NOT LIKE 'Ens%'  
    AND Name NOT LIKE 'HS%'  
    AND Name NOT LIKE 'INFORMATION.SCHEMA%'  
    AND Name NOT LIKE 'dc.withLove.engine%'
}

Query GetProperties(pClassName As %String) As %SQLQuery(COMPILEMODE = "IMMEDIATE", ROWSPEC = "Name:%String, Type:%String", SELECTMODE = "RUNTIME") [ SqlProc ]
{
    SELECT Name, Type FROM %Dictionary.PropertyDefinition WHERE parent = :pClassName
}

/// Lists all Persistent Classes (Tables) belonging to the user/tenant.
/// Filters out system classes and libraries to reduce noise.
ClassMethod ScanTenantClasses(pTenantId As %String) As %String
{
    Set tSchemaInfo = []
    
    Set tPropStat =  ##class(%SQL.Statement).%New()
    $$$ThrowOnError(tPropStat.%PrepareClassQuery("dc.withLove.service.ScannerService", "GetProperties"))
    Set statement = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(statement.%PrepareClassQuery("dc.withLove.service.ScannerService", "GetAllClasses"))
    Set tRS = statement.%Execute()
    
    While tRS.%Next() {
        Set tClassName = tRS.%Get("ID")
        Continue:($Extract(tClassName, 1) = "%")
        Continue:($Extract(tClassName, 1, 4) = "Ens.")
        Continue:($Extract(tClassName, 1, 3) = "HS.") 
        Continue:($Extract(tClassName, 1, 4) = "CSP.") 
        Continue:($Extract(tClassName, 1, 11) = "dc.withLove") 
        // ---------------------------------------
        Set tClassObj = { "className": (tClassName), "properties": [] }
        
        Set tPropRS = tPropStat.%Execute(tClassName) 
        
        While tPropRS.%Next() {
            If ($Extract(tPropRS.%Get("Name"), 1) '= "%") {
                Do tClassObj.properties.%Push(tPropRS.%Get("Name") _ " (" _ tPropRS.%Get("Type") _ ")")
            }
        }
        
        Do tSchemaInfo.%Push(tClassObj)
    }
    If tSchemaInfo.%Size() = 0 {
        Return "No legacy tables found in this Namespace. The scanner ignored system classes and 'dc.withLove' classes."
    }
    
    Return tSchemaInfo.%ToJSON()
}

/// Retrieves the full source code (UDL) of a given asset.
/// Used by the AI to analyze structure and suggest improvements.
ClassMethod GetAssetContent(pAssetName As %String) As %String
{
    Set tContent = ""
    Try {
        // Check if class exists
        If ##class(%Dictionary.ClassDefinition).%ExistsId(pAssetName) {
            Set tStream = ##class(%Stream.GlobalCharacter).%New()
            // Export class definition to stream
            Do ##class(%Dictionary.ClassDefinition).%OpenId(pAssetName).ExportToStream(.tStream)
            Do tStream.Rewind()
            Set tContent = tStream.Read($$$MaxStringLength)
        } Else {
            Set tContent = "Class not found: " _ pAssetName
        }
    } Catch ex {
        Set tContent = "Error retrieving content: " _ ex.DisplayString()
    }
    Return tContent
}

}
