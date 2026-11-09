Include %occStatus

/// Local, explicitly fictional partner setup. Never resets food, needs, promises, or existing passwords.
Class Allfedo.Demo Extends %RegisteredObject
{
ClassMethod IsNetwork(networkId As %String) As %Boolean
{
    If networkId="" Quit 0
    Quit $Get(^Allfedo.Demo.Registry(networkId,"owned"))=1
}

ClassMethod Status() As %String
{
    Do ##class(Allfedo.Rescue).Require($SYSTEM.Security.Check("%Admin_Secure","U"),"Local demo setup requires the privileged installer.")
    Set demoNetwork=$Get(^Allfedo.Demo.DefaultNetwork)
    Quit {"ok":true,"provisioned":(..IsNetwork(demoNetwork)),"network_id":(demoNetwork)}.%ToJSON()
}

ClassMethod SeedFromEnvironment() As %String
{
    Set demoLocked=0
    Try {
        Do ##class(Allfedo.Rescue).Require(($TLEVEL=0)&&$SYSTEM.Security.Check("%Admin_Secure","U"),"Local demo setup requires the privileged installer outside a transaction.")
        Set demoInstaller=$USERNAME
        Set demoConfig=##class(Allfedo.Rescue).Parse(..ValidateConfig($SYSTEM.Util.GetEnviron("ALLFEDO_DEMO_CONFIG")))
        Set demoNetwork=demoConfig."network_id", demoProfiles=..Profiles()
        Lock +^Allfedo.Demo.Install:5
        Do ##class(Allfedo.Rescue).Require($Test,"Another local demo setup is running. Retry shortly.")
        Set demoLocked=1, demoKnown=..IsNetwork(demoNetwork), demoDefault=$Get(^Allfedo.Demo.DefaultNetwork)
        Do ##class(Allfedo.Rescue).Require((demoDefault="")||(demoDefault=demoNetwork),"A local demo already exists. Restore its private account file; setup will not replace its users or history.")
        If 'demoKnown {
            Set demoQuery=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 ID FROM Allfedo_Record.Actor WHERE NetworkId=?",demoNetwork)
            Do ##class(Allfedo.Rescue).QueryOK(demoQuery)
            Set demoFound=demoQuery.%Next()
            Do ##class(Allfedo.Rescue).QueryOK(demoQuery)
            Do ##class(Allfedo.Rescue).Require('demoFound,"This network already contains foreign records. No demo ownership was granted.")
        }
        // Check every existing identity before creating anything. Matching passwords never grant ownership.
        For demoKey="northside","harbor","riverside","bridge","coordinator","collector" {
            Set demoAccount=demoConfig.accounts.%Get(demoKey), demoProfile=demoProfiles.%Get(demoKey)
            Set demoUserInfo=..UserInfo(demoAccount.username), demoActor=..FindActor(demoAccount.username)
            Set demoSavedName=$Get(^Allfedo.Demo.Registry(demoNetwork,"accounts",demoKey))
            Do ##class(Allfedo.Rescue).Require((demoSavedName="")||(demoSavedName=demoAccount.username),"The private account file does not match this demo's known users.")
            If $IsObject(demoActor) {
                Do ##class(Allfedo.Rescue).Require(demoKnown&&(demoActor.NetworkId=demoNetwork)&&(demoActor.OrganizationId=demoProfile."organization_id")&&(demoActor.Role=demoProfile.role)&&demoActor.Active,"A demo membership was changed or belongs elsewhere. Setup leaves it untouched.")
            }
            Set demoSavedActor=$Get(^Allfedo.Demo.Registry(demoNetwork,"actors",demoKey))
            If demoSavedActor'="" {
                Do ##class(Allfedo.Rescue).Require($IsObject(demoActor)&&(demoActor.%Id()=demoSavedActor),"A known demo membership is missing or renamed. Restore it before rerunning setup.")
            }
            If demoUserInfo.exists {
                Do ##class(Allfedo.Rescue).Require(demoKnown&&(demoUserInfo.comment=..Owner(demoNetwork,demoKey)),"An existing user is not owned by this demo. No password or account was changed.")
                Do ##class(Allfedo.Rescue).Require(demoUserInfo.enabled&&(demoUserInfo.roles="Allfedo_Partner"),"An existing demo user's access was changed. Setup does not reset access or roles.")
                Do ##class(Allfedo.Rescue).Require(..PasswordMatches(demoAccount.username,demoAccount.password),"A demo password differs from the private file. Setup will not replace it.")
            }
        }
        Set ^Allfedo.Demo.DefaultNetwork=demoNetwork, ^Allfedo.Demo.Registry(demoNetwork,"owned")=1
        Set ^Allfedo.Demo.Registry(demoNetwork,"state")="preparing", demoNew=0, demoSites=0
        For demoKey="northside","harbor","riverside","bridge","coordinator","collector" {
            Set demoAccount=demoConfig.accounts.%Get(demoKey), demoProfile=demoProfiles.%Get(demoKey)
            Set demoUserInfo=..UserInfo(demoAccount.username)
            If 'demoUserInfo.exists {
                Do ..CreateUser(demoAccount.username,demoAccount.password,demoProfile.name,..Owner(demoNetwork,demoKey))
                Set demoNew=demoNew+1
            }
            Set demoActor=..FindActor(demoAccount.username)
            If '$IsObject(demoActor) {
                Set demoActor=##class(Allfedo.Record.Actor).%New()
                Set demoActor.UserName=demoAccount.username, demoActor.NetworkId=demoNetwork, demoActor.OrganizationId=demoProfile."organization_id"
                Set demoActor.DisplayName=demoProfile.name, demoActor.Email=demoProfile.email, demoActor.Role=demoProfile.role
                Do ##class(Allfedo.Rescue).Save(demoActor)
            }
            Set ^Allfedo.Demo.Registry(demoNetwork,"accounts",demoKey)=demoAccount.username
            Set ^Allfedo.Demo.Registry(demoNetwork,"actors",demoKey)=""_demoActor.%Id()
            If demoProfile.%IsDefined("site") {
                Set demoSite=##class(Allfedo.Facts).SiteFor(demoNetwork,demoActor.OrganizationId)
                If '$IsObject(demoSite) {
                    Set demoInput=demoProfile.site, demoInput.revision=0
                    Set demoResult=##class(Allfedo.Rescue).Parse(##class(Allfedo.Rescue).Execute(demoActor.%Id(),"demo:site:"_demoKey,"save_site",demoInput.%ToJSON()))
                    Do ##class(Allfedo.Rescue).Require(demoResult.ok,"A fictional partner profile could not be prepared. Rerun using the same private account file.")
                    Set demoSite=##class(Allfedo.Facts).SiteFor(demoNetwork,demoActor.OrganizationId)
                    Do ##class(Allfedo.Rescue).Require($IsObject(demoSite),"A known demo profile is missing. Setup will not erase its saved history.")
                }
                Set demoSites=demoSites+1
            }
        }
        Set ^Allfedo.Demo.Registry(demoNetwork,"state")="ready"
        Do ##class(Allfedo.Rescue).Require($USERNAME=demoInstaller,"Demo setup did not preserve the installer's identity.")
        Set demoResult={"ok":true,"demo":true,"network_id":(demoNetwork),"accounts":6,"new_accounts":(demoNew),"sites":(demoSites)}
    } Catch demoError {
        If $TLEVEL TROLLBACK
        Set demoMessage=$Select(demoError.Code=1000:demoError.Data,1:"Demo setup could not finish. Keep the same private account file and check the local runtime.")
        Set demoResult={"ok":false,"error":{"code":"DEMO_SETUP_FAILED","message":(demoMessage)}}
    }
    If demoLocked Lock -^Allfedo.Demo.Install
    Quit demoResult.%ToJSON()
}

