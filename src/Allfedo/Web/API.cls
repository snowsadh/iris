Include Ensemble

/// Same-origin JSON interface. Native authentication owns identity; records own all business state.
Class Allfedo.Web.API Extends %CSP.REST
{
Parameter CHARSET = "utf-8";
Parameter CONTENTTYPE = "application/json";
Parameter CONVERTINPUTSTREAM = 1;
Parameter UseSession = 1;
Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/commands" Method="POST" Call="Command"/>
  <Route Url="/plan-check" Method="POST" Call="PlanCheck"/>
  <Route Url="/logout" Method="POST" Call="Logout"/>
  <Route Url="/:resource/:id" Method="GET" Call="Read"/>
  <Route Url="/:resource" Method="GET" Call="Read"/>
</Routes>
}

ClassMethod Read(resource As %String, id As %String = "") As %Status
{
    Try {
        Set actor=..Principal()
        If resource="session",id="" {
            Set result={"ok":true,"user":{"id":(""_actor.%Id()),"name":(actor.DisplayName),"role":(actor.Role),"organization_id":(actor.OrganizationId),"network_id":(actor.NetworkId)},"now":(##class(Allfedo.Policy).NowISO())}
            Do result.user.%Set("demo",##class(Allfedo.Demo).IsNetwork(actor.NetworkId),"boolean")
        } ElseIf resource="collectors",id="" {
            Set result=..Collectors(actor)
        } ElseIf resource="site",id="" {
            Set site=..Site(actor.NetworkId,actor.OrganizationId)
            Set result={"ok":true,"record":null}
            If $IsObject(site) Set result.record=site
        } ElseIf resource="plans",id'="" {
            Set result=..Plan(actor,id)
        } ElseIf resource="worklist",id="" {
            Do ..Check(actor.Role="coordinator",403,"FORBIDDEN","Only the coordinator can read the rescue worklist.")
            Set result=..Worklist(actor)
        } Else {
            Do ..Check($ListFind($ListBuild("offers","needs","allocations"),resource),404,"NOT_FOUND","This page does not exist.")
            If id'="" {
                Do ..Check(id?1.N,404,"NOT_FOUND","This record does not exist.")
                Set item=..Record(resource,id,actor)
                Do ..Check($IsObject(item),404,"NOT_FOUND","This record does not exist or is not addressed to you.")
                Set result={"ok":true,"record":(item)}
                If (actor.Role="coordinator")&&((resource="offers")||(resource="allocations")) {
                    Set result.history=..History(actor,resource,id), result.notifications=..Notifications(actor,resource,id)
                }
            } Else {
                Set after=$Get(%request.Data("after",1),"0")
                Do ..Check((after?1.N)&&($Length(after)<=18),400,"INVALID_CURSOR","after must be a saved record ID.")
                Set result=..List(resource,actor,after)
            }
        }
        Set status=..Reply(result)
    } Catch error {
        Set status=..Failure(error)
    }
    Quit status
}

ClassMethod Command() As %Status
{
    Try {
        Set actor=..Principal()
        Set body=..ReadBody()
        Do ..Check(body.%IsA("%Library.DynamicObject")&&(body.%Size()=3)&&body.%IsDefined("request_id")&&body.%IsDefined("action")&&body.%IsDefined("payload"),400,"INVALID_COMMAND","Use only request_id, action, and payload. Identity comes from your signed-in account.")
        Do ..Check((body.%GetTypeOf("request_id")="string")&&(body."request_id"'="")&&($Length(body."request_id")<=100)&&(body.%GetTypeOf("action")="string")&&(body.action'="")&&(body.%GetTypeOf("payload")="object"),400,"INVALID_COMMAND","Give a request ID, an action, and a payload object.")
        Set status=..Production(body."request_id",body.action,body.payload,.result)
        If $$$ISERR(status) {
            Set result={"ok":false,"request_id":(body."request_id"),"error":{"code":"COMMAND_RESULT_UNKNOWN","message":"The saved result is not available yet. Check again using this same request ID."}}
            Set status=..Reply(result,503)
        } Else {
            Set http=200
            If 'result.ok {
                Set code=result.error.code
                Set http=$Select(code="NOT_SAVED":503,code="COMMAND_REJECTED":422,1:409)
            }
            Set result."request_id"=body."request_id"
            Set status=..Reply(result,http)
        }
    } Catch error {
        Set status=..Failure(error)
    }
    Quit status
}

