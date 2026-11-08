Include Ensemble

/// Native scheduled service. The outbox alone owns bounded mail retries; the operation never asks for retries.
Class Allfedo.OutboxService Extends Ens.BusinessService
{
Parameter ADAPTER = "Ens.InboundAdapter";

Method OnProcessInput(input As %RegisteredObject, Output output As %RegisteredObject) As %Status
{
    Set now=##class(Allfedo.Policy).Now()
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 20 ID FROM Allfedo_Record.Outbox WHERE State IN ('pending','queued') AND DueAt<=? AND LeaseUntil<=? ORDER BY DueAt,ID",now,now)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set id=""_query.ID, key="outbox:"_id
        Lock +^Allfedo.Lock(key):0
        If $Test {
            Try {
                Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",id)
                If $IsObject(item)&&((item.State="pending")||(item.State="queued"))&&(item.LeaseUntil<=now) {
                    Set item.State="queued", item.LeaseUntil=now+120
                    Do ##class(Allfedo.Rescue).Save(item)
                    Set message=##class(Allfedo.Message.DeliveryRequest).%New(), message.OutboxId=id
                    Set status=..SendRequestAsync("Allfedo.Mail",message)
                    If $$$ISERR(status) {
                        Set item.State="pending", item.LeaseUntil=0, item.DueAt=now+15, item.LastError="The native delivery request could not be queued."
                        Do ##class(Allfedo.Rescue).Save(item)
                    }
                }
            } Catch error {
                $$$LOGWARNING("Allfedo could not queue a saved notification. Its lease allows later recovery.")
            }
            Lock -^Allfedo.Lock(key)
        }
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit $$$OK
}
}
