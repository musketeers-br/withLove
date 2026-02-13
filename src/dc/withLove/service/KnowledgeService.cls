Class dc.withLove.service.KnowledgeService Extends %RegisteredObject
{

/// Adiciona um documento, gera o vetor automaticamente e salva.
ClassMethod AddDocument(pTenantId As %String, pTitle As %String, pContent As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tKB = ##class(dc.withLove.storage.KnowledgeBase).%New()
        Set tKB.TenantID = pTenantId
        Set tKB.Title = pTitle
        Set tKB.Content = pContent
        
        Set tVectorStr = ##class(dc.withLove.engine.GenAi).GenerateEmbedding(pContent)
        If (tVectorStr = "") || (tVectorStr = "[]") {
            Throw ##class(%Exception.General).%New("Embedding Error", 500, , "Could not generate vector.")
        }

        Set tKB.Embedding = tKB.EmbeddingDisplayToLogical(tVectorStr)

        Set tSC = tKB.%Save()
        
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Return tSC
}

ClassMethod ListDocuments(pTenantId As %String) As %DynamicArray
{
    Set tList = []
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Title FROM dc_withLove_storage.KnowledgeBase WHERE TenantID = ?", pTenantId)
    While tRS.%Next() {
        Do tList.%Push({ "id": (tRS.ID), "title": (tRS.Title) })
    }
    Return tList
}

}
