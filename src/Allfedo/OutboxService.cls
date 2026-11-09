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
        Set id=""_query.ID, key="outbox:"_id, claimed=0,lease=now+120
        Lock +^Allfedo.Lock(key):0
        If $Test {
            Try {
                Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",id)
                If $IsObject(item)&&((item.State="pending")||(item.State="queued"))&&(item.LeaseUntil<=now) {
                    Set item.State="queued", item.LeaseUntil=lease
                    Do ##class(Allfedo.Rescue).Save(item)
                    Set claimed=1
                }
            } Catch error {
                $$$LOGWARNING("Allfedo could not queue a saved notification. Its lease allows later recovery.")
            }
            Lock -^Allfedo.Lock(key)
        }
        If claimed {
            // The receiver needs this same lock. Never queue delivery while retaining it.
            Set message=##class(Allfedo.Message.DeliveryRequest).%New(),message.OutboxId=id
            Try {
                Set status=..SendRequestAsync("Allfedo.Mail",message)
            } Catch queueError {
                Set status=$$$ERROR($$$GeneralError,"The native delivery request could not be queued.")
            }
            If $$$ISERR(status) {
                Lock +^Allfedo.Lock(key):2
                If $Test {
                    Try {
                        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",id)
                        If $IsObject(item)&&(item.State="queued")&&(item.LeaseUntil=lease) {
                            Set item.State="pending",item.LeaseUntil=0,item.DueAt=##class(Allfedo.Policy).Now()+15,item.LastError="The native delivery request could not be queued."
                            Do ##class(Allfedo.Rescue).Save(item)
                        }
                    } Catch resetError {
                        $$$LOGWARNING("Allfedo could not reset a delivery lease. Its expiry allows later recovery.")
                    }
                    Lock -^Allfedo.Lock(key)
                }
            }
        }
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit $$$OK
}
}