ClassMethod PlanCheck() As %Status
{
    Try {
        Set actor=..Principal()
        Do ..Check(actor.Role="coordinator",403,"FORBIDDEN","Only the coordinator can review recipient plans.")
        Set proposal=..ReadBody()
        Do ..Check(proposal.%GetTypeOf("offer_id")="string",400,"INVALID_PROPOSAL","A plan must identify its saved food offer.")
        Set offer=..Record("offers",proposal."offer_id",actor)
        Do ..Check($IsObject(offer),404,"NOT_FOUND","This offer does not exist or is outside your network.")
        Set status=..Production("check:"_$SYSTEM.Util.CreateGUID(),"check_plan",proposal,.checked)
        If $$$ISERR(status) {
            Set status=..Reply({"ok":false,"check_only":true,"reservation_created":false,"error":{"code":"CHECK_UNAVAILABLE","message":"The current check is not available yet. No offers were sent; try the check again."}},503)
        } Else {
            Set status=..Reply(checked,$Select(checked.ok:200,1:422))
        }
    } Catch error {
        Set status=..Failure(error)
    }
    Quit status
}

/// One trusted message path; the business service resolves $USERNAME again before dispatch.
ClassMethod Production(requestId As %String, action As %String, payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    Set message=##class(Allfedo.Message.CommandRequest).%New()
    Set message.RequestId=requestId, message.Action=action, message.PayloadJSON=payload.%ToJSON()
    Set status=##class(Ens.Director).CreateBusinessService("Allfedo.Commands",.service)
    If $$$ISOK(status) Set status=service.ProcessInput(message,.response)
    If $$$ISOK(status) Set result=##class(Allfedo.Rescue).Parse(response.ResultJSON)
    Quit status
}

ClassMethod ReadBody() As %DynamicObject
{
    Do ..WriteGuard()
    Do ..Check($IsObject(%request.Content)&&(%request.Content.Size<=110000),413,"REQUEST_TOO_LARGE","The request body is missing or too large.")
    Try {
        Set body=##class(%DynamicObject).%FromJSON(%request.Content)
    } Catch parseError {
        Do ..Check(0,400,"INVALID_JSON","The request must contain a JSON object.")
    }
    Do ..Check($IsObject(body)&&body.%IsA("%Library.DynamicObject"),400,"INVALID_JSON","The request must contain a JSON object.")
    Quit body
}

ClassMethod Logout() As %Status
{
    Try {
        Set actor=..Principal()
        Do ..WriteGuard()
        Set %session.EndSession=1
        Set status=..Reply({"ok":true,"signed_out":true})
    } Catch error {
        Set status=..Failure(error)
    }
    Quit status
}

ClassMethod WriteGuard()
{
    Do ..Check(%request.GetCgiEnv("HTTP_X_ALLFEDO_REQUEST")="1",403,"CROSS_SITE_BLOCKED","Send this change from Allfedo using its request header.")
    Set origin=%request.GetCgiEnv("HTTP_ORIGIN"), expected=$Select(%request.Secure:"https://",1:"http://")_%request.GetCgiEnv("HTTP_HOST")
    Do ..Check((origin="")||(origin=expected),403,"CROSS_SITE_BLOCKED","This change must come from the same site as Allfedo.")
    Do ..Check($ZConvert($Piece(%request.ContentType,";",1),"L")="application/json",415,"JSON_REQUIRED","Send the command as application/json.")
}

ClassMethod Login(skipheader As %Boolean = 1) As %Status [ ProcedureBlock = 0 ]
{
    Quit ..Reply({"ok":false,"error":{"code":"SIGN_IN_REQUIRED","message":"Sign in with your invited Allfedo account."}},401,1)
}

