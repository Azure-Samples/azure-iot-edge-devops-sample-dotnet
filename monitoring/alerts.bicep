param scheduledqueryrules_Iot_Alert_name string = 'Iot Alert'
param IotHubs_IoTStarter_iothub_externalid string = '/subscriptions/0fe1cc35-0cfa-4152-97d7-5dfb45a8d4ba/resourceGroups/IoTStarter-rg/providers/Microsoft.Devices/IotHubs/IoTStarter-iothub'

resource scheduledqueryrules_Iot_Alert_name_resource 'microsoft.insights/scheduledqueryrules@2021-02-01-preview' = {
  name: scheduledqueryrules_Iot_Alert_name
  location: 'eastus'
  properties: {
    description: 'Triggers if there is no update from a device for 5 minutes or longer'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      IotHubs_IoTStarter_iothub_externalid
    ]
    targetResourceTypes: []
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'InsightsMetrics\n| where Name == "edgehub_gettwin_total" or Name == "edgeAgent_total_time_running_correctly_seconds"\n| extend dimensions=parse_json(Tags)\n| extend device = tostring(dimensions.edge_device)\n| project TimeGenerated, device\n| summarize lastUpdateTime= datetime_diff(\'minute\',now(),max(TimeGenerated)) by device'
          timeAggregation: 'Maximum'
          metricMeasureColumn: 'lastUpdateTime'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 5
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {}
  }
}