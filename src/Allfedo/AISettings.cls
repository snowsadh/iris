Include %occStatus

/// Provider configuration and short-lived personal keys. Keys never enter workflow messages.
Class Allfedo.AISettings Extends %RegisteredObject
{
ClassMethod Install() As %Status
{
    If ##class(%Wallet.Collection).%ExistsId("Allfedo") {
        Set collection=##class(%Wallet.Collection).GetObject("Allfedo")
        If (collection.UseResource'="%DB_ALLFEDO:READ")||(collection.EditResource'="%DB_ALLFEDO:WRITE") Quit $$$ERROR($$$GeneralError,"Another application owns the Allfedo wallet collection.")
        Quit $$$OK
    }
    Set properties={"UseResource":"%DB_ALLFEDO:READ","EditResource":"%DB_ALLFEDO:WRITE"}
    Quit ##class(%Wallet.Collection).Create("Allfedo",properties)
}

ClassMethod Choices() As %DynamicArray
{
    Quit [{"id":"openai","name":"OpenAI","model":"gpt-4.1-mini"},{"id":"openrouter","name":"OpenRouter","model":"openai/gpt-4.1-mini"},{"id":"gemini","name":"Google Gemini","model":"gemini-3.8-flash"}]
}

ClassMethod Validate(provider As %String, model As %String)
{
    Do ##class(Allfedo.Rescue).Require($ListFind($ListBuild("openai","openrouter","gemini"),provider),"Choose OpenAI, OpenRouter or Google Gemini.")
    Set allowed="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.:/"
    Do ##class(Allfedo.Rescue).Require((model'="")&&($Length(model)<=150)&&($Translate(model,allowed)=""),"Enter a model ID supported by your provider, with no spaces.")
}

ClassMethod Default() As %DynamicObject
{
    Set provider=$SYSTEM.Util.GetEnviron("AI_PROVIDER")
    If provider="" Set provider="openai"
    Set choices=..Choices(),model=$SYSTEM.Util.GetEnviron("AI_MODEL"),key=$SYSTEM.Util.GetEnviron("AI_API_KEY")
    If provider="openai" {
        If model="" Set model=$SYSTEM.Util.GetEnviron("OPENAI_MODEL")
        If key="" Set key=$SYSTEM.Util.GetEnviron("OPENAI_API_KEY")
    }
    If model="" {
        For i=0:1:choices.%Size()-1 { Set choice=choices.%Get(i) If choice.id=provider Set model=choice.model }
    }
    Do ..Validate(provider,model)
    Quit {"provider":(provider),"model":(model),"api_key":(key)}
}

ClassMethod Metadata(actor As Allfedo.Record.Actor, reference As %String) As %DynamicObject
{
    Set value=$Get(^Allfedo.AISettings(reference))
    If (reference="")||(value="") Throw ##class(%Exception.General).%New("AI_SETTINGS_EXPIRED",1102,,"Personal AI settings expired.")
    Set metadata=##class(Allfedo.Rescue).Parse(value)
    Do ##class(Allfedo.Rescue).Require(metadata."actor_id"=actor.%Id(),"These AI settings belong to another account.")
    If metadata."expires_at"<=##class(Allfedo.Policy).Now() Throw ##class(%Exception.General).%New("AI_SETTINGS_EXPIRED",1102,,"Personal AI settings expired.")
    Quit metadata
}