ClassMethod Principal() As Allfedo.Record.Actor
{
    Do ..Check(($USERNAME'="")&&($USERNAME'="_PUBLIC"),401,"SIGN_IN_REQUIRED","Sign in with your invited account.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Actor WHERE UserName=? AND Active=1",$USERNAME)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set found=query.%Next()
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ..Check(found,403,"MEMBERSHIP_REQUIRED","This account has no active Allfedo membership.")
    Quit ##class(Allfedo.Rescue).Actor(""_query.ID)
}

/// Lists and direct links cross the same role/organization/assignment checks.
ClassMethod List(resource As %String, actor As Allfedo.Record.Actor, after As %String = "0") As %DynamicObject
{
    Set filter="", value="", table=""
    If resource="offers" {
        Set table="Allfedo_Record.Offer"
        Do ..Check((actor.Role="coordinator")||(actor.Role="kitchen"),403,"FORBIDDEN","Use the invitations or pickups addressed to you.")
        Set filter=$Select(actor.Role="kitchen":"OrganizationId=?",1:"?='coordinator'"), value=$Select(actor.Role="kitchen":actor.OrganizationId,1:actor.Role)
    } ElseIf resource="needs" {
        Set table="Allfedo_Record.Need"
        Do ..Check((actor.Role="coordinator")||(actor.Role="recipient"),403,"FORBIDDEN","Only receiving partners and the coordinator can read receiving needs.")
        Set filter=$Select(actor.Role="recipient":"OrganizationId=?",1:"?='coordinator'"), value=$Select(actor.Role="recipient":actor.OrganizationId,1:actor.Role)
    } Else {
        Set table="Allfedo_Record.Allocation"
        If actor.Role="coordinator" { Set filter="?='coordinator'", value=actor.Role }
        If actor.Role="collector" { Set filter="CollectorActorId=?", value=actor.%Id() }
        If actor.Role="recipient" { Set filter="NeedId IN (SELECT ID FROM Allfedo_Record.Need WHERE NetworkId=r.NetworkId AND OrganizationId=?)", value=actor.OrganizationId }
        If actor.Role="kitchen" { Set filter="OfferId IN (SELECT ID FROM Allfedo_Record.Offer WHERE NetworkId=r.NetworkId AND OrganizationId=?)", value=actor.OrganizationId }
        Do ..Check(filter'="",403,"FORBIDDEN","This membership cannot read collections.")
    }
    Set sql="SELECT TOP 101 ID FROM "_table_" r WHERE NetworkId=? AND ID>? AND "_filter
    Set offerId=$Get(%request.Data("offer_id",1)), needId=$Get(%request.Data("need_id",1))
    If resource="allocations",((offerId'="")||(needId'="")) {
        Do ..Check(((offerId="")||(offerId?1.N))&&((needId="")||(needId?1.N)),400,"INVALID_FILTER","Use saved offer and receiving-need IDs.")
        If (offerId'="")&&(needId'="") {
            Set query=##class(%SQL.Statement).%ExecDirect(,sql_" AND OfferId=? AND NeedId=? ORDER BY ID",actor.NetworkId,after,value,offerId,needId)
        } ElseIf offerId'="" {
            Set query=##class(%SQL.Statement).%ExecDirect(,sql_" AND OfferId=? ORDER BY ID",actor.NetworkId,after,value,offerId)
        } Else {
            Set query=##class(%SQL.Statement).%ExecDirect(,sql_" AND NeedId=? ORDER BY ID",actor.NetworkId,after,value,needId)
        }
    } Else {
        Set query=##class(%SQL.Statement).%ExecDirect(,sql_" ORDER BY ID",actor.NetworkId,after,value)
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set rows=[], next=""
    While query.%Next() {
        If rows.%Size()=100 { Set next=last Quit }
        Set item=..Record(resource,""_query.ID,actor)
        If $IsObject(item) { Do rows.%Push(item) Set last=""_query.ID }
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit {"ok":true,"records":(rows),"next_after":(next)}
}

ClassMethod Record(resource As %String, id As %String, actor As Allfedo.Record.Actor) As %DynamicObject
{
    Set class=$Select(resource="offers":"Allfedo.Record.Offer",resource="needs":"Allfedo.Record.Need",1:"Allfedo.Record.Allocation")
    Set record=##class(Allfedo.Rescue).Open(class,id)
    If '$IsObject(record) Quit ""
    If record.NetworkId'=actor.NetworkId Quit ""
    If resource="offers" {
        If actor.Role="coordinator" Quit ..Food(record,1,actor)
        If (actor.Role="kitchen")&&(actor.OrganizationId=record.OrganizationId) Quit ..Food(record,0,actor)
        // Recipient/collector food details are included only inside their addressed collection.
        Quit ""
    }
    If resource="needs" {
        If actor.Role="coordinator" Quit ..Need(record,1)
        If (actor.Role="recipient")&&(actor.OrganizationId=record.OrganizationId) Quit ..Need(record)
        Quit ""
    }
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",record.OfferId), need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",record.NeedId)
    If '$IsObject(offer)||'$IsObject(need) Quit ""
    If (offer.NetworkId'=actor.NetworkId)||(need.NetworkId'=actor.NetworkId) Quit ""
    Set permitted=(actor.Role="coordinator")||((actor.Role="kitchen")&&(actor.OrganizationId=offer.OrganizationId))||((actor.Role="recipient")&&(actor.OrganizationId=need.OrganizationId))||((actor.Role="collector")&&(record.CollectorActorId=actor.%Id()))
    If 'permitted Quit ""
    Set collector=""
    If record.CollectorActorId'="" {
        Set contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",record.CollectorActorId)
        If $IsObject(contact),contact.NetworkId=actor.NetworkId Set collector=contact.DisplayName
    }
    Set stockActor=""
    If (actor.Role="coordinator")||(actor.Role="kitchen") Set stockActor=actor
    Set result={"id":(""_record.%Id()),"revision":(record.Revision),"state":(record.State),"quantity":(""_record.Quantity),"unit":(record.Unit),"hold_until":(..Time(record.HoldUntil)),"collector_id":(record.CollectorActorId),"collector_name":(collector),"transport_confirmed":(record.TransportConfirmed),"pickup_at":(..Time(record.PickupAt)),"arrival_by":(..Time(record.ArrivalBy)),"collected_quantity":(""_record.CollectedQuantity),"received_quantity":(""_record.ReceivedQuantity),"unresolved_quantity":(""_record.UnresolvedQuantity),"note":(record.OutcomeNote),"offer":(..Food(offer,0,stockActor)),"need":(..Need(need))}
    Set result.recovery=..Recovery(record,actor)
    Quit result
}

