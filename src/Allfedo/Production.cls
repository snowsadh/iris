Class Allfedo.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Allfedo.Production" TestingEnabled="true" LogGeneralTraceEvents="true">
  <Description>Food invitations, confirmed collection, receipt, and recoverable partner notifications.</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="Allfedo.Commands" Category="Partners" ClassName="Allfedo.CommandService" PoolSize="0" Enabled="true" Foreground="false" Comment="Uses the authenticated native principal.">
  </Item>
  <Item Name="Allfedo.Rescue" Category="Rescue" ClassName="Allfedo.RescueProcess" PoolSize="2" Enabled="true" Foreground="false"/>
  <Item Name="Allfedo.Agent" Category="Rescue" ClassName="Allfedo.Operation.Agent" PoolSize="1" Enabled="true" Foreground="false">
    <Setting Target="Host" Name="Model">gpt-4.1-mini</Setting>
    <Setting Target="Host" Name="RetryInterval">0</Setting>
    <Setting Target="Host" Name="FailureTimeout">0</Setting>
  </Item>
  <Item Name="Allfedo.Outbox" Category="Partners" ClassName="Allfedo.OutboxService" PoolSize="1" Enabled="true" Foreground="false">
    <Setting Target="Adapter" Name="CallInterval">2</Setting>
  </Item>
  <Item Name="Allfedo.Mail" Category="Partners" ClassName="Allfedo.Operation.Mail" PoolSize="1" Enabled="true" Foreground="false">
    <Setting Target="Adapter" Name="SMTPServer">mailpit</Setting>
    <Setting Target="Adapter" Name="SMTPPort">1025</Setting>
    <Setting Target="Adapter" Name="From">Allfedo &lt;allfedo@example.test&gt;</Setting>
    <Setting Target="Adapter" Name="ContinueAfterBadSend">0</Setting>
    <Setting Target="Host" Name="RetryInterval">0</Setting>
    <Setting Target="Host" Name="FailureTimeout">0</Setting>
  </Item>
</Production>
}
}