ClassMethod FindActor(demoUsername As %String) As Allfedo.Record.Actor [ Private ]
{
    Set demoQuery=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Actor WHERE UserName=?",demoUsername)
    Do ##class(Allfedo.Rescue).QueryOK(demoQuery)
    Set demoFound=demoQuery.%Next()
    Do ##class(Allfedo.Rescue).QueryOK(demoQuery)
    If 'demoFound Quit ""
    Quit ##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",demoQuery.ID)
}

ClassMethod Owner(demoNetwork As %String, demoKey As %String) As %String [ Private ]
{
    Quit "Allfedo local demo; network="_demoNetwork_"; profile="_demoKey
}

ClassMethod UserInfo(demoUsername As %String) As %DynamicObject [ Private ]
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    If '##class(Security.Users).Exists(demoUsername,.demoUser) Quit {"exists":false}
    Set demoRoles=""
    For demoRoleIndex=1:1:demoUser.Roles.Count() {
        Set demoRoles=demoRoles_$Select(demoRoles="":"",1:",")_demoUser.Roles.GetAt(demoRoleIndex)
    }
    Quit {"exists":true,"comment":(demoUser.Comment),"roles":(demoRoles),"enabled":(demoUser.Enabled)}
}

ClassMethod PasswordMatches(demoUsername As %String, demoPassword As %String) As %Boolean [ Private ]
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    If '##class(Security.Users).Exists(demoUsername,.demoUser) Quit 0
    Quit ##class(Security.Users).CheckPassword(.demoUser,demoPassword)
}

