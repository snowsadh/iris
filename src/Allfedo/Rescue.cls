Include %occStatus

/// Owns authoritative rescue changes. Every public command rechecks identity and current facts.
Class Allfedo.Rescue Extends %RegisteredObject
{
/// Stable requestId must be reused for retries. No model, mail, or human waits inside this transaction.
ClassMethod Execute(actorId As %String, requestId As %String, action As %String, payloadJSON As %String) As %String
{
    Do ..Require($TLEVEL=0, "Commands must start outside another transaction.")
    Do ..Require((requestId'="")&&($Length(requestId)<=100), "A request ID of at most 100 characters is required.")
    Do ..Require($Length(payloadJSON)<=100000, "The command is too large.")
    Set actor = ..Actor(actorId)
    Set commandKey = "command:"_actorId_":"_requestId
    Lock +^Allfedo.Lock(commandKey):5
    If '$Test Quit {"ok":false,"error":{"code":"BUSY","message":"This request is already being handled. Check its saved result."}}.%ToJSON()
    Set result = "", command = ""
    Try {
        Set query = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Allfedo_Record.Command WHERE ActorId=? AND RequestId=?", actorId, requestId)
        Do ..QueryOK(query)
        Set found=query.%Next()
        Do ..QueryOK(query)
        If found {
            Set command = ..Open("Allfedo.Record.Command",query.ID)
            If (command.Action'=action)||(command.PayloadJSON'=payloadJSON) {
                Set result = {"ok":false,"error":{"code":"REQUEST_ID_REUSED","message":"This request ID already belongs to a different intention. Use a new ID for changed input."}}.%ToJSON()
            } Else {
                Set result = command.ResultJSON
            }
        } Else {
            Set parsed = ..Parse(##class(Allfedo.Policy).Normalize(action, payloadJSON))
            If 'parsed.ok Do ..Require(0,parsed.message)
            Set normalized=parsed.payload
            Do ..ResourceKeys(action, normalized, actor, .keys)
            Set key=""
            For {
                Set key=$Order(keys(key))
                Quit:key=""
                Lock +^Allfedo.Lock(key):5
                If '$Test {
                    Throw ##class(%Exception.General).%New("BUSY",1001,,"A related record is busy. Retry this same request shortly.")
                }
                Set held(key)=1
            }
            TSTART
            Set actor = ..Actor(actorId)
            Set outcome = ..Change(actor, action, normalized)
            Set command = ##class(Allfedo.Record.Command).%New()
            Set command.ActorId=actorId, command.RequestId=requestId, command.Action=action, command.PayloadJSON=payloadJSON
            Set command.ResultJSON=outcome.%ToJSON(), command.RecordedAt=##class(Allfedo.Policy).Now(), command.WorkerJob=""_$Job
            Do ..Save(command)
            TCOMMIT
            Set result=command.ResultJSON
        }
    } Catch error {
        If $TLEVEL TROLLBACK
        If error.Code=1001 {
            Set result={"ok":false,"error":{"code":"BUSY","message":(error.Data)}}.%ToJSON()
        } ElseIf error.Code=1000 {
            // A rejected intention changes nothing. Save only confirmed business rejections, never transient failures.
            Set failure={"ok":false,"error":{"code":"COMMAND_REJECTED","message":(error.Data)}}
            Set command=##class(Allfedo.Record.Command).%New()
            Set command.ActorId=actorId, command.RequestId=requestId, command.Action=action, command.PayloadJSON=payloadJSON
            Set command.ResultJSON=failure.%ToJSON(), command.RecordedAt=##class(Allfedo.Policy).Now(), command.WorkerJob=""_$Job
            Try { Do ..Save(command) Set result=command.ResultJSON } Catch saveError { Set result={"ok":false,"error":{"code":"NOT_SAVED","message":"The result could not be saved. Check server availability before retrying."}}.%ToJSON() }
        } Else {
            Set result={"ok":false,"error":{"code":"NOT_SAVED","message":"The request could not be completed. Check the command fields and server availability, then retry with the same request ID."}}.%ToJSON()
        }
    }
    Set key=""
    For { Set key=$Order(held(key)) Quit:key=""  Lock -^Allfedo.Lock(key) }
    Lock -^Allfedo.Lock(commandKey)
    Quit result
}

ClassMethod ResourceKeys(action As %String, data As %DynamicObject, actor As Allfedo.Record.Actor, ByRef keys)
{
    If action="save_site" {
        Set keys("site:"_actor.NetworkId _ ":"_actor.OrganizationId)=1
    } ElseIf action="confirm_food" {
        Set keys("offer:"_data."offer_id")=1
    } ElseIf action="update_need" {
        Set keys("need:"_data."need_id")=1
    } ElseIf action="apply_plan" {
        Set keys("offer:"_data."offer_id")=1
        Set requests=data.requests
        Do ..Require($IsObject(requests), "A plan needs recipient requests.")
        For i=0:1:requests.%Size()-1 { Set request=requests.%Get(i) Set keys("need:"_request."need_id")=1 }
    } ElseIf action="observe_stock" {
        Set keys("offer:"_data."offer_id")=1
    } ElseIf $ListFind($ListBuild("accept","decline","assign_collector","confirm_transport","handoff","receive","expire_hold"),action) {
        Set allocation=..Open("Allfedo.Record.Allocation",data."allocation_id")
        Do ..Require($IsObject(allocation), "This invitation does not exist.")
        Do ..Require(allocation.NetworkId=actor.NetworkId, "This invitation is outside your network.")
        Set keys("allocation:"_data."allocation_id")=1, keys("offer:"_allocation.OfferId)=1, keys("need:"_allocation.NeedId)=1
        If action="confirm_transport" Set keys("collector:"_actor.%Id())=1
        If (action="handoff")&&(allocation.CollectorActorId'= "") Set keys("collector:"_allocation.CollectorActorId)=1
    }
}

ClassMethod Change(actor As Allfedo.Record.Actor, action As %String, data As %DynamicObject) As %DynamicObject
{
    If action="save_site" Quit ##class(Allfedo.Facts).SaveSite(actor,data)
    If action="confirm_food" Quit ##class(Allfedo.Facts).ConfirmFood(actor,data)
    If action="update_need" Quit ##class(Allfedo.Facts).UpdateNeed(actor,data)
    If action="create_offer" Quit ..CreateOffer(actor,data)
    If action="create_need" Quit ..CreateNeed(actor,data)
    If action="apply_plan" Quit ..ApplyPlan(actor,data)
    If action="observe_stock" Quit ..ObserveStock(actor,data)
    Quit ..AllocationChange(actor,action,data)
}

ClassMethod CreateOffer(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Do ..Require(actor.Role="kitchen", "The kitchen contact must confirm its own food facts.")
    Set source=..Source(actor,"offer_confirmation",data)
    Set offer=##class(Allfedo.Record.Offer).%New()
    Set offer.NetworkId=actor.NetworkId, offer.OrganizationId=actor.OrganizationId, offer.ContactActorId=actor.%Id()
    Set offer.Description=data.description, offer.DeclaredQuantity=+data.quantity, offer.CurrentQuantity=+data.quantity, offer.Unit=data.unit, offer.SourceId=source.%Id(), offer.OriginalSourceId=source.%Id()
    Set changed=##class(Allfedo.Facts).SetFoodFields(offer,data)
    Set offer.State=##class(Allfedo.Facts).FoodState(offer)
    Do ..Save(offer), ..Event(actor,"offer_confirmed",offer.%Id(),data)
    Quit {"ok":true,"offer_id":(offer.%Id()),"revision":1,"state":(offer.State)}
}

ClassMethod CreateNeed(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Do ..Require(actor.Role="recipient", "The receiving contact must confirm its own need and handling capability.")
    Set receiving=##class(Allfedo.Policy).Instant(data."receiving_until"), confirmed=##class(Allfedo.Policy).Instant(data."confirmed_until"), now=##class(Allfedo.Policy).Now()
    Do ..Require((receiving>now)&&(confirmed>now)&&(confirmed<=receiving), "The receiving and confirmation deadlines must be current; confirmation cannot outlast receiving.")
    Set source=..Source(actor,"need_confirmation",data)
    Set need=##class(Allfedo.Record.Need).%New()
    Set need.NetworkId=actor.NetworkId, need.OrganizationId=actor.OrganizationId, need.ContactActorId=actor.%Id(), need.RequestedQuantity=+data.quantity
    Set need.Unit=data.unit, need.ReceivingUntil=receiving, need.ConfirmedUntil=confirmed
    Set need.ExcludedAllergensJSON=data."excluded_allergens".%ToJSON(), need.AcceptedHoldingJSON=data."accepted_holding".%ToJSON(), need.SourceId=source.%Id()
    Set need.State=##class(Allfedo.Facts).NeedState(need)
    Do ..Save(need), ..Event(actor,"need_confirmed",need.%Id(),data)
    Quit {"ok":true,"need_id":(need.%Id()),"revision":1,"state":(need.State)}
}

/// Caller holds every cited offer/need lock. The validator sees freshly read, confirmed records.
ClassMethod ApplyPlan(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Do ..Require(actor.Role="coordinator", "Only the coordinator can send a recipient plan.")
    Set snapshot=..Snapshot(actor.%Id(),data."offer_id")
    Set checked=..Parse(##class(Allfedo.Policy).Validate(snapshot.%ToJSON(),data.%ToJSON()))
    Do ..Require(checked.ok, $Select(checked.ok:"",1:checked.error.message))
    Set offer=..Open("Allfedo.Record.Offer",data."offer_id"), ids=[]
    Set now=##class(Allfedo.Policy).Now(), expiry=now+900
    If expiry>offer.CollectBy Set expiry=offer.CollectBy
    If expiry>offer.HandlingUntil Set expiry=offer.HandlingUntil
    For i=0:1:checked.plan.requests.%Size()-1 {
        Set request=checked.plan.requests.%Get(i), quantity=+request.quantity
        Set need=..Open("Allfedo.Record.Need",request."need_id")
        Set invitationExpiry=expiry
        If invitationExpiry>need.ConfirmedUntil Set invitationExpiry=need.ConfirmedUntil
        If invitationExpiry>need.ReceivingUntil Set invitationExpiry=need.ReceivingUntil
        // No caller, including a coordinator, can bypass either resource check.
        Do ..Require((offer.CurrentQuantity-offer.HeldQuantity-offer.CommittedQuantity-offer.CollectedQuantity)>=quantity,"The food quantity changed.")
        Do ..Require((need.RequestedQuantity-need.HeldQuantity-need.CommittedQuantity)>=quantity,"The receiving capacity changed.")
        Set offer.HeldQuantity=offer.HeldQuantity+quantity, need.HeldQuantity=need.HeldQuantity+quantity
        Set need.Revision=need.Revision+1
        Set allocation=##class(Allfedo.Record.Allocation).%New()
        Set allocation.NetworkId=actor.NetworkId, allocation.OfferId=offer.%Id(), allocation.NeedId=need.%Id(), allocation.Quantity=quantity
        Set allocation.HoldUntil=invitationExpiry, allocation.OfferRevision=offer.Revision, allocation.NeedRevision=need.Revision, allocation.DecisionJSON=data.%ToJSON()
        Do ..Save(need), ..Save(allocation), ids.%Push(""_allocation.%Id())
        Do ..Notify(need.ContactActorId,allocation,"Food invitation: "_quantity_" meal boxes", "Please respond to invitation "_allocation.%Id()_" before "_##class(Allfedo.Policy).ISO(invitationExpiry)_". This is a temporary hold. Collection still needs a named collector and a confirmed trip.")
        Do ..Event(actor,"invitation_held",allocation.%Id(),request)
    }
    Set offer.Revision=offer.Revision+1
    Do ..Save(offer)
    Quit {"ok":true,"allocation_ids":(ids),"offer_revision":(offer.Revision),"state":"held"}
}

ClassMethod AllocationChange(actor As Allfedo.Record.Actor, action As %String, data As %DynamicObject) As %DynamicObject
{
    Set allocation=..Open("Allfedo.Record.Allocation",data."allocation_id"), now=##class(Allfedo.Policy).Now()
    Do ..Require($IsObject(allocation)&&(allocation.NetworkId=actor.NetworkId),"This invitation is outside your network.")
    Do ..Require(allocation.Revision=data.revision,"The invitation changed. Read its current version before acting.")
    Set offer=..Open("Allfedo.Record.Offer",allocation.OfferId), need=..Open("Allfedo.Record.Need",allocation.NeedId)
    If $ListFind($ListBuild("accept","confirm_transport","handoff"),action) {
        Do ..Require((##class(Allfedo.Facts).FoodState(offer)="open")&&(##class(Allfedo.Facts).NeedState(need)="open"),"The current food, site, or receiving facts need review before this step.")
    }
    If action="accept" {
        Do ..Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId),"Only this receiving organization can accept.")
        Do ..Require((allocation.State="held")&&(now<allocation.HoldUntil),"This invitation is no longer open for acceptance.")
        Do ..Require((offer.State="open")&&(now<offer.CollectBy)&&(now<need.ConfirmedUntil),"The food or receiving facts need a fresh review.")
        Set quantity=+data.quantity, released=allocation.Quantity-quantity
        Do ..Require((quantity>0)&&(released>=0),"Accept a positive quantity up to the amount held.")
        Set offer.HeldQuantity=offer.HeldQuantity-allocation.Quantity, need.HeldQuantity=need.HeldQuantity-allocation.Quantity
        Set offer.CommittedQuantity=offer.CommittedQuantity+quantity, need.CommittedQuantity=need.CommittedQuantity+quantity
        Set allocation.Quantity=quantity, allocation.AcceptedByActorId=actor.%Id(), allocation.State="accepted"
    } ElseIf (action="decline")||(action="expire_hold") {
        Do ..Require(allocation.State="held","Only an unaccepted invitation can be released here. Accepted pickups need explicit follow-up.")
        If action="decline" {
            Do ..Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId),"Only this receiving organization can decline.")
            Set allocation.OutcomeNote=data.reason
        } Else {
            Do ..Require((actor.Role="coordinator")&&(now>=allocation.HoldUntil),"Only a coordinator can expire an elapsed invitation hold.")
        }
        Set offer.HeldQuantity=offer.HeldQuantity-allocation.Quantity, need.HeldQuantity=need.HeldQuantity-allocation.Quantity, allocation.State="released"
    } ElseIf action="assign_collector" {
        Do ..Require((actor.Role="coordinator")||((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId)),"Only the coordinator or this receiving partner can assign a collector.")
        Do ..Require((allocation.State="accepted")&&'allocation.TransportConfirmed,"Only an accepted request without a confirmed trip can receive an assignment.")
        Set collector=..Actor(data."collector_actor_id")
        Do ..Require((collector.Role="collector")&&(collector.NetworkId=actor.NetworkId),"Assign an active approved collector from this network.")
        Set allocation.CollectorActorId=collector.%Id(), allocation.AssignedByActorId=actor.%Id()
    } ElseIf action="confirm_transport" {
        Do ..Require(actor.Role="collector","The named collector must confirm their own trip.")
        Do ..Require(allocation.State="accepted","Transport belongs to an accepted food request.")
        Do ..Require((offer.State="open")&&(allocation.CollectorActorId=actor.%Id())&&'allocation.TransportConfirmed,"Only the assigned collector can confirm this trip; changed food facts need review.")
        Do ..Require(offer.Packaging'="","Ask the kitchen to confirm packaging and carrying details before agreeing transport.")
        Set pickup=##class(Allfedo.Policy).Instant(data."pickup_at"), arrival=##class(Allfedo.Policy).Instant(data."arrival_by")
        Do ..Require((pickup>=now)&&(pickup>=offer.ReadyAt)&&(pickup<offer.CollectBy)&&(arrival>pickup)&&(arrival<need.ReceivingUntil)&&(arrival<=offer.HandlingUntil),"The proposed trip must fit the food and receiving windows.")
        Do ..Require((+data.capacity>=allocation.Quantity)&&data."handling_accepted","Confirm enough transport capacity and acceptance of the food handling requirements.")
        Do ..CollectorAvailable(actor.%Id(),allocation.%Id(),pickup,arrival,now)
        Set allocation.CollectorActorId=actor.%Id(), allocation.PickupAt=pickup, allocation.ArrivalBy=arrival, allocation.TransportConfirmed=1, allocation.State="ready"
    } ElseIf action="handoff" {
        Do ..Require((actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId),"Only this kitchen can confirm the physical handoff.")
        Do ..Require((allocation.State="ready")&&allocation.TransportConfirmed,"A named collector must confirm the trip before handoff.")
        Do ..Require((offer.State="open")&&(now>=offer.ReadyAt)&&(now<offer.CollectBy),"The food is paused or outside its confirmed collection window. Ask the coordinator.")
        Set collector=..Actor(allocation.CollectorActorId)
        Do ..Require((collector.Role="collector")&&(collector.NetworkId=actor.NetworkId),"The assigned collector is no longer approved for this network.")
        Do ..CollectorAvailable(collector.%Id(),allocation.%Id(),allocation.PickupAt,allocation.ArrivalBy,now)
        Set quantity=+data.quantity
        Do ..Require((quantity>0)&&(quantity<=allocation.Quantity),"Record the actual positive quantity handed over, up to the commitment.")
        Set offer.CommittedQuantity=offer.CommittedQuantity-quantity, offer.CollectedQuantity=offer.CollectedQuantity+quantity
        Set allocation.CollectedQuantity=quantity, allocation.UnresolvedQuantity=allocation.Quantity-quantity, allocation.OutcomeNote=data.note, allocation.State="collected"
        // Any boxes not handed over remain committed until a person resolves their custody.
    } ElseIf action="receive" {
        Do ..Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId),"Only this receiving organization can confirm receipt.")
        Do ..Require(allocation.State="collected","A recorded kitchen handoff must precede receipt.")
        Set quantity=+data.quantity
        Do ..Require(quantity<=allocation.CollectedQuantity,"Receipt cannot exceed the quantity actually handed over.")
        Do ..Require((quantity=allocation.Quantity)||(data.note'=""),"Explain any missing or rejected boxes so the coordinator can follow up.")
        Set allocation.ReceivedQuantity=quantity, allocation.UnresolvedQuantity=allocation.Quantity-quantity, allocation.OutcomeNote=data.note
        Set allocation.State=$Select(allocation.UnresolvedQuantity=0:"received",1:"receipt_issue")
        // Need commitments include fulfilled food; missing boxes do not silently reopen receiving capacity.
    } Else {
        Do ..Require(0,"Unknown allocation action.")
    }
    Set allocation.Revision=allocation.Revision+1, offer.Revision=offer.Revision+1, need.Revision=need.Revision+1
    Do ..Save(offer), ..Save(need), ..Save(allocation), ..Event(actor,action,allocation.%Id(),data)
    Quit {"ok":true,"allocation_id":(allocation.%Id()),"revision":(allocation.Revision),"state":(allocation.State),"quantity":(""_allocation.Quantity),"collected_quantity":(""_allocation.CollectedQuantity),"received_quantity":(""_allocation.ReceivedQuantity),"unresolved_quantity":(""_allocation.UnresolvedQuantity)}
}

/// Planned arrival is not proof that a collector or their vehicle is free again.
ClassMethod CollectorAvailable(collectorId As %String, allocationId As %String, pickup As %BigInt, arrival As %BigInt, now As %BigInt)
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE CollectorActorId=? AND ID<>? AND (State IN ('collected','receipt_issue') OR (State='ready' AND (ArrivalBy<=? OR (PickupAt<? AND ArrivalBy>?))))",collectorId,allocationId,now,arrival,pickup)
    Do ..QueryOK(query)
    Set blocked=query.%Next()
    Do ..QueryOK(query)
    Do ..Require('blocked,"This collector has an overlapping trip or an earlier collection whose custody is unresolved. Confirm its outcome or assign another collector.")
}

ClassMethod ObserveStock(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set offer=..Open("Allfedo.Record.Offer",data."offer_id")
    Do ..Require($IsObject(offer)&&(offer.NetworkId=actor.NetworkId)&&(actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId),"Only this kitchen can report its physical stock.")
    Do ..Require(offer.Revision=data.revision,"The offer changed; review the current record first.")
    Do ..Require(data.note'="","Explain when and how this stock was counted.")
    Do ..Require(+data.quantity>=offer.CollectedQuantity,"A new total must include food already handed over; report a discrepancy instead of erasing custody.")
    Set offer.ObservedQuantity=+data.quantity, offer.CurrentQuantity=+data.quantity, offer.Revision=offer.Revision+1
    Set offer.State="review_required"
    Do ..Save(offer), ..Event(actor,"stock_observed",offer.%Id(),data)
    Quit {"ok":true,"offer_id":(offer.%Id()),"revision":(offer.Revision),"state":"review_required","declared_quantity":(""_offer.DeclaredQuantity),"observed_quantity":(""_offer.ObservedQuantity),"message":"New invitations and handoffs are paused. Existing promises remain recorded for coordinator review."}
}

/// Read only; a later ApplyPlan must re-read this under the resource locks.
ClassMethod Snapshot(actorId As %String, offerId As %String) As %DynamicObject
{
    Set actor=..Actor(actorId), offer=..Open("Allfedo.Record.Offer",offerId)
    Do ..Require($IsObject(offer)&&(offer.NetworkId=actor.NetworkId)&&(actor.Role="coordinator"),"Only an authorized coordinator can plan this offer.")
    Do ..ConfirmedSource(offer.SourceId,offer.NetworkId,offer.OrganizationId,"offer_confirmation")
    Set foodState=##class(Allfedo.Facts).FoodState(offer)
    Set food={"id":(""_offer.%Id()),"network_id":(offer.NetworkId),"revision":(offer.Revision),"available_quantity":(""_$Select(foodState="open":offer.CurrentQuantity-offer.HeldQuantity-offer.CommittedQuantity-offer.CollectedQuantity,1:0)),"unit":(offer.Unit),"ready_at":(##class(Allfedo.Policy).ISO(offer.ReadyAt)),"collect_by":(##class(Allfedo.Policy).ISO(offer.CollectBy)),"holding":(offer.Holding),"state":(foodState)}
    If offer.HandlingUntil="" { Do food.%Set("handling_until","","null") } Else { Set food."handling_until"=##class(Allfedo.Policy).ISO(offer.HandlingUntil) }
    If offer.Holding="" Do food.%Set("holding","","null")
    Set food.packaging=offer.Packaging
    Set food."source_ids"=[(""_offer.SourceId)]
    If (offer.OriginalSourceId'="")&&(offer.OriginalSourceId'=offer.SourceId) {
        Do ..ConfirmedSource(offer.OriginalSourceId,offer.NetworkId,offer.OrganizationId,"offer_confirmation")
        Do food."source_ids".%Push(""_offer.OriginalSourceId,"string")
    }
    Set food."present_allergens"=..ParseArray(offer.PresentAllergensJSON), food."assessed_allergens"=..ParseArray(offer.AssessedAllergensJSON)
    Set needs=[], query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Need WHERE NetworkId=? ORDER BY ID",actor.NetworkId)
    Do ..QueryOK(query)
    While query.%Next() {
        Set need=..Open("Allfedo.Record.Need",query.ID)
        Do ..ConfirmedSource(need.SourceId,need.NetworkId,need.OrganizationId,"need_confirmation")
        Set remaining=need.RequestedQuantity-need.HeldQuantity-need.CommittedQuantity, needState=##class(Allfedo.Facts).NeedState(need)
        If (remaining<0)||(needState'="open") Set remaining=0
        Set item={"id":(""_need.%Id()),"organization_id":(need.OrganizationId),"network_id":(need.NetworkId),"revision":(need.Revision),"remaining_quantity":(""_remaining),"unit":(need.Unit),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil))}
        Set item.state=needState
        Set item."source_ids"=[(""_need.SourceId)]
        Set item."excluded_allergens"=..ParseArray(need.ExcludedAllergensJSON), item."accepted_holding"=..ParseArray(need.AcceptedHoldingJSON)
        Do needs.%Push(item)
    }
    Do ..QueryOK(query)
    Quit {"network_id":(actor.NetworkId),"now":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now())),"offer":(food),"needs":(needs)}
}

ClassMethod Actor(actorId As %String) As Allfedo.Record.Actor
{
    Set actor=..Open("Allfedo.Record.Actor",actorId)
    Do ..Require($IsObject(actor)&&actor.Active,"An active authenticated network membership is required.")
    Quit actor
}

ClassMethod Source(actor As Allfedo.Record.Actor, kind As %String, data As %DynamicObject) As Allfedo.Record.Source
{
    Set source=##class(Allfedo.Record.Source).%New()
    Set source.NetworkId=actor.NetworkId, source.OrganizationId=actor.OrganizationId, source.SenderName=actor.DisplayName, source.ActorId=actor.%Id(), source.Kind=kind, source.RecordedAt=##class(Allfedo.Policy).Now(), source.EventAt=##class(Allfedo.Policy).Instant(data."event_at"), source.BodyJSON=data.%ToJSON()
    Do ..Require(source.EventAt<=source.RecordedAt+60,"A source event cannot be in the future.")
    Do ..Save(source)
    Quit source
}

/// A model cannot promote extracted text into a confirmed offer or receiving need.
ClassMethod ConfirmedSource(sourceId As %String, networkId As %String, organizationId As %String, kind As %String)
{
    Set source=..Open("Allfedo.Record.Source",sourceId)
    Do ..Require($IsObject(source),"A confirmed source record is missing.")
    Do ..Require((source.NetworkId=networkId)&&(source.OrganizationId=organizationId)&&(source.Kind=kind)&&(source.ConfirmationMethod="authenticated_submission"),"The source does not confirm these partner facts.")
}

ClassMethod Notify(actorId As %String, allocation As Allfedo.Record.Allocation, subject As %String, body As %String)
{
    Set contact=..Actor(actorId), item=##class(Allfedo.Record.Outbox).%New()
    Set item.NetworkId=allocation.NetworkId, item.AllocationId=allocation.%Id(), item.AllocationRevision=allocation.Revision, item.Recipient=contact.Email, item.Subject=subject, item.Body=body, item.DueAt=##class(Allfedo.Policy).Now()
    Do ..Save(item)
}

ClassMethod Event(actor As Allfedo.Record.Actor, kind As %String, resourceId As %String, body As %DynamicObject)
{
    Set item=##class(Allfedo.Record.Event).%New()
    Set item.NetworkId=actor.NetworkId, item.ActorId=actor.%Id(), item.Kind=kind, item.ResourceId=resourceId, item.RecordedAt=##class(Allfedo.Policy).Now(), item.BodyJSON=body.%ToJSON()
    Do ..Save(item)
}

ClassMethod Require(condition As %Boolean, message As %String)
{
    If 'condition Throw ##class(%Exception.General).%New("REJECTED",1000,,message)
}

/// IRIS reuses an already-open object in this process. Reload so a retained OREF cannot bypass revision checks.
ClassMethod QueryOK(result As %SQL.StatementResult)
{
    If result.%SQLCODE<0 Throw ##class(%Exception.SQL).%New(,result.%SQLCODE,,result.%Message)
}

ClassMethod Open(className As %String, id As %String) As %Persistent
{
    Set record=$ClassMethod(className,"%OpenId",id)
    If $IsObject(record) {
        Set status=record.%Reload()
        If $$$ISERR(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
    }
    Quit record
}

ClassMethod Save(record As %Persistent)
{
    Set status=record.%Save()
    If $$$ISERR(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
}

ClassMethod Parse(value As %String) As %DynamicObject
{
    Quit ##class(%DynamicObject).%FromJSON(value)
}

ClassMethod ParseArray(value As %String) As %DynamicArray
{
    Quit ##class(%DynamicArray).%FromJSON(value)
}
}
