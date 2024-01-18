local g = import 'grafana-builder/grafana.libsonnet';

{
  // The classicNativeHistogramQuantile function is used to calculate quantiles from native histograms or classic histograms.
  nativeClassicHistogramQuantile(percentile, metric, selector, sum_by=[], rate_interval='$__rate_interval')::
    local classicSumBy = if std.length(sum_by) > 0 then ' by (%(lbls)s) ' % { lbls: std.join(',', ['le'] + sum_by) } else ' by (le) ';
    local nativeSumBy = if std.length(sum_by) > 0 then ' by (%(lbls)s) ' % { lbls: std.join(',', sum_by) } else ' ';
    'histogram_quantile(%(percentile)s, sum%(nativeSumBy)s(rate(%(metric)s{%(selector)s}[%(rateInterval)s]))) or histogram_quantile(%(percentile)s, sum%(classicSumBy)s(rate(%(metric)s_bucket{%(selector)s}[%(rateInterval)s])))' % {
      classicSumBy: classicSumBy,
      metric: metric,
      nativeSumBy: nativeSumBy,
      percentile: percentile,
      rateInterval: rate_interval,
      selector: selector,
    },

  // The classicNativeHistogramSumRate function is used to calculate the sum or rate from native histograms or classic histograms.
  nativeClassicHistogramSumRate(metric, selector, rate_interval='$__rate_interval')::
    'histogram_sum(rate(%(metric)s{%(selector)s}[%(rateInterval)s])) or rate(%(metric)s_sum{%(selector)s}[%(rateInterval)s])' % {
      classicSumBy: classicSumBy,
      metric: metric,
      nativeSumBy: nativeSumBy,
      rateInterval: rate_interval,
      selector: selector,
    },

  // The classicNativeHistogramCountRate function is used to calculate the count or rate from native histograms or classic histograms.
  nativeClassicHistogramCountRate(metric, selector, rate_interval='$__rate_interval')::
    'histogram_count(rate(%(metric)s{%(selector)s}[%(rateInterval)s])) or rate(%(metric)s_count{%(selector)s}[%(rateInterval)s])' % {
      classicSumBy: classicSumBy,
      metric: metric,
      nativeSumBy: nativeSumBy,
      rateInterval: rate_interval,
      selector: selector,
    },

  histogramRules(metric, labels, interval='1m')::
    local vars = {
      metric: metric,
      labels_underscore: std.join('_', labels),
      labels_comma: std.join(', ', labels),
      interval: interval,
    };
    [
      {
        record: '%(labels_underscore)s:%(metric)s:99quantile' % vars,
        expr: 'histogram_quantile(0.99, sum(rate(%(metric)s_bucket[%(interval)s])) by (le, %(labels_comma)s))' % vars,
      },
      {
        record: '%(labels_underscore)s:%(metric)s:50quantile' % vars,
        expr: 'histogram_quantile(0.50, sum(rate(%(metric)s_bucket[%(interval)s])) by (le, %(labels_comma)s))' % vars,
      },
      {
        record: '%(labels_underscore)s:%(metric)s:avg' % vars,
        expr: 'sum(rate(%(metric)s_sum[1m])) by (%(labels_comma)s) / sum(rate(%(metric)s_count[%(interval)s])) by (%(labels_comma)s)' % vars,
      },
      {
        record: '%(labels_underscore)s:%(metric)s_bucket:sum_rate' % vars,
        expr: 'sum(rate(%(metric)s_bucket[%(interval)s])) by (le, %(labels_comma)s)' % vars,
      },
      {
        record: '%(labels_underscore)s:%(metric)s_sum:sum_rate' % vars,
        expr: 'sum(rate(%(metric)s_sum[%(interval)s])) by (%(labels_comma)s)' % vars,
      },
      {
        record: '%(labels_underscore)s:%(metric)s_count:sum_rate' % vars,
        expr: 'sum(rate(%(metric)s_count[%(interval)s])) by (%(labels_comma)s)' % vars,
      },
    ],


  // latencyRecordingRulePanel - build a latency panel for a recording rule.
  // - metric: the base metric name (middle part of recording rule name)
  // - selectors: list of selectors which will be added to first part of
  //   recording rule name, and to the query selector itself.
  // - extra_selectors (optional): list of selectors which will be added to the
  //   query selector, but not to the beginnig of the recording rule name.
  //   Useful for external labels.
  // - multiplier (optional): assumes results are in seconds, will multiply
  //   by 1e3 to get ms.  Can be turned off.
  // - sum_by (optional): additional labels to use in the sum by clause, will also be used in the legend
  latencyRecordingRulePanel(metric, selectors, extra_selectors=[], multiplier='1e3', sum_by=[])::
    local labels = std.join('_', [matcher.label for matcher in selectors]);
    local selectorStr = $.toPrometheusSelector(selectors + extra_selectors);
    local sb = ['le'];
    local legend = std.join('', ['{{ %(lb)s }} ' % lb for lb in sum_by]);
    local sumBy = if std.length(sum_by) > 0 then ' by (%(lbls)s) ' % { lbls: std.join(',', sum_by) } else '';
    local sumByHisto = std.join(',', sb + sum_by);
    {
      nullPointMode: 'null as zero',
      yaxes: g.yaxes('ms'),
      targets: [
        {
          expr: 'histogram_quantile(0.99, sum by (%(sumBy)s) (%(labels)s:%(metric)s_bucket:sum_rate%(selector)s)) * %(multiplier)s' % {
            labels: labels,
            metric: metric,
            selector: selectorStr,
            multiplier: multiplier,
            sumBy: sumByHisto,
          },
          format: 'time_series',
          legendFormat: '%(legend)s99th percentile' % legend,
          refId: 'A',
        },
        {
          expr: 'histogram_quantile(0.50, sum by (%(sumBy)s) (%(labels)s:%(metric)s_bucket:sum_rate%(selector)s)) * %(multiplier)s' % {
            labels: labels,
            metric: metric,
            selector: selectorStr,
            multiplier: multiplier,
            sumBy: sumByHisto,
          },
          format: 'time_series',
          legendFormat: '%(legend)s50th percentile' % legend,
          refId: 'B',
        },
        {
          expr: '%(multiplier)s * sum(%(labels)s:%(metric)s_sum:sum_rate%(selector)s)%(sumBy)s / sum(%(labels)s:%(metric)s_count:sum_rate%(selector)s)%(sumBy)s' % {
            labels: labels,
            metric: metric,
            selector: selectorStr,
            multiplier: multiplier,
            sumBy: sumBy,
          },
          format: 'time_series',
          legendFormat: '%(legend)sAverage' % legend,
          refId: 'C',
        },
      ],
    },

  // not in use yet
  // latencyRecordingRulePanelNativeHistogram(metric, selectors, extra_selectors=[], multiplier='1e3', sum_by=[])::
  //   local labels = std.join('_', [matcher.label for matcher in selectors]);
  //   local selectorStr = $.toPrometheusSelector(selectors + extra_selectors);
  //   local sb = ['le'];
  //   local legend = std.join('', ['{{ %(lb)s }} ' % lb for lb in sum_by]);
  //   // sumBy is used in the averge calculation and also for native histograms where 'le' is not used
  //   local sumBy = if std.length(sum_by) > 0 then ' by (%(lbls)s) ' % { lbls: std.join(',', sum_by) } else '';
  //   local sumByHisto = std.join(',', sb + sum_by);
  //   {
  //     nullPointMode: 'null as zero',
  //     yaxes: g.yaxes('ms'),
  //     targets: [
  //       {
  //         expr:
  //           |||
  //             (histogram_quantile(0.99, sum by (%(sumBy)s) (%(labels)s:%(metric)s:sum_rate%(selector)s)) or
  //              histogram_quantile(0.99, sum by (%(sumByHisto)s) (%(labels)s:%(metric)s_bucket:sum_rate%(selector)s))) * %(multiplier)s
  //           ||| % {
  //             labels: labels,
  //             metric: metric,
  //             selector: selectorStr,
  //             multiplier: multiplier,
  //             sumBy: sumBy,
  //             sumByHisto: sumByHisto,
  //           },
  //         format: 'time_series',
  //         legendFormat: '%(legend)s99th percentile' % legend,
  //         refId: 'A',
  //         step: 10,
  //       },
  //       {
  //         expr:
  //           |||
  //             (histogram_quantile(0.50, sum by (%(sumBy)s) (%(labels)s:%(metric)s:sum_rate%(selector)s)) or
  //              histogram_quantile(0.50, sum by (%(sumByHisto)s) (%(labels)s:%(metric)s_bucket:sum_rate%(selector)s))) * %(multiplier)s
  //           ||| % {
  //             labels: labels,
  //             metric: metric,
  //             selector: selectorStr,
  //             multiplier: multiplier,
  //             sumBy: sumBy,
  //             sumByHisto: sumByHisto,
  //           },
  //         format: 'time_series',
  //         legendFormat: '%(legend)s50th percentile' % legend,
  //         refId: 'B',
  //         step: 10,
  //       },
  //       {
  //         expr:
  //           |||
  //             %(multiplier)s * (histogram_sum(sum(%(labels)s:%(metric)s:sum_rate%(selector)s)%(sumBy)s) or sum(%(labels)s:%(metric)s_sum:sum_rate%(selector)s)%(sumBy)s) /
  //             (histogram_count(sum(%(labels)s:%(metric)s:sum_rate%(selector)s)%(sumBy)s) or sum(%(labels)s:%(metric)s_count:sum_rate%(selector)s)%(sumBy)s)
  //           ||| % {
  //             labels: labels,
  //             metric: metric,
  //             selector: selectorStr,
  //             multiplier: multiplier,
  //             sumBy: sumBy,
  //           },
  //         format: 'time_series',
  //         legendFormat: '%(legend)sAverage' % legend,
  //         refId: 'C',
  //         step: 10,
  //       },
  //     ],
  //   },

  selector:: {
    eq(label, value):: { label: label, op: '=', value: value },
    neq(label, value):: { label: label, op: '!=', value: value },
    re(label, value):: { label: label, op: '=~', value: value },
    nre(label, value):: { label: label, op: '!~', value: value },

    // Use with latencyRecordingRulePanel to get the label in the metric name
    // but not in the selector.
    noop(label):: { label: label, op: 'nop' },
  },

  toPrometheusSelector(selector)::
    local pairs = [
      '%(label)s%(op)s"%(value)s"' % matcher
      for matcher in std.filter(function(matcher) matcher.op != 'nop', selector)
    ];
    '{%s}' % std.join(', ', pairs),

  // withRunbookURL - Add/Override the runbook_url annotations for all alerts inside a list of rule groups.
  // - url_format: an URL format for the runbook, the alert name will be substituted in the URL.
  // - groups: the list of rule groups containing alerts.
  withRunbookURL(url_format, groups)::
    local update_rule(rule) =
      if std.objectHas(rule, 'alert')
      then rule {
        annotations+: {
          runbook_url: url_format % rule.alert,
        },
      }
      else rule;
    [
      group {
        rules: [
          update_rule(alert)
          for alert in group.rules
        ],
      }
      for group in groups
    ],

  removeRuleGroup(ruleName):: {
    local removeRuleGroup(rule) = if rule.name == ruleName then null else rule,
    local currentRuleGroups = super.groups,
    groups: std.prune(std.map(removeRuleGroup, currentRuleGroups)),
  },

  removeAlertRuleGroup(ruleName):: {
    prometheusAlerts+:: $.removeRuleGroup(ruleName),
  },

  removeRecordingRuleGroup(ruleName):: {
    prometheusRules+:: $.removeRuleGroup(ruleName),
  },

  overrideAlerts(overrides):: {
    local overrideRule(rule) =
      if 'alert' in rule && std.objectHas(overrides, rule.alert)
      then rule + overrides[rule.alert]
      else rule,
    local overrideInGroup(group) = group { rules: std.map(overrideRule, super.rules) },
    prometheusAlerts+:: {
      groups: std.map(overrideInGroup, super.groups),
    },
  },

  removeAlerts(alerts):: {
    local removeRule(rule) =
      if 'alert' in rule && std.objectHas(alerts, rule.alert)
      then {}
      else rule,
    local removeInGroup(group) = group { rules: std.map(removeRule, super.rules) },
    prometheusAlerts+:: {
      groups: std.prune(std.map(removeInGroup, super.groups)),
    },
  },
}
