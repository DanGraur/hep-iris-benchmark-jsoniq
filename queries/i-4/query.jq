import module namespace hep = "../common/hep.jq";
declare variable $dataPath as anyURI external := anyURI("../../data/Run2012B_SingleMu.root");

let $histogram := hep:histogramConsts(0, 2000, 100)


let $filtered := (
  for $i in parquet-file($dataPath)
  let $subCount := sum(
      for $j in $i.Jet_pt[]
      return  if ($j > 40) 
              then 1
              else 0
  )
  where $subCount > 1
  return $i.MET_sumet
)

return hep:buildHistogram($filtered, $histogram)