ClassMethod CreateUser(demoUsername As %String, demoPassword As %String, demoName As %String, demoOwner As %String) [ Private ]
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    If ##class(Security.Users).Exists(demoUsername) Throw ##class(%Exception.General).%New("DEMO_REJECTED",1000,,"A user appeared during setup. No existing account was changed.")
    Set demoStatus=##class(Security.Users).Create(demoUsername,"Allfedo_Partner",demoPassword,demoName,"ALLFEDO","","",0,1,demoOwner)
    If $$$ISERR(demoStatus) Throw ##class(%Exception.StatusException).CreateFromStatus(demoStatus)
}

ClassMethod ValidateConfig(demoJSON As %String) As %String [ Language = python, Private ]
{
    import json
    import re
    config = json.loads(demoJSON)
    keys = {"northside", "harbor", "riverside", "bridge", "coordinator", "collector"}
    if not isinstance(config, dict) or set(config) != {"version", "network_id", "accounts"} or type(config["version"]) is not int or config["version"] != 1:
        raise ValueError("The local demo configuration is invalid.")
    network = config["network_id"]
    if not isinstance(network, str) or not re.fullmatch(r"allfedo-demo-[a-f0-9]{12}", network):
        raise ValueError("The local demo network ID is invalid.")
    accounts = config["accounts"]
    if not isinstance(accounts, dict) or set(accounts) != keys:
        raise ValueError("The local demo needs exactly its six known accounts.")
    for key, account in accounts.items():
        if not isinstance(account, dict) or set(account) != {"username", "password"} or account["username"] != network + "-" + key:
            raise ValueError("The local demo account identity is invalid.")
        if not isinstance(account["password"], str) or len(account["password"]) < 24 or len(account["password"]) > 200:
            raise ValueError("The private demo password is invalid.")
    return json.dumps(config)
}

ClassMethod Profiles() As %DynamicObject [ Private ]
{
    Quit {"northside":{"role":"kitchen","organization_id":"northside-kitchen","name":"Alex Morgan","email":"northside@example.test","site":{"name":"Northside Kitchen","address":"12 Market Lane, London (fictional demo address)","entrance":"Blue side door beside the loading bay. Call on arrival.","time_zone":"Europe/London","contact_phone":"+44 20 7946 0101"}},"harbor":{"role":"kitchen","organization_id":"harbor-kitchen","name":"Robin Clarke","email":"harbor@example.test","site":{"name":"Harbor Kitchen","address":"8 Wharf Street, London (fictional demo address)","entrance":"Rear collection counter; do not use the restaurant entrance.","time_zone":"Europe/London","contact_phone":"+44 20 7946 0102"}},"riverside":{"role":"recipient","organization_id":"riverside-shelter","name":"Jamie Taylor","email":"riverside@example.test","site":{"name":"Riverside Shelter","address":"24 River Road, London (fictional demo address)","entrance":"Ring the service-door bell and ask for the receiving contact.","time_zone":"Europe/London","contact_phone":"+44 20 7946 0103"}},"bridge":{"role":"recipient","organization_id":"bridge-centre","name":"Sam Reed","email":"bridge@example.test","site":{"name":"Bridge Centre","address":"6 Bridge Lane, London (fictional demo address)","entrance":"Use the courtyard entrance; receiving desk is on the ground floor.","time_zone":"Europe/London","contact_phone":"+44 20 7946 0104"}},"coordinator":{"role":"coordinator","organization_id":"rescue-office","name":"Jordan Lee","email":"office@example.test"},"collector":{"role":"collector","organization_id":"rescue-team","name":"Casey Brooks","email":"collection@example.test"}}
}
}
