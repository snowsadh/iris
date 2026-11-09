/// A new receiving promise for food already with a collector. Never creates kitchen stock or a second pickup.
Class Allfedo.Redirect Extends %RegisteredObject
{
ClassMethod Report(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(item)&&(item.NetworkId=actor.NetworkId)&&(actor.Role="collector")&&(item.CollectorActorId=actor.%Id()),"Only the assigned collector can report its current destination problem and custody.")
    Do ##class(Allfedo.Rescue).Require((item.Revision=data.revision)&&(item.AcceptedByActorId'="")&&(data.note'=""),"Review the current collection and explain what happened at the destination.")
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",item.NeedId),body=##class(Allfedo.Rescue).Parse(data.%ToJSON())
    Set body."event_at"=##class(Allfedo.Policy).NowISO(),body."received_quantity"=""_item.ReceivedQuantity,body."accounted_quantity"=""_item.AccountedQuantity,body."transferred_out_quantity"=""_item.TransferredOutQuantity,body."need_source_id"=""_need.SourceId
    Set source=##class(Allfedo.Rescue).Source(actor,"destination_issue",body)
    If 'data."handling_maintained" Set item.HandlingBreakReported=1
    Set item.DestinationIssueSourceId=source.%Id(),item.Revision=item.Revision+1,need.State="availability_review",need.Revision=need.Revision+1
    Do ##class(Allfedo.Recovery).RefreshCase(item),##class(Allfedo.Rescue).Save(item),##class(Allfedo.Rescue).Save(need),##class(Allfedo.Rescue).Event(actor,"destination_unavailable",item.%Id(),body)
    Quit {"ok":true,"allocation_id":(""_item.%Id()),"revision":(item.Revision),"state":(item.State),"available_quantity":(""_..Available(item))}
}

ClassMethod HandlingBlocked(item As Allfedo.Record.Allocation) As %Boolean
{
    Set blocked=item.HandlingBreakReported,parentId=item.ParentAllocationId
    While parentId'="" {
        Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId)
        If '$IsObject(parent) {
            Set blocked=1,parentId=""
        } Else {
            If parent.HandlingBreakReported Set blocked=1
            Set parentId=parent.ParentAllocationId
        }
    }
    Quit blocked
}

ClassMethod Pending(parent As Allfedo.Record.Allocation, exceptId As %String = "") As %Integer
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT COALESCE(SUM(HeldQuantity),0) AS Total FROM Allfedo_Record.Allocation WHERE ParentAllocationId=? AND State='held' AND ID<>?",parent.%Id(),$Select(exceptId="":0,1:exceptId))
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ##class(Allfedo.Rescue).Require(query.%Next(),"Pending redirect reservations could not be read.")
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit +query.Total
}

/// The collector attests to actual current custody; unlocated food is never assumed to be on the vehicle.
ClassMethod Available(parent As Allfedo.Record.Allocation, exceptId As %String = "") As %Integer
{
    If (parent.DestinationIssueSourceId="")||..HandlingBlocked(parent) Quit 0
    Set source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",parent.DestinationIssueSourceId),body=##class(Allfedo.Rescue).Parse(source.BodyJSON)
    If 'body."handling_maintained" Quit 0
    Set balance=##class(Allfedo.Recovery).Balance(parent),known=+body."quantity_in_custody"
    Set received=parent.ReceivedQuantity-(+body."received_quantity"),accounted=parent.AccountedQuantity-(+body."accounted_quantity"),moved=parent.TransferredOutQuantity-(+body."transferred_out_quantity")
    If received>0 Set known=known-received
    If accounted>0 Set known=known-accounted
    If moved>0 Set known=known-moved
    If known>+balance."physical_unknown_quantity" Set known=+balance."physical_unknown_quantity"
    Set known=known-..Pending(parent,exceptId)
    Quit $Select(known>0:known,1:0)
}

