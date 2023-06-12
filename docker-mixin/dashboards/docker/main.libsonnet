local queries = import 'queries.libsonnet';
local templates = import 'templates.libsonnet';
local panels = import 'panels.libsonnet';
local dashboards = import 'dashboards.libsonnet';

local resourceSet = {
  new(kind, list):: [
    {
      kind: kind,
      metadata: {
        name: key,
      },
      spec: list[key]
    }
    for key in std.objectFields(list)
  ]
};

{
  // note, some of these functions don't use their `config` parameter. However,
  // we still provide it so as to have a consistent interface.
  queries(config): resourceSet.new('Query', queries),
  templates(config): resourceSet.new('Template', templates(queries)),
  panels(config): resourceSet.new('Panel', panels(queries)),
  dashboards(config): resourceSet.new('Dashboard', dashboards(config, templates(queries), panels(queries))),
}