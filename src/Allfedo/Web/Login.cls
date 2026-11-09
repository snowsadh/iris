/// Native password/session login retains IRIS's CSRF fields and account policies.
Class Allfedo.Web.Login Extends %CSP.Login
{
Parameter LOGINTITLE = "Sign in to Allfedo";
Parameter HandleCorsRequest = 0;

ClassMethod DrawTitle(pTitle As %String)
{
    Write "<h1>Allfedo</h1><p>Sign in with the account your food-rescue coordinator invited.</p>"
}

ClassMethod DrawSTYLE()
{
    Write "<style>",!
    Write "*{box-sizing:border-box}body{margin:0;padding:32px 16px;min-height:100vh;display:grid;place-items:center;background:#f5f5f2;color:#29262c;font:15px/1.65 system-ui,sans-serif}",!
    Write "#content{width:min(460px,100%);margin:0;padding:34px 32px;border:1px solid #ded6db;border-radius:6px;background:#fff}",!
    Write "#content h1{margin:0 0 12px;color:#543045;font-size:33px;line-height:1.15;letter-spacing:-1.3px}#content p{margin:0 0 24px;color:#655d66;font-size:14px;line-height:1.75}#content form{margin:0}",!
    Write "#content table,#content tbody,#content tr,#content td{display:block;width:100%!important;height:auto!important;min-height:0;margin:0;padding:0;border:0;background:transparent}#content>div{background:transparent!important}",!
    Write "#content table.login tr{margin-top:18px}#content td.loginCaption{padding-bottom:7px;text-align:left;color:#49333f;font-size:13px;font-weight:600}",!
    Write "#content input[type=text],#content input[type=password]{width:100%;min-height:45px;padding:11px 12px;border:1px solid #bdabb7;border-radius:4px;color:#29262c;background:white;font:16px system-ui,sans-serif}",!
    Write "#content input[type=submit]{width:100%!important;min-height:44px;margin-top:4px;padding:11px 16px;border:1px solid #713c59;border-radius:4px;background:#713c59;color:#fff;font:600 14px system-ui,sans-serif;cursor:pointer}",!
    Write "#content input:focus-visible,#content a:focus-visible{outline:3px solid #b776a0;outline-offset:3px}#content a{color:#713c59}@media(max-width:500px){body{padding:22px 15px}#content{padding:29px 23px}}",!
    Write "</style>",!
}

ClassMethod DrawCSS3STYLE()
{
    Do ..DrawSTYLE()
}
}