ClassMethod Propose(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(parent)&&(parent.NetworkId=actor.NetworkId)&&(actor.Role="coordinator"),"Only the coordinator can invite another receiving partner for this collected food.")
    Do ##class(Allfedo.Rescue).Require(parent.Revision=data.revision,"This collection changed. Review the current custody and invitations.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",parent.OfferId),oldNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",parent.NeedId),target=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",data."target_need_id"),quantity=+data.quantity,now=##class(Allfedo.Policy).Now()
    Do ##class(Allfedo.Rescue).Require((quantity>0)&&(quantity<=..Available(parent)),"That quantity is not confirmed with the collector or is already held for another redirect invitation.")
    Set collector=##class(Allfedo.Rescue).Actor(parent.CollectorActorId)
    Do ##class(Allfedo.Rescue).Require((collector.Role="collector")&&(collector.NetworkId=actor.NetworkId),"The current collector is no longer approved for this network.")
    Set issue=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",parent.DestinationIssueSourceId),issueBody=##class(Allfedo.Rescue).Parse(issue.BodyJSON)
    Do ##class(Allfedo.Rescue).Require((oldNeed.State="availability_review")&&(oldNeed.SourceId=issueBody."need_source_id"),"The original receiving partner updated its facts. Review the current situation before redirecting.")
    Do ##class(Allfedo.Rescue).Require($IsObject(target)&&(target.NetworkId=actor.NetworkId)&&(target.OrganizationId'=oldNeed.OrganizationId)&&(target.Revision=data."target_need_revision"),"Choose a current need at a different receiving partner in this network.")
    Set contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",target.ContactActorId)
    Do ##class(Allfedo.Rescue).Require($IsObject(contact)&&contact.Active&&(contact.NetworkId=actor.NetworkId)&&(contact.OrganizationId=target.OrganizationId)&&(contact.Role="recipient"),"Ask this receiving partner to reconfirm today's need with its current contact before sending an invitation.")
    Set earliest=$Select(target.ReceivingFrom>now:target.ReceivingFrom,1:now+1)
    Do ##class(Allfedo.Recovery).AssertCompatible(offer,target,earliest,1)
    Do ##class(Allfedo.Rescue).Require(target.RequestedQuantity-target.HeldQuantity-target.CommittedQuantity>=quantity,"Another promise already uses part of this partner's receiving need.")
    Set expiry=now+900
    If expiry>offer.HandlingUntil Set expiry=offer.HandlingUntil
    If expiry>target.ConfirmedUntil Set expiry=target.ConfirmedUntil
    If expiry>target.ReceivingUntil Set expiry=target.ReceivingUntil
    Set child=##class(Allfedo.Record.Allocation).%New(),root=$Select(parent.RootAllocationId'="":parent.RootAllocationId,1:parent.%Id())
    Set child.NetworkId=parent.NetworkId,child.OfferId=parent.OfferId,child.NeedId=target.%Id(),child.ParentAllocationId=parent.%Id(),child.RootAllocationId=root,child.Quantity=quantity,child.OfferedQuantity=quantity,child.HeldQuantity=quantity,child.StockCommittedQuantity=0,child.LegacyCollectedQuantity=0,child.LegacyReceivedQuantity=0,child.HoldUntil=expiry,child.OfferRevision=offer.Revision,child.NeedRevision=target.Revision+1,child.CollectorActorId=parent.CollectorActorId,child.AssignedByActorId=actor.%Id(),child.PickupAt=parent.PickupAt
    Set decision=##class(Allfedo.Rescue).Parse(data.%ToJSON()),decision."destination_issue_source_id"=""_issue.%Id(),decision."event_at"=##class(Allfedo.Policy).NowISO()
    Set source=##class(Allfedo.Rescue).Source(actor,"redirect_proposal",decision),decision."proposal_source_id"=""_source.%Id(),child.DecisionJSON=decision.%ToJSON()
    Set target.HeldQuantity=target.HeldQuantity+quantity,target.Revision=target.Revision+1,parent.Revision=parent.Revision+1
    Do ##class(Allfedo.Rescue).Save(child),##class(Allfedo.Rescue).Save(target),##class(Allfedo.Rescue).Save(parent),##class(Allfedo.Rescue).Event(actor,"redirect_invited",child.%Id(),decision)
    Do ##class(Allfedo.Recovery).Notice(target.ContactActorId,child,"redirect_invitation","Food already collected: please review this receiving invitation",data.reason)
    Quit {"ok":true,"allocation_id":(""_parent.%Id()),"revision":(parent.Revision),"child_allocation_id":(""_child.%Id()),"child_revision":1,"state":"held"}
}

