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
            Set stale=..ObsoleteReason(item,allocation)
            If stale'="" {
                Set item.State="superseded",item.LastError=stale
            } ElseIf item.Attempts>=5 {
                Set item.State="failed", item.LastError="Five delivery attempts were made. Check the inbox and service before any further send."
            } Else {
                // No database transaction spans this outside send. A lost acknowledgement can cause a duplicate email.
                Set item.Attempts=item.Attempts+1
                Do ##class(Allfedo.Rescue).Save(item)
                Set mail=##class(%Net.MailMessage).%New()
                Set mail.From=..Adapter.From, mail.Subject=item.Subject,mail.Charset="utf-8"
                Do mail.To.Insert(item.Recipient), mail.TextData.Write(..Text(item,allocation))
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

/// A later state can obsolete a request, but must not hide a factual change notification.
ClassMethod ObsoleteReason(item As Allfedo.Record.Outbox, allocation As Allfedo.Record.Allocation) As %String
{
    If '$IsObject(allocation) Quit "The saved collection no longer exists."
    If allocation.NetworkId'=item.NetworkId Quit "The notification does not belong to this collection's network."
    Set contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",item.RecipientActorId)
    If '$IsObject(contact) Quit "The addressed partner account is no longer available."
    If 'contact.Active||(contact.NetworkId'=item.NetworkId)||(contact.Email'=item.Recipient) Quit "The addressed contact changed. Review the current contact before sending."
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    If '$IsObject(offer)||'$IsObject(need) Quit "The food or receiving record no longer exists."
    If (offer.NetworkId'=item.NetworkId)||(need.NetworkId'=item.NetworkId) Quit "The food and receiving records are outside this network."
    Set party=$Select((contact.Role="recipient")&&(contact.OrganizationId=need.OrganizationId):"recipient",(contact.Role="kitchen")&&(contact.OrganizationId=offer.OrganizationId):"kitchen",(contact.Role="collector")&&(contact.%Id()=allocation.CollectorActorId):"collector",1:"")
    If party="" Quit "This account no longer has a responsibility in the collection."
    If (item.Purpose="")||(item.Purpose="invitation") {
        If (party'="recipient")||(allocation.State'="held")||(allocation.Revision'=item.AllocationRevision)||(##class(Allfedo.Policy).Now()>=allocation.HoldUntil) Quit "This invitation is no longer awaiting the original reply."
        Quit ""
    }
    If item.Purpose="withdrawn" Quit ""
    If (item.Purpose'="change_request")&&(item.Purpose'="change_applied") Quit "The notification purpose is not recognized."
    Set change=##class(Allfedo.Rescue).Open("Allfedo.Record.ChangeRequest",item.RelatedChangeId)
    If '$IsObject(change) Quit "The related promise change no longer exists."
    If (change.NetworkId'=item.NetworkId)||(change.AllocationId'=allocation.%Id()) Quit "The related change does not belong to this collection."
    If item.Purpose="change_applied" Quit $Select(change.State="applied":"",1:"This proposed change was not applied.")
    If (change.State'="awaiting_response")||(allocation.PendingChangeId'=change.%Id()) Quit "This change no longer needs the requested replies."
    If party="recipient",('change.RecipientRequired||(change.RecipientSourceId'="")) Quit "The receiving partner no longer needs to reply to this change."
    If party="kitchen",('change.KitchenRequired||(change.KitchenSourceId'="")) Quit "The kitchen no longer needs to reply to this change."
    If party="collector",change.CollectorSourceId'="" Quit "The collector already replied to this change."
    Quit ""
}

/// Plain text keeps instructions useful in every inbox. The signed-in case owns the latest state.
ClassMethod Text(item As Allfedo.Record.Outbox, allocation As Allfedo.Record.Allocation) As %String
{
    Set context=##class(Allfedo.Recovery).CurrentContext(allocation),details=context.details,newline=$Char(13,10),body=item.Body
    Set pickup=details.pickup,destination=details.destination,food=details.food
    If item.Purpose="invitation" {
        Set body="Please accept or decline this food invitation before " _ ..At(##class(Allfedo.Policy).ISO(allocation.HoldUntil),destination."time_zone") _ ". This is a temporary hold; no collector or trip is confirmed."
    } ElseIf (item.Purpose="change_request")||(item.Purpose="change_applied") {
        Set change=##class(Allfedo.Rescue).Open("Allfedo.Record.ChangeRequest",item.RelatedChangeId)
        Set body=$Select(item.Purpose="change_request":"Proposed change: ",1:"Saved promise change: ") _ change.OriginalQuantity _ " to " _ change.NewQuantity _ " meal boxes." _ newline _ "Reason: " _ change.Reason
        Set body=body _ newline _ $Select(item.Purpose="change_request":"Open the case to review and reply. A proposal alone does not change the promise.",1:"This describes the saved change. Later updates may already exist; read the current case before acting.")
    }
    Set text="Allfedo | Collection " _ allocation.%Id() _ newline _ newline _ body _ newline _ newline
    Set text=text _ "Food: " _ food.description _ newline _ "From: " _ pickup.name _ newline _ "Receiving team: " _ destination.name _ newline
    Set text=text _ "Current recorded quantity: " _ allocation.Quantity _ " meal boxes" _ newline
    If item.Purpose="invitation" {
        Set text=text _ "Ready: " _ ..At(food."ready_at",pickup."time_zone") _ newline _ "Collect before: " _ ..At(food."collect_by",pickup."time_zone") _ newline
        Set text=text _ "Handling deadline: " _ ..At(food."handling_until",pickup."time_zone") _ newline
        Set text=text _ "Receiving from: " _ ..At(details.receiving."receiving_from",destination."time_zone") _ newline _ "Receiving before: " _ ..At(details.receiving."receiving_until",destination."time_zone") _ newline
        Set text=text _ "Holding: " _ food.holding _ newline _ "Packing: " _ $Select(food.packaging="":"Not confirmed",1:food.packaging) _ newline
        Set text=text _ "Review the declared allergens, handling limits, pickup address and receiving instructions before accepting." _ newline
    }
    Set text=text _ newline _ "Open the saved case: " _ ..PublicURL() _ "#/allocations/" _ allocation.%Id() _ newline _ newline
    Quit text _ "Sign in with your invited account. Email delivery does not confirm acceptance, collection or receipt."
}

ClassMethod At(value As %String, zone As %String) As %String [ Language = python ]
{
    from datetime import datetime
    from zoneinfo import ZoneInfo
    if not value:
        return "Not confirmed"
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(ZoneInfo(zone or "UTC")).strftime("%d %b %Y, %H:%M %Z")
}

ClassMethod PublicURL(value As %String = "") As %String [ Language = python ]
{
    import os
    from urllib.parse import urlsplit, urlunsplit
    value = value or os.environ.get("ALLFEDO_PUBLIC_URL", "http://127.0.0.1:52773/allfedo/")
    parsed = urlsplit(value)
    if (any(ord(char) <= 32 for char in value) or parsed.scheme not in {"http", "https"}
            or not parsed.hostname or parsed.username is not None or parsed.password is not None
            or parsed.query or parsed.fragment or parsed.path.rstrip("/") != "/allfedo"):
        raise ValueError("ALLFEDO_PUBLIC_URL must be the application's http(s) /allfedo/ address, without credentials or a query.")
    parsed.port  # Validate a supplied port without copying request headers into links.
    return urlunsplit((parsed.scheme, parsed.netloc, "/allfedo/", "", ""))
}
}
