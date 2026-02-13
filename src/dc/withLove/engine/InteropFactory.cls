Class dc.withLove.engine.InteropFactory Extends %RegisteredObject
{

/// Compiles Interoperability Components AND Registers them in the Tenant Production.
ClassMethod DeployComponent(pSourceCode As %String, pTenantId As %String) As %String
{
    Set tResult = ""
    Try {
        // 1. Sanitization & Fixes
        Set pSourceCode = $Replace(pSourceCode, "```objectscript", "")
        Set pSourceCode = $Replace(pSourceCode, "```xml", "") 
        Set pSourceCode = $Replace(pSourceCode, "```", "")
        
        If (pSourceCode [ "<transform") && (pSourceCode '[ "xmlns:xsi") {
            Set pSourceCode = $Replace(pSourceCode, "<transform", "<transform xmlns:xsi=""[http://www.w3.org/2001/XMLSchema-instance](http://www.w3.org/2001/XMLSchema-instance)""")
        }

        // 2. Identify Class Name
        Set tMatcher = ##class(%Regex.Matcher).%New("Class\s+([\w\.]+)\s+Extends")
        Set tMatcher.Text = pSourceCode
        If 'tMatcher.Locate() Throw ##class(%Exception.General).%New("Parser", 500, , "Could not identify Class Name.")
        Set tOriginalName = tMatcher.Group(1)
        
        // 3. Package Enforcement
        Set tCleanTenant = $ZStrip(pTenantId, "*E", "", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        If tCleanTenant="" Set tCleanTenant = "default"
        
        Set tPkg = "dc.withLove." _ tCleanTenant _ ".interop"
        Set tShortName = $Piece(tOriginalName, ".", *)
        Set tNewName = tPkg _ "." _ tShortName
        
        // Rename logic
        Set pSourceCode = $Replace(pSourceCode, tOriginalName, tNewName)
        
        // 4. Cleanup Previous Version
        If ##class(%Dictionary.ClassDefinition).%ExistsId(tNewName) {
            Do $System.OBJ.Delete(tNewName, "-d")
        }
        
        // 5. Compile the Component Class
        Set tStream = ##class(%Stream.GlobalCharacter).%New()
        Do tStream.Write(pSourceCode)
        Do tStream.Rewind()
        
        Set tSC = $System.OBJ.LoadStream(tStream, "ck-d", .tErr)
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
        
        // ---------------------------------------------------------
        // 6. AUTO-MAGIC: Register in Production
        // Only if it's a Service or Operation (DTLs don't need registration)
        // ---------------------------------------------------------
        If (pSourceCode [ "Ens.BusinessOperation") || (pSourceCode [ "Ens.BusinessService") || (pSourceCode [ "Ens.BusinessProcess") {
            Do ..AddToProduction(tPkg, tNewName)
            Set tResult = tNewName _ " (Added to Production)"
        } Else {
            Set tResult = tNewName _ " (Compiled)"
        }
        
    } Catch ex {
        Set tResult = "ERROR: " _ ex.DisplayString()
    }
    Return tResult
}

/// Checks if Tenant Production exists, creates if not, and adds the item.
ClassMethod AddToProduction(pPackage As %String, pClassName As %String)
{
    Set tProdName = pPackage _ ".Production"
    
    // A. Create Production Class if missing
    If '##class(%Dictionary.ClassDefinition).%ExistsId(tProdName) {
        Set tProdClass = ##class(%Dictionary.ClassDefinition).%New(tProdName)
        Set tProdClass.Super = "Ens.Production"
        Do tProdClass.%Save()
        Do $System.OBJ.Compile(tProdName, "ck-d")
    }
    
    // B. Add Item to Production Configuration
    // We use Ens.Config.Production to manipulate the XData/Settings programmatically
    Set tSC = ##class(Ens.Config.Production).LoadFromClass(tProdName, .tProduction)
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    
    // Check if item already exists to avoid duplicates
    Set tFound = 0
    For i=1:1:tProduction.Items.Count() {
        If tProduction.Items.GetAt(i).ClassName = pClassName Set tFound = 1 Quit
    }
    
    If 'tFound {
        Set tItem = ##class(Ens.Config.Item).%New()
        Set tItem.ClassName = pClassName
        
        // Naming convention: Use the short class name
        Set tItem.Name = $Piece(pClassName, ".", *) 
        
        // Default Settings based on type
        If (pClassName [ "Operation") {
            Set tItem.PoolSize = 1
        } Else {
            Set tItem.PoolSize = 0 // Services usually 0 or 1
        }
        
        Do tItem.EnabledSet(1)
        Do tProduction.Items.Insert(tItem)
        
        // Save the Production Configuration back to the Class
        Set tSC = tProduction.SaveToClass()
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
        
        // C. Update Production (Live Update)
        // Compile the production again to ensure XData is fresh
        Do $System.OBJ.Compile(tProdName, "ck-d")
        
        // If Production is running, update it. If not, don't worry (it will load next start)
        If ##class(Ens.Director).IsProductionRunning(tProdName) {
            Do ##class(Ens.Director).UpdateProduction(tProdName)
        }
    }
}

}