ClassMethod Invitation(actor As Allfedo.Record.Actor, action As %String, data As %DynamicObject) As %DynamicObject
{
    Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id"),parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",child.ParentAllocationId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",child.NeedId),oldNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",parent.NeedId),offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",child.OfferId),now=##class(Allfedo.Policy).Now()
    Do ##class(Allfedo.Rescue).Require((child.NetworkId=actor.NetworkId)&&(child.State="held")&&(child.Revision=data.revision),"This redirect invitation changed or already ended.")
    If action="accept" {
        Do ##class(Allfedo.Rescue).Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId)&&(now<child.HoldUntil),"Only this receiving partner can accept its current invitation.")
        Set context=##class(Allfedo.Recovery).CurrentContext(child)
        Do ##class(Allfedo.Rescue).Require(context."context_key"=data."context_key","The food or destination details changed. Review this invitation again.")
        Set quantity=+data.quantity
        Do ##class(Allfedo.Rescue).Require((quantity>0)&&(quantity<=child.HeldQuantity)&&(quantity<=..Available(parent,child.%Id())),"The collector's current food changed or another invitation already uses it.")
        Set issue=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",parent.DestinationIssueSourceId),issueBody=##class(Allfedo.Rescue).Parse(issue.BodyJSON)
        Do ##class(Allfedo.Rescue).Require((oldNeed.State="availability_review")&&(oldNeed.SourceId=issueBody."need_source_id"),"The original partner updated its situation. Ask the coordinator to review this redirect.")
        Set earliest=$Select(need.ReceivingFrom>now:need.ReceivingFrom,1:now+1)
        Do ##class(Allfedo.Recovery).AssertCompatible(offer,need,earliest,1)
        Set acceptedContext=##class(Allfedo.Recovery).CurrentContext(child,quantity)
        Set child.Quantity=quantity,child.OriginalPromiseQuantity=quantity,child.AcceptedByActorId=actor.%Id(),child.ConsentContextKey=##class(Allfedo.Recovery).RecipientKey(acceptedContext),child.TransferredInQuantity=quantity,child.HeldQuantity=0,child.Revision=child.Revision+1
        Set parent.TransferredOutQuantity=parent.TransferredOutQuantity+quantity,parent.Quantity=parent.Quantity-quantity,parent.Revision=parent.Revision+1
        If parent.Quantity<parent.ReceivedQuantity Set parent.Quantity=parent.ReceivedQuantity
        Do ##class(Allfedo.Recovery).RefreshCase(child),##class(Allfedo.Recovery).RefreshCase(parent),##class(Allfedo.Rescue).Save(child),##class(Allfedo.Rescue).Save(parent)
        Do ##class(Allfedo.Recovery).RebuildCommitments(offer,oldNeed),##class(Allfedo.Recovery).RebuildCommitments(offer,need)
        Set oldNeed.State="availability_review",oldNeed.Revision=oldNeed.Revision+1,need.Revision=need.Revision+1,offer.Revision=offer.Revision+1
        Do ##class(Allfedo.Rescue).Save(oldNeed),##class(Allfedo.Rescue).Save(need),##class(Allfedo.Rescue).Save(offer)
        Do ##class(Allfedo.Recovery).Notice(parent.CollectorActorId,child,"redirect_accepted","A new receiving partner accepted; confirm the changed destination","The food stays with the current collector. No kitchen collection is needed.")
        Do ##class(Allfedo.Recovery).Notice(oldNeed.ContactActorId,parent,"redirected","Food moved to a different receiving promise","The original destination was reported unavailable. This is a coordinator-led redirect, not an acceptance or receipt by your team.")
    } Else {
        If action="decline" {
            Do ##class(Allfedo.Rescue).Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId),"Only this invited receiving partner can decline.")
        } Else {
            Do ##class(Allfedo.Rescue).Require((actor.Role="coordinator")&&((action'="expire_hold")||(now>=child.HoldUntil)),"Only the coordinator can withdraw or expire this redirect invitation.")
        }
        Set child.HeldQuantity=0,child.State="released",child.Revision=child.Revision+1,parent.Revision=parent.Revision+1
        Do ##class(Allfedo.Rescue).Save(child),##class(Allfedo.Rescue).Save(parent),##class(Allfedo.Recovery).RebuildCommitments(offer,need)
        Set need.Revision=need.Revision+1
        Do ##class(Allfedo.Rescue).Save(need)
        Do ##class(Allfedo.Recovery).Notice(need.ContactActorId,child,"withdrawn","Redirect invitation ended","This invitation ended. No food was released into kitchen stock.")
    }
    Do ##class(Allfedo.Rescue).Event(actor,"redirect_"_action,child.%Id(),data)
    Quit {"ok":true,"allocation_id":(""_child.%Id()),"revision":(child.Revision),"state":(child.State),"quantity":(""_child.Quantity),"collected_quantity":(""_child.CollectedQuantity),"received_quantity":(""_child.ReceivedQuantity)}
}

