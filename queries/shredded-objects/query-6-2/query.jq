import module namespace hep = "../../common/hep.jq";
import module namespace query-6 = "../query-6-common/common.jq";
declare variable $input-path as anyURI external := anyURI("../../../data/Run2012B_SingleMu.root");

let $filtered :=
  for $event in hep:restructure-data-parquet($input-path)
  where $event.nJet > 2
  let $min-triplet := query-6:find-min-triplet($event)
  return max($min-triplet.btag)

return hep:histogram($filtered, 0, 1, 100)