/// Native recovery owns balances and permissions; this layer removes internal source references.
ClassMethod Recovery(record As Allfedo.Record.Allocation, actor As Allfedo.Record.Actor) As %DynamicObject
{
    Set result=##class(Allfedo.Recovery).View(record,actor)
    If actor.Role="coordinator" Quit result
    For field="current_context","original_trip","agreed_trip" {
        Set context=result.%Get(field)
        If $IsObject(context) { Do context.%Remove("evidence"),context.%Remove("source_id") }
    }
    Set change=result.%Get("change")
    If $IsObject(change) {
        If $IsObject(change.context) Do change.context.%Remove("evidence")
        For party="recipient","kitchen","collector" Do change.responses.%Get(party).%Remove("source_id")
    }
    For historyIndex=0:1:result."custody_history".%Size()-1 {
        Set item=result."custody_history".%Get(historyIndex)
        Do item.%Remove("source_id")
    }
    Quit result
}

ClassMethod Food(record As Allfedo.Record.Offer, evidence As %Boolean = 0, stockActor As Allfedo.Record.Actor = "") As %DynamicObject
{
    Set state=##class(Allfedo.Facts).FoodState(record)
    Set available=record.CurrentQuantity-record.HeldQuantity-record.CommittedQuantity-record.CollectedQuantity
    Set result={"id":(""_record.%Id()),"revision":(record.Revision),"organization_id":(record.OrganizationId),"description":(record.Description),"state":(state),"declared_quantity":(""_record.DeclaredQuantity),"current_quantity":(""_record.CurrentQuantity),"held_quantity":(""_record.HeldQuantity),"committed_quantity":(""_record.CommittedQuantity),"collected_quantity":(""_record.CollectedQuantity),"available_quantity":(""_$Select((available>0)&&(state="open"):available,1:0)),"shortfall_quantity":(""_$Select(available<0:-available,1:0)),"unit":(record.Unit),"ready_at":(..Time(record.ReadyAt)),"collect_by":(..Time(record.CollectBy)),"holding":(record.Holding),"present_allergens":(##class(Allfedo.Rescue).ParseArray(record.PresentAllergensJSON)),"assessed_allergens":(##class(Allfedo.Rescue).ParseArray(record.AssessedAllergensJSON))}
    If evidence {
        Set result."source_ids"=[(""_record.SourceId)]
        If (record.OriginalSourceId'="")&&(record.OriginalSourceId'=record.SourceId) Do result."source_ids".%Push(""_record.OriginalSourceId)
    }
    Set result."contact_name"=..ContactName(record.NetworkId,record.OrganizationId,record.ContactActorId)
    If $IsObject(stockActor) {
        Set result."custody_history"=##class(Allfedo.Recovery).History(record.%Id(),stockActor)
        If stockActor.Role'="coordinator" {
            For historyIndex=0:1:result."custody_history".%Size()-1 { Set historyItem=result."custody_history".%Get(historyIndex) Do historyItem.%Remove("source_id") }
        }
        Do result.%Set("stock_source_id","","null"),result.%Set("stock_count","","null"),result.%Set("stock_projection","","null")
        Set result."quarantined_quantity"=""_record.QuarantinedQuantity
        If record.ObservationSourceId'="" {
            Set countSource=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",record.ObservationSourceId)
            Do ..Check($IsObject(countSource)&&(countSource.NetworkId=record.NetworkId)&&(countSource.OrganizationId=record.OrganizationId)&&(countSource.Kind="stock_observation"),500,"INVALID_STOCK_SOURCE","The saved stock count needs review.")
            Set counted=##class(Allfedo.Rescue).Parse(countSource.BodyJSON),result."stock_source_id"=""_record.ObservationSourceId
            Set result."stock_count"={"on_hand_quantity":(counted."on_hand_quantity"),"occurred_at":(counted."occurred_at"),"recorded_at":(..Time(countSource.RecordedAt)),"note":(counted.%Get("note"))}
        }
        If record.StockProjectionJSON'="" {
            Set projection=##class(Allfedo.Rescue).Parse(record.StockProjectionJSON)
            If evidence,projection.%IsDefined("source_ids") {
                Set seen(record.SourceId)=1
                If record.OriginalSourceId'="" Set seen(record.OriginalSourceId)=1
                For sourceIndex=0:1:projection."source_ids".%Size()-1 {
                    Set sourceId=projection."source_ids".%Get(sourceIndex)
                    If '$Data(seen(sourceId)) { Do result."source_ids".%Push(sourceId,"string") Set seen(sourceId)=1 }
                }
            }
            If 'evidence {
                Do projection.%Remove("source_ids")
                For issueIndex=0:1:projection.issues.%Size()-1 { Set issue=projection.issues.%Get(issueIndex) Do issue.%Remove("source_id") }
            }
            Set result."stock_projection"=projection
            If projection.%GetTypeOf("quarantined_quantity")="null" Do result.%Set("quarantined_quantity","","null")
        }
    }
    Set result.packaging=record.Packaging
    Do result.%Set("observed_quantity","","null")
    If record.ObservedQuantity'="" Set result."observed_quantity"=""_record.ObservedQuantity
    Do result.%Set("handling_until","","null")
    If record.HandlingUntil'="" Set result."handling_until"=..Time(record.HandlingUntil)
    If record.Holding="" Do result.%Set("holding","","null")
    Do result.%Set("site","","null")
    Set site=..Site(record.NetworkId,record.OrganizationId)
    If $IsObject(site) Set result.site=site
    Quit result
}