ClassMethod Confirm(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id"),balance=##class(Allfedo.Recovery).Balance(child)
    Do ##class(Allfedo.Rescue).Require((child.NetworkId=actor.NetworkId)&&(child.ParentAllocationId'="")&&(child.AcceptedByActorId'="")&&(actor.Role="collector")&&(child.CollectorActorId=actor.%Id())&&(child.Revision=data.revision),"Only the assigned collector can confirm this current onward delivery.")
    Do ##class(Allfedo.Rescue).Require('..HandlingBlocked(child),"A reported break in food handling blocks onward delivery. Record the actual return, quarantine, or disposal outcome.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",child.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",child.NeedId),arrival=##class(Allfedo.Policy).Instant(data."arrival_by")
    Do ##class(Allfedo.Rescue).Require((+balance."physical_unknown_quantity">0)&&data."handling_accepted"&&(offer.Packaging'=""),"Confirm the actual remaining load, its packing, and food-handling requirements.")
    // Related cases share this one physical load. Other trips still block a new promise.
    Set root=child.RootAllocationId,query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE CollectorActorId=? AND ID<>? AND ID<>? AND (RootAllocationId IS NULL OR RootAllocationId<>?) AND (CollectedQuantity>ReceivedQuantity+COALESCE(AccountedQuantity,0)+COALESCE(TransferredOutQuantity,0) OR State='custody_review' OR (State='ready' AND (ArrivalBy<=? OR (PickupAt<? AND ArrivalBy>?))))",actor.%Id(),child.%Id(),root,root,##class(Allfedo.Policy).Now(),arrival,##class(Allfedo.Policy).Now())
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set blocked=query.%Next()
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ##class(Allfedo.Rescue).Require('blocked,"An unrelated collection still occupies this collector or overlaps this delivery.")
    Do ##class(Allfedo.Rescue).Require(+data.capacity>=..RequiredCapacity(child),"Confirm capacity for all food still carried across the linked receiving promises.")
    Set child.ArrivalBy=arrival
    Do ##class(Allfedo.Recovery).RecordAgreement(actor,child,data,1),##class(Allfedo.Recovery).RefreshCase(child)
    Set child.Revision=child.Revision+1
    Do ##class(Allfedo.Rescue).Save(child),##class(Allfedo.Rescue).Event(actor,"redirect_trip_confirmed",child.%Id(),data)
    Quit {"ok":true,"allocation_id":(""_child.%Id()),"revision":(child.Revision),"state":(child.State),"trip_confirmed":true}
}