ClassMethod Read(actor As Allfedo.Record.Actor, reference As %String = "") As %DynamicObject
{
    Do ##class(Allfedo.Rescue).Require(actor.Role="coordinator","Only the coordinator configures planning AI.")
    Do ..PurgeExpired()
    Set defaults=..Default(),personal="",source="default"
    If reference'="" {
        Try { Set personal=..Metadata(actor,reference),source="personal" } Catch error { Set source="expired" }
    }
    Set result={"ok":true,"source":(source),"providers":(..Choices()),"default":{"provider":(defaults.provider),"model":(defaults.model)},"personal":null}
    Do result.default.%Set("available",defaults."api_key"'="","boolean")
    If $IsObject(personal) {
        Set result.personal={"provider":(personal.provider),"model":(personal.model),"expires_at":(##class(Allfedo.Policy).ISO(personal."expires_at"))}
    }
    Quit result
}

ClassMethod Store(actor As Allfedo.Record.Actor, data As %DynamicObject) As %String
{
    Do ##class(Allfedo.Rescue).Require(actor.Role="coordinator","Only the coordinator configures planning AI.")
    Do ##class(Allfedo.Rescue).Require((data.%Size()=3)&&(data.%GetTypeOf("provider")="string")&&(data.%GetTypeOf("model")="string")&&(data.%GetTypeOf("api_key")="string"),"Supply provider, model and api_key only.")
    Do ..Validate(data.provider,data.model)
    Set key=data."api_key"
    Do ##class(Allfedo.Rescue).Require((key'="")&&($Length(key)<=2000)&&('$Find(key,$Char(10)))&&('$Find(key,$Char(13))),"Enter your provider's API key.")
    Do ..PurgeExpired()
    Set reference="Allfedo.Session"_$SYSTEM.Encryption.ToHex($SYSTEM.Encryption.GenCryptRand(16)),properties={"Secret":{"api_key":(key)},"Usage":["CUSTOM"]}
    Set status=##class(%Wallet.KeyValue).Create(reference,properties)
    If $$$ISERR(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
    Try {
        Set metadata={"actor_id":(""_actor.%Id()),"provider":(data.provider),"model":(data.model),"expires_at":(##class(Allfedo.Policy).Now()+3600)}
        Set ^Allfedo.AISettings(reference)=metadata.%ToJSON()
    } Catch error {
        Set removed=##class(%Wallet.Secret).Delete(reference)
        Throw error
    }
    Quit reference
}

ClassMethod Clear(actor As Allfedo.Record.Actor, reference As %String)
{
    If reference="" Quit
    Set value=$Get(^Allfedo.AISettings(reference))
    If value="" Quit
    Set metadata=##class(Allfedo.Rescue).Parse(value)
    Do ##class(Allfedo.Rescue).Require(metadata."actor_id"=actor.%Id(),"These AI settings belong to another account.")
    Do ..Remove(reference)
}

ClassMethod Remove(reference As %String) [ Private ]
{
    Set key="ai-settings:"_reference
    Lock +^Allfedo.Lock(key):5
    If '$Test Throw ##class(%Exception.General).%New("BUSY",1001,,"These AI settings are being updated. Try again shortly.")
    Try {
        If ##class(%Wallet.Secret).Exists(reference) {
            Set status=##class(%Wallet.Secret).Delete(reference)
            If $$$ISERR(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
        }
        Kill ^Allfedo.AISettings(reference)
    } Catch error {
        Lock -^Allfedo.Lock(key)
        Throw error
    }
    Lock -^Allfedo.Lock(key)
}

/// Expired connections are unusable immediately and removed on the next settings request.
ClassMethod PurgeExpired()
{
    Set reference="",now=##class(Allfedo.Policy).Now()
    For {
        Set reference=$Order(^Allfedo.AISettings(reference)) Quit:reference=""
        Set value=$Get(^Allfedo.AISettings(reference))
        Continue:value=""
        Set metadata=##class(Allfedo.Rescue).Parse(value)
        If metadata."expires_at"<=now Do ..Remove(reference)
    }
}

ClassMethod Connection(actor As Allfedo.Record.Actor, reference As %String = "") As %DynamicObject
{
    Do ##class(Allfedo.Rescue).Require(actor.Role="coordinator","Only the coordinator can request planning AI.")
    If reference="" {
        Set connection=..Default(),connection.source="default"
    } Else {
        Set metadata=..Metadata(actor,reference)
        Set secret=##class(Allfedo.Rescue).Parse(##class(%Wallet.KeyValue).GetSecretValue(reference))
        Set connection={"provider":(metadata.provider),"model":(metadata.model),"api_key":(secret."api_key"),"source":"personal"}
    }
    Do ##class(Allfedo.Rescue).Require(connection."api_key"'="","No AI key is configured. Add your key in Settings or use a checked manual plan.")
    Quit connection
}

/// Count default-key attempts under one lock; a lost response never reserves another attempt.
ClassMethod StartRun(run As Allfedo.Record.AgentRun)
{
    If run.CredentialSource'="default" { Do ##class(Allfedo.Rescue).Save(run) Quit }
    Set limit=$SYSTEM.Util.GetEnviron("AI_DAILY_LIMIT")
    If limit="" Set limit=50
    Do ##class(Allfedo.Rescue).Require((limit?1.6N)&&(+limit>0),"AI_DAILY_LIMIT must be a positive whole number.")
    Set day=(##class(Allfedo.Policy).Now()\86400)*86400,key="ai-budget:"_day
    Lock +^Allfedo.Lock(key):5
    If '$Test Throw ##class(%Exception.General).%New("BUSY",1001,,"Planning allowance is busy; try again shortly.")
    Try {
        Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS Total FROM Allfedo_Record.AgentRun WHERE CredentialSource='default' AND StartedAt>=?",day)
        Do ##class(Allfedo.Rescue).QueryOK(query)
        Do ##class(Allfedo.Rescue).Require(query.%Next(),"The planning allowance could not be checked.")
        If query.Total>=limit {
            Set run.CredentialSource="blocked"
            Throw ##class(%Exception.General).%New("DEMO_LIMIT",1101,,"Daily demo AI allowance used.")
        }
        Do ##class(Allfedo.Rescue).Save(run)
    } Catch error {
        Lock -^Allfedo.Lock(key)
        Throw error
    }
    Lock -^Allfedo.Lock(key)
}

ClassMethod Provider(connection As %DynamicObject) As %AI.Provider
{
    Set settings={"api_key":(connection."api_key"),"http_config":{"connect_timeout_secs":10,"request_timeout_secs":20}}
    If connection.provider="openrouter" Set settings."base_url"="https://openrouter.ai/api/v1/"
    Quit ##class(%AI.Provider).Create(connection.provider,settings)
}
}
