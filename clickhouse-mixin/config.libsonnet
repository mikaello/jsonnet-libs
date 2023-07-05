{
  _config+:: {
    dashboardTags: ['clickhouse-mixin'],
    dashboardPeriod: 'now-30m',
    dashboardTimezone: 'default',
    dashboardRefresh: '1m',

    // for alerts
    alertsReplicasMaxQueueSize: '99',

    // enable Loki logs
    enableLokiLogs: true,
    // filter all logs results by this
    filterSelector: 'filename=~".*clickhouse.*"',
    //
    logLabels: ['job', 'instance'],
  },
}
