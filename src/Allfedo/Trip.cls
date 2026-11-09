/// Current trip instructions, receiving consent and preserved collector agreements.
Class Allfedo.Trip Extends %RegisteredObject
{
ClassMethod SiteDetails(networkId As %String, organizationId As %String) As %DynamicObject
{
    Set site=##class(Allfedo.Facts).SiteFor(networkId,organizationId)
    If '$IsObject(site) Quit {"name":"","address":"","entrance":"","time_zone":"","contact_name":"","contact_email":"","contact_phone":""}
    Set contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",site.ContactActorId), name="", email=""
    If $IsObject(contact)&&contact.Active&&(contact.NetworkId=networkId)&&(contact.OrganizationId=organizationId) Set name=contact.DisplayName,email=contact.Email
    Quit {"name":(site.Name),"address":(site.Address),"entrance":(site.Entrance),"time_zone":(site.TimeZone),"contact_name":(name),"contact_email":(email),"contact_phone":(site.ContactPhone)}
}

/// Native only: callable by authorized read paths without granting browser users Embedded Python execution.
ClassMethod CurrentContext(allocation As Allfedo.Record.Allocation, quantity As %Integer = -1) As %DynamicObject
{
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId), need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    If quantity<0 Set quantity=allocation.Quantity
    Set holdingUntil=""
    If offer.HandlingUntil'="" Set holdingUntil=##class(Allfedo.Policy).ISO(offer.HandlingUntil)
    Set food={"description":(offer.Description),"holding":(offer.Holding),"handling_until":(holdingUntil),"ready_at":(##class(Allfedo.Policy).ISO(offer.ReadyAt)),"collect_by":(##class(Allfedo.Policy).ISO(offer.CollectBy)),"packaging":(offer.Packaging),"present_allergens":(##class(Allfedo.Rescue).ParseArray(offer.PresentAllergensJSON)),"assessed_allergens":(##class(Allfedo.Rescue).ParseArray(offer.AssessedAllergensJSON))}
    Set receivingFrom=""
    If need.ReceivingFrom'="" Set receivingFrom=##class(Allfedo.Policy).ISO(need.ReceivingFrom)
    Set receiving={"receiving_from":(receivingFrom),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"excluded_allergens":(##class(Allfedo.Rescue).ParseArray(need.ExcludedAllergensJSON)),"accepted_holding":(##class(Allfedo.Rescue).ParseArray(need.AcceptedHoldingJSON))}
    Set details={"allocation_id":(""_allocation.%Id()),"quantity":(""_quantity),"pickup":(..SiteDetails(allocation.NetworkId,offer.OrganizationId)),"destination":(..SiteDetails(allocation.NetworkId,need.OrganizationId)),"food":(food),"receiving":(receiving)}
    Set key=$SYSTEM.Encryption.ToHex($SYSTEM.Encryption.SHAHash(256,$ZCONVERT(details.%ToJSON(),"O","UTF8")))
    Set pickupSite=##class(Allfedo.Facts).SiteFor(allocation.NetworkId,offer.OrganizationId), receivingSite=##class(Allfedo.Facts).SiteFor(allocation.NetworkId,need.OrganizationId), evidence={"food_source_id":(offer.SourceId),"need_source_id":(need.SourceId)}
    If $IsObject(pickupSite) Set evidence."pickup_site_id"=""_pickupSite.%Id(),evidence."pickup_site_revision"=pickupSite.Revision,evidence."pickup_site_source_id"=pickupSite.SourceId
    If $IsObject(receivingSite) Set evidence."receiving_site_id"=""_receivingSite.%Id(),evidence."receiving_site_revision"=receivingSite.Revision,evidence."receiving_site_source_id"=receivingSite.SourceId
    Set context={"details":(details),"evidence":(evidence),"context_key":(key)}
    Quit ##class(Allfedo.Redirect).Context(allocation,context)
}

ClassMethod TripChanged(allocation As Allfedo.Record.Allocation) As %Boolean
{
    If 'allocation.TransportConfirmed Quit 1
    If allocation.TripContextKey="" Quit 1
    Set current=..CurrentContext(allocation)
    Quit current."context_key"'=allocation.TripContextKey
}

ClassMethod AgreementAt(allocation As Allfedo.Record.Allocation, occurredAt As %String) As %DynamicObject
{
    Set selected={}, history=[]
    If allocation.TripHistoryJSON'="" Set history=##class(Allfedo.Rescue).ParseArray(allocation.TripHistoryJSON)
    For index=0:1:history.%Size()-1 {
        Set ticket=history.%Get(index)
        If ##class(Allfedo.Policy).AtOrBefore(ticket."agreed_at",occurredAt) Set selected=ticket
    }
    Quit selected
}

ClassMethod RecipientKey(context As %DynamicObject) As %String
{
    Set food=##class(Allfedo.Rescue).Parse(context.details.food.%ToJSON())
    Do food.%Remove("packaging")
    Set recipient={"allocation_id":(context.details."allocation_id"),"quantity":(context.details.quantity),"food":(food),"destination":(context.details.destination),"receiving":(context.details.receiving)}
    Quit $SYSTEM.Encryption.ToHex($SYSTEM.Encryption.SHAHash(256,$ZCONVERT(recipient.%ToJSON(),"O","UTF8")))
}

/// Hard gates for an existing promise. Consent never overrides allergen, handling, or receiving limits.
ClassMethod AssertCompatible(offer As Allfedo.Record.Offer, need As Allfedo.Record.Need, arrival As %BigInt, inTransit As %Boolean = 0)
{
    Do ##class(Allfedo.Rescue).ConfirmedSource(offer.SourceId,offer.NetworkId,offer.OrganizationId,"offer_confirmation")
    Do ##class(Allfedo.Rescue).ConfirmedSource(need.SourceId,need.NetworkId,need.OrganizationId,"need_confirmation")
    Set now=##class(Allfedo.Policy).Now()
    Do ##class(Allfedo.Rescue).Require((##class(Allfedo.Facts).NeedState(need)="open")&&((need.HeldQuantity+need.CommittedQuantity)<=need.RequestedQuantity),"The receiving need or existing promises require review before confirming this trip.")
    Do ##class(Allfedo.Rescue).Require((offer.Unit=need.Unit)&&(offer.Unit="meal_box"),"Food and receiving need must use supported whole meal boxes.")
    Do ##class(Allfedo.Rescue).Require((offer.Holding'="")&&(offer.HandlingUntil'="")&&(arrival<=offer.HandlingUntil)&&(arrival>now),"The kitchen must confirm holding and a handling deadline that covers the agreed arrival.")
    Do ##class(Allfedo.Rescue).Require((need.ReceivingFrom'="")&&(arrival>=need.ReceivingFrom)&&(arrival<need.ReceivingUntil)&&(now<need.ConfirmedUntil),"The arrival must fit this partner's current confirmed receiving window.")
    Set present=##class(Allfedo.Rescue).ParseArray(offer.PresentAllergensJSON),assessed=##class(Allfedo.Rescue).ParseArray(offer.AssessedAllergensJSON),excluded=##class(Allfedo.Rescue).ParseArray(need.ExcludedAllergensJSON),accepted=##class(Allfedo.Rescue).ParseArray(need.AcceptedHoldingJSON)
    For index=0:1:present.%Size()-1 Set knownPresent($ZCONVERT(present.%Get(index),"L"))=1
    For index=0:1:assessed.%Size()-1 Set knownAssessed($ZCONVERT(assessed.%Get(index),"L"))=1
    For index=0:1:excluded.%Size()-1 {
        Set label=$ZCONVERT(excluded.%Get(index),"L")
        Do ##class(Allfedo.Rescue).Require('$Data(knownPresent(label)),"The kitchen declares an allergen this receiving partner excludes. Consent cannot override it.")
        Do ##class(Allfedo.Rescue).Require($Data(knownAssessed(label)),"A required allergen assessment is missing. Ask the kitchen to confirm it.")
    }
    Set capable=0
    For index=0:1:accepted.%Size()-1 { If accepted.%Get(index)=offer.Holding Set capable=1 }
    Do ##class(Allfedo.Rescue).Require(capable,"This receiving partner has not confirmed it can handle the declared holding condition.")
    Set pickup=..SiteDetails(offer.NetworkId,offer.OrganizationId),destination=..SiteDetails(need.NetworkId,need.OrganizationId)
    Do ##class(Allfedo.Rescue).Require((inTransit||(pickup."contact_name"'=""))&&(destination."contact_name"'=""),"A required partner contact is no longer active. Ask the receiving team, or the kitchen before collection, to confirm its contact details.")
}

ClassMethod RecordAgreement(actor As Allfedo.Record.Actor, allocation As Allfedo.Record.Allocation, data As %DynamicObject, first As %Boolean = 0)
{
    Set context=..CurrentContext(allocation),offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    Do ##class(Allfedo.Rescue).Require('##class(Allfedo.Redirect).HandlingBlocked(allocation),"A reported handling break blocks another delivery agreement; record its actual return, quarantine or disposal.")
    Do ..AssertCompatible(offer,need,allocation.ArrivalBy,(allocation.ParentAllocationId'=""))
    Do ##class(Allfedo.Rescue).Require(context."context_key"=data."context_key","Pickup or receiving instructions changed while you reviewed them. Read the current details and confirm again.")
    Do ##class(Allfedo.Rescue).Require(allocation.ConsentContextKey=..RecipientKey(context),"The receiving partner must confirm the changed food or destination facts before this agreement.")
    Set context."pickup_at"=##class(Allfedo.Policy).ISO(allocation.PickupAt),context."arrival_by"=##class(Allfedo.Policy).ISO(allocation.ArrivalBy),context."collector_actor_id"=""_actor.%Id(),context."collector_name"=actor.DisplayName,context."agreed_at"=##class(Allfedo.Policy).NowISO()
    Set evidence=##class(Allfedo.Rescue).Parse(context.%ToJSON())
    Set evidence."event_at"=context."agreed_at"
    Set source=##class(Allfedo.Rescue).Source(actor,"transport_agreement",evidence)
    Set context."source_id"=""_source.%Id(),history=[]
    If allocation.TripHistoryJSON'="" Set history=##class(Allfedo.Rescue).ParseArray(allocation.TripHistoryJSON)
    Do history.%Push(context)
    Set allocation.TripHistoryJSON=history.%ToJSON(),allocation.TripContextJSON=context.%ToJSON(),allocation.TripContextKey=context."context_key",allocation.TransportConfirmed=1
    If first&&(allocation.OriginalTripJSON="") Set allocation.OriginalTripJSON=context.%ToJSON()
}
}