ClassMethod RequiredCapacity(item As Allfedo.Record.Allocation) As %Integer
{
    Set root=$Select(item.RootAllocationId'="":item.RootAllocationId,1:item.%Id())
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT COALESCE(SUM(CASE WHEN CollectedQuantity>ReceivedQuantity+COALESCE(AccountedQuantity,0)+COALESCE(TransferredOutQuantity,0) THEN CollectedQuantity-ReceivedQuantity-COALESCE(AccountedQuantity,0)-COALESCE(TransferredOutQuantity,0) ELSE 0 END),0) AS Load FROM Allfedo_Record.Allocation WHERE ID=? OR RootAllocationId=?",root,root)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ##class(Allfedo.Rescue).Require(query.%Next(),"The related carried load could not be read.")
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit +query.Load
}

ClassMethod ReleaseUnavailable(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id"),offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",item.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",item.NeedId)
    Do ##class(Allfedo.Rescue).Require((actor.Role="coordinator")&&(item.NetworkId=actor.NetworkId)&&(item.Revision=data.revision)&&(need.State="availability_review")&&(item.DestinationIssueSourceId'=""),"A current recorded destination failure is required for this coordinator cancellation.")
    Do ##class(Allfedo.Rescue).Require((offer.ObservationSourceId=data."stock_source_id")&&(data."stock_source_id"'=""),"Use the kitchen's latest actual stock count; this does not assert missing boxes exist.")
    Set issue=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",item.DestinationIssueSourceId),issueBody=##class(Allfedo.Rescue).Parse(issue.BodyJSON)
    Do ##class(Allfedo.Rescue).Require(need.SourceId=issueBody."need_source_id","The receiving partner updated its facts. Review them before cancelling the promise.")
    Set projection=##class(Allfedo.Recovery).RebuildStock(offer),quantity=+data.quantity
    Do ##class(Allfedo.Rescue).Require('projection."review_required"&&(quantity>0)&&(quantity<=item.StockCommittedQuantity),"Cancel only current unhanded promises after resolving the actual stock history.")
    Set item.CancelledUnhandedQuantity=item.CancelledUnhandedQuantity+quantity,item.Quantity=item.Quantity-quantity,item.TransportConfirmed=0,item.Revision=item.Revision+1
    Do ##class(Allfedo.Recovery).RefreshCase(item),##class(Allfedo.Rescue).Save(item),##class(Allfedo.Recovery).RebuildCommitments(offer,need)
    Set offer.Revision=offer.Revision+1,need.Revision=need.Revision+1,need.State="availability_review"
    Do ##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Save(need),##class(Allfedo.Rescue).Event(actor,"unavailable_unhanded_released",item.%Id(),data)
    Do ##class(Allfedo.Recovery).Notice(need.ContactActorId,item,"unavailable_released","Unhanded food promise cancelled after destination failure",data.reason)
    Quit {"ok":true,"allocation_id":(""_item.%Id()),"revision":(item.Revision),"state":(item.State),"released_unhanded_quantity":(""_quantity)}
}

ClassMethod Context(item As Allfedo.Record.Allocation, context As %DynamicObject) As %DynamicObject
{
    If item.ParentAllocationId'="" {
        Do context.details.%Set("in_transit",1,"boolean")
        Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",item.ParentAllocationId),contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",item.CollectorActorId),location="",confirmed=""
        Set custodySource=$Select(item.DestinationIssueSourceId'="":item.DestinationIssueSourceId,1:parent.DestinationIssueSourceId)
        If custodySource'="" {
            Set source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",custodySource),body=##class(Allfedo.Rescue).Parse(source.BodyJSON),location=body."current_location",confirmed=body."event_at"
        }
        Set collectorName="Unavailable contact",collectorEmail=""
        If $IsObject(contact)&&contact.Active Set collectorName=contact.DisplayName,collectorEmail=contact.Email
        Set context.details.custody={"collector_name":(collectorName),"collector_email":(collectorEmail),"location":(location),"confirmed_at":(confirmed)}
        If parent.OriginalTripJSON'="" {
            Set original=##class(Allfedo.Rescue).Parse(parent.OriginalTripJSON)
            Set context.details.pickup=original.details.pickup,context.evidence."origin_trip_source_id"=original.%Get("source_id")
        } Else {
            // A legacy custody total does not prove its old entrance or contact details.
            Set context.details.pickup={"name":(context.details.pickup.name),"address":"","entrance":"","time_zone":"","contact_name":"","contact_email":"","contact_phone":""}
        }
        For field="pickup_site_id","pickup_site_revision","pickup_site_source_id" Do context.evidence.%Remove(field)
        If custodySource'="" Set context.evidence."custody_source_id"=""_custodySource
    }
    Set context."context_key"=$SYSTEM.Encryption.ToHex($SYSTEM.Encryption.SHAHash(256,$ZCONVERT(context.details.%ToJSON(),"O","UTF8")))
    Quit context
}

