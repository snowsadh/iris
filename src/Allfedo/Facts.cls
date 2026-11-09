/// Confirmed partner facts and their revisions. Called inside Rescue's resource-locked transaction.
Class Allfedo.Facts Extends %RegisteredObject
{
ClassMethod SaveSite(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Do ##class(Allfedo.Rescue).Require((actor.Role="kitchen")||(actor.Role="recipient"),"The partner must confirm its own place and contact.")
    Set site=..SiteFor(actor.NetworkId,actor.OrganizationId)
    If $IsObject(site) {
        Do ##class(Allfedo.Rescue).Require(site.Revision=data.revision,"The site changed. Review its current details first.")
        Set site.Revision=site.Revision+1
    } Else {
        Do ##class(Allfedo.Rescue).Require(data.revision=0,"Use revision zero for a first site confirmation.")
        Set site=##class(Allfedo.Record.Site).%New(), site.NetworkId=actor.NetworkId, site.OrganizationId=actor.OrganizationId
    }
    Set evidence=##class(Allfedo.Rescue).Parse(data.%ToJSON())
    Set evidence."event_at"=##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now())
    Set source=##class(Allfedo.Rescue).Source(actor,"site_confirmation",evidence)
    Set site.Name=data.name, site.Address=data.address, site.Entrance=data.entrance, site.TimeZone=data."time_zone", site.ContactPhone=data."contact_phone", site.ContactActorId=actor.%Id(), site.SourceId=source.%Id()
    Do ##class(Allfedo.Rescue).Save(site), ##class(Allfedo.Rescue).Event(actor,"site_confirmed",site.%Id(),evidence)
    Quit {"ok":true,"site_id":(""_site.%Id()),"revision":(site.Revision)}
}

ClassMethod SiteFor(networkId As %String, organizationId As %String) As Allfedo.Record.Site
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Site WHERE NetworkId=? AND OrganizationId=?",networkId,organizationId)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set found=query.%Next()
    Do ##class(Allfedo.Rescue).QueryOK(query)
    If 'found Quit ""
    Set site=##class(Allfedo.Rescue).Open("Allfedo.Record.Site",query.ID)
    Do ##class(Allfedo.Rescue).ConfirmedSource(site.SourceId,networkId,organizationId,"site_confirmation")
    Quit site
}

ClassMethod SetFoodFields(offer As Allfedo.Record.Offer, data As %DynamicObject) As %Boolean
{
    Set ready=##class(Allfedo.Policy).Instant(data."ready_at"), closes=##class(Allfedo.Policy).Instant(data."collect_by"), until=""
    If data.%GetTypeOf("handling_until")'="null" Set until=##class(Allfedo.Policy).Instant(data."handling_until")
    Do ##class(Allfedo.Rescue).Require(ready<closes,"The collection window must end after the food is ready.")
    Set present=data."present_allergens".%ToJSON(), assessed=data."assessed_allergens".%ToJSON()
    Set changed=((offer.Packaging'="")&&(offer.Packaging'=data.packaging))||(offer.Holding'=data.holding)||(offer.HandlingUntil'=until)||(offer.ReadyAt'=ready)||(offer.CollectBy'=closes)||(offer.PresentAllergensJSON'=present)||(offer.AssessedAllergensJSON'=assessed)
    Set offer.Holding=data.holding, offer.HandlingUntil=until, offer.ReadyAt=ready, offer.CollectBy=closes, offer.Packaging=data.packaging, offer.PresentAllergensJSON=present, offer.AssessedAllergensJSON=assessed
    Quit changed
}

ClassMethod FoodState(offer As Allfedo.Record.Offer) As %String
{
    If offer.State="review_required" Quit "review_required"
    If (offer.Holding="")||(offer.HandlingUntil="") Quit "needs_details"
    Set site=..SiteFor(offer.NetworkId,offer.OrganizationId)
    If '$IsObject(site) Quit "needs_details"
    Set now=##class(Allfedo.Policy).Now()
    If (now>=offer.CollectBy)||(now>=offer.HandlingUntil)||(offer.HandlingUntil<=offer.ReadyAt) Quit "expired"
    Quit "open"
}

