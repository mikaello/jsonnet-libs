local queries = import 'queries.libsonnet';
local variables = import 'variables.libsonnet';
local targets = import 'targets.libsonnet';
local panels = import 'panels.libsonnet';
local dashboards = import 'dashboards.libsonnet';

local resourceSet = {
  new(kind, list):: {
    [key]: {
      kind: kind,
      metadata: {
        name: key,
      },
      annotations: {
        docs: list[key].docs,
      },
      spec: list[key].spec,
    }
    for key in std.objectFields(list)
  }
};

{
  // note, some of these functions don't use their `config` parameter. However,
  // we still provide it so as to have a consistent interface.
  queries(config): resourceSet.new('Query', queries),
  variables(config): resourceSet.new('Variable', variables),
  targets(config): resourceSet.new('Target', targets(queries)),
  panels(config): resourceSet.new('Panel', panels(targets(queries))),
  dashboards(config): resourceSet.new('Dashboard', dashboards(config, variables, panels(targets(queries)))),
}