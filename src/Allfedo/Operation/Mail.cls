Include Ensemble

/// Sends actual SMTP email. Server acknowledgement is delivery-channel evidence, never recipient acceptance.
Class Allfedo.Operation.Mail Extends Ens.BusinessOperation
{
Parameter ADAPTER = "EnsLib.EMail.OutboundAdapter";
Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems><MapItem MessageType="Allfedo.Message.DeliveryRequest"><Method>Deliver</Method></MapItem></MapItems>
}

Method Deliver(request As Allfedo.Message.DeliveryRequest, Output response As Allfedo.Message.DeliveryResponse) As %Status
{
    Set response=##class(Allfedo.Message.DeliveryResponse).%New(), key="outbox:"_request.OutboxId
    Lock +^Allfedo.Lock(key):0
    If '$Test { Set response.State="already_in_progress" Quit $$$OK }
    Set item=""
    Try {
        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",request.OutboxId)
        Do ##class(Allfedo.Rescue).Require($IsObject(item),"This delivery intention does not exist.")
        If (item.State="sent")||(item.State="superseded")||(item.State="failed") {
            Set response.State=item.State
        } ElseIf (item.State="pending")&&(item.DueAt>##class(Allfedo.Policy).Now()) {
            Set response.State="retry_scheduled"
        } Else {
            Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",item.AllocationId), now=##class(Allfedo.Policy).Now()
            If '$IsObject(allocation) {
                Set item.State="superseded"
            } ElseIf (allocation.State'="held")||(allocation.Revision'=item.AllocationRevision)||(now>=allocation.HoldUntil) {
                Set item.State="superseded"
            } ElseIf item.Attempts>=5 {
                Set item.State="failed", item.LastError="Five delivery attempts were made. Check the inbox and service before any further send."
            } Else {
                // No database transaction spans this outside send. A lost acknowledgement can cause a duplicate email.
                Set item.Attempts=item.Attempts+1
                Do ##class(Allfedo.Rescue).Save(item)
                Set mail=##class(%Net.MailMessage).%New()
                Set mail.From=..Adapter.From, mail.Subject=item.Subject
                Do mail.To.Insert(item.Recipient), mail.TextData.Write(item.Body)
                Set status=..Adapter.SendMail(mail,.failedRecipients)
                If $$$ISERR(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
                If $IsObject(failedRecipients) Do ##class(Allfedo.Rescue).Require(failedRecipients.Count()=0,"The email server rejected the destination.")
                Set item.State="sent", item.SentAt=##class(Allfedo.Policy).Now(), item.LastError=""
            }
            Set item.LeaseUntil=0
            Do ##class(Allfedo.Rescue).Save(item)
            Set response.State=item.State
        }
    } Catch error {
        If $IsObject(item) {
            Set item.State=$Select(item.Attempts>=5:"failed",1:"pending"), item.LeaseUntil=0
            Set item.DueAt=##class(Allfedo.Policy).Now()+(15*(2**item.Attempts)), item.LastError="SMTP delivery was not confirmed. Check the destination and mail service."
            Try {
                Do ##class(Allfedo.Rescue).Save(item)
                Set response.State=item.State
            } Catch saveError {
                Set response.State="delivery_state_unknown"
            }
        } Else {
            Set response.State="missing"
        }
        $$$LOGWARNING("Allfedo SMTP delivery was not confirmed. The saved outbox row owns retry or follow-up.")
    }
    Lock -^Allfedo.Lock(key)
    Quit $$$OK
}
}