ClassMethod NeedState(need As Allfedo.Record.Need) As %String
{
    If need.State="review_required" Quit "review_required"
    Set site=..SiteFor(need.NetworkId,need.OrganizationId)
    If '$IsObject(site) Quit "needs_details"
    Set now=##class(Allfedo.Policy).Now()
    If (now>=need.ConfirmedUntil)||(now>=need.ReceivingUntil) Quit "expired"
    Quit "open"
}

ClassMethod ConfirmFood(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",data."offer_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(offer)&&(actor.Role="kitchen")&&(offer.NetworkId=actor.NetworkId)&&(offer.OrganizationId=actor.OrganizationId),"Only this kitchen can confirm these food facts.")
    Do ##class(Allfedo.Rescue).Require(offer.Revision=data.revision,"The food offer changed. Review its current details first.")
    If offer.OriginalSourceId="" {
        Set original=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",offer.SourceId), body=##class(Allfedo.Rescue).Parse(original.BodyJSON)
        Do ##class(Allfedo.Rescue).Require(body.%IsDefined("quantity")&&body.%IsDefined("description"),"The original declared quantity source is missing; review the food record before changing its evidence.")
        Set offer.OriginalSourceId=offer.SourceId
    }
    Set changed=..SetFoodFields(offer,data), source=##class(Allfedo.Rescue).Source(actor,"offer_confirmation",data)
    Set offer.SourceId=source.%Id(), offer.Revision=offer.Revision+1
    If changed&&((offer.HeldQuantity+offer.CommittedQuantity)>0) Set offer.State="review_required"
    Set offer.State=..FoodState(offer)
    Do ##class(Allfedo.Rescue).Save(offer), ##class(Allfedo.Rescue).Event(actor,"food_reconfirmed",offer.%Id(),data)
    Quit {"ok":true,"offer_id":(""_offer.%Id()),"revision":(offer.Revision),"state":(offer.State),"source_id":(""_offer.SourceId)}
}

ClassMethod UpdateNeed(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",data."need_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(need)&&(actor.Role="recipient")&&(need.NetworkId=actor.NetworkId)&&(need.OrganizationId=actor.OrganizationId),"Only this receiving partner can confirm its current need.")
    Do ##class(Allfedo.Rescue).Require(need.Revision=data.revision,"The receiving need changed. Review its current version first.")
    Set receiving=##class(Allfedo.Policy).Instant(data."receiving_until"), confirmed=##class(Allfedo.Policy).Instant(data."confirmed_until")
    Do ##class(Allfedo.Rescue).Require((confirmed<=receiving)&&(data.unit=need.Unit),"Confirmation cannot outlast receiving, and an existing need cannot change units.")
    Set excluded=data."excluded_allergens".%ToJSON(), holding=data."accepted_holding".%ToJSON(), promises=need.HeldQuantity+need.CommittedQuantity
    Set changed=(need.ReceivingUntil'=receiving)||(need.ConfirmedUntil'=confirmed)||(need.ExcludedAllergensJSON'=excluded)||(need.AcceptedHoldingJSON'=holding)
    Set source=##class(Allfedo.Rescue).Source(actor,"need_confirmation",data)
    Set need.RequestedQuantity=+data.quantity, need.ReceivingUntil=receiving, need.ConfirmedUntil=confirmed, need.ExcludedAllergensJSON=excluded, need.AcceptedHoldingJSON=holding, need.SourceId=source.%Id(), need.Revision=need.Revision+1
    Set shortfall=$Select(promises>need.RequestedQuantity:promises-need.RequestedQuantity,1:0)
    Set need.State=$Select((shortfall>0)||(changed&&(promises>0)):"review_required",1:"open")
    Set need.State=..NeedState(need)
    Do ##class(Allfedo.Rescue).Save(need), ##class(Allfedo.Rescue).Event(actor,"need_reconfirmed",need.%Id(),data)
    Quit {"ok":true,"need_id":(""_need.%Id()),"revision":(need.Revision),"state":(need.State),"requested_quantity":(""_need.RequestedQuantity),"held_quantity":(""_need.HeldQuantity),"committed_quantity":(""_need.CommittedQuantity),"shortfall_quantity":(""_shortfall)}
}
}