ClassMethod Need(record As Allfedo.Record.Need, evidence As %Boolean = 0) As %DynamicObject
{
    Set state=##class(Allfedo.Facts).NeedState(record)
    Set remaining=record.RequestedQuantity-record.HeldQuantity-record.CommittedQuantity
    Set result={"id":(""_record.%Id()),"revision":(record.Revision),"state":(state),"organization_id":(record.OrganizationId),"requested_quantity":(""_record.RequestedQuantity),"remaining_quantity":(""_$Select((remaining>0)&&(state="open"):remaining,1:0)),"held_quantity":(""_record.HeldQuantity),"committed_quantity":(""_record.CommittedQuantity),"unit":(record.Unit),"receiving_until":(..Time(record.ReceivingUntil)),"confirmed_until":(..Time(record.ConfirmedUntil)),"excluded_allergens":(##class(Allfedo.Rescue).ParseArray(record.ExcludedAllergensJSON)),"accepted_holding":(##class(Allfedo.Rescue).ParseArray(record.AcceptedHoldingJSON))}
    Do result.%Set("receiving_from","","null")
    If record.ReceivingFrom'="" Set result."receiving_from"=..Time(record.ReceivingFrom)
    Set result."contact_name"=..ContactName(record.NetworkId,record.OrganizationId,record.ContactActorId)
    If evidence Set result."source_ids"=[(record.SourceId)]
    Set result."shortfall_quantity"=""_$Select(remaining<0:-remaining,1:0)
    Do result.%Set("site","","null")
    Set site=..Site(record.NetworkId,record.OrganizationId)
    If $IsObject(site) Set result.site=site
    Quit result
}

ClassMethod Site(networkId As %String, organizationId As %String) As %DynamicObject
{
    Set record=##class(Allfedo.Facts).SiteFor(networkId,organizationId)
    If '$IsObject(record) Quit ""
    Set name=..ContactName(networkId,organizationId,record.ContactActorId)
    Quit {"name":(record.Name),"address":(record.Address),"entrance":(record.Entrance),"time_zone":(record.TimeZone),"contact_phone":(record.ContactPhone),"contact_name":(name),"revision":(record.Revision),"confirmed":true}
}

ClassMethod ContactName(networkId As %String, organizationId As %String, actorId As %String) As %String
{
    Set contact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",actorId)
    If '$IsObject(contact) Quit ""
    If (contact.NetworkId'=networkId)||(contact.OrganizationId'=organizationId) Quit ""
    Quit contact.DisplayName
}

ClassMethod Collectors(actor As Allfedo.Record.Actor) As %DynamicObject
{
    Do ..Check((actor.Role="coordinator")||(actor.Role="recipient"),403,"FORBIDDEN","Only receiving partners and the coordinator can choose approved collectors.")
    Set after=$Get(%request.Data("after",1),"0")
    Do ..Check((after?1.N)&&($Length(after)<=18),400,"INVALID_CURSOR","after must be a saved record ID.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 101 ID FROM Allfedo_Record.Actor WHERE NetworkId=? AND Active=1 AND ""Role""='collector' AND ID>? ORDER BY ID",actor.NetworkId,after)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set rows=[], next=""
    While query.%Next() {
        If rows.%Size()=100 { Set next=last Quit }
        Set collector=##class(Allfedo.Rescue).Actor(""_query.ID), last=""_query.ID
        Do rows.%Push({"id":(last),"name":(collector.DisplayName),"organization_id":(collector.OrganizationId)})
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit {"ok":true,"records":(rows),"next_after":(next)}
}

ClassMethod Plan(actor As Allfedo.Record.Actor, offerId As %String) As %DynamicObject
{
    Do ..Check(actor.Role="coordinator",403,"FORBIDDEN","Only the coordinator can review saved recipient plans.")
    Do ..Check((offerId?1.N)&&($Length(offerId)<=18),404,"NOT_FOUND","This offer does not exist.")
    Set offer=..Record("offers",offerId,actor)
    Do ..Check($IsObject(offer),404,"NOT_FOUND","This offer does not exist or is outside your network.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 ID FROM Allfedo_Record.AgentRun WHERE NetworkId=? AND OfferId=? ORDER BY StartedAt DESC, ID DESC",actor.NetworkId,offerId)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set found=query.%Next(), result={"ok":true,"record":null}
    Do ##class(Allfedo.Rescue).QueryOK(query)
    If found {
        Set run=##class(Allfedo.Rescue).Open("Allfedo.Record.AgentRun",query.ID)
        Set saved={"run_id":(""_run.%Id()),"state":(run.Outcome),"started_at":(..Time(run.StartedAt)),"finished_at":(..Time(run.FinishedAt))}
        Set saved.model=run.Model
        Do saved.%Set("tool_audit","","null"),saved.%Set("usage","","null")
        If run.ToolAuditJSON'="" Set saved."tool_audit"=##class(Allfedo.Rescue).ParseArray(run.ToolAuditJSON)
        If run.UsageJSON'="" Set saved.usage=##class(Allfedo.Rescue).Parse(run.UsageJSON)
        If run.ProposalJSON'="" Set saved.proposal=##class(Allfedo.Rescue).Parse(run.ProposalJSON)
        If run.ResultJSON'="" {
            Set outcome=##class(Allfedo.Rescue).Parse(run.ResultJSON)
            If outcome.%IsDefined("reason") Set saved.reason=outcome.reason
            If outcome.%IsDefined("error") Set saved.error=outcome.error
        }
        Set result.record=saved
    }
    Quit result
}

/// Event kinds identify their resource table; numeric IDs alone are not globally unique.
ClassMethod History(actor As Allfedo.Record.Actor, resource As %String, id As %String) As %DynamicArray
{
    Set actions="'invitation_held','accept','decline','assign_collector','confirm_transport','handoff','receive','receive_more','record_disposition','expire_hold','change_requested','change_response','trip_reconfirmed','invitation_withdrawn','destination_unavailable','redirect_invited','redirect_accept','redirect_decline','redirect_expire_hold','redirect_withdraw_invitation','redirect_trip_confirmed','unavailable_unhanded_released','rejected_food_moved'"
    If resource="offers" {
        Set sql="SELECT TOP 100 ID FROM Allfedo_Record.Event WHERE NetworkId=? AND ((ResourceId=? AND Kind IN ('offer_confirmed','stock_observed','stock_counted','food_reconfirmed','quarantine_disposed','invitations_resumed')) OR (Kind IN ("_actions_") AND ResourceId IN (SELECT ID FROM Allfedo_Record.Allocation WHERE NetworkId=? AND OfferId=?))) ORDER BY RecordedAt DESC, ID DESC"
        Set query=##class(%SQL.Statement).%ExecDirect(,sql,actor.NetworkId,id,actor.NetworkId,id)
    } Else {
        Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 100 ID FROM Allfedo_Record.Event WHERE NetworkId=? AND ResourceId=? AND Kind IN ("_actions_") ORDER BY RecordedAt DESC, ID DESC",actor.NetworkId,id)
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set rows=[]
    While query.%Next() {
        Set event=##class(Allfedo.Rescue).Open("Allfedo.Record.Event",query.ID), person=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",event.ActorId), name=""
        If $IsObject(person),person.NetworkId=actor.NetworkId Set name=person.DisplayName
        Set item={"id":(""_event.%Id()),"kind":(event.Kind),"at":(..Time(event.RecordedAt)),"actor_name":(name)}
        Set body=##class(Allfedo.Rescue).Parse(event.BodyJSON)
        For field="quantity","note","reason","occurred_at","on_hand_quantity","new_quantity","outcome","quantity_in_custody","from_custody_id" { If body.%IsDefined(field) Do item.%Set(field,body.%Get(field)) }
        Do rows.%Push(item)
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit rows
}

ClassMethod Notifications(actor As Allfedo.Record.Actor, resource As %String, id As %String) As %DynamicArray
{
    Set filter=$Select(resource="offers":"AllocationId IN (SELECT ID FROM Allfedo_Record.Allocation WHERE NetworkId=? AND OfferId=?)",1:"NetworkId=? AND AllocationId=?")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 100 ID FROM Allfedo_Record.Outbox WHERE NetworkId=? AND "_filter_" ORDER BY ID DESC",actor.NetworkId,actor.NetworkId,id)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set rows=[]
    While query.%Next() {
        Set item=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",query.ID)
        Do rows.%Push({"id":(""_item.%Id()),"allocation_id":(item.AllocationId),"state":(item.State),"purpose":(item.Purpose),"related_change_id":(item.RelatedChangeId),"attempts":(item.Attempts),"due_at":(..Time(item.DueAt)),"sent_at":(..Time(item.SentAt))})
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit rows
}

/// Derived from saved cases, not invented tasks or notification-delivery claims.
ClassMethod Worklist(actor As Allfedo.Record.Actor) As %DynamicObject
{
    Set now=##class(Allfedo.Policy).Now(), rows=[], truncated=0
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 101 ID FROM Allfedo_Record.Allocation WHERE NetworkId=? AND ((State='held' AND HoldUntil<=?) OR State='accepted' OR (State='ready' AND PickupAt<?) OR (State='collected' AND ArrivalBy<?) OR State IN ('receipt_issue','custody_review','closed_unconfirmed','destination_issue') OR PendingChangeId IN (SELECT ID FROM Allfedo_Record.ChangeRequest WHERE NetworkId=? AND State='awaiting_response')) ORDER BY ID",actor.NetworkId,now,now,now,actor.NetworkId)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        If rows.%Size()=100 { Set truncated=1 Quit }
        Set record=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",query.ID)
        Set kind=$Select(record.State="held":"expire_invitation",record.State="accepted":"assign_collector",record.State="ready":"check_pickup",record.State="collected":"check_arrival",1:"resolve_receipt")
        If record.State="destination_issue" Set kind="resolve_destination"
        If (record.State="accepted")&&(record.CollectorActorId'="") Set kind="confirm_collector"
        If record.PendingChangeId'="" {
            Set change=##class(Allfedo.Rescue).Open("Allfedo.Record.ChangeRequest",record.PendingChangeId)
            If $IsObject(change),change.State="awaiting_response" Set kind="review_change"
        }
        Do rows.%Push({"kind":(kind),"allocation":(..Record("allocations",""_query.ID,actor))})
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 101 ID FROM Allfedo_Record.Offer WHERE NetworkId=? AND (State='review_required' OR (State IN ('open','needs_details','expired') AND CurrentQuantity-HeldQuantity-CommittedQuantity-CollectedQuantity>0 AND CollectBy>? AND (HandlingUntil IS NULL OR HandlingUntil>?))) ORDER BY CollectBy,ID",actor.NetworkId,now,now)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        If rows.%Size()=100 { Set truncated=1 Quit }
        Set offer=..Record("offers",""_query.ID,actor), kind=""
        If $IsObject(offer) {
            If offer.state="review_required" Set kind="review_stock"
            If offer.state="needs_details" Set kind="confirm_food_details"
            If (offer.state="open")&&(+offer."available_quantity">0) Set kind="plan_offer"
            If kind'="" Do rows.%Push({"kind":(kind),"offer":(offer)})
        }
    }
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Quit {"ok":true,"items":(rows),"has_more":(truncated),"generated_at":(..Time(now))}
}

ClassMethod Time(value As %BigInt) As %String
{
    Quit $Select(value="":"",1:##class(Allfedo.Policy).ISO(value))
}

ClassMethod Check(condition As %Boolean, http As %Integer, code As %String, message As %String)
{
    If 'condition Throw ##class(%Exception.General).%New(code,http,,message)
}

ClassMethod Failure(error As %Exception.AbstractException) As %Status
{
    If (error.Code>=400)&&(error.Code<=499) Quit ..Reply({"ok":false,"error":{"code":(error.Name),"message":(error.Data)}},error.Code)
    Quit ..Reply({"ok":false,"error":{"code":"INTERNAL_ERROR","message":"This request could not be completed. Try again shortly."}},500)
}

ClassMethod Reply(body As %DynamicObject, http As %Integer = 200, sendHeaders As %Boolean = 0) As %Status
{
    Set %response.Status=$Select(http=200:"200 OK",http=400:"400 Bad Request",http=401:"401 Unauthorized",http=403:"403 Forbidden",http=404:"404 Not Found",http=409:"409 Conflict",http=413:"413 Content Too Large",http=415:"415 Unsupported Media Type",http=422:"422 Unprocessable Entity",http=503:"503 Service Unavailable",1:"500 Internal Server Error")
    Set %response.ContentType="application/json", %response.CharSet="utf-8"
    Set %response.Headers("Cache-Control")="no-store", %response.Headers("X-Content-Type-Options")="nosniff"
    If sendHeaders Do %response.WriteHTTPHeader()
    Write body.%ToJSON()
    Quit $$$OK
}
}