ClassMethod Private(actor As Allfedo.Record.Actor, item As Allfedo.Record.Allocation) As %Boolean
{
    If '$IsObject(actor) Quit 0
    If actor.NetworkId'=item.NetworkId Quit 0
    If actor.Role="coordinator" Quit 1
    If (actor.Role="collector")&&(actor.%Id()=item.CollectorActorId) Quit 1
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",item.OfferId)
    Quit (actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId)
}

ClassMethod PublicContext(item As Allfedo.Record.Allocation, context As %DynamicObject, actor As Allfedo.Record.Actor = "") As %DynamicObject
{
    If context.details.%IsDefined("custody"),'..Private(actor,item) {
        Set context=##class(Allfedo.Rescue).Parse(context.%ToJSON())
        Do context.details.custody.%Remove("location")
    }
    Quit context
}

ClassMethod View(item As Allfedo.Record.Allocation, actor As Allfedo.Record.Actor = "") As %DynamicObject
{
    Set children=[],view={"parent_allocation_id":(item.ParentAllocationId),"root_allocation_id":($Select(item.RootAllocationId'="":item.RootAllocationId,1:""_item.%Id())),"transferred_in_quantity":(""_item.TransferredInQuantity),"transferred_out_quantity":(""_item.TransferredOutQuantity),"pending_quantity":(""_..Pending(item)),"available_quantity":(""_..Available(item)),"required_capacity_quantity":(""_..RequiredCapacity(item)),"children":(children),"issue":null,"handling_break_reported":(..HandlingBlocked(item))}
    Do view.%Set("parent_readable",..Private(actor,item),"boolean"),view.%Set("handling_break_reported",..HandlingBlocked(item),"boolean")
    If '..Private(actor,item) Do view.%Remove("required_capacity_quantity")
    If item.DestinationIssueSourceId'="" {
        Set source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",item.DestinationIssueSourceId),body=##class(Allfedo.Rescue).Parse(source.BodyJSON)
        Set issue={"quantity_in_custody":(body."quantity_in_custody"),"current_location":(body."current_location"),"handling_maintained":(body."handling_maintained"),"confirmed_at":(body."event_at"),"actor_name":(source.SenderName),"note":(body.note)}
        If '..Private(actor,item) Set issue."current_location"="",issue.note=""
        Set view.issue=issue
    }
    If ..Private(actor,item) {
        Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE ParentAllocationId=? ORDER BY ID",item.%Id())
        Do ##class(Allfedo.Rescue).QueryOK(query)
        While query.%Next() {
            Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",query.ID),entry={"id":(""_child.%Id()),"state":(child.State),"quantity":(""_child.Quantity),"held_quantity":(""_child.HeldQuantity),"can_open":true}
            Do children.%Push(entry)
        }
        Do ##class(Allfedo.Rescue).QueryOK(query)
    }
    Quit view
}
}
