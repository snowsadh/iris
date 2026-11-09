/// Physical facts, current promises, and explicit recovery. Rescue owns the surrounding locks/transaction.
Class Allfedo.Recovery Extends %RegisteredObject
{
ClassMethod Evidence(actor As Allfedo.Record.Actor, kind As %String, data As %DynamicObject) As Allfedo.Record.Source
{
    Set body=##class(Allfedo.Rescue).Parse(data.%ToJSON())
    If body.%IsDefined("occurred_at") Do ##class(Allfedo.Rescue).Require(##class(Allfedo.Policy).AtOrBefore(body."occurred_at",##class(Allfedo.Policy).NowISO()),"A physical event cannot occur in the future. Check the date, time, and offset.")
    Set body."event_at"=body.%Get("occurred_at",##class(Allfedo.Policy).NowISO())
    Quit ##class(Allfedo.Rescue).Source(actor,kind,body)
}

ClassMethod Prepare(offer As Allfedo.Record.Offer, allocation As Allfedo.Record.Allocation = "")
{
    If offer.LegacyCollectedQuantity="" {
        Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT COALESCE(SUM(Quantity),0) AS Total FROM Allfedo_Record.Custody WHERE OfferId=? AND Active=1 AND Kind='handoff'",offer.%Id())
        Do ##class(Allfedo.Rescue).QueryOK(query)
        Do ##class(Allfedo.Rescue).Require(query.%Next(),"The recorded handoff balance could not be read.")
        Do ##class(Allfedo.Rescue).QueryOK(query)
        Set legacy=offer.CollectedQuantity-query.Total
        Do ##class(Allfedo.Rescue).Require(legacy>=0,"The old and new handoff records need review before changing stock.")
        Set offer.LegacyCollectedQuantity=legacy
        // This is an upper bound on when an earlier stored aggregate was observed, not an invented physical time.
        If legacy>0 {
            Set old=##class(%SQL.Statement).%ExecDirect(,"SELECT MAX(e.RecordedAt) AS Latest FROM Allfedo_Record.Event e JOIN Allfedo_Record.Allocation a ON e.ResourceId=a.ID WHERE e.Kind='handoff' AND a.OfferId=?",offer.%Id())
            Do ##class(Allfedo.Rescue).QueryOK(old)
            Do ##class(Allfedo.Rescue).Require(old.%Next(),"The earlier handoff recording bound could not be read.")
            Do ##class(Allfedo.Rescue).QueryOK(old)
            Set offer.LegacyRecordedUntil=$Select(old.Latest'="":old.Latest+1,1:##class(Allfedo.Policy).Now()+1)
        }
    }
    If $IsObject(allocation) {
        If allocation.HeldQuantity="" Set allocation.HeldQuantity=$Select(allocation.State="held":allocation.Quantity,1:0)
        If allocation.OriginalPromiseQuantity="",allocation.AcceptedByActorId'="" Set allocation.OriginalPromiseQuantity=allocation.Quantity
        If allocation.LegacyCollectedQuantity="" Set allocation.LegacyCollectedQuantity=allocation.CollectedQuantity
        If allocation.LegacyReceivedQuantity="" Set allocation.LegacyReceivedQuantity=allocation.ReceivedQuantity
        If allocation.StockCommittedQuantity="" Set allocation.StockCommittedQuantity=$Select(allocation.AcceptedByActorId="":0,allocation.Quantity>allocation.CollectedQuantity:allocation.Quantity-allocation.CollectedQuantity,1:0)
    }
}

ClassMethod RebuildStock(offer As Allfedo.Record.Offer) As %DynamicObject
{
    Do ..Prepare(offer)
    Set declarationSource=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",$Select(offer.OriginalSourceId'="":offer.OriginalSourceId,1:offer.SourceId))
    Set original=##class(Allfedo.Rescue).Parse(declarationSource.BodyJSON)
    Set declaration={"quantity":(""_offer.DeclaredQuantity),"unit":(offer.Unit),"source_id":(""_declarationSource.%Id()),"occurred_at":(original.%Get("event_at",##class(Allfedo.Policy).ISO(declarationSource.EventAt))),"legacy_collected_quantity":(""_offer.LegacyCollectedQuantity)}
    If offer.LegacyCollectedQuantity>0 Set declaration."legacy_recorded_until"=##class(Allfedo.Policy).ISO(offer.LegacyRecordedUntil)
    Set countJSON="null"
    If offer.ObservationSourceId'="" {
        Set counted=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",offer.ObservationSourceId), body=##class(Allfedo.Rescue).Parse(counted.BodyJSON)
        Set count={"on_hand_quantity":(body."on_hand_quantity"),"source_id":(""_counted.%Id()),"occurred_at":(body."occurred_at")}
        Set countJSON=count.%ToJSON()
    }
    Set entries=[], query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Custody WHERE OfferId=? AND Active=1 AND Kind IN ('handoff','returned','quarantine_disposed') ORDER BY ID",offer.%Id())
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set fact=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",query.ID), source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",fact.SourceId), body=##class(Allfedo.Rescue).Parse(source.BodyJSON)
        Do entries.%Push({"kind":(fact.Kind),"quantity":(""_fact.Quantity),"source_id":(""_fact.SourceId),"occurred_at":(body."occurred_at")})
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Try {
        Set projected=##class(Allfedo.Rescue).Parse(##class(Allfedo.Policy).ProjectStock(declaration.%ToJSON(),countJSON,entries.%ToJSON()))
    } Catch projectionError {
        // Keep the physical report even if older evidence cannot yet produce a reliable balance.
        Set projected={"current_total_quantity":null,"collected_quantity":(""_offer.CollectedQuantity),"quarantined_quantity":null,"usable_on_hand_quantity":"0","review_required":true,"issues":[{"code":"STOCK_REQUIRES_REVIEW","message":"A physical report was saved, but its stock history needs review before new invitations."}]}
    }
    If offer.ObservationConflict {
        Set projected."review_required"=1,projected."usable_on_hand_quantity"="0"
        Do projected.issues.%Push({"code":"CONFLICTING_COUNT_TIME","message":"Two different counts share the same physical time. Confirm a later recount."})
    }
    Set references=[]
    If offer.ObservationSourceId'="" Do references.%Push(""_offer.ObservationSourceId,"string")
    For entryIndex=0:1:entries.%Size()-1 { Set entry=entries.%Get(entryIndex) Do references.%Push(entry."source_id","string") }
    Set projected."source_ids"=references
    If projected.%GetTypeOf("current_total_quantity")'="null" Set offer.CurrentQuantity=+projected."current_total_quantity"
    Set offer.CollectedQuantity=+projected."collected_quantity"
    If projected.%GetTypeOf("quarantined_quantity")'="null" Set offer.QuarantinedQuantity=+projected."quarantined_quantity"
    Set offer.StockProjectionJSON=projected.%ToJSON()
    If projected."review_required" Set offer.State="review_required"
    Quit projected
}

ClassMethod CountStock(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",data."offer_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(offer)&&(actor.Role="kitchen")&&(offer.NetworkId=actor.NetworkId)&&(offer.OrganizationId=actor.OrganizationId),"Only this kitchen can report what is physically at its site.")
    Do ##class(Allfedo.Rescue).Require(data.note'="","Explain how and when the food was counted, including quarantined returns.")
    Do ..Prepare(offer)
    Set source=..Evidence(actor,"stock_observation",data), occurrence=##class(Allfedo.Policy).Instant(data."occurred_at"), applied=0
    Set later=1,equal=0
    If offer.ObservationSourceId'="" {
        Set previous=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",offer.ObservationSourceId),previousBody=##class(Allfedo.Rescue).Parse(previous.BodyJSON)
        Set equal=data."occurred_at"=previousBody."occurred_at"
        Set later='##class(Allfedo.Policy).AtOrBefore(data."occurred_at",previousBody."occurred_at")
        If equal&&(+data."on_hand_quantity"'=+previousBody."on_hand_quantity") Set offer.ObservationConflict=1
    }
    If (offer.Revision=data.revision)&&later {
        Set offer.ObservedQuantity=+data."on_hand_quantity",offer.ObservationAt=occurrence,offer.ObservationSourceId=source.%Id(),offer.ObservationConflict=0,applied=1
    }
    Set projected=..RebuildStock(offer)
    Set offer.State="review_required", offer.Revision=offer.Revision+1
    Do ##class(Allfedo.Rescue).Save(offer), ##class(Allfedo.Rescue).Event(actor,"stock_counted",offer.%Id(),data)
    Quit {"ok":true,"offer_id":(""_offer.%Id()),"revision":(offer.Revision),"state":(offer.State),"observation_applied":(applied),"source_id":(""_source.%Id()),"declared_quantity":(""_offer.DeclaredQuantity),"observed_on_hand_quantity":(data."on_hand_quantity"),"quarantined_quantity":(""_offer.QuarantinedQuantity)}
}

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
    Quit {"details":(details),"evidence":(evidence),"context_key":(key)}
}

ClassMethod TripChanged(allocation As Allfedo.Record.Allocation) As %Boolean
{
    If 'allocation.TransportConfirmed Quit 1
    If allocation.TripContextKey="" Quit 1
    Set current=..CurrentContext(allocation)
    Quit current."context_key"'=allocation.TripContextKey
}

ClassMethod Balance(allocation As Allfedo.Record.Allocation) As %DynamicObject
{
    Set stock=allocation.StockCommittedQuantity
    If stock="" Set stock=$Select(allocation.State="held":0,allocation.Quantity>allocation.CollectedQuantity:allocation.Quantity-allocation.CollectedQuantity,1:0)
    Set unknown=$Select(allocation.CollectedQuantity>allocation.ReceivedQuantity+allocation.AccountedQuantity:allocation.CollectedQuantity-allocation.ReceivedQuantity-allocation.AccountedQuantity,1:0)
    Set unmatched=$Select(allocation.ReceivedQuantity+allocation.AccountedQuantity>allocation.CollectedQuantity:allocation.ReceivedQuantity+allocation.AccountedQuantity-allocation.CollectedQuantity,1:0)
    Set cannot=$Select(allocation.AccountedQuantity>allocation.SettledHandedQuantity:allocation.AccountedQuantity-allocation.SettledHandedQuantity,1:0)
    Quit {"unhanded_quantity":(""_stock),"physical_unknown_quantity":(""_unknown),"unmatched_report_quantity":(""_unmatched),"cannot_arrive_quantity":(""_cannot),"accounted_quantity":(""_allocation.AccountedQuantity)}
}
ClassMethod RefreshCase(allocation As Allfedo.Record.Allocation)
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT Kind,COALESCE(SUM(Quantity),0) AS Total FROM Allfedo_Record.Custody WHERE AllocationId=? AND Active=1 GROUP BY Kind",allocation.%Id())
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set handed=+allocation.LegacyCollectedQuantity, received=+allocation.LegacyReceivedQuantity, accounted=0, lost=0, rejected=0, returned=0, disposed=0
    While query.%Next() {
        Set kind=$ZCONVERT(query.Kind,"L")
        If kind="handoff" Set handed=handed+query.Total
        If kind="receipt" Set received=received+query.Total
        If kind="lost" Set lost=lost+query.Total
        If kind="rejected_at_site" Set rejected=rejected+query.Total
        If kind="returned" Set returned=returned+query.Total
        If kind="discarded" Set disposed=disposed+query.Total
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set accounted=lost+rejected+returned+disposed
    Set allocation.CollectedQuantity=handed, allocation.ReceivedQuantity=received, allocation.AccountedQuantity=accounted, allocation.LostQuantity=lost, allocation.RejectedQuantity=rejected, allocation.ReturnedQuantity=returned, allocation.DisposedQuantity=disposed
    Set original=+allocation.OriginalPromiseQuantity, stock=original-handed-allocation.CancelledUnhandedQuantity
    If stock<0 Set stock=0
    Set allocation.StockCommittedQuantity=stock
    // A later confirmed outcome can explain food previously closed as unknown, without creating replacement demand twice.
    Set explained=accounted-allocation.SettledHandedQuantity
    If explained>allocation.ClosedUnknownQuantity Set explained=allocation.ClosedUnknownQuantity
    If explained>0 Set allocation.SettledHandedQuantity=allocation.SettledHandedQuantity+explained,allocation.ClosedUnknownQuantity=allocation.ClosedUnknownQuantity-explained
    Set balance=..Balance(allocation), unknown=+balance."physical_unknown_quantity", unmatched=+balance."unmatched_report_quantity", cannot=+balance."cannot_arrive_quantity"
    If allocation.ClosedUnknownQuantity>unknown Set allocation.ClosedUnknownQuantity=unknown
    Set allocation.UnresolvedQuantity=stock+unknown+cannot
    If unmatched>allocation.UnresolvedQuantity Set allocation.UnresolvedQuantity=unmatched
    If unmatched>0 {
        Set allocation.State="custody_review"
    } ElseIf (allocation.ClosedUnknownQuantity>0)&&(stock=0) {
        Set allocation.State="closed_unconfirmed"
    } ElseIf (+allocation.HeldQuantity>0) {
        Set allocation.State=$Select(handed>0:"custody_review",1:"held")
    } ElseIf (stock=0)&&(unknown=0)&&(cannot=0)&&(allocation.Quantity<=received) {
        Set allocation.State=$Select((allocation.Quantity=0)&&(handed=0):"cancelled",original>received:"partial_closed",1:"received")
    } ElseIf (cannot>0)||((received+accounted)>0) {
        Set allocation.State="receipt_issue"
    } ElseIf handed>0 {
        Set allocation.State="collected"
    } Else {
        Set allocation.State=$Select(allocation.TransportConfirmed:"ready",1:"accepted")
    }
}

/// Read every allocation under the shared lot/need locks; do not subtract a transit loss from kitchen stock.
ClassMethod RebuildCommitments(offer As Allfedo.Record.Offer, need As Allfedo.Record.Need)
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE OfferId=?",offer.%Id()), held=0, committed=0
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",query.ID), h=item.HeldQuantity
        If h="" Set h=$Select(item.State="held":item.Quantity,1:0)
        Set held=held+h, stock=item.StockCommittedQuantity
        If stock="" Set stock=$Select(item.AcceptedByActorId="":0,item.Quantity>item.CollectedQuantity:item.Quantity-item.CollectedQuantity,1:0)
        Set committed=committed+stock
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set offer.HeldQuantity=held,offer.CommittedQuantity=committed
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE NeedId=?",need.%Id()), held=0,committed=0
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",query.ID), h=item.HeldQuantity
        If h="" Set h=$Select(item.State="held":item.Quantity,1:0)
        Set held=held+h, promised=$Select(item.AcceptedByActorId'="":item.Quantity,1:0)
        If item.ReceivedQuantity>promised Set promised=item.ReceivedQuantity
        Set committed=committed+promised
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set need.HeldQuantity=held,need.CommittedQuantity=committed
    If held+committed>need.RequestedQuantity Set need.State="review_required"
}

ClassMethod StorePhysical(actor As Allfedo.Record.Actor, allocation As Allfedo.Record.Allocation, kind As %String, data As %DynamicObject, issue As %String = "", supersedes As %String = "") As Allfedo.Record.Custody
{
    Set source=..Evidence(actor,kind,data), fact=##class(Allfedo.Record.Custody).%New()
    Set fact.NetworkId=actor.NetworkId,fact.AllocationId=$Select($IsObject(allocation):allocation.%Id(),1:""),fact.OfferId=data.%Get("offer_id"),fact.ActorId=actor.%Id(),fact.Kind=kind,fact.Quantity=+data.quantity,fact.OccurredAt=##class(Allfedo.Policy).Instant(data."occurred_at"),fact.RecordedAt=##class(Allfedo.Policy).Now(),fact.SourceId=source.%Id(),fact.AgreementIssue=issue,fact.SupersedesId=supersedes
    If $IsObject(allocation) Set fact.OfferId=allocation.OfferId
    Do ##class(Allfedo.Rescue).Save(fact)
    Quit fact
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

ClassMethod RecordPhysical(actor As Allfedo.Record.Actor, action As %String, data As %DynamicObject) As %DynamicObject
{
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id"), now=##class(Allfedo.Policy).Now()
    Do ##class(Allfedo.Rescue).Require($IsObject(allocation)&&(allocation.NetworkId=actor.NetworkId),"This collection is outside your network.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId), need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    Do ..Prepare(offer,allocation)
    Set issue="", kind="", quantity=+data.quantity, occurrence=##class(Allfedo.Policy).Instant(data."occurred_at")
    If allocation.Revision'=data.revision Set issue="This report arrived after other case changes. Its physical facts remain recorded for review."
    If action="handoff" {
        Do ##class(Allfedo.Rescue).Require((actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId),"Only this kitchen can report its actual handoff.")
        Set kind="handoff", agreement=..AgreementAt(allocation,data."occurred_at")
        If 'agreement.%IsDefined("details") {
            Set issue="No recorded collector agreement existed at the reported handoff time."
        } Else {
            Set facts=agreement.details.food
            If (occurrence<##class(Allfedo.Policy).Instant(facts."ready_at"))||(occurrence>=##class(Allfedo.Policy).Instant(facts."collect_by"))||(occurrence>=##class(Allfedo.Policy).Instant(facts."handling_until")) Set issue="The reported physical handoff did not meet the recorded food or collection deadline."
        }
        If quantity>allocation.StockCommittedQuantity Set issue="The reported handoff exceeds the unhanded promise. Confirm the actual stock and recipient outcome."
    } ElseIf (action="receive")||(action="receive_more") {
        Do ##class(Allfedo.Rescue).Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId),"Only this receiving partner can report what it actually accepted.")
        If action="receive" Do ##class(Allfedo.Rescue).Require('..ReceiptRecorded(allocation),"A receiving count already exists. Record additional accepted boxes separately, or correct the earlier report.")
        Set kind="receipt",agreement=..AgreementAt(allocation,data."occurred_at")
        If 'agreement.%IsDefined("details") {
            Set issue="No recorded collector agreement existed at the reported receiving time. The actual accepted food remains recorded."
        } Else {
            Set receiving=agreement.details.receiving,food=agreement.details.food
            If (receiving."receiving_from"="")||(occurrence<##class(Allfedo.Policy).Instant(receiving."receiving_from"))||(occurrence>=##class(Allfedo.Policy).Instant(receiving."receiving_until"))||(occurrence>##class(Allfedo.Policy).Instant(food."handling_until")) Set issue="The actual receiving time fell outside the recorded receiving or food-handling window. The accepted food remains recorded."
        }
        If allocation.ReceivedQuantity+quantity+allocation.AccountedQuantity>allocation.CollectedQuantity Set issue="This receiving report is not yet matched to a recorded kitchen handoff."
    } Else {
        Set kind=$Select(data.outcome="returned_to_kitchen":"returned",1:data.outcome)
        If kind="returned" {
            Do ##class(Allfedo.Rescue).Require((actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId),"Only this kitchen can confirm returned food physically arrived; it stays quarantined.")
        } ElseIf kind="rejected_at_site" {
            Do ##class(Allfedo.Rescue).Require((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId),"Only this receiving partner can confirm food rejected and kept at its site.")
        } Else {
            Do ##class(Allfedo.Rescue).Require((actor.Role="collector")&&(allocation.CollectorActorId=actor.%Id()),"Only the assigned collector can report loss or disposal of food in their custody.")
        }
        Do ##class(Allfedo.Rescue).Require(data.note'="","Explain what happened and where the food was last known to be.")
        If allocation.ReceivedQuantity+allocation.AccountedQuantity+quantity>allocation.CollectedQuantity Set issue="This disposition is not yet matched to the recorded handed-over amount."
    }
    Set physical=..StorePhysical(actor,allocation,kind,data,issue), allocation.OutcomeNote=data.note
    If issue'="" Set allocation.CustodyIssue=issue,offer.State="review_required"
    Do ..RefreshCase(allocation)
    Set allocation.Revision=allocation.Revision+1
    Do ##class(Allfedo.Rescue).Save(allocation)
    Do ..RebuildCommitments(offer,need)
    Set projected=..RebuildStock(offer), offer.Revision=offer.Revision+1,need.Revision=need.Revision+1
    Do ##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Save(need),##class(Allfedo.Rescue).Event(actor,action,allocation.%Id(),data)
    Quit {"ok":true,"allocation_id":(""_allocation.%Id()),"revision":(allocation.Revision),"state":(allocation.State),"physical_report_saved":true,"custody_id":(""_physical.%Id()),"agreement_issue":(issue),"collected_quantity":(""_allocation.CollectedQuantity),"received_quantity":(""_allocation.ReceivedQuantity),"accounted_quantity":(""_allocation.AccountedQuantity),"unresolved_quantity":(""_allocation.UnresolvedQuantity)}
}

ClassMethod RecipientKey(context As %DynamicObject) As %String
{
    Set food=##class(Allfedo.Rescue).Parse(context.details.food.%ToJSON())
    Do food.%Remove("packaging")
    Set recipient={"allocation_id":(context.details."allocation_id"),"quantity":(context.details.quantity),"food":(food),"destination":(context.details.destination),"receiving":(context.details.receiving)}
    Quit $SYSTEM.Encryption.ToHex($SYSTEM.Encryption.SHAHash(256,$ZCONVERT(recipient.%ToJSON(),"O","UTF8")))
}

/// Hard gates for an existing promise. Consent never overrides allergen, handling, or receiving limits.
ClassMethod AssertCompatible(offer As Allfedo.Record.Offer, need As Allfedo.Record.Need, arrival As %BigInt)
{
    Do ##class(Allfedo.Rescue).ConfirmedSource(offer.SourceId,offer.NetworkId,offer.OrganizationId,"offer_confirmation")
    Do ##class(Allfedo.Rescue).ConfirmedSource(need.SourceId,need.NetworkId,need.OrganizationId,"need_confirmation")
    Set now=##class(Allfedo.Policy).Now()
    Do ##class(Allfedo.Rescue).Require((##class(Allfedo.Facts).NeedState(need)="open")&&(need.HeldQuantity+need.CommittedQuantity<=need.RequestedQuantity),"The receiving need or existing promises require review before confirming this trip.")
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
    Do ##class(Allfedo.Rescue).Require((pickup."contact_name"'="")&&(destination."contact_name"'=""),"A partner's named site contact is no longer active. Ask that partner to confirm its contact details.")
}

ClassMethod RecordAgreement(actor As Allfedo.Record.Actor, allocation As Allfedo.Record.Allocation, data As %DynamicObject, first As %Boolean = 0)
{
    Set context=..CurrentContext(allocation),offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    Do ..AssertCompatible(offer,need,allocation.ArrivalBy)
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

ClassMethod AcknowledgeTrip(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(allocation)&&(allocation.NetworkId=actor.NetworkId)&&(actor.Role="collector")&&(allocation.CollectorActorId=actor.%Id()),"Only this collection's assigned collector can confirm changed instructions.")
    Do ##class(Allfedo.Rescue).Require(allocation.Revision=data.revision,"This collection changed. Review the current quantities and instructions.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId),arrival=##class(Allfedo.Policy).Instant(data."arrival_by"),now=##class(Allfedo.Policy).Now()
    Do ..Prepare(offer,allocation)
    Do ##class(Allfedo.Rescue).Require((allocation.Quantity>allocation.ReceivedQuantity)&&(allocation.State'="cancelled")&&(allocation.State'="closed_unconfirmed"),"There is no current agreed delivery left to confirm.")
    Do ##class(Allfedo.Rescue).Require((need.ReceivingFrom'="")&&(arrival>=need.ReceivingFrom)&&(arrival>now)&&(arrival<need.ReceivingUntil)&&(arrival<=offer.HandlingUntil)&&data."handling_accepted","The changed arrival and handling agreement must fit the current confirmed limits.")
    Set load=allocation.StockCommittedQuantity+allocation.CollectedQuantity-allocation.ReceivedQuantity-allocation.AccountedQuantity
    Do ##class(Allfedo.Rescue).Require((+data.capacity>=load)&&(offer.Packaging'=""),"Confirm actual carrying details and enough capacity for the remaining load.")
    Do ##class(Allfedo.Rescue).CollectorAvailable(actor.%Id(),allocation.%Id(),$Select(allocation.StockCommittedQuantity>0:allocation.PickupAt,1:now),arrival,now)
    Set allocation.ArrivalBy=arrival
    Do ..RecordAgreement(actor,allocation,data,0),..RefreshCase(allocation)
    Set allocation.Revision=allocation.Revision+1
    Do ##class(Allfedo.Rescue).Save(allocation),##class(Allfedo.Rescue).Event(actor,"trip_reconfirmed",allocation.%Id(),data)
    Quit {"ok":true,"allocation_id":(""_allocation.%Id()),"revision":(allocation.Revision),"state":(allocation.State),"trip_confirmed":true}
}

ClassMethod ResumeOffer(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",data."offer_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(offer)&&(offer.NetworkId=actor.NetworkId)&&(actor.Role="coordinator"),"Only the network coordinator can resume invitations after a review.")
    Do ##class(Allfedo.Rescue).Require(offer.Revision=data.revision,"This food lot changed. Review the latest count and commitments.")
    Set projected=..RebuildStock(offer)
    Do ##class(Allfedo.Rescue).Require('projected."review_required","The physical stock history is still uncertain. Confirm a fresh count or correct the conflicting report.")
    Do ##class(Allfedo.Rescue).Require(##class(Allfedo.Facts).FoodFactsState(offer)="open","Food, place, or handling details are missing or expired. The kitchen must confirm them.")
    Do ##class(Allfedo.Rescue).Require((offer.CurrentQuantity-offer.CollectedQuantity)>=offer.HeldQuantity+offer.CommittedQuantity,"Existing food promises still exceed the confirmed usable stock. Agree the affected changes first.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE OfferId=? AND AcceptedByActorId IS NOT NULL",offer.%Id())
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",query.ID),balance=..Balance(item)
        If +balance."unhanded_quantity">0 {
            Set context=..CurrentContext(item)
            Do ##class(Allfedo.Rescue).Require(item.ConsentContextKey=..RecipientKey(context),"An affected receiving partner still needs to confirm the changed food or destination.")
        }
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set offer.State="open",offer.Revision=offer.Revision+1
    Do ##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Event(actor,"invitations_resumed",offer.%Id(),data)
    Quit {"ok":true,"offer_id":(""_offer.%Id()),"revision":(offer.Revision),"state":"open"}
}

ClassMethod Withdraw(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(allocation)&&(allocation.NetworkId=actor.NetworkId),"This invitation is outside your network.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    Do ..Prepare(offer,allocation)
    Do ##class(Allfedo.Rescue).Require((actor.Role="coordinator")||((actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId)),"Only the coordinator or this kitchen can withdraw its invitation.")
    Do ##class(Allfedo.Rescue).Require((allocation.Revision=data.revision)&&(allocation.HeldQuantity>0)&&(allocation.AcceptedByActorId=""),"Only a current unaccepted invitation can be withdrawn. An accepted promise needs an agreed change.")
    Set allocation.HeldQuantity=0,allocation.State="released",allocation.OutcomeNote=data.reason,allocation.Revision=allocation.Revision+1
    Do ##class(Allfedo.Rescue).Save(allocation),..RebuildCommitments(offer,need)
    Set offer.Revision=offer.Revision+1,need.Revision=need.Revision+1
    Do ##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Save(need),##class(Allfedo.Rescue).Event(actor,"invitation_withdrawn",allocation.%Id(),data)
    Do ..Notice(need.ContactActorId,allocation,"withdrawn","Food invitation withdrawn",data.reason)
    Quit {"ok":true,"allocation_id":(""_allocation.%Id()),"revision":(allocation.Revision),"state":(allocation.State)}
}

ClassMethod RequestChange(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",data."allocation_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(allocation)&&(allocation.NetworkId=actor.NetworkId)&&(actor.Role="coordinator"),"Only the coordinator can propose this promise change.")
    Do ##class(Allfedo.Rescue).Require((allocation.Revision=data.revision)&&(allocation.AcceptedByActorId'=""),"Review the current accepted promise before proposing a change.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    Do ..Prepare(offer,allocation)
    If allocation.PendingChangeId'="" {
        Set previous=##class(Allfedo.Rescue).Open("Allfedo.Record.ChangeRequest",allocation.PendingChangeId)
        Do ##class(Allfedo.Rescue).Require('$IsObject(previous)||(previous.State'="awaiting_response"),"A change is already awaiting a reply. Do not send a competing promise.")
    }
    Set quantity=+data."new_quantity",delta=allocation.Quantity-quantity,balance=..Balance(allocation)
    Do ##class(Allfedo.Rescue).Require((delta>=0)&&(quantity>=allocation.ReceivedQuantity),"A change may reduce the outstanding promise, but cannot erase food already accepted.")
    Set known=+balance."cannot_arrive_quantity",settled=$Select(delta<known:delta,1:known),left=delta-settled,stock=$Select(left<allocation.StockCommittedQuantity:left,1:allocation.StockCommittedQuantity),unconfirmed=left-stock
    Do ##class(Allfedo.Rescue).Require(unconfirmed<=(+balance."physical_unknown_quantity"-allocation.ClosedUnknownQuantity),"That reduction is not explained by current stock, confirmed outcomes, or explicitly unknown custody.")
    Set context=..CurrentContext(allocation,quantity),change=##class(Allfedo.Record.ChangeRequest).%New()
    Set change.NetworkId=actor.NetworkId,change.AllocationId=allocation.%Id(),change.RequestedByActorId=actor.%Id(),change.OriginalQuantity=allocation.Quantity,change.NewQuantity=quantity,change.Reason=data.reason,change.ContextJSON=context.%ToJSON(),change.ContextKey=context."context_key",change.CreatedAt=##class(Allfedo.Policy).Now(),change.StockReleaseQuantity=stock,change.HandedSettlementQuantity=settled,change.UnconfirmedSettlementQuantity=unconfirmed
    Set change.RecipientRequired=(delta>0)||(allocation.ConsentContextKey'=..RecipientKey(context)),change.KitchenRequired=(stock>0),change.AllocationRevision=allocation.Revision+1
    Do ##class(Allfedo.Rescue).Save(change)
    Set allocation.PendingChangeId=change.%Id(),allocation.Revision=allocation.Revision+1,change.AllocationRevision=allocation.Revision
    Do ##class(Allfedo.Rescue).Save(allocation),##class(Allfedo.Rescue).Save(change),##class(Allfedo.Rescue).Event(actor,"change_requested",allocation.%Id(),data)
    If change.RecipientRequired Do ..Notice(need.ContactActorId,allocation,"change_request","Please review this food promise change",data.reason,change.%Id())
    If change.KitchenRequired Do ..Notice(offer.ContactActorId,allocation,"change_request","Please confirm actual kitchen stock",data.reason,change.%Id())
    If allocation.CollectorActorId'="" Do ..Notice(allocation.CollectorActorId,allocation,"change_request","A collection change needs review",data.reason,change.%Id())
    Do ..ApplyChangeIfReady(change,allocation,offer,need)
    Quit {"ok":true,"allocation_id":(""_allocation.%Id()),"revision":(allocation.Revision),"change_id":(""_change.%Id()),"change_revision":(change.Revision),"state":(change.State),"stock_release_quantity":(""_stock),"handed_settlement_quantity":(""_settled),"unconfirmed_settlement_quantity":(""_unconfirmed)}
}

ClassMethod RespondChange(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set change=##class(Allfedo.Rescue).Open("Allfedo.Record.ChangeRequest",data."change_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(change)&&(change.NetworkId=actor.NetworkId),"This proposed change is outside your network.")
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",change.AllocationId),offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",allocation.OfferId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    Do ..Prepare(offer,allocation)
    Do ##class(Allfedo.Rescue).Require(change.Revision=data.revision,"This proposal changed. Review its current result.")
    Set party=$Select((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId):"recipient",(actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId):"kitchen",(actor.Role="collector")&&(actor.%Id()=allocation.CollectorActorId):"collector",1:"")
    Do ##class(Allfedo.Rescue).Require(party'="","Only the responsible receiving partner, kitchen, or assigned collector can reply.")
    Do ##class(Allfedo.Rescue).Require((change.State="awaiting_response")||((change.State="applied")&&(party="collector")),"This proposal already ended. Review its saved result instead of changing the old reply.")
    Set source=..Evidence(actor,"change_response",data)
    If party="recipient" {
        Do ##class(Allfedo.Rescue).Require(change.RecipientSourceId="","This receiving partner already replied to the proposal.")
        Set change.RecipientSourceId=source.%Id()
        If data.agree {
            Do ##class(Allfedo.Rescue).Require((data.%GetTypeOf("need_total")'="null")&&(data.%GetTypeOf("need_revision")'="null")&&(need.Revision=data."need_revision"),"Confirm the full current receiving need and its current revision; replacement demand is not inferred.")
            Set full={"need_id":(""_need.%Id()),"revision":(need.Revision),"quantity":(data."need_total"),"unit":(need.Unit),"receiving_from":(##class(Allfedo.Policy).ISO(need.ReceivingFrom)),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil)),"excluded_allergens":(##class(Allfedo.Rescue).ParseArray(need.ExcludedAllergensJSON)),"accepted_holding":(##class(Allfedo.Rescue).ParseArray(need.AcceptedHoldingJSON)),"event_at":(##class(Allfedo.Policy).NowISO())}
            Set needSource=##class(Allfedo.Rescue).Source(actor,"need_confirmation",full),need.RequestedQuantity=+data."need_total",need.SourceId=needSource.%Id(),need.ContactActorId=actor.%Id(),need.Revision=need.Revision+1,change.RecipientNeedSourceId=needSource.%Id(),change.NeedBaseSourceId=needSource.%Id()
            If need.HeldQuantity+need.CommittedQuantity>need.RequestedQuantity Set need.State="review_required"
            Do ##class(Allfedo.Rescue).Save(need)
        }
    } ElseIf party="kitchen" {
        Do ##class(Allfedo.Rescue).Require(change.KitchenSourceId="","This kitchen already replied to the proposal.")
        Set change.KitchenSourceId=source.%Id()
        If data.agree&&change.KitchenRequired {
            Do ##class(Allfedo.Rescue).Require((data.%GetTypeOf("stock_source_id")'="null")&&(offer.ObservationSourceId=data."stock_source_id"),"Confirm the latest actual on-hand stock count. Do not assert that missing cancelled boxes exist.")
            Set projected=..RebuildStock(offer)
            Do ##class(Allfedo.Rescue).Require('projected."review_required","The current count still has conflicting physical history. Confirm a fresh count first.")
            Set change.KitchenStockSourceId=offer.ObservationSourceId
            Do ##class(Allfedo.Rescue).Save(offer)
        }
    } Else {
        Do ##class(Allfedo.Rescue).Require(change.CollectorSourceId="","The assigned collector already replied to the proposal.")
        Set change.CollectorSourceId=source.%Id()
    }
    If 'data.agree&&(party'="collector") {
        Set change.State="rejected",change.CompletedAt=##class(Allfedo.Policy).Now()
    }
    Set change.Revision=change.Revision+1
    Do ##class(Allfedo.Rescue).Save(change)
    If change.State="awaiting_response" Do ..ApplyChangeIfReady(change,allocation,offer,need)
    Do ##class(Allfedo.Rescue).Event(actor,"change_response",allocation.%Id(),data)
    Quit {"ok":true,"change_id":(""_change.%Id()),"revision":(change.Revision),"allocation_id":(""_allocation.%Id()),"allocation_revision":(allocation.Revision),"state":(change.State)}
}

ClassMethod ApplyChangeIfReady(change As Allfedo.Record.ChangeRequest, allocation As Allfedo.Record.Allocation, offer As Allfedo.Record.Offer, need As Allfedo.Record.Need)
{
    If change.RecipientRequired&&(change.RecipientSourceId="") Quit
    If change.KitchenRequired&&(change.KitchenSourceId="") Quit
    Set context=..CurrentContext(allocation,change.NewQuantity)
    If (allocation.Revision'=change.AllocationRevision)||(context."context_key"'=change.ContextKey)||((change.RecipientNeedSourceId'="")&&(need.SourceId'=change.NeedBaseSourceId)) {
        Set change.State="stale",change.CompletedAt=##class(Allfedo.Policy).Now(),change.Revision=change.Revision+1
        Do ##class(Allfedo.Rescue).Save(change)
        Quit
    }
    Set allocation.Quantity=change.NewQuantity,allocation.CancelledUnhandedQuantity=allocation.CancelledUnhandedQuantity+change.StockReleaseQuantity,allocation.SettledHandedQuantity=allocation.SettledHandedQuantity+change.HandedSettlementQuantity,allocation.ClosedUnknownQuantity=allocation.ClosedUnknownQuantity+change.UnconfirmedSettlementQuantity,allocation.ConsentContextKey=..RecipientKey(context),allocation.TransportConfirmed=0,allocation.Revision=allocation.Revision+1
    Do ..RefreshCase(allocation),##class(Allfedo.Rescue).Save(allocation)
    Do ..RebuildCommitments(offer,need)
    Set need.Revision=need.Revision+1,offer.Revision=offer.Revision+1
    If need.CommittedQuantity+need.HeldQuantity<=need.RequestedQuantity Set need.State="open"
    Set need.State=##class(Allfedo.Facts).NeedState(need)
    Set change.State="applied",change.CompletedAt=##class(Allfedo.Policy).Now(),change.Revision=change.Revision+1
    Do ##class(Allfedo.Rescue).Save(change),##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Save(need)
    Do ..Notice(need.ContactActorId,allocation,"change_applied","Food promise changed",change.Reason,change.%Id())
    Do ..Notice(offer.ContactActorId,allocation,"change_applied","Food promise changed",change.Reason,change.%Id())
    If allocation.CollectorActorId'="" Do ..Notice(allocation.CollectorActorId,allocation,"change_applied","Earlier collection ticket needs attention",change.Reason,change.%Id())
}

ClassMethod Notice(actorId As %String, allocation As Allfedo.Record.Allocation, purpose As %String, subject As %String, body As %String, changeId As %String = "")
{
    Set contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",actorId)
    If '$IsObject(contact)||'contact.Active Quit
    Do ##class(Allfedo.Rescue).Require((contact.NetworkId=allocation.NetworkId),"A notification contact is outside the case network.")
    Set item=##class(Allfedo.Record.Outbox).%New()
    Set item.NetworkId=allocation.NetworkId,item.AllocationId=allocation.%Id(),item.AllocationRevision=allocation.Revision,item.Purpose=purpose,item.RelatedChangeId=changeId,item.RecipientActorId=actorId,item.Recipient=contact.Email,item.Subject=subject,item.Body=body,item.DueAt=##class(Allfedo.Policy).Now()
    Do ##class(Allfedo.Rescue).Save(item)
}

ClassMethod ReplyView(sourceId As %String) As %DynamicObject
{
    If sourceId="" Quit {"status":"awaiting","actor_name":"","source_id":null,"note":""}
    Set source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",sourceId),body=##class(Allfedo.Rescue).Parse(source.BodyJSON)
    Quit {"status":($Select(body.agree:"agreed",1:"declined")),"actor_name":(source.SenderName),"source_id":(sourceId),"note":(body.note)}
}

ClassMethod ChangeView(change As Allfedo.Record.ChangeRequest) As %DynamicObject
{
    Set parties=[]
    If change.RecipientRequired Do parties.%Push("recipient")
    If change.KitchenRequired Do parties.%Push("kitchen")
    Set responses={"recipient":(..ReplyView(change.RecipientSourceId)),"kitchen":(..ReplyView(change.KitchenSourceId)),"collector":(..ReplyView(change.CollectorSourceId))}
    Quit {"id":(""_change.%Id()),"revision":(change.Revision),"state":(change.State),"original_quantity":(""_change.OriginalQuantity),"new_quantity":(""_change.NewQuantity),"reason":(change.Reason),"stock_release_quantity":(""_change.StockReleaseQuantity),"handed_settlement_quantity":(""_change.HandedSettlementQuantity),"unconfirmed_settlement_quantity":(""_change.UnconfirmedSettlementQuantity),"required_parties":(parties),"responses":(responses),"context":(##class(Allfedo.Rescue).Parse(change.ContextJSON))}
}

ClassMethod View(allocation As Allfedo.Record.Allocation, actor As Allfedo.Record.Actor = "") As %DynamicObject
{
    Set view=..Balance(allocation),view."offered_quantity"=""_allocation.OfferedQuantity,view."original_promise_quantity"=""_allocation.OriginalPromiseQuantity
    If allocation.OfferedQuantity="" Do view.%Set("offered_quantity","","null")
    If allocation.OriginalPromiseQuantity="" Do view.%Set("original_promise_quantity","","null")
    Set view."stock_committed_quantity"=view."unhanded_quantity",view."lost_quantity"=""_allocation.LostQuantity,view."rejected_quantity"=""_allocation.RejectedQuantity,view."returned_quantity"=""_allocation.ReturnedQuantity,view."disposed_quantity"=""_allocation.DisposedQuantity,view."settled_handed_quantity"=""_allocation.SettledHandedQuantity,view."closed_unknown_quantity"=""_allocation.ClosedUnknownQuantity,view."current_context"=..CurrentContext(allocation)
    Do view.%Set("original_trip","","null"),view.%Set("agreed_trip","","null"),view.%Set("change","","null")
    If allocation.OriginalTripJSON'="" Set view."original_trip"=##class(Allfedo.Rescue).Parse(allocation.OriginalTripJSON)
    If allocation.TripContextJSON'="" Set view."agreed_trip"=##class(Allfedo.Rescue).Parse(allocation.TripContextJSON)
    Do view.%Set("trip_needs_confirmation",..TripChanged(allocation),"boolean")
    Do view.%Set("recipient_needs_confirmation",allocation.ConsentContextKey'=..RecipientKey(view."current_context"),"boolean")
    Do view.%Set("receipt_recorded",..ReceiptRecorded(allocation),"boolean")
    If allocation.PendingChangeId'="" {
        Set change=##class(Allfedo.Rescue).Open("Allfedo.Record.ChangeRequest",allocation.PendingChangeId)
        If $IsObject(change) Set view.change=..ChangeView(change)
    }
    Set view."custody_history"=..History(allocation.OfferId,actor,allocation.%Id())
    Quit view
}

ClassMethod ReceiptRecorded(allocation As Allfedo.Record.Allocation) As %Boolean
{
    If allocation.LegacyReceivedQuantity>0 Quit 1
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 ID FROM Allfedo_Record.Custody WHERE AllocationId=? AND Active=1 AND Kind='receipt'",allocation.%Id())
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set found=query.%Next()
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit found
}

/// Shared by authorized offer and collection reads. Callers authorize case visibility before this helper.
ClassMethod History(offerId As %String, actor As Allfedo.Record.Actor = "", allocationId As %String = "") As %DynamicArray
{
    Set history=[]
    If allocationId="" {
        Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Custody WHERE OfferId=? ORDER BY RecordedAt,ID",offerId)
    } Else {
        Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Custody WHERE OfferId=? AND AllocationId=? ORDER BY RecordedAt,ID",offerId,allocationId)
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set fact=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",query.ID),source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",fact.SourceId),body=##class(Allfedo.Rescue).Parse(source.BodyJSON)
        Set item={"id":(""_fact.%Id()),"revision":(fact.Revision),"active":(fact.Active),"kind":(fact.Kind),"quantity":(""_fact.Quantity),"occurred_at":(body."occurred_at"),"recorded_at":(##class(Allfedo.Policy).ISO(fact.RecordedAt)),"source_id":(""_fact.SourceId),"actor_name":(source.SenderName),"note":(body.%Get("note")),"agreement_issue":(fact.AgreementIssue),"supersedes_id":(fact.SupersedesId)}
        Do item.%Set("can_correct",..CanCorrect(actor,fact),"boolean"),history.%Push(item)
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit history
}

ClassMethod DisposeQuarantined(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",data."offer_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(offer)&&(offer.NetworkId=actor.NetworkId)&&(actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId),"Only this kitchen can report disposal of returned food at its site.")
    Do ##class(Allfedo.Rescue).Require(data.note'="","Record how the quarantined food was disposed of.")
    Do ..Prepare(offer)
    Set fact=..StorePhysical(actor,"","quarantine_disposed",data),projected=..RebuildStock(offer),offer.Revision=offer.Revision+1
    If offer.Revision'=data.revision+1 Set offer.State="review_required"
    Do ##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Event(actor,"quarantine_disposed",offer.%Id(),data)
    Quit {"ok":true,"offer_id":(""_offer.%Id()),"revision":(offer.Revision),"state":(offer.State),"custody_id":(""_fact.%Id()),"quarantined_quantity":(""_offer.QuarantinedQuantity),"physical_report_saved":true}
}

ClassMethod CorrectCustody(actor As Allfedo.Record.Actor, data As %DynamicObject) As %DynamicObject
{
    Set previous=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",data."custody_id")
    Do ##class(Allfedo.Rescue).Require($IsObject(previous)&&(previous.NetworkId=actor.NetworkId)&&previous.Active&&(previous.Revision=data.revision),"Review the current physical report before correcting it.")
    Do ##class(Allfedo.Rescue).Require(data.note'="","Explain which earlier count or time was wrong; its original source stays in history.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",previous.OfferId),allocation="",need=""
    If previous.AllocationId'="" {
        Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",previous.AllocationId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    }
    Do ##class(Allfedo.Rescue).Require(..CanCorrect(actor,previous),"Only the responsible physical reporting party can correct this kind of report.")
    Do ..Prepare(offer,allocation)
    Set body=##class(Allfedo.Rescue).Parse(data.%ToJSON()),body."offer_id"=""_offer.%Id()
    If $IsObject(allocation) Set body."allocation_id"=""_allocation.%Id()
    Set next=..StorePhysical(actor,allocation,previous.Kind,body,"Corrected physical report; previous source remains in history.",previous.%Id()),previous.Active=0,previous.Revision=previous.Revision+1
    Do ##class(Allfedo.Rescue).Save(previous)
    If $IsObject(allocation) {
        Set allocation.CustodyIssue="A physical count was corrected. Review its effects on any earlier promise change.",allocation.Revision=allocation.Revision+1
        Do ..RefreshCase(allocation),##class(Allfedo.Rescue).Save(allocation),..RebuildCommitments(offer,need)
        Set need.Revision=need.Revision+1,need.State="review_required"
        Do ##class(Allfedo.Rescue).Save(need)
    }
    Set projected=..RebuildStock(offer),offer.State="review_required",offer.Revision=offer.Revision+1
    Do ##class(Allfedo.Rescue).Save(offer),##class(Allfedo.Rescue).Event(actor,"custody_corrected",previous.%Id(),body)
    Quit {"ok":true,"custody_id":(""_next.%Id()),"supersedes_id":(""_previous.%Id()),"offer_id":(""_offer.%Id()),"state":"review_required"}
}

ClassMethod CanCorrect(actor As Allfedo.Record.Actor, fact As Allfedo.Record.Custody) As %Boolean
{
    If '$IsObject(actor) Quit 0
    If 'actor.Active||(actor.NetworkId'=fact.NetworkId)||'fact.Active Quit 0
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",fact.OfferId)
    If $ListFind($ListBuild("handoff","returned","quarantine_disposed"),fact.Kind) Quit (actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId)
    If fact.AllocationId="" Quit 0
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",fact.AllocationId),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",allocation.NeedId)
    If $ListFind($ListBuild("receipt","rejected_at_site"),fact.Kind) Quit (actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId)
    If $ListFind($ListBuild("lost","discarded"),fact.Kind) Quit (actor.Role="collector")&&(actor.%Id()=fact.ActorId)
    Quit 0
}

}
